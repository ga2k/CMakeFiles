#!/usr/bin/env python3
"""
YAML to C++ Group Generator
Generates C++ Group module files from YAML form definitions.
"""

import sys
import subprocess
import argparse
import re
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional
import datetime
from dataclasses import dataclass

def ensure_yaml():
    try:
        import yaml
        return yaml
    except ImportError:
        print("pyyaml not found, attempting to install...")
        try:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "pyyaml", "--break-system-packages"])
            import yaml
            return yaml
        except Exception as e:
            print(f"Failed to install pyyaml: {e}")
            sys.exit(1)


yaml = ensure_yaml()

# A C++ numeric literal, optionally signed, optionally hex, optionally carrying an
# integer/float suffix (-1L, 0x10u, 3.0f, 123ULL, .5, 5.). Recognized so it can be
# emitted verbatim instead of being run through int()/float() (which chokes on the
# suffix) or quoted as a string.
_CPP_NUMERIC_LITERAL_RE = re.compile(r'^[+-]?(?:0[xX][0-9a-fA-F]+|\d+\.\d*|\.\d+|\d+)[uUlLfF]*$')

# A bare C++ identifier (wxNOT_FOUND, nullptr, MY_CONSTANT) -- as opposed to a
# quoted piece of text -- recognized so named constants can be emitted verbatim
# instead of being quoted as a string literal.
_CPP_IDENTIFIER_RE = re.compile(r'^[A-Za-z_]\w*$')

class CppGenerator:
    """
    Generates C++23 module (.ixx) files from YAML form definitions: wxWidgets
    Group/Page/WizardPage modules for `groups:`/`pages:`/`wizardpages:` sections.
    See generate_from_yaml() for the single-parse entry point.

    `tables:` sections are no longer generated into C++ at all -- db::TableLoader
    (Libs/Core/src/Table.cpp, hand-written) parses the same `tables:`/`relationships:`
    YAML directly at runtime to CREATE TABLE the schema and CREATE VIEW a
    "<table>_detail" joined view per table with relationships. Reads/writes go through
    the generic db::RowSet (Libs/Core/src/RowSet.ixx) -- no per-table generated struct.
    """

    debugging = False

    quiet: bool = False
    sizer_info = False
    target_type: str = "groups"
    target_class: str = "Group"
    app_target: str = "pass_the_name_of_your_app_target_to_yaml2ui"
    now: str = datetime.datetime.now().date().isoformat() + " " + datetime.datetime.now().time().strftime("%H:%M:%S")
    next_PageType: int = 1000
    export_var: str = "GFX_EXPORT"
    impl_dir: Optional[Path] = None

    @dataclass(frozen=True)
    class SizerProperties:
        position: Optional[Tuple[int, int]]
        span: Optional[Tuple[int, int]]
        rows: int
        cols: int
        kind: str = "flexgrid"
        proportion: int = 0
        growable_rows: List[int] = None
        growable_cols: List[int] = None
        col_width: int = 0
        row_height: int = 0
        hgap: int = 0
        vgap: int = 0
        flag: int = 0  # e.g. wx.ALIGN_RIGHT | wx.EXPAND | wx.ALL
        border: int = 0
        min_size: Optional[Tuple[int, int]] = None
        size: Optional[Tuple[int, int]] = None

    def __init__(self):
        self.control_value_mapping = {
            'Activity': 'hs::NullValue',
            'BitmapToggleButton': 'bool',
            'Button': 'std::string',
            'CheckBox': 'bool',
            'Choice': 'ID::Type',
            'Combo': 'ID::Type',
            'ComplexComboBox': 'ID::Type',
            'DatePicker': 'wxDateTime',
            'ELBox': 'WhoCared',
            'Gauge': 'int',
            'GridCtrl': 'dunno',
            'Group': 'std::string',
            'InfoBar': 'hs::NullType',
            'IntTextCtrl': 'int',
            'MarkupText': 'std::string',
            'MaskedEdit': 'std::string',
            'RadioBox': 'int',
            'RadioButton': 'bool',
            'ScrollBar': 'int',
            'SearchBar': 'std::string',
            'SearchToolBar': 'std::string',
            'Slider': 'int',
            'SpinCtrl': 'int',
            'SpinCtrlDouble': 'double',
            'StaticBox': 'std::string',
            'StaticLine': 'hs::NullValue',
            'StaticText': 'std::string',
            'TextCtrl': 'std::string',
            'ToggleButton': 'bool',
            'TreeCtrl': 'hs::NullValue',
        }

        self.control_default_mapping = {
            'Activity': 'hs::NullValue::Null',
            'BitmapToggleButton': 'false',
            'Button': '""',
            'CheckBox': 'false',
            'Choice': 'ID::Null',
            'Combo': 'ID::Null',
            'ComplexComboBox': 'ID::Null',
            'DatePicker': 'nulldatetime',
            'ELBox': 'WhoCared',
            'Gauge': '0',
            'GridCtrl': 'dunno',
            'Group': '""',
            'InfoBar': 'Null',
            'IntTextCtrl': '0',
            'MarkupText': '""',
            'MaskedEdit': '""',
            'RadioBox': '0',
            'RadioButton': 'false',
            'ScrollBar': '0',
            'SearchBar': '""',
            'SearchToolBar': '""',
            'Slider': '0',
            'SpinCtrl': '0',
            'SpinCtrlDouble': '0',
            'StaticBox': '""',
            'StaticLine': 'hs::NullValue::Null',
            'StaticText': '""',
            'TextCtrl': '""',
            'ToggleButton': 'false',
            'TreeCtrl': 'hs::NullValue::Null',
        }

        self.control_contains_value_mapping = {
            'Activity': False,
            'BitmapButton': False,
            'BitmapToggleButton': False,
            'Button': False,
            'CheckBox': True,
            'Choice': True,
            'Combo': True,
            'ComplexComboBox': True,
            'DateCtrl': True,
            'DatePicker': True,
            'ELBox': True,
            'Gauge': True,
            'GridCtrl': True,
            'Group': False,
            'InfoBar': False,
            'IntTextCtrl': True,
            'MarkupText': True,
            'MaskedEdit': True,
            'OutlineText': False,
            'Page': False,
            'RadioBox': True,
            'RadioButton': True,
            'ScrollBar': True,
            'SearchBar': False,
            'SearchToolBar': False,
            'Slider': True,
            'SpinCtrl': True,
            'SpinCtrlDouble': True,
            'StaticBox': False,
            'StaticLine': False,
            'StaticText': True,
            'TextCtrl': True,
            'ToggleButton': False,
            'TreeCtrl': False,
        }

        # Controls that hold a set of rows rather than one scalar value. The table/field
        # binding machinery (initFromField/where()/commit() on Ctrl) is built around a
        # single-row scalar and doesn't apply to these - see collect_refresh_targets().
        self.multi_row_control_classes = {
            'ListCtrl',
            'ELBox',
        }
        # self.control_to_module = {
        #     'Activity': 'Activity',
        #     'Button': 'Button',
        #     'ToggleButton': 'Button',
        #     'BitmapToggleButton': 'Button',
        #     'CheckBox': 'CheckBox',
        #     'Choice': 'Choice',
        #     'IntChoice': 'Choice',
        #     'ComboBox': 'Combo',
        #     'IntComboBox': 'Combo',
        #     'ComplexComboBox': 'Ctrl.ComplexComboBox',
        #     'DatePicker': 'Date',
        #     'DateCtrl': 'Date',
        #     'ELBox': 'EditableListBox',
        #     'Gauge': 'Gauge',
        #     'GridCtrl': 'Grid',
        #     'AuiInfoBar': 'InfoBar.Aui',
        #     'InfoBar': 'InfoBar',
        #     'MarkupText': 'Markup',
        #     'MaskedEdit': 'MaskedEdit',
        #     'OutlineText': 'OutlineText',
        #     'RadioButton': 'RadioButton',
        #     'RadioBox': 'RadioButton',
        #     'ScrollBar': 'ScrollBar',
        #     'SearchBar': 'Search.Bar',
        #     'SearchToolBar': 'SearchToolBar',
        #     'Slider': 'Slider',
        #     'SpinCtrl': 'Spin',
        #     'SpinCtrlDouble': 'Spin',
        #     'StaticBox': 'StaticBox',
        #     'StaticLine': 'StaticLine',
        #     'StaticText': 'StaticText',
        #     'TextCtrl': 'TextCtrl',
        #     'Toolbar': 'Toolbar',
        #     'TreeCtrl': 'Tree',
        #     'UserBar': 'User.Bar'
        # }

        self.validator_class_mapping = {
            'CapsValidator': 'CapsValidator',
            'GenericValidator': 'GenericValidator',
            'ComboLikeValidator': 'ComboLikeValidator'
        }
        # Validator to module mapping
        self.validator_to_module = {
            'CapsValidator': 'TextCtrl',
            'CapsValidatorBase': 'GenericValidator',
            'ComboLikeCapsValidator': 'GenericValidator',
            'ComboLikeValidator': 'GenericValidator',
            'ComplexComboBoxValidator': 'Ctrl.ComplexComboBox',
            'CurrencyValidator': 'TextCtrl',
            'DateValidator': 'Date',
            'DomainValidator': 'GenericValidator',
            'ELBoxValidator': 'EditableListBox',
            'EmailValidator': 'GenericValidator',
            'GenericValidator': 'GenericValidator',
            'MaskValidator': 'MaskedEdit',
            'PhoneValidator': 'MaskedEdit',
            'TextFilterValidator': 'TextCtrl'
        }
        # Size to wxSize mapping
        self.size_mapping = {
            'sizeCtrlButton': 'sizeCtrlButton',
            'sizeCtrlCheckBox': 'sizeCtrlCheckBox',
            'sizeCtrlELB': 'sizeCtrlELB',
            'sizeCtrlLarge': 'sizeCtrlLarge',
            'sizeCtrlMedium': 'sizeCtrlMedium',
            'sizeCtrlMediumLarge': 'sizeCtrlMediumLarge',
            'sizeCtrlSmall': 'sizeCtrlSmall',
            'sizeCtrlSpin': 'sizeCtrlSpin',
            'sizeNotes': 'sizeNotes',
            'sizeLabel': 'sizeLabel',
            'sizeLabelLarge': 'sizeLabelLarge',
            'sizeLabelMedium': 'sizeLabelMedium',
            'sizeLabelSmall': 'sizeLabelSmall',
            'sizeGroup': 'wxDefaultSize',
            'sizePage': 'wxDefaultSize',
            'sizeWizardPage': 'wxDefaultSize'
        }
        self.event_mapping = {

            'EVT_BUTTON': 'wxEVT_BUTTON',
            'EVT_TOGGLEBUTTON': 'wxEVT_TOGGLEBUTTON',

            'EVT_CHECKBOX': 'wxEVT_CHECKBOX',

            'EVT_CHOICE': 'wxEVT_CHOICE',

            'EVT_COMBOBOX_CLOSEUP': 'wxEVT_COMBOBOX_CLOSEUP',
            'EVT_COMBOBOX_DROPDOWN': 'wxEVT_COMBOBOX_DROPDOWN',
            'EVT_COMBOBOX': 'wxEVT_COMBOBOX',

            'EVT_DATE_CHANGED': 'wxEVT_DATE_CHANGED',

            'EVT_LISTBOX': 'wxEVT_LISTBOX',
            'EVT_LISTBOX_DCLICK': 'wxEVT_LISTBOX_DCLICK',

            'EVT_LIST_BEGIN_LABEL_EDIT': 'wxEVT_LIST_BEGIN_LABEL_EDIT',
            'EVT_LIST_BEGIN_RDRAG': 'wxEVT_LIST_BEGIN_RDRAG',
            'EVT_LIST_CACHE_HINT': 'wxEVT_LIST_CACHE_HINT',
            'EVT_LIST_COL_BEGIN_DRAG': 'wxEVT_LIST_COL_BEGIN_DRAG',
            'EVT_LIST_COL_CLICK': 'wxEVT_LIST_COL_CLICK',
            'EVT_LIST_COL_DRAGGING': 'wxEVT_LIST_COL_DRAGGING',
            'EVT_LIST_COL_END_DRAG': 'wxEVT_LIST_COL_END_DRAG',
            'EVT_LIST_COL_RIGHT_CLICK': 'wxEVT_LIST_COL_RIGHT_CLICK',
            'EVT_LIST_DELETE_ALL_ITEMS': 'wxEVT_LIST_DELETE_ALL_ITEMS',
            'EVT_LIST_DELETE_ITEM': 'wxEVT_LIST_DELETE_ITEM',
            'EVT_LIST_END_LABEL_EDIT': 'wxEVT_LIST_END_LABEL_EDIT',
            'EVT_LIST_INSERT_ITEM': 'wxEVT_LIST_INSERT_ITEM',
            'EVT_LIST_ITEM_ACTIVATED': 'wxEVT_LIST_ITEM_ACTIVATED',
            'EVT_LIST_ITEM_CHECKED': 'wxEVT_LIST_ITEM_CHECKED',
            'EVT_LIST_ITEM_DESELECTED': 'wxEVT_LIST_ITEM_DESELECTED',
            'EVT_LIST_ITEM_FOCUSED': 'wxEVT_LIST_ITEM_FOCUSED',
            'EVT_LIST_ITEM_MIDDLE_CLICK': 'wxEVT_LIST_ITEM_MIDDLE_CLICK',
            'EVT_LIST_ITEM_RIGHT_CLICK': 'wxEVT_LIST_ITEM_RIGHT_CLICK',
            'EVT_LIST_ITEM_SELECTED': 'wxEVT_LIST_ITEM_SELECTED',
            'EVT_LIST_ITEM_UNCHECKED': 'wxEVT_LIST_ITEM_UNCHECKED',
            'EVT_LIST_KEY_DOWN': 'wxEVT_LIST_KEY_DOWN',

            'EVT_RADIOBOX': 'wxEVT_RADIOBOX',

            'EVT_RADIOBUTTON': 'wxEVT_RADIOBUTTON',

            'EVT_SCROLL_TOP': 'wxEVT_SCROLL_TOP',
            'EVT_SCROLL_BOTTOM': 'wxEVT_SCROLL_BOTTOM',
            'EVT_SCROLL_LINEUP': 'wxEVT_SCROLL_LINEUP',
            'EVT_SCROLL_LINEDOWN': 'wxEVT_SCROLL_LINEDOWN',
            'EVT_SCROLL_PAGEUP': 'wxEVT_SCROLL_PAGEUP',
            'EVT_SCROLL_PAGEDOWN': 'wxEVT_SCROLL_PAGEDOWN',
            'EVT_SCROLL_THUMBTRACK': 'wxEVT_SCROLL_THUMBTRACK',
            'EVT_SCROLL_THUMBRELEASE': 'wxEVT_SCROLL_THUMBRELEASE',
            'EVT_SCROLL_CHANGED': 'wxEVT_SCROLL_CHANGED',

            'EVT_SLIDER': 'wxEVT_SLIDER',

            'EVT_SPIN': 'wxEVT_SPIN',
            'EVT_SPINCTRL': 'wxEVT_SPINCTRL',
            'EVT_SPINCTRLDOUBLE': 'wxEVT_SPINCTRLDOUBLE',

            'EVT_TEXT': 'wxEVT_TEXT',
            'EVT_TEXT_ENTER': 'wxEVT_TEXT_ENTER',
            'EVT_TEXT_URL': 'wxEVT_TEXT_URL',
            'EVT_TEXT_MAXLEN': 'wxEVT_TEXT_MAXLEN',

            'EVT_TREE_BEGIN_DRAG': 'wxEVT_TREE_BEGIN_DRAG',
            'EVT_TREE_BEGIN_LABEL_EDIT': 'wxEVT_TREE_BEGIN_LABEL_EDIT',
            'EVT_TREE_BEGIN_RDRAG': 'wxEVT_TREE_BEGIN_RDRAG',
            'EVT_TREE_DELETE_ITEM': 'wxEVT_TREE_DELETE_ITEM',
            'EVT_TREE_END_DRAG': 'wxEVT_TREE_END_DRAG',
            'EVT_TREE_END_LABEL_EDIT': 'wxEVT_TREE_END_LABEL_EDIT',
            'EVT_TREE_GET_INFO': 'wxEVT_TREE_GET_INFO',
            'EVT_TREE_ITEM_GETTOOLTIP': 'wxEVT_TREE_ITEM_GETTOOLTIP',
            'EVT_TREE_ITEM_ACTIVATED': 'wxEVT_TREE_ITEM_ACTIVATED',
            'EVT_TREE_ITEM_COLLAPSED': 'wxEVT_TREE_ITEM_COLLAPSED',
            'EVT_TREE_ITEM_COLLAPSING': 'wxEVT_TREE_ITEM_COLLAPSING',
            'EVT_TREE_ITEM_EXPANDED': 'wxEVT_TREE_ITEM_EXPANDED',
            'EVT_TREE_ITEM_EXPANDING': 'wxEVT_TREE_ITEM_EXPANDING',
            'EVT_TREE_ITEM_MENU': 'wxEVT_TREE_ITEM_MENU',
            'EVT_TREE_ITEM_MIDDLE_CLICK': 'wxEVT_TREE_ITEM_MIDDLE_CLICK',
            'EVT_TREE_ITEM_RIGHT_CLICK': 'wxEVT_TREE_ITEM_RIGHT_CLICK',
            'EVT_TREE_KEY_DOWN': 'wxEVT_TREE_KEY_DOWN',
            'EVT_TREE_SEL_CHANGED': 'wxEVT_TREE_SEL_CHANGED',
            'EVT_TREE_SEL_CHANGING': 'wxEVT_TREE_SEL_CHANGING',
            'EVT_TREE_SET_INFO': 'wxEVT_TREE_SET_INFO',
            'EVT_TREE_STATE_IMAGE_CLICK': 'wxEVT_TREE_STATE_IMAGE_CLICK',

            'EVT_SET_FOCUS': 'wxEVT_SET_FOCUS',
            'EVT_KILL_FOCUS': 'wxEVT_KILL_FOCUS',

            'EVT_MENU': 'wxEVT_MENU',
            'EVT_UPDATE_UI': 'wxEVT_UPDATE_UI',
            'EVT_TOOL': 'wxEVT_TOOL',
            'EVT_TOOL_RCLICKED': 'wxEVT_TOOL_RCLICKED',

            'EVT_SIZE': 'wxEVT_SIZE',
            'EVT_MOVE': 'wxEVT_MOVE',
            'EVT_PAINT': 'wxEVT_PAINT',
            'EVT_IDLE': 'wxEVT_IDLE',
            'EVT_TIMER': 'wxEVT_TIMER',

            'EVT_KEY_DOWN': 'wxEVT_KEY_DOWN',
            'EVT_KEY_UP': 'wxEVT_KEY_UP',
            'EVT_CHAR': 'wxEVT_CHAR',
            'EVT_CHAR_HOOK': 'wxEVT_CHAR_HOOK',

            'EVT_LEFT_DOWN': 'wxEVT_LEFT_DOWN',
            'EVT_LEFT_UP': 'wxEVT_LEFT_UP',
            'EVT_LEFT_DCLICK': 'wxEVT_LEFT_DCLICK',
            'EVT_MIDDLE_DOWN': 'wxEVT_MIDDLE_DOWN',
            'EVT_MIDDLE_UP': 'wxEVT_MIDDLE_UP',
            'EVT_MIDDLE_DCLICK': 'wxEVT_MIDDLE_DCLICK',
            'EVT_RIGHT_DOWN': 'wxEVT_RIGHT_DOWN',
            'EVT_RIGHT_UP': 'wxEVT_RIGHT_UP',
            'EVT_RIGHT_DCLICK': 'wxEVT_RIGHT_DCLICK',
            'EVT_MOTION': 'wxEVT_MOTION',
            'EVT_ENTER_WINDOW': 'wxEVT_ENTER_WINDOW',
            'EVT_LEAVE_WINDOW': 'wxEVT_LEAVE_WINDOW',
            'EVT_MOUSEWHEEL': 'wxEVT_MOUSEWHEEL',
        }

    def be_quiet(self, _quiet: bool) -> None:
        self.quiet = bool(_quiet)

    def show_sizer_info(self, _show: bool) -> None:
        self.sizer_info = bool(_show)

    def _dbg(self, msg: str) -> None:
        """Verbose trace output, gated on the per-file 'debugging: true' YAML key
        (see generate_from_yaml). Always to stderr so it never pollutes generated
        code piped to stdout in single-file mode."""
        if self.debugging:
            print(f"[DEBUG] {msg}", file=sys.stderr)

    def target(self, _targets: str) -> None:
        t = _targets.lower()
        if t == "groups" or t == "group":
            self.target_class = "Group"
            self.target_type = "groups"
        elif t == "pages" or t == "page":
            self.target_class = "Page"
            self.target_type = "pages"
        elif t == "wizardpages" or t == "wizardpage":
            self.target_class = "WizardPage"
            self.target_type = "wizardpages"
        elif t == "wizard":
            self.target_class = "Wizard"
            self.target_type = "wizard"
        elif t == "book":
            self.target_class = "Book"
            self.target_type = "book"
        else:
            raise ValueError(f"Unknown target '{_targets}'")

    def generate_ui_module(self, target_name: str, class_def: Dict[str, Any], yaml_file: Path, top_verbatim: str,
                         output_dir: Optional[Path] = None) -> str:
        """Generate the complete C++ group/page/wizardpage module file (list-based schema)."""
        self._dbg(f"generate_ui_module: '{target_name}' -> {self.target_class} "
                  f"(top-level keys: {list(class_def.keys()) if isinstance(class_def, dict) else class_def})")
        allow = self._allowed_sets()
        self._warn_unknown_keys(class_def, allow["class_def"], f"control class_def '{target_name}'", yaml_file)

        variables_block = self.extract_variables_block(class_def, yaml_file)
        if variables_block:
            self._dbg(f"'{target_name}': variables block: {list(variables_block.keys())}")
        else:
            self._dbg(f"'{target_name}': no 'variables' block")

        code: List[str] = []
        code.append('module;')
        code.append('//')
        # Use YAML file modification time for deterministic headers (prevents needless rebuilds)
        try:
            _mt = datetime.datetime.fromtimestamp(yaml_file.stat().st_mtime)
            _mts = _mt.isoformat(sep=' ', timespec='seconds')
        except Exception:
            _mts = 'unknown'
        code.append(f'// Auto-generated from')
        code.append(f'// {yaml_file} (mtime: {_mts})')
        code.append('')
        code.append('// Make any changes there. This file will be overwritten.')
        code.append('')
        code.append('#include "Core/Core.h"')
        code.append('#include "Core/CoreData.h"')
        code.append('#include "Core/Util.h"')
        code.append('')
        # wx/wx.h omitted intentionally: including it in every generated module's
        # global fragment multiplies its SLoc entries by the number of BMIs, exhausting
        # Clang's 2.1 GB source-location budget.  wx types (wxWindowIDRef, etc.) are
        # reachable via `import SplitterPage;` in the module body, so they don't need
        # to be re-declared here.  See commit 8c24e32 for the Windows precedent.
        code.append('#include "Gfx/gfx_export.h"')
        code.append('#include "Gfx/WidgetsFwd.h"')
        code.append('')
        code.append(f'#include "{self.app_target}/Sizes.h"')
        code.append('')
        code.append('#include <unordered_set>')
        for directive in self.collect_variable_includes(variables_block):
            code.append(f'#include {directive}')
        code.append('')

        layout_key = target_name
        #
        # if ':' not in target_name:
        #     layout_category = "GeneratorSource"
        #     layout_key = target_name
        # else:
        #     layout_category, layout_key = target_name.split(':', 1)
        #     target_name = layout_key

        pascal_name = self.to_pascal_case(target_name)
        class_name = f"{pascal_name}{self.target_class}"

        # Elements are a list in the new schema
        elements = class_def.get('elements', [])
        if not isinstance(elements, list):
            self._dbg(f"'{target_name}': 'elements' is a {type(elements).__name__}, not a list - treating as empty")
            elements = []
        else:
            self._dbg(f"'{target_name}': {len(elements)} element section(s)")

        cpp_class = class_def.get("class_name") or self.to_pascal_case(target_name) + self.target_class

        # Required imports
        required_imports = self.get_required_imports(elements, yaml_file)
        for mod in self.collect_variable_modules(variables_block):
            if mod not in required_imports:
                required_imports.append(mod)

        # A book-container item (book: ... container: true) declares child pages to
        # populate its nested Book with, via the same 'pages' key the book: category's
        # container:false 'populate' flavour uses. Not a widget/element - just gather
        # each child's module for import here; the actual new-Page-call lines are
        # emitted further down, right after this class's own control-grid layout loads.
        book_children = class_def.get('pages')
        if isinstance(book_children, list):
            self._dbg(f"'{target_name}': {len(book_children)} book child page(s) declared under 'pages'")
            for child in book_children:
                if isinstance(child, dict):
                    mod = child.get('module')
                    if isinstance(mod, str) and mod.strip() and mod.strip() not in required_imports:
                        required_imports.append(mod.strip())
            if book_children and "Book" not in required_imports:
                required_imports.append("Book")
        else:
            self._dbg(f"'{target_name}': no book child 'pages' declared")

        # RecordSet-refresh scaffolding (recordset: block) — pages and groups only
        recordset = self.extract_recordset(target_name, class_def, yaml_file) \
            if self.target_type in ("pages", "groups") else None
        if recordset and "DB.RowSet" not in required_imports:
            required_imports.append("DB.RowSet")
        self._dbg(f"'{target_name}': recordset = {recordset}" if recordset
                  else f"'{target_name}': no 'recordset:' block (or not applicable to {self.target_type})")
        module_name = self.extract_module(self.to_pascal_case(target_name), class_def, cpp_class, yaml_file)
        module_list = self.extract_needed_modules(self.to_pascal_case(target_name), class_def, cpp_class, yaml_file)
        export_module = self.extract_export_module(self.to_pascal_case(target_name), class_def, cpp_class, yaml_file)
        if not module_name is None and not module_name == export_module:
            required_imports.append(module_name)
        elif not module_list is None:
            required_imports.extend(module_list)

        true_imports = []
        for module in required_imports:
            if not module == export_module:
                true_imports.append(module)
            else:
                print(f'export_module {export_module} cannot be imported: {target_name} {yaml_file}')
                self._dbg(f"'{target_name}': import '{module}' DROPPED (same as this module's own export_module)")

        self._dbg(f"'{target_name}': resolved imports: {true_imports}")
        imports_formatted = '\n'.join(f"import {module};" for module in true_imports)
        code.append(f'export module {export_module};')
        code.append('')
        code.append(f'{imports_formatted}')
        code.append('')
        code.append('export namespace PageType {')
        code.append(f"const Type {cpp_class}({self.next_PageType});")
        code.append('}')
        code.append('')

        ns = class_def.get("namespace", "wx")
        layout_class_name = class_def.get("layout", self.to_pascal_case(target_name) + self.target_class)

        if ':' not in layout_class_name:
            layout_category = "GeneratorSource"
        else:
            layout_category, layout_class_name = layout_class_name.split(':', 1)

        # Determine base class (Page/Group/WizardPage)
        _, top_base_class = self.extract_control_class(target_name, class_def, yaml_file)

        code.append(f"namespace {ns} {{")
        code.append("")
        self.next_PageType += 1

        # Placement 1: top-level verbatim (inside namespace, before class)
        if isinstance(top_verbatim, str) and top_verbatim.strip():
            for line in top_verbatim.rstrip().splitlines():
                code.append(f"{line}")

        # alt_data_source: emit each control's generated DBSource policy struct (namespace
        # scope, non-exported) before the class that names it as a template argument. Backed
        # by the generic db::Row (DB.RowSet) -- value_field is assumed integer-typed (id/FK),
        # matching every real usage (a lookup table's id, populating an ID::Type-valued control).
        for var, tag, alt_ds, data_type in self.collect_alt_data_sources(elements, yaml_file):
            struct_name = f"{tag}DBSource"
            value_get = f'r.get<int>("{alt_ds["value_field"]}")'
            value_expr = f"ID::Type({value_get})" if data_type == "ID::Type" else value_get
            code.append(f"struct {struct_name} {{")
            code.append(f'   static auto table() -> std::string {{ return "{alt_ds["table"]}"; }}')
            code.append(f'   static auto displayText(const db::Row &r) -> std::string {{ return r.get<std::string>("{alt_ds["display_field"]}"); }}')
            code.append(f"   static auto value(const db::Row &r) -> {data_type} {{ return {value_expr}; }}")
            code.append(f"   static constexpr auto includeBlank() -> bool {{ return {'true' if alt_ds['include_blank'] else 'false'}; }}")
            code.append(f'   static auto blankText() -> std::string {{ return "{alt_ds["blank_text"]}"; }}')
            code.append("};")
            code.append("")

        code.append(f"export class {self.export_var} {cpp_class} : public {top_base_class} {{")
        code.append("   std::filesystem::path layoutPath;")
        code.append("   std::string layoutKey;")

        # The generated ctor parameter is always named 'args' (see ctor signature
        # emission below), regardless of whether this page/group declares its own
        # class_args.args_in factory. Children that don't supply their own
        # 'args:' block must receive that same parameter unaltered, not a
        # hardcoded nullanymap — so this is set unconditionally rather than only when
        # a factory is built.
        parent_args_var_for_children: Optional[str] = "args"
        page_extract_inside_entries: List[Tuple[str, str, bool, str, str, Any]] = []

        # Class-level (class_args:) args map and extract_inside entries at top of ctor
        page_args_factory: Optional[str] = None
        page_args_var: Optional[str] = None
        merge_helper_name: Optional[str] = None
        has_class_args = False
        packed_args_in = self._emit_page_scope_args(target_name, class_def, yaml_file)
        if packed_args_in is not None:
            emplace_lines, page_args_var, page_extract_inside_entries = packed_args_in
            if emplace_lines:
                has_class_args = True
                # Clang 21 previously crashed (infinite recursion in getTypeInfoImpl) on
                # a static anymap variable brace-aggregate-initialized with std::any
                # values inside a C++ module — class-level inline or function-local,
                # didn't matter, as long as the whole map came from one initializer_list
                # expression. Building the map with sequential .emplace() calls instead
                # (one std::any construction per statement, never inside a brace-init
                # list) avoids that expression shape entirely. The same reasoning rules
                # out a static anymap *member* for class_args' own defaults -- it's
                # regenerated by this same factory function, called fresh at every merge
                # site below (merge() drains its source, so reusing one instance across
                # calls would silently empty it out after the first construction).
                page_args_factory = f"{page_args_var}Default"
                code.append(f"   static auto {page_args_factory}() -> anymap {{")
                code.append("      anymap m;")
                code.extend(emplace_lines)
                code.append("      return m;")
                code.append("   }")
                # param calls in the body use 'args' (the ctor parameter); the
                # factory function above only supplies the ctor's default argument.

                # merge() returns void, so it can't sit inline as the anymap argument to
                # the base-class constructor call below -- this helper mutates the
                # caller's own 'args' local in place (by reference) and hands back a
                # reference to it, so later body code (extract_inside's param() calls)
                # sees the filled-in class defaults too.
                merge_helper_name = f"{page_args_var}Merged"
                code.append(f"   static auto {merge_helper_name}(anymap &a) -> anymap & {{")
                code.append(f"      a.merge({page_args_factory}());")
                code.append("      return a;")
                code.append("   }")

        # Impl dir/stub path determined early: both the on_set_active/on_kill_active
        # overrides and 'functions:' entries may need to be stubbed out here.
        if self.impl_dir is not None:
            impl_dir = self.impl_dir
        elif output_dir is not None:
            impl_dir = output_dir / "impl"
        else:
            impl_dir = yaml_file.parent / "impl"
        stub_path = impl_dir / f"{cpp_class}_impl.cpp"

        kill_declared, on_kill_active = self.extract_group_method_body('on_kill_active', target_name, class_def, yaml_file)
        set_declared, on_set_active = self.extract_group_method_body('on_set_active', target_name, class_def, yaml_file)
        event_declared, on_event = self.extract_group_method_body('on_event', target_name, class_def, yaml_file)
        self._dbg(f"'{target_name}': on_kill_active declared={kill_declared} (has body={on_kill_active is not None}), "
                  f"on_set_active declared={set_declared} (has body={on_set_active is not None}), "
                  f"on_event declared={event_declared} (has body={on_event is not None})")
        # refreshFromCurrent() always hands off to refreshEx() so hand-written
        # tweaks to freshly-loaded field values have a stable, never-overwritten home.
        refresh_ex_declared = recordset is not None
        if kill_declared or set_declared or event_declared or refresh_ex_declared:
            code.append("")
            code.append("protected:")
            code.append("   // OnKillActive/SetActive/onEvent overrides")
            if kill_declared:
                note = "" if on_kill_active is not None else f"  // Implemented in {stub_path}"
                code.append(f"   auto onKillActive(bool autoDisable) -> void override;{note}")
            if set_declared:
                note = "" if on_set_active is not None else f"  // Implemented in {stub_path}"
                code.append(f"   auto onSetActive(bool autoEnable) -> void override;{note}")
            if event_declared:
                note = "" if on_event is not None else f"  // Implemented in {stub_path}"
                code.append(f"   auto onEvent(sig::RecordSetEvent event) -> void override;{note}")
            if refresh_ex_declared:
                code.append(f"   auto refreshEx(const db::Row *rec) -> void;  // Implemented in {stub_path}")

        # Declarations
        control_decls = self.generate_control_declarations(elements, yaml_file)
        self._dbg(f"'{target_name}': {len(control_decls)} member declaration line(s) generated"
                  if control_decls else f"'{target_name}': NO control declarations generated from 'elements'")
        code.append("")
        code.append('\n'.join(control_decls) if control_decls else '   // No elements defined')

        # RecordSet members (pages own the shared_ptr and the Move* subscription)
        if recordset and self.target_type == "pages":
            if not (kill_declared or set_declared):
                code.append("")
                code.append("protected:")
            code.append(f"   using rs_t = std::shared_ptr<db::RowSet>;")
            code.append(f"   rs_t m_rs;")
            code.append( "   size_t m_moveHandle{};")

        # Custom member variables (variables: block) — grouped under explicit access
        # specifiers so placement here is independent of whatever access level the
        # preceding declarations left the class in.
        variable_access_groups = {'public': [], 'protected': [], 'private': []}
        for var_name, var_def in variables_block.items():
            variable_access_groups[var_def['access']].append(self.format_variable_declaration(var_name, var_def))

        def format_variable_access_block(access_name: str, decls: List[str]) -> str:
            if not decls:
                return ""
            return f"\n{access_name}:\n" + '\n'.join(decls)

        variables_public_block = format_variable_access_block('public', variable_access_groups['public'])
        variables_protected_block = format_variable_access_block('protected', variable_access_groups['protected'])
        variables_private_block = format_variable_access_block('private', variable_access_groups['private'])
        if variables_public_block:     code.append(variables_public_block)
        if variables_protected_block:  code.append(variables_protected_block)
        if variables_private_block:    code.append(variables_private_block)

        # Functions (group/page level) inside class
        functions_all = self._validate_functions(class_def.get('functions'))
        access_groups = {'public': [], 'protected': [], 'private': []}
        for fname, fdef in functions_all.items():
            args = fdef['args']
            ret = fdef['return']
            body = fdef['body']
            const_suffix = " const" if fdef['const'] else ""
            static_prefix = "static " if fdef['static'] else ""
            override_suffix = " override" if fdef['override'] else ""
            noexcept_suffix = self._format_noexcept(fdef.get('noexcept', False))
            if body is None:
                fn_text = (
                    f"   {static_prefix}auto {fname} ({args})"
                    f"{const_suffix}{noexcept_suffix} -> {ret}{override_suffix};"
                    f"  // Implemented in {stub_path}"
                )
            else:
                body = body.replace('\r\n', '\n').replace('\r', '\n')
                body_lines = body.split('\n')
                indented_body = '\n'.join(f"      {line}" if line else "" for line in body_lines)
                fn_text = (
                    f"   {static_prefix}auto {fname} ({args}){const_suffix}{noexcept_suffix} -> {ret}{override_suffix} {{\n"
                    f"{indented_body}"
                    f"   }}"
                )
            access_groups[fdef['access']].append(fn_text)

        # Generated refreshFromCurrent(): pages read the current record from m_rs and fan
        # out; groups receive the record and initialize their field-bound controls. Records
        # are always db::Row -- there's no per-table generated struct, so every field read
        # goes through get<T>(name), always wrapped in optional<> so a NULL column never
        # throws (wx::initFromField already handles the optional-empty case by leaving the
        # control untouched).
        if recordset:
            bound_controls, group_members = self.collect_refresh_targets(elements, yaml_file)
            rfc: List[str] = []
            if self.target_type == "pages":
                rfc.append( "   auto refreshFromCurrent () -> void {")
                rfc.append( "      const db::Row *rec = m_rs ? m_rs->current() : nullptr;")
                rfc.append( "      if (!rec)")
                rfc.append( "         return;")
            else:  # groups
                rfc.append( "   auto refreshFromCurrent (const db::Row *rec) -> void {")
                rfc.append( "      if (!rec)")
                rfc.append( "         return;")
            for var, fld, cpp_type in bound_controls:
                rfc.append(f'      wx::initFromField({var}, rec->get<std::optional<{cpp_type}>>("{fld}"));')
                # Retarget the control's commit() UPDATE at the current record
                rfc.append(f'      {var}->where("id = " + std::to_string(rec->get<int>("id")));')
            for var in group_members:
                # Guarded: a nested group without its own recordset: is skipped instead of
                # breaking the build.
                rfc.append(f"      if constexpr (requires {{ {var}->refreshFromCurrent(rec); }})")
                rfc.append(f"         {var}->refreshFromCurrent(rec);")
            rfc.append("      refreshEx(rec);")
            # initFromField()/pushToCtrl() above only paint the raw ValueT (e.g. cents
            # as a plain int) onto the native control; validators (e.g. CurrencyValidator's
            # cents -> "$123.45" formatting) only run via transferToWindow(), so re-run it
            # here or freshly-displayed records show unformatted raw values until the user
            # starts editing (which is the only other place transferToWindow() is invoked).
            rfc.append("      ICtrl::transferTheseToWindow(controlMap());")
            rfc.append("   }")
            access_groups['public'].append('\n'.join(rfc))

            # Method to reload the table from the physical db on disk

            rt: List[str] = []
            tbl = recordset['table']
            order_by = recordset['order_by']

            if self.target_type == "pages" and tbl is not None:
                rt.append(f'   auto reloadTable (const std::string &t = "{tbl}") -> rs_t {{')
                rt.append( '      auto db = db::db();')
                rt.append( '      if (!db)')
                rt.append( '         return nullptr;')
                rt.append( '      auto table = db->getTable(t);')
                rt.append( '      if (!table)')
                rt.append( '         return nullptr;')
                rt.append( '   ')
                rt.append( '      auto rs = std::make_shared<db::RowSet>(*table);')
                rt.append(''   )
                rt.append( "      // Same order as select()'s list query, so the list's displayed order and the")
                rt.append( "      // recordset's navigation order agree (clicking a row and Prev/Next-ing from it")
                rt.append( "      // should walk the same sequence).")
                rt.append(''   )
                rt.append(f'      if (!rs->load("", "{order_by}")) {{ // false = the query itself failed')
                rt.append( '         doutif(TraceLevel::Info) << "initial query failed: " << rs->lastError_ << std::endl;')
                rt.append('          return nullptr;')
                rt.append( '      }')
                rt.append( '      const db::Row *rec = rs->moveLast(); // nullptr = rows_ is empty')
                rt.append(f'      if (rec)')
                rt.append( '          doutif(TraceLevel::Info) << "got record id " << rec->get<int>("id") << std::endl;')
                rt.append( '')
                rt.append(f'      db::rsInterface()->select(rs); // buttons now gate on the REAL recordset')
                rt.append( '      return rs;')
                rt.append( '   }')
                access_groups['public'].append('\n'.join(rt))

        def format_access_block(access_name: str, fns: List[str]) -> str:
            if not fns:
                return ""
            return f"\n{access_name}:\n" + '\n'.join(fns)

        public_access_block = format_access_block('public', access_groups['public'])
        protected_access_block = format_access_block('protected', access_groups['protected'])
        private_access_block = format_access_block('private', access_groups['private'])

        if public_access_block:     code.append(public_access_block)
        if protected_access_block:  code.append(protected_access_block)
        if private_access_block:    code.append(private_access_block)

        code.append("")
        code.append("public:")
        if recordset and self.target_type == "pages":
            # The Subscribe lambda in the ctor captures 'this' — must unsubscribe.
            code.append(f"   ~{cpp_class}() override {{ sig::recordSetSignal().Unsubscribe(m_moveHandle); }}")
        else:
            code.append(f"   ~{cpp_class}() override = default;")
        code.append("")

        # Constructor signature and base ctor call.
        # The ctor parameter itself (named 'args') is what param() reads from in the
        # body (to stay non-circular) and what gets forwarded unaltered to children;
        # the default *value* for that parameter comes from the emplace-based factory
        # function when args_in triplets were declared, else the empty nullanymap.
        # When this class declares class_args, 'args' must be a by-value parameter
        # (not const anymap&) so {merge_helper_name}(args) -- which mutates it via
        # unordered_map::merge -- can be called on it; classes without class_args keep
        # the original const-ref parameter unchanged.
        default_args_expr = f"{page_args_factory}()" if page_args_factory else "nullanymap"
        args_param_type = "anymap " if has_class_args else "const anymap &"
        value_default = "PageType::Null" if top_base_class == "Page" else "std::string{}"
        pad1: str = " " * len(f"   explicit {cpp_class} ( ")
        if self.target_type == "pages":
            code.append(f"   explicit {cpp_class} ( Book *book, ")
            code.append(f"{pad1}wxWindowIDRef id, ")
            code.append(f"{pad1}const std::string& name,")
            code.append(f"{pad1}PageType::Type type = PageType::{cpp_class},")
            code.append(f"{pad1}int imageIndex = -1,")
            code.append(f"{pad1}{args_param_type}args = {default_args_expr})")
            if has_class_args:
                code.append(f"      : {top_base_class} (book, id, name, type, imageIndex, {merge_helper_name}(args)) {{")
            else:
                code.append(f"      : {top_base_class} (book, id, name, type, imageIndex, args) {{")
        else:
            code.append(f"   explicit {cpp_class} ( UICreateFlags cflags, ")
            code.append(f"{pad1}std::string name, ")
            code.append(f"{pad1}wxWindow *pParent, ")
            code.append(f"{pad1}value_t value = {value_default},")
            code.append(f"{pad1}{args_param_type}args = {default_args_expr},")
            code.append(f"{pad1}long style = 0)")
            if has_class_args:
                code.append(f"      : {top_base_class} (cflags, name, pParent, value, {merge_helper_name}(args), style) {{")
            else:
                code.append(f"      : {top_base_class} (cflags, name, pParent, value, args, style) {{")

        # class_args: feed the Interface-level creationArgs() storage too (fresh
        # factory call, independent of the merge above) so post-construction reads of
        # creationArgs() also see the filled-in class defaults. Interface:: is
        # explicitly qualified because Group also inherits mergeWithCreationArgs from
        # Ctrl (via StaticBox), making an unqualified call ambiguous there.
        if has_class_args:
            code.append(f"      this->Interface::mergeWithCreationArgs({page_args_factory}());")

        # class_args.extract_inside at ctor top
        if page_extract_inside_entries:
            for var_name, ty, no_auto, map_name, entry_name, default in page_extract_inside_entries:
                lit = self._format_cpp_literal(default, ty, string_style="construct")
                prefix = "" if no_auto else "auto "
                code.append(f'      {prefix}{var_name} = param({map_name}, "{entry_name}", {lit});')
            # code.append("")

        # Layout boilerplate
        code.append(
            f'      layoutPath = Util::getInstance().resourceName(UIType::{layout_category}, "{layout_class_name}", false, nullptr);')
        code.append(
            f'      ASSERT_MSG(!layoutPath.empty(), "Couldn\'t find layout resource \'{layout_class_name}\'");')
        code.append(f'      layoutKey = "{layout_key}";')
        code.append("")

        # # Page-level sizer properties. Needed before any placement calls.

        # if self.sizer_info:
        #     # Get sizer information
        #     sizer_def = class_def.get('sizer')
        #     if sizer_def:
        #         sizer_properties: CppGenerator.SizerProperties = self.extract_sizer(sizer_def)
        #         code.append(f'      /*')
        #         code.append(f'       * Sizer information for {self.target_class}:')
        #         code.append(f'       *')
        #         code.append(f'       *        border : {sizer_properties.border}')
        #         code.append(f'       *     col_width : {sizer_properties.col_width}')
        #         code.append(f'       *          cols : {sizer_properties.cols}')
        #         code.append(f'       *          flag : {sizer_properties.flag}')
        #         code.append(f'       * growable_cols : {sizer_properties.growable_cols}')
        #         code.append(f'       * growable_rows : {sizer_properties.growable_rows}')
        #         code.append(f'       *          hgap : {sizer_properties.hgap}')
        #         code.append(f'       *          kind : {sizer_properties.kind}')
        #         code.append(f'       *      min_size : {sizer_properties.min_size}')
        #         code.append(f'       *      position : {sizer_properties.position}')
        #         code.append(f'       *    proportion : {sizer_properties.proportion}')
        #         code.append(f'       *    row_height : {sizer_properties.row_height}')
        #         code.append(f'       *          rows : {sizer_properties.rows}')
        #         code.append(f'       *          size : {sizer_properties.size}')
        #         code.append(f'       *          span : {sizer_properties.span}')
        #         code.append(f'       *          vgap : {sizer_properties.vgap}')
        #         code.append(f'       */')
        #         code.append(f'')

        # Creation code for list-based elements
        creation_code, target_parent = self.generate_control_creation(target_name, elements, layout_class_name,
                                                                      yaml_file,
                                                                      parent_args_var_for_children)

        self._dbg(f"'{target_name}': generate_control_creation -> {len(creation_code)} line(s), "
                  f"target_parent='{target_parent}'")
        if creation_code:

            code.append(f'      auto targetParent = {target_parent};')
            code.append('')
            code.append('\n'.join(creation_code))

        else:
            self._dbg(f"'{target_name}': NO control creation code produced - class body will have an empty ctor")
            code.append('      // No control creation code\n')

        # RecordSet Move* subscription: refresh the page when the RecordSetInterface
        # navigates. Suspended until onSetActive resumes it (per-subscription).
        if recordset and self.target_type == "pages":
            code.append("")
            code.append("      m_moveHandle = sig::recordSetSignal().Subscribe([this](auto) { refreshFromCurrent(); },")
            code.append("                                                     sig::RecordSetEvent::MoveFirst, sig::RecordSetEvent::MovePrevious,")
            code.append("                                                     sig::RecordSetEvent::MoveNext, sig::RecordSetEvent::MoveLast,")
            code.append("                                                     sig::RecordSetEvent::MoveAbsolute);")
            code.append("      sig::recordSetSignal().suspendSignals(m_moveHandle);")
            code.append("")

        # Placement: finally (before loadLayout). Spliced in here, rather than at the
        # end of the ctor, so a finally block's effects (state/widgets it sets up) are
        # already in place by the time loadLayout's resolution pass runs, instead of
        # only existing after layout has already completed.
        finally_block = self._extract_finally_begin(class_def)
        if isinstance(finally_block, str) and finally_block.strip():
            for line in finally_block.rstrip().splitlines():
                code.append(f"      {line}")

        code.append(
            '      VERIFY_MSG(this->loadLayout(layoutPath, layoutKey), "Error loading layout resource " + layoutPath.string());')

        if self.target_type == 'wizardpages':
            code.append("      GetPageSizer().Add(&grid(), 1, wxALL | wxGROW);")
        elif self.target_type == 'pages':
            if isinstance(book_children, list) and book_children:
                if not isinstance(top_base_class, str) or "PageContainer" not in top_base_class:
                    print(f"Warning: '{target_name}' declares 'pages' (book children) but base_class "
                          f"'{top_base_class}' does not derive from PageContainer; book() won't exist "
                          f"{yaml_file}", file=sys.stderr)
                code.append("      load();")
                code.extend(self._generate_book_child_calls(target_name, book_children, "this->book()", yaml_file,
                                                            parent_args_var="args"))

        # Placement: sizer fit/freeze (end of ctor) - after loadLayout and any book
        # children, so controls added by either are accounted for in the fit instead
        # of being tacked onto an already-sized page.
        if self.target_type == 'wizardpages':
            code.append('      SetSizerAndFit(&GetPageSizer(), true);')
        elif self.target_type == 'pages':
            code.append('      if (getForm())')
            code.append('         getForm()->SetSizerAndFit(&grid(), true);')

        code.append("   }")
        code.append("};")

        if on_kill_active is not None or on_set_active is not None or on_event is not None:
            code.append("")
            if on_kill_active is not None:
                code.append(f"auto {cpp_class}::onKillActive(bool autoDisable) -> void {{")
                code.append(f"{on_kill_active}")
                code.append(f"}}")
            if on_set_active is not None:
                code.append(f"auto {cpp_class}::onSetActive(bool autoEnable) -> void {{")
                code.append(f"{on_set_active}")
                code.append(f"}}")
            if on_event is not None:
                code.append(f"auto {cpp_class}::onEvent(sig::RecordSetEvent event) -> void {{")
                code.append(f"{on_event}")
                code.append(f"}}")

        code.append(f"}} // namespace {ns}")

        # Write _impl.cpp stub for any declaration-only functions (no body: key in YAML)
        stub_fns = {n: d for n, d in functions_all.items() if d['body'] is None}
        if kill_declared and on_kill_active is None:
            stub_fns['onKillActive'] = {
                'args': 'bool autoDisable', 'return': 'void', 'const': False, 'override': True,
                'stub_body': [
                    "    // Interface::onKillActive(autoDisable); must be called at some point",
                    "    Interface::onKillActive(autoDisable);",
                ],
            }
        if set_declared and on_set_active is None:
            stub_fns['onSetActive'] = {
                'args': 'bool autoEnable', 'return': 'void', 'const': False, 'override': True,
                'stub_body': [
                    "    // Interface::onSetActive(autoEnable); must be called at some point",
                    "    Interface::onSetActive(autoEnable);",
                ],
            }
        if event_declared and on_event is None:
            stub_fns['onEvent'] = {
                'args': 'sig::RecordSetEvent event', 'return': 'void', 'const': False, 'override': True,
                'stub_body': [
                    "    Interface::onEvent(event);",
                ],
            }
        if refresh_ex_declared:
            stub_fns['refreshEx'] = {
                'args': "const db::Row *rec", 'return': 'void', 'const': False, 'override': False,
                'stub_body': [
                    "    // Tweak values set by refreshFromCurrent() here.",
                ],
            }
        if stub_fns:
            self._dbg(f"'{target_name}': writing impl stub(s) for {list(stub_fns.keys())} to {stub_path}")
            self._write_impl_stub(impl_dir, cpp_class, export_module, ns, stub_fns)

        self._dbg(f"'{target_name}': generate_ui_module complete, {len(code)} line(s) of C++ generated")
        return "\n".join(code)

    # Default cancel-dialog text, mirrored from Wizard::cancelMessage()'s own default in
    # Gfx (Libs/Gfx/src/interface/wizard/Wizard.cpp) so a partial 'cancel_message:'
    # override (only sub_heading, or only body) can fall back to the same text.
    _DEFAULT_CANCEL_SUB_HEADING = "Setup is incomplete"
    _DEFAULT_CANCEL_BODY = "<p>The wizard was canceled.</p><p>Setup is incomplete; exiting.</p>"

    def _cpp_string_literal(self, s: str) -> str:
        """Escape a Python string for embedding as a C++ string literal body (no surrounding quotes)."""
        return str(s).replace("\\", "\\\\").replace('"', '\\"')

    def generate_wizard_module(self, target_name: str, class_def: Dict[str, Any], yaml_file: Path,
                               output_dir: Optional[Path] = None) -> str:
        """Generate a Wizard-container module: a Wizard subclass (ctor(wxFrame*, std::string,
           anymap = <class default>), source-compatible with the DBManager.cpp call-site
           contract, which always passes args explicitly) that chains a declared sequence of
           already-generated WizardPage classes in order.

           Unlike groups/pages/wizardpages, a wizard's 'pages:' list describes class
           instantiations to chain together, not physical controls on a sizer grid, so this
           does not reuse the elements/control schema or generate_ui_module."""
        allow = self._allowed_sets()
        self._warn_unknown_keys(class_def, allow["wizard_def"], f"wizard '{target_name}'", yaml_file)

        pascal_name = self.to_pascal_case(target_name)
        cpp_class = class_def.get("class") or f"{pascal_name}Wizard"
        if not isinstance(cpp_class, str) or not cpp_class.strip():
            print(f"Warning: wizard '{target_name}' 'class' must be a non-empty string; defaulting", file=sys.stderr)
            cpp_class = f"{pascal_name}Wizard"
        cpp_class = cpp_class.strip()

        export_module = class_def.get("module") or f"{pascal_name}.Wizard"
        if not isinstance(export_module, str) or not export_module.strip():
            print(f"Warning: wizard '{target_name}' 'module' must be a non-empty string; defaulting", file=sys.stderr)
            export_module = f"{pascal_name}.Wizard"
        export_module = export_module.strip()

        # class_args: args_in gets the same factory/merge treatment as Page/Group's class_args
        # (see generate_ui_module) -- a private static '{arg_name}Default()' factory and
        # '{arg_name}Merged(anymap&)' merge helper, with the ctor's 'args' parameter defaulted
        # to the factory and merged in before the body (so page_call_lines below, and any
        # if:/header.condition: param<bool>(args, ...) reads, see the merged result). Wizard
        # doesn't derive from Interface (unlike Page/Group/WizardPage), so there's no
        # mergeWithCreationArgs()/creationArgs() call to make here -- Wizard::args() (its own
        # stored anymap) is fed straight from the ctor parameter instead.
        # extract_inside/extract_before/extract_after are still not supported: wizard_class_args
        # only allows arg_name/args_in (see _allowed_sets()["wizard_class_args_def"]) since a
        # wizard's own body has no per-page scope to extract into -- extraction still belongs on
        # each 'pages:' entry's own 'args:' block. Declared args_in names are also used to
        # validate 'if:'/header 'condition:' keys on page entries below.
        declared_arg_names: set[str] = set()
        wizard_args_var: Optional[str] = None
        wizard_args_factory: Optional[str] = None
        wizard_merge_helper_name: Optional[str] = None
        wizard_emplace_lines: List[str] = []
        args_node = class_def.get("class_args")
        if args_node is not None:
            if isinstance(args_node, dict) and any(
                    args_node.get(k) for k in ("extract_inside", "extract_before", "extract_after")):
                print(f"Warning: wizard '{target_name}' class_args does not support extraction -- "
                      f"a wizard's own body has no per-page scope to extract into; put "
                      f"extract_before/extract_after on the individual page entry's own 'args:' "
                      f"block instead {yaml_file}", file=sys.stderr)
            wizard_args_var, ins, _translate, _extracts = self._parse_args_block(
                args_node, f"wizard '{target_name}'", yaml_file, schema="wizard_class_args")
            declared_arg_names = {n for n, _, _ in ins}
            if wizard_args_var:
                for name_in, type_in, default_in in ins:
                    lit = self._format_cpp_literal(default_in, type_in, string_style="construct")
                    wizard_emplace_lines.append(f'         m.emplace("{name_in}", std::any({lit}));')

        cancel_message = class_def.get("cancel_message")
        required_imports: set[str] = {"Wizard", "WizardPage", "Ctrl", "CtrlSignals", "InterfaceController",
                                      "Util", "DDT", "Types"}
        modules_extra = class_def.get("modules")
        if isinstance(modules_extra, list):
            required_imports.update(m.strip() for m in modules_extra if isinstance(m, str) and m.strip())
        elif isinstance(modules_extra, str) and modules_extra.strip():
            required_imports.add(modules_extra.strip())
        if cancel_message is not None:
            required_imports.add("HtmlDialog")

        pages = class_def.get("pages", [])
        page_call_lines: List[str] = []
        for idx, page in enumerate(pages):
            if not isinstance(page, dict):
                print(f"Warning: wizard '{target_name}'.pages[{idx}] must be a mapping; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            self._warn_unknown_keys(page, allow["wizard_page_entry"], f"wizard '{target_name}'.pages[{idx}]",
                                    yaml_file)

            page_class = page.get("class")
            if not isinstance(page_class, str) or not page_class.strip():
                print(f"Warning: wizard '{target_name}'.pages[{idx}] missing required 'class'; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            page_class = page_class.strip()

            page_module = page.get("module")
            if not isinstance(page_module, str) or not page_module.strip():
                print(f"Warning: wizard '{target_name}'.pages[{idx}] ('{page_class}') missing required 'module'; "
                      f"skipping {yaml_file}", file=sys.stderr)
                continue
            required_imports.add(page_module.strip())

            page_name = page.get("name")
            if not isinstance(page_name, str) or not page_name.strip():
                print(f"Warning: wizard '{target_name}'.pages[{idx}] ('{page_class}') missing required 'name'; "
                      f"skipping {yaml_file}", file=sys.stderr)
                continue
            page_name = page_name.strip()

            if "uicreateflags" in page:
                _, cflags, _ = self.extract_uicreate_flags(f"{target_name}.pages[{idx}]", page, yaml_file)
            else:
                cflags = "UICreateFlags::ExcludeFromColour | UICreateFlags::NoValidation | UICreateFlags::NoDefaultBinds"

            header = page.get("header", "")
            if isinstance(header, dict):
                condition = header.get("condition")
                if_true = self._cpp_string_literal(str(header.get("if_true", "")))
                if_false = self._cpp_string_literal(str(header.get("if_false", "")))
                if not isinstance(condition, str) or not condition.strip():
                    print(f"Warning: wizard '{target_name}'.pages[{idx}] header.condition must be a non-empty "
                          f"string naming an args_in key {yaml_file}", file=sys.stderr)
                    header_expr = f'"{if_true}"s'
                else:
                    cond = condition.strip()
                    if declared_arg_names and cond not in declared_arg_names:
                        print(f"Warning: wizard '{target_name}'.pages[{idx}] header.condition '{cond}' is not "
                              f"declared in this wizard's args_in {yaml_file}", file=sys.stderr)
                    header_expr = f'(param<bool>(args, "{cond}", false) ? "{if_true}"s : "{if_false}"s)'
            elif isinstance(header, str):
                header_expr = f'"{self._cpp_string_literal(header)}"s'
            else:
                print(f"Warning: wizard '{target_name}'.pages[{idx}] ('{page_class}') 'header' must be a string "
                      f"or {{condition, if_true, if_false}} mapping; defaulting to empty {yaml_file}",
                      file=sys.stderr)
                header_expr = '""s'

            page_args_lines: List[str] = []
            raw_args = page.get("args", "args")
            if isinstance(raw_args, dict):
                page_args_lines, local_name, _extract_after = self._emit_item_args(
                    page, "args", yaml_file, f"wizard '{target_name}'.pages[{idx}]")
                args_expr = local_name if local_name else "args"
            else:
                args_expr = raw_args.strip() if isinstance(raw_args, str) and raw_args.strip() else "args"

            call_line = (f'addPage(new {page_class}({cflags}, "{page_name}", this, '
                        f'{header_expr}, {args_expr}, 0L));')

            if_key = page.get("if")
            if isinstance(if_key, str) and if_key.strip():
                raw = if_key.strip()
                negate = raw.startswith("!")
                key = raw[1:].strip() if negate else raw
                if declared_arg_names and key not in declared_arg_names:
                    print(f"Warning: wizard '{target_name}'.pages[{idx}] if: '{key}' is not declared in this "
                          f"wizard's args_in {yaml_file}", file=sys.stderr)
                cond_expr = f'{"!" if negate else ""}param<bool>(args, "{key}", false)'
                page_call_lines.append(f"      if ({cond_expr}) {{")
                page_call_lines.extend(f"   {l}" for l in page_args_lines)
                page_call_lines.append(f"         {call_line}")
                page_call_lines.append("      }")
            else:
                page_call_lines.extend(page_args_lines)
                page_call_lines.append(f"      {call_line}")

        finally_body = self._extract_finally_begin(class_def)

        code: List[str] = []
        code.append('module;')
        code.append('//')
        try:
            _mt = datetime.datetime.fromtimestamp(yaml_file.stat().st_mtime)
            _mts = _mt.isoformat(sep=' ', timespec='seconds')
        except Exception:
            _mts = 'unknown'
        code.append(f'// Auto-generated from')
        code.append(f'// {yaml_file} (mtime: {_mts})')
        code.append('')
        code.append('// Make any changes there. This file will be overwritten.')
        code.append('')
        code.append('#include "Core/Core.h"')
        code.append('#include "Core/CoreData.h"')
        code.append('#include "Core/Util.h"')
        code.append('#include "Gfx/gfx_export.h"')
        code.append('#include "Gfx/WidgetsFwd.h"')
        # nid:: notification IDs (used by a 'finally:' body, e.g. ctrlSignal().Notify(...))
        # live in the app's own GlobalIDs.h, a plain header — not a module.
        code.append(f'#include "{self.app_target}/GlobalIDs.h"')
        code.append('#include <wx/wizard.h>')
        code.append('#include <utility>')
        code.append('')

        true_imports = sorted(m for m in required_imports if m != export_module)
        code.append(f'export module {export_module};')
        code.append('')
        code.extend(f"import {module};" for module in true_imports)
        code.append('')
        code.append('namespace wx {')
        code.append(f'export class {self.export_var} {cpp_class} : public Wizard {{')

        has_class_args = bool(wizard_args_var) and bool(wizard_emplace_lines)
        if has_class_args:
            wizard_args_factory = f"{wizard_args_var}Default"
            code.append(f"   static auto {wizard_args_factory}() -> anymap {{")
            code.append("      anymap m;")
            code.extend(wizard_emplace_lines)
            code.append("      return m;")
            code.append("   }")
            wizard_merge_helper_name = f"{wizard_args_var}Merged"
            code.append(f"   static auto {wizard_merge_helper_name}(anymap &a) -> anymap & {{")
            code.append(f"      a.merge({wizard_args_factory}());")
            code.append("      return a;")
            code.append("   }")
            code.append('')

        if cancel_message is not None:
            if not isinstance(cancel_message, dict):
                print(f"Warning: wizard '{target_name}' 'cancel_message' must be a mapping "
                      f"{{sub_heading, body}} {yaml_file}", file=sys.stderr)
                cancel_message = {}
            sub_heading = self._cpp_string_literal(str(cancel_message.get("sub_heading", self._DEFAULT_CANCEL_SUB_HEADING)))
            body = self._cpp_string_literal(str(cancel_message.get("body", self._DEFAULT_CANCEL_BODY)))
            code.append('protected:')
            code.append('   [[nodiscard]] auto cancelMessage() const -> std::pair<std::string, std::string> override;')
            code.append('')

        code.append(' public:')
        default_args_expr = f"{wizard_args_factory}()" if has_class_args else "nullanymap"
        ctor_args_expr = f"{wizard_merge_helper_name}(args)" if has_class_args else "args"
        code.append(f'   explicit {cpp_class}(wxFrame *frame, std::string title, anymap args = {default_args_expr}) '
                    f': Wizard(frame, title, {ctor_args_expr}) {{')
        code.append('')
        code.append('      TraceCall();;')
        code.append('')
        code.extend(page_call_lines)
        if finally_body.strip():
            code.append('')
            for line in finally_body.rstrip().splitlines():
                code.append(f"      {line}" if line.strip() else "")
        code.append('   }')
        code.append('};')

        if cancel_message is not None:
            code.append('')
            code.append(f'auto {cpp_class}::cancelMessage() const -> std::pair<std::string, std::string> {{')
            code.append(f'   return {{"{sub_heading}", "{body}"}};')
            code.append('}')

        code.append('} // namespace wx')

        return "\n".join(code)

    def _book_child_arg_expr(self, val: Any, ctx: str, yaml_file: Path) -> str:
        """A single value in a book page-entry's 'args' mapping: either a plain scalar
           literal, or {icon: {type, file, must_exist}} -> a wx::getIcon(...) call."""
        if isinstance(val, dict) and "icon" in val:
            icon = val.get("icon") or {}
            if not isinstance(icon, dict):
                print(f"Warning: {ctx} 'icon' must be a mapping {yaml_file}", file=sys.stderr)
                icon = {}
            itype = icon.get("type", "Button")
            if not isinstance(itype, str) or not itype.strip():
                print(f"Warning: {ctx} icon.type must be a non-empty string; defaulting to 'Button' {yaml_file}",
                      file=sys.stderr)
                itype = "Button"
            file = icon.get("file", "")
            if not isinstance(file, str) or not file.strip():
                print(f"Warning: {ctx} icon.file must be a non-empty string {yaml_file}", file=sys.stderr)
                file = ""
            must_exist = icon.get("must_exist", True)
            if not isinstance(must_exist, bool):
                print(f"Warning: {ctx} icon.must_exist must be hs_bool; defaulting to true {yaml_file}",
                      file=sys.stderr)
                must_exist = True
            return f'wx::getIcon(UIType::{itype.strip()}, "{self._cpp_string_literal(file.strip())}", ' \
                   f'{"true" if must_exist else "false"})'
        if isinstance(val, bool):
            return "true" if val else "false"
        if isinstance(val, (int, float)):
            return str(val)
        return f'"{self._cpp_string_literal(str(val))}"'

    def _generate_book_child_calls(self, ctx_name: str, children: List[Any], parent_expr: str,
                                   yaml_file: Path, parent_args_var: Optional[str] = None) -> List[str]:
        """Shared by both book: flavours (container:true's own constructor, and
           container:false's free populate() function): emit, in declared order, an
           optional local anymap arg variable plus a '(void) new <class>(<parent_expr>,
           wx::nextID(), "<name>", PageType::<type>, -1[, <argsVar>]);' line per child
           page. imageIndex is always -1 here - Book::loadLayout() assigns real image
           indexes at runtime from the paired form-layout file, not at construction.

           A child's 'args:' may be either the original flat {key: literal/icon}
           mapping (built fresh, no parent forwarding - still needed for container:false,
           which has no incoming anymap at all), or, when it contains any args_def
           key (arg_name/insert/translate/extract_before/extract_after), the same schema
           args: blocks elsewhere use, remapped from parent_args_var via
           _emit_item_args. The latter requires an anymap actually be in scope at the call
           site (parent_args_var not None)."""
        allow = self._allowed_sets()
        lines: List[str] = []
        for idx, child in enumerate(children):
            if not isinstance(child, dict):
                print(f"Warning: '{ctx_name}'.pages[{idx}] must be a mapping; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            ctx = f"'{ctx_name}'.pages[{idx}]"
            self._warn_unknown_keys(child, allow["book_page_entry"], ctx, yaml_file)

            child_class = child.get("class")
            if not isinstance(child_class, str) or not child_class.strip():
                print(f"Warning: {ctx} missing required 'class'; skipping {yaml_file}", file=sys.stderr)
                continue
            child_class = child_class.strip()

            child_module = child.get("module")
            if not isinstance(child_module, str) or not child_module.strip():
                print(f"Warning: {ctx} ('{child_class}') missing required 'module'; skipping {yaml_file}",
                      file=sys.stderr)
                continue

            child_name = child.get("name")
            if not isinstance(child_name, str) or not child_name.strip():
                print(f"Warning: {ctx} ('{child_class}') missing required 'name'; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            child_name = child_name.strip()

            child_type = child.get("type")
            if not isinstance(child_type, str) or not child_type.strip():
                print(f"Warning: {ctx} ('{child_class}') missing required 'type'; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            child_type = child_type.strip()

            args_expr = None
            args_map = child.get("args")
            if isinstance(args_map, dict) and any(k in args_map for k in allow["args_def"]):
                if parent_args_var:
                    arg_lines, local_name, _extract_after = self._emit_item_args(child, parent_args_var, yaml_file,
                                                                                 f"{ctx} args")
                    lines.extend(arg_lines)
                    args_expr = local_name
                else:
                    print(f"Warning: {ctx} 'args' uses the arg_name/insert/translate schema, but no "
                          f"parent anymap is available here (book container:false populate() takes no args); "
                          f"ignoring {yaml_file}", file=sys.stderr)
            elif isinstance(args_map, dict) and args_map:
                var_name = f"{self.to_camel_case(child_name)}Args"
                lines.append(f'      anymap {var_name};')
                for key, val in args_map.items():
                    expr = self._book_child_arg_expr(val, f"{ctx} args.{key}", yaml_file)
                    lines.append(f'      {var_name}.emplace("{key}", {expr});')
                args_expr = var_name
            elif args_map is not None:
                print(f"Warning: {ctx} 'args' must be a mapping; ignoring {yaml_file}", file=sys.stderr)

            ctor_args = f'{parent_expr}, wx::nextID(), "{child_name}", PageType::{child_type}, -1'
            if args_expr:
                ctor_args += f', {args_expr}'
            lines.append(f'      (void) new {child_class}({ctor_args});')
        return lines

    def generate_book_module(self, target_name: str, class_def: Dict[str, Any], yaml_file: Path,
                             top_verbatim: str, output_dir: Optional[Path] = None) -> str:
        """Generate a 'book:' item. Two flavours, chosen by 'container':
             - container: true  -> a PageContainer-derived class (same shape 'pages:'
               already produces for a base_class: PageContainer item), with its
               declared 'pages' children instantiated into its own nested book().
               Implemented by reusing generate_ui_module() itself (temporarily, since
               that function already has all the Page ctor/layoutPath/args_out
               scaffolding this needs) rather than duplicating that machinery here.
             - container: false (default) -> a free 'populate(Book *book)' function
               that instantiates the declared 'pages' children directly into a
               caller-supplied Book* (the top-level book, which the app - not the
               generator - already owns via CView::initBook()).
        """
        container = class_def.get('container', False)
        if not isinstance(container, bool):
            print(f"Warning: book '{target_name}' 'container' must be hs_bool; defaulting to false {yaml_file}",
                  file=sys.stderr)
            container = False

        if container:
            saved_type, saved_class = self.target_type, self.target_class
            self.target("pages")
            try:
                content = self.generate_ui_module(target_name, class_def, yaml_file, top_verbatim, output_dir)
            finally:
                self.target_type, self.target_class = saved_type, saved_class
            return content

        return self._generate_book_populate_module(target_name, class_def, yaml_file)

    def _generate_book_populate_module(self, target_name: str, class_def: Dict[str, Any],
                                       yaml_file: Path) -> str:
        allow = self._allowed_sets()
        self._warn_unknown_keys(class_def, allow["class_def"], f"book '{target_name}'", yaml_file)

        pascal_name = self.to_pascal_case(target_name)
        export_module = class_def.get("module") or f"{pascal_name}.Book"
        if not isinstance(export_module, str) or not export_module.strip():
            print(f"Warning: book '{target_name}' 'module' must be a non-empty string; defaulting", file=sys.stderr)
            export_module = f"{pascal_name}.Book"
        export_module = export_module.strip()

        children = class_def.get("pages", [])
        required_imports: set[str] = {"Book", "wxTypes", "Util", "DDT", "Types"}
        for child in children:
            if isinstance(child, dict):
                mod = child.get("module")
                if isinstance(mod, str) and mod.strip():
                    required_imports.add(mod.strip())

        call_lines = self._generate_book_child_calls(target_name, children, "book", yaml_file)

        code: List[str] = []
        code.append('module;')
        code.append('//')
        try:
            _mt = datetime.datetime.fromtimestamp(yaml_file.stat().st_mtime)
            _mts = _mt.isoformat(sep=' ', timespec='seconds')
        except Exception:
            _mts = 'unknown'
        code.append(f'// Auto-generated from')
        code.append(f'// {yaml_file} (mtime: {_mts})')
        code.append('')
        code.append('// Make any changes there. This file will be overwritten.')
        code.append('')
        code.append('#include "Core/Core.h"')
        code.append('#include "Core/CoreData.h"')
        code.append('#include "Core/Util.h"')
        code.append('#include "Gfx/gfx_export.h"')
        code.append('#include "Gfx/WidgetsFwd.h"')
        code.append('')

        true_imports = sorted(m for m in required_imports if m != export_module)
        code.append(f'export module {export_module};')
        code.append('')
        code.extend(f"import {module};" for module in true_imports)
        code.append('')
        code.append('namespace wx {')
        code.append('export auto populate(Book *book) -> void {')
        code.append('')
        code.extend(call_lines)
        code.append('}')
        code.append('} // namespace wx')

        return "\n".join(code)

    def generate_control_creation(self, group_name: str, elements: Any, layout_path: str, yaml_file: Path,
                                  parent_args_var: Optional[str]) -> Tuple[List[str], str]:
        """Build creation code from list-based elements[*].items."""
        creation_code: List[str] = []
        target_parent: str = ""

        allow = self._allowed_sets()

        if not isinstance(elements, list):
            self._dbg(f"generate_control_creation('{group_name}'): 'elements' is a "
                      f"{type(elements).__name__}, not a list - DROPPED, no creation code")
            return creation_code, target_parent

        for idx, element in enumerate(elements):
            if not isinstance(element, dict):
                self._dbg(f"'{group_name}': elements[{idx}] is a {type(element).__name__}, not a mapping - "
                          f"DROPPED")
                continue

            # Element-level verbatim (Placement: before this element's items)
            elements_verbatim = self._extract_verbatim_body(element)
            if elements_verbatim:
                for line in elements_verbatim.rstrip().splitlines():
                    creation_code.append(f"      {line}")

            identity = element.get('section') or element.get('Section') or ""
            tool_tip = element.get('tool_tip', '')
            items = element.get('items', [])
            if not isinstance(items, list):
                self._dbg(f"'{group_name}': section '{identity}' (elements[{idx}]) 'items' is a "
                          f"{type(items).__name__}, not a list - DROPPED, section produces nothing")
                continue

            self._dbg(f"'{group_name}': section '{identity}' (elements[{idx}]): {len(items)} item(s)")

            if self.target_type == "groups":
                target_parent = "getSBSizer()->GetStaticBox();"
            elif self.target_type == "pages":
                target_parent = "getForm()"
            elif self.target_type == "wizardpages":
                target_parent = "this"
            else:
                target_parent = "pParent"

            for item_idx, item in enumerate(items):
                if not isinstance(item, dict):
                    self._dbg(f"'{group_name}': section '{identity}'.items[{item_idx}] is a "
                              f"{type(item).__name__}, not a mapping - DROPPED")
                    continue

                # Controls in groups; groups in pages
                if self.target_type == "groups" and "control" in item and isinstance(item["control"], dict):
                    md = item["control"]
                    var = self.extract_member_variable(md, f"control '{identity}'", yaml_file)
                    self._dbg(f"'{group_name}': section '{identity}'.items[{item_idx}]: control "
                              f"'{var}' (class={md.get('class')!r})")
                    # Per-member verbatim (Placement: before addControl)
                    controlset_verbatim = self._extract_verbatim_body(md)
                    creation_code.extend(self._generate_single_control(
                        member_name=var,
                        member_def=md,
                        control_name=identity,
                        tool_tip=tool_tip,
                        all_elements=element,  # pass element dict for labels
                        yaml_file=yaml_file,
                        parent_args_var=parent_args_var,
                        controlset_verbatim=controlset_verbatim
                    ))

                elif ((self.target_type == "pages" or self.target_type == "wizardpages")
                      and "control" in item and isinstance(item["control"], dict)):

                    md = item["control"]
                    var = self.extract_member_variable(md, f"control '{identity}'", yaml_file)
                    self._dbg(f"'{group_name}': section '{identity}'.items[{item_idx}]: nested group "
                              f"'{var}' (class={md.get('class')!r})")
                    # Per-member verbatim (Placement: before addGroup)
                    controlset_verbatim = self._extract_verbatim_body(md)
                    creation_code.extend(self._generate_single_group(
                        member_name=var,
                        member_def=md,
                        control_name=identity,
                        tool_tip=tool_tip,
                        all_elements=element,  # pass element dict for labels (if nested in group later)
                        yaml_file=yaml_file,
                        parent_args_var=parent_args_var,
                        controlset_verbatim=controlset_verbatim
                    ))

                # Spacers carry no C++ object - just placement, resolved at runtime by
                # Interface::loadLayout. Only validate the schema and (optionally) trace it.
                elif "spacer" in item and isinstance(item["spacer"], dict):
                    self._dbg(f"'{group_name}': section '{identity}'.items[{item_idx}]: spacer")
                    spacer_def = item["spacer"]
                    self._warn_unknown_keys(spacer_def, {"sizer"}, f"spacer '{identity}'", yaml_file)
                    if self.sizer_info and spacer_def.get('sizer'):
                        sp = self.extract_sizer(spacer_def['sizer'])
                        creation_code.append(
                            f'      // Spacer: Position: {sp.position}, Border: {sp.border}')

                elif "expanding_spacer" in item and isinstance(item["expanding_spacer"], dict):
                    self._dbg(f"'{group_name}': section '{identity}'.items[{item_idx}]: expanding_spacer")
                    spacer_def = item["expanding_spacer"]
                    self._warn_unknown_keys(spacer_def, {"sizer"}, f"expanding_spacer '{identity}'", yaml_file)
                    if self.sizer_info and spacer_def.get('sizer'):
                        sp = self.extract_sizer(spacer_def['sizer'])
                        creation_code.append(
                            f'      // Expanding spacer: Position: {sp.position}, Proportion: {sp.proportion}')

                else:
                    # No 'control'/'spacer'/'expanding_spacer' key this target_type
                    # recognizes here (e.g. a label-only item - those are picked up
                    # separately via _generate_labels()). Not an error, but silent
                    # unless traced.
                    self._dbg(f"'{group_name}': section '{identity}'.items[{item_idx}]: no control/spacer "
                              f"recognized for target_type '{self.target_type}' (keys: {list(item.keys())}) "
                              f"- contributes no creation code here")

        self._dbg(f"generate_control_creation('{group_name}'): {len(creation_code)} line(s) total, "
                  f"target_parent='{target_parent}'")
        return creation_code, target_parent

    def _generate_single_control(self, member_name: str, member_def: Dict[str, Any],
                                 control_name: str, tool_tip: str, all_elements: Dict[str, Any], yaml_file: Path,
                                 parent_args_var: Optional[str],
                                 controlset_verbatim: str = "") -> List[str]:
        """Generate creation code for a single control (new list schema)."""
        code: List[str] = []

        if "class_args" in member_def:
            raise ValueError(
                f"control '{member_name}': 'class_args' is not valid inside a control: block "
                f"(class_args is class-scope only -- page/group/wizardpage/wizard/book); "
                f"did you mean 'args'? {yaml_file}")

        # insert:/translate:/extract_before before allocation
        args_lines, local_args_var, extract_after = self._emit_item_args(member_def, parent_args_var, yaml_file,
                                                                         f"control '{member_name}'")

        code.extend(args_lines)

        control_class, base_class = self.extract_control_class(member_name, member_def, yaml_file)
        cpp_class = self.resolve_member_cpp_type(member_name, member_def, yaml_file)
        pos = self.extract_position(member_name, member_def, yaml_file)
        size = self.extract_size(member_name, member_def, control_class, yaml_file)
        style = self.extract_style(member_name, member_def, yaml_file)
        data_type = self.extract_data_type(member_name, member_def, yaml_file)
        value, value_is_literal = self.extract_value(member_name, member_def, control_class, base_class, yaml_file)
        cflags_list, cflags, is_group = self.extract_uicreate_flags(member_name, member_def, yaml_file)

        # Use 'key' for constructor-visible name (fallback to legacy name extractor)
        name = self.extract_member_tag(member_def, control_name, yaml_file)  # adapter you added
        #
        # parent: str = "dynamic_cast<Page*>(pParent)->getForm()"
        # if self.target_type == "wizardpages":
        #     parent = "pParent"

        table, field = self.extract_db_info(member_name, member_def, yaml_file)
        is_multi_row_control = control_class.split('<', 1)[0].strip() in self.multi_row_control_classes
        if is_multi_row_control and table and field:
            print(f"Warning: '{member_name}' is a {control_class} (multi-row); ignoring 'table'/'field' - "
                  f"they only apply to single-value controls {yaml_file}", file=sys.stderr)
        # signature = member_def.get('signature', '{cflags}, "{name}", {parent}, nextID(), {value}, {size}, {style}')
        # signature = member_def.get('signature', '{cflags}, "{name}", targetParent, nextID(), {value}, {size}, {style}')
        signature = member_def.get('signature', '{cflags}, "{name}", targetParent, {value}')
        signature = self._signature_with_args(signature, local_args_var or parent_args_var)
        signature += f', {style}, {size})'
        if (member_name):
            out = f'      ({member_name} = new {cpp_class}({signature})'
        else:
            out = f'      (new {cpp_class}({signature})'

        out = out.format_map(locals())
        code.append(out)

        if self.sizer_info:
            # Get sizer information
            sizer_def = member_def.get('sizer')
            if sizer_def:
                sizer_properties: CppGenerator.SizerProperties = self.extract_sizer(sizer_def)
                code.append(
                    f'      // Sizer information: Position: {sizer_properties.position}, Proportion: {sizer_properties.proportion}, Border: {sizer_properties.border}, Flags: {sizer_properties.flag}')

        # chain
        member_accessor = '->'
        if value and not value == "hs::NullValue::Null" and signature.find('value') == -1:
            code.append(f"         ->set <{data_type}> ({value if not value_is_literal else repr(value)})")
            member_accessor = '.'

        xfer_required = member_def.get('transfer', True)
        xfer_method = "pushToCtrl(live_)"

        validator = member_def.get('validator', {})
        if validator:
            xfer_method = "transferToWindow()"
            validator_code = self._generate_validator(validator, member_name, member_def)
            if validator_code:
                code.append(f"         {member_accessor}{validator_code}")
                member_accessor = '.'

        # Labels from the element dict
        label_code = self._generate_labels(all_elements, None)
        if label_code:
            label_code[0] = label_code[0].replace('.createLabel', f'{member_accessor}createLabel', 1)
            member_accessor = '.'
            code.extend(label_code)

        if tool_tip:
            code.append(f"         {member_accessor}setToolTip(\"{tool_tip}\")")
            member_accessor = '.'

        handlers = member_def.get('handlers', [])
        for handler in handlers:
            handler_code = self._generate_event_handler(handler, member_name, member_def)
            if handler_code:
                code.append(f"         {member_accessor}{handler_code}")
                member_accessor = '.'

        if style != '0' and signature.find('style') == -1:
            code.append(f"         {member_accessor}setWindowStyleFlags({style})")
            member_accessor = '.'

        if table and field and not is_multi_row_control and signature.find('table') == -1 and signature.find('field') == -1:
            db_chain = f'dbInfo({table}, {field})'
            code.append(f"         {member_accessor}{db_chain}")
            member_accessor = '.'

        if xfer_required:
            code.append(f"         {member_accessor}{xfer_method}")
            member_accessor = '.'

        # terminate allocation line
        potential_last_line: str = ''
        linx: int = -1
        while abs(linx) < len(code):
            potential_last_line = code[linx].strip()
            if not potential_last_line.startswith('//'):
                break
            linx -= 1

        code[linx] = code[linx] + ";"

        # Placement: per-member verbatim before addControl
        if controlset_verbatim:
            for line in controlset_verbatim.rstrip().splitlines():
                code.append(f"      {line}")

        # alt_data_source: auto-call the generic DB-backed loadFromDB() right where a
        # hand-written 'verbatim: body: member->loadFromDB();' would otherwise go.
        if self.extract_alt_data_source(member_name, member_def, yaml_file) is not None:
            code.append(f"      {member_name}->loadFromDB();")

        # add to map
        if is_group:
            code.append(f"      addGroup({member_name});")
        else:
            code.append(f"      addControl({member_name});")

        # extract_after, once construction is done -- each entry names its own source
        # anymap/key explicitly, so no fallback to local_args_var/parent_args_var is needed
        if extract_after:
            code.append("")
            for var_name, ty, no_auto, map_name, entry_name, default in extract_after:
                lit = self._format_cpp_literal(default, ty, string_style="construct")
                prefix = "" if no_auto else "auto "
                code.append(f'      {prefix}{var_name} = param({map_name}, "{entry_name}", {lit});')

        code.append("")

        return code

    def _generate_single_group(self, member_name: str, member_def: Dict[str, Any],
                               control_name: str, tool_tip: str, all_elements: Dict[str, Any], yaml_file: Path,
                               parent_args_var: Optional[str],
                               controlset_verbatim: str = "") -> List[str]:
        """Generate creation code for a single nested control (used when target is Page/WizardPage)."""
        code: List[str] = []

        if "class_args" in member_def:
            raise ValueError(
                f"control '{member_name}': 'class_args' is not valid inside a control: block "
                f"(class_args is class-scope only -- page/group/wizardpage/wizard/book); "
                f"did you mean 'args'? {yaml_file}")

        # insert:/translate:/extract_before before allocation
        args_lines, local_args_var, extract_after = self._emit_item_args(member_def, parent_args_var, yaml_file,
                                                                         f"control '{member_name}'")
        code.extend(args_lines)

        control_class, base_class = self.extract_control_class(member_name, member_def, yaml_file)
        cpp_class = control_class
        pos = self.extract_position(member_name, member_def, yaml_file)
        size = self.extract_size(member_name, member_def, control_class, yaml_file)
        style = self.extract_style(member_name, member_def, yaml_file)
        value, value_is_literal = self.extract_value(member_name, member_def, control_class, base_class, yaml_file)
        cflags_list, cflags, is_group = self.extract_uicreate_flags(member_name, member_def, yaml_file)

        name = self.extract_member_tag(member_def, control_name, yaml_file)
        # parent: str = "getForm()"
        # if self.target_class == "Page":
        #     parent = "getForm()"

        signature = member_def.get('signature', '{cflags}, "{name}", targetParent, {value}')
        # signature = member_def.get('signature', '{cflags}, "{name}", {parent}, nextID(), {value}, {size}, {style}')
        signature = self._signature_with_args(signature, local_args_var or parent_args_var)
        signature += f', {style}'
        out = f'      ({member_name} = new {cpp_class}({signature}));'
        out = out.format_map(locals())
        code.append(out)

        if self.sizer_info:
            # Get sizer information
            sizer_def = member_def.get('sizer')
            if sizer_def:
                sizer_properties: CppGenerator.SizerProperties = self.extract_sizer(sizer_def)
                code.append(
                    f'      // Sizer information: Position: {sizer_properties.position}, Proportion: {sizer_properties.proportion}, Border: {sizer_properties.border}, Flags: {sizer_properties.flag}')

        # Placement: per-member verbatim before addGroup
        if controlset_verbatim:
            for line in controlset_verbatim.rstrip().splitlines():
                code.append(f"      {line}")

        code.append(f"      addGroup({member_name});")

        # extract_after, once construction is done -- each entry names its own source
        # anymap/key explicitly, so no fallback to local_args_var/parent_args_var is needed
        if extract_after:
            for var_name, ty, no_auto, map_name, entry_name, default in extract_after:
                lit = self._format_cpp_literal(default, ty, string_style="construct")
                prefix = "" if no_auto else "auto "
                code.append(f'      {prefix}{var_name} = param({map_name}, "{entry_name}", {lit});')

        code.append("")
        return code

    def generate_control_declarations(self, elements: Any, yaml_file: Path) -> List[str]:
        decls: List[str] = []
        # elements is now a list
        if not isinstance(elements, list):
            return decls
        for element in elements:
            if not isinstance(element, dict):
                continue
            has_group = bool(element.get("has_group"))
            has_control = bool(element.get("has_control"))
            items = element.get("items", [])
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict):
                    continue
                if (
                        self.target_type == "pages" or self.target_type == "wizardpages") and "control" in item and isinstance(
                    item["control"], dict):
                    md = item["control"]
                    var = self.extract_member_variable(md, "control declaration", yaml_file)
                    ctrl_class = self.resolve_member_cpp_type(var or "Group", md, yaml_file)
                    decls.append(f"   {ctrl_class}* {var} {{}};")
                elif self.target_type == "groups" and "control" in item and isinstance(item["control"], dict):
                    md = item["control"]
                    var = self.extract_member_variable(md, "control declaration", yaml_file)
                    ctrl_class = self.resolve_member_cpp_type(var or "Ctrl", md, yaml_file)
                    decls.append(f"   {ctrl_class}* {var} {{}};")
        return decls

    # -------- helpers for debugging unknown keys --------
    def _warn_unknown_keys(self, obj: Any, allowed: set[str], context: str, yamlfile: Path) -> None:
        if isinstance(obj, dict):
            unknown = [k for k in obj.keys() if k not in allowed]
            if unknown:
                print(f"Warning: unknown keys {unknown} in {context} {yamlfile}", file=sys.stderr)

    def _allowed_sets(self):

        return {
            "root": {
                "verbatim",
            },
            "class_def": {
                "class_args",
                "base_class",
                "class",
                "class_name",
                "container",
                "elements",
                "export_module",
                "finally",
                "functions",
                "layout",
                "module",
                "modules",
                "on_event",
                "on_kill_active",
                "on_set_active",
                "pages",
                "pos",
                "recordset",
                "run_generator",
                "size",
                "sizer",
                "style",
                "title",
                "value",
                "variables",
                "verbatim",
            },
            "sizer_def": {
                "border",
                "col_widths",
                "cols",
                "growable_cols",
                "growable_rows",
                "hgap",
                "kind",
                "position",
                "proportion",
                "row_heights",
                "rows",
                "span",
                "vgap",
            },
            "sizer_kinds": {
                "flex",
                "grid",
            },
            "class_args_def": {                  # page / group / wizardpage / book(container:true)
                "arg_name",
                "args_in",
                "extract_inside",
            },
            "wizard_class_args_def": {           # wizard: only -- reduced scope, no extraction
                "arg_name",
                "args_in",
            },
            "args_def": {                # nested inside control: only
                "arg_name",
                "insert",
                "translate",
                "extract_before",
                "extract_after",
            },
            "recordset_def": {
                "table",
                "order_by"
            },
            "alt_data_source_def": {
                "blank_text",
                "display_field",
                "include_blank",
                "table",
                "value_field",
            },
            "elements_root": {
                "verbatim",
            },
            "control_set": {
                "section",
                "items",
                "size",
                "sizer",
                "tool_tip",
                "verbatim",
            },
            "item_entry": {
                "labels",
                "control",
                "spacer",
                "expanding_spacer",
            },
            "control_member_def": {
                "alt_data_source",
                "args",
                "base_class",
                "class",
                "contains",
                "default",
                "field",
                "handlers",
                "is_group",
                "module",
                "name",
                "pos",
                "signature",
                "size",
                "sizer",
                "style",
                "table",
                "uicreateflags",
                "validator",
                "value",
            },
            "label_entry": {
                "class",
                "key",
                "pos",
                "size",
                "sizer",
                "style",
                "name",
                "value",
            },
            "handler_entry": {
                "event",
                "handler",
            },
            "validator_def": {
                "allow_empty",
                "class",
                "tool_tip",
                "transfer_model",
            },
            "variable_def": {
                "access",
                "default",
                "include",
                "module",
                "type",
            },
            "wizard_def": {
                "class_args",
                "cancel_message",
                "class",
                "finally",
                "module",
                "modules",
                "pages",
                "run_generator",
            },
            "wizard_page_entry": {
                "args",
                "class",
                "header",
                "if",
                "module",
                "name",
                "uicreateflags",
            },
            "book_page_entry": {
                "args",
                "class",
                "module",
                "name",
                "type",
            },
        }

    # ---------------- verbatim extraction helpers ----------------
    def _extract_verbatim_body(self, node: Any) -> str:
        if not isinstance(node, dict):
            return ""
        vb = node.get("verbatim")
        if isinstance(vb, dict):
            beg = vb.get("body")
            if isinstance(beg, str):
                return beg
            if beg is not None:
                print("Warning: 'verbatim.body' must be a string; ignoring", file=sys.stderr)
        return ""

    def _extract_finally_begin(self, node: Any) -> str:
        """Extracts 'finally.body' text block from a group-level node, mirroring 'verbatim' handling."""
        if not isinstance(node, dict):
            return ""
        fin = node.get("finally")
        if isinstance(fin, dict):
            beg = fin.get("body")
            if isinstance(beg, str):
                return beg
            if beg is not None:
                print("Warning: 'finally.body' must be a string; ignoring", file=sys.stderr)
        return ""

    def _is_identifier(self, s: str) -> bool:
        """Rudimentary C++-like identifier check."""
        if not isinstance(s, str) or not s:
            return False
        if not (s[0].isalpha() or s[0] == "_"):
            return False
        return all(c.isalnum() or c == "_" for c in s)

    def _normalize_event_name(self, ev: str) -> str:
        """Normalize event name to a wxEVT_* token; accept exact wxEVT_* constants, map common EVT_* aliases."""
        if not isinstance(ev, str):
            return 'wxEVT_TEXT'
        s = ev.strip()
        if not s:
            return 'wxEVT_TEXT'
        # If already a wxEVT_* constant, keep as-is
        if s.startswith('wxEVT_'):
            return s

        # Canonicalize input a bit
        up = s.upper().replace('-', '_').replace(' ', '_')

        # Allow bare tokens like "TEXT", "BUTTON" -> prefix EVT_
        if not up.startswith('EVT_'):
            up = f'EVT_{up}'

        # 1) Try explicit alias table
        mapped = self.event_mapping.get(up)
        if mapped:
            return mapped

        # 2) Try modernizing legacy COMMAND_* aliases by dropping "COMMAND_"
        if 'EVT_COMMAND_' in up:
            try2 = up.replace('EVT_COMMAND_', 'EVT_', 1)
            mapped2 = self.event_mapping.get(try2)
            if mapped2:
                return mapped2
            # As a last attempt, synthesize wxEVT_COMMAND_* directly (some projects prefer these)
            return 'wx' + up  # e.g., EVT_COMMAND_BUTTON_CLICKED -> wxEVT_COMMAND_BUTTON_CLICKED

        # 3) Fallback: synthesize wxEVT_* directly (e.g., EVT_MENU -> wxEVT_MENU)
        synthesized = 'wx' + up
        if synthesized.startswith('wxEVT_'):
            return synthesized

        # 4) Final fallback with warning
        print(f"Warning: unknown event alias '{ev}', defaulting to wxEVT_TEXT", file=sys.stderr)
        return 'wxEVT_TEXT'

    def to_pascal_case(self, snake_str: str) -> str:
        """Convert snake_case to PascalCase."""
        if not snake_str:
            return ""

        if '_' not in snake_str:
            if snake_str[0].isupper():
                return snake_str
            return snake_str[0].upper() + snake_str[1:] if len(snake_str) > 1 else snake_str.upper()

        components = snake_str.split('_')
        return ''.join(word.capitalize() for word in components if word)

    def to_camel_case(self, snake_str: str) -> str:
        """Convert snake_case to camelCase."""
        components = snake_str.split('_')
        return components[0] + ''.join(word.capitalize() for word in components[1:])

    def get_required_imports(self, elements: list[Any], yaml_file: Path) -> List[str]:
        """Generate the list of required imports based on elements used (list-based schema)."""
        used_modules: set[str] = set()

        if self.target_type == "groups":
            used_modules.update(
                ['Ctrl', 'Database', 'DDT', 'RecordSetInterface', 'Interface', 'Group', 'StringUtil', 'Validator', 'wxTypes', 'wxUtil',
                 'Page'])
        elif self.target_type == "pages":
            used_modules.update(
                ['Ctrl', 'Database', 'DDT', 'RecordSetInterface', 'Interface', 'Group', 'Page', 'StringUtil', 'wxTypes', 'wxUtil'])
        elif self.target_type == "wizardpages":
            used_modules.update(
                ['Ctrl', 'Database', 'DDT', 'RecordSetInterface', 'Interface', 'Group', 'WizardPage', 'StringUtil', 'wxTypes', 'wxUtil'])

        if not isinstance(elements, list):
            return sorted(used_modules)

        allow = self._allowed_sets()

        for element in elements:
            if not isinstance(element, dict):
                continue
            items = element.get('items', [])
            if not isinstance(items, list):
                continue

            for item in items:
                if not isinstance(item, dict):
                    continue

                control_map_key = "control"
                if control_map_key in item and isinstance(item[control_map_key], dict):
                    md = item[control_map_key]

                    # modules
                    module_prop = md.get('module')
                    if isinstance(module_prop, str) and module_prop.strip():
                        used_modules.add(module_prop.strip())
                    elif isinstance(module_prop, list):
                        for m in module_prop:
                            if isinstance(m, str) and m.strip():
                                used_modules.add(m.strip())

                    # alt_data_source: control-level DB source for loadFromDB(), backed by
                    # the generic db::Row (DB.RowSet) -- no per-table module to add.
                    if control_map_key == "control":
                        alt_ds = self.extract_alt_data_source(md.get('variable', ''), md, yaml_file)
                        if alt_ds is not None:
                            used_modules.add("DB.RowSet")

                    # validator modules (controls only)
                    if control_map_key == "control":
                        validator = md.get('validator', {})
                        if isinstance(validator, dict):
                            self._warn_unknown_keys(validator, allow["validator_def"],
                                                    f"validator for control '{md.get('variable', '')}' {{validator_def}}",
                                                    yaml_file)
                            vclass = validator.get('class', '')
                            if vclass in self.validator_to_module:
                                used_modules.add(self.validator_to_module[vclass])

        return sorted(used_modules)

    def extract_control_class(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> Tuple[str, str]:
        """
        Rewritten:
        - base_class: required to select the correct base (Group, Page, WizardPage, etc.). Falls back to self.target_class if missing.
        - class: concrete C++ class name to instantiate for child items; falls back to base_class if missing.
        Returns (control_class, base_class).
        """
        base_class = elements.get('base_class') or self.target_class
        if not isinstance(base_class, str) or not base_class.strip():
            print(
                f"Warning: '{element_name}': base_class missing/invalid; defaulting to {self.target_class} {yaml_file}",
                file=sys.stderr)
            base_class = self.target_class
        else:
            base_class = base_class.strip()

        control_class = elements.get('class') or base_class
        if not isinstance(control_class, str) or not control_class.strip():
            print(f"Warning: '{element_name}': class missing/invalid; defaulting to {base_class} {yaml_file}",
                  file=sys.stderr)
            control_class = base_class
        else:
            control_class = control_class.strip()

        return control_class, base_class

    def extract_data_type(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> str:
        data_type = elements.get('contains', 'std::string')
        if not isinstance(data_type, str) and data_type is not None:
            print(f"Warning: 'data_type' for '{element_name}' must be a string; {yaml_file}",
                  file=sys.stderr)
        else:
            data_type = data_type.strip()

        return data_type

    def extract_db_info(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> Tuple[str, str]:
        table = ''
        field = ''
        tbl = elements.get('table')
        fld = elements.get('field')
        if (tbl is None) ^ (fld is None):
            # exactly one present -> error
            print(
                f"Error: control '{element_name}': both or neither 'table' and 'field' must be provided {yaml_file}",
                file=sys.stderr)
        elif tbl is not None and fld is not None:
            if isinstance(tbl, str) and tbl.strip() and isinstance(fld, str) and fld.strip():
                table = f'db::TableName {{"{tbl.strip()}"}}'
                field = f'db::FieldName {{"{fld.strip()}"}}'
            else:
                print(f"Error: control '{element_name}': 'table' and 'field' must be non-empty strings {yaml_file}",
                      file=sys.stderr)

        return table, field

    def extract_recordset(self, element_name: str, class_def: Dict[str, Any],
                          yaml_file: Path) -> Optional[Dict[str, str]]:
        """Extract the 'recordset:' block: {table, order_by}. Reads/writes go through the
        generic db::RowSet/db::Row (DB.RowSet) -- no generated per-table class needed.
        'table' is only required to generate a page's reloadTable() -- a group's recordset:
        (which only needs refreshFromCurrent()/refreshEx() scaffolding) can omit it."""
        rs = class_def.get('recordset')
        if rs is None:
            return None
        if not isinstance(rs, dict):
            print(f"Error: '{element_name}': 'recordset' must be a mapping {yaml_file}", file=sys.stderr)
            return None
        self._warn_unknown_keys(rs, self._allowed_sets()["recordset_def"],
                                f"recordset for '{element_name}' {{recordset_def}}", yaml_file)
        tbl = rs.get('table')
        if not (tbl is None or (isinstance(tbl, str) and tbl.strip())):
            print(f"Error: '{element_name}': 'recordset' 'table' must be a non-empty string {yaml_file}",
                  file=sys.stderr)
            return None
        if self.debugging and tbl is None:
            print(f"Warning: '{element_name}': reloadTable() generation skipped (no 'table') {yaml_file}")
        order_by = rs.get('order_by', 'id')
        return {'table': tbl.strip() if isinstance(tbl, str) else None, 'order_by': order_by}

    def extract_alt_data_source(self, element_name: str, member_def: Dict[str, Any],
                                yaml_file: Path) -> Optional[Dict[str, Any]]:
        """Extract a control's 'alt_data_source:' block: the db::RowSet-backed source for
        a DB-populated Choice/Combo/ListBox's generic loadFromDB(). Returns None when absent."""
        ads = member_def.get('alt_data_source')
        if ads is None:
            return None
        if not isinstance(ads, dict):
            print(f"Error: control '{element_name}': 'alt_data_source' must be a mapping {yaml_file}",
                  file=sys.stderr)
            return None
        self._warn_unknown_keys(ads, self._allowed_sets()["alt_data_source_def"],
                                f"alt_data_source for control '{element_name}' {{alt_data_source_def}}", yaml_file)
        table = ads.get('table')
        display_field = ads.get('display_field')
        value_field = ads.get('value_field')
        if not (isinstance(table, str) and table.strip() and
                isinstance(display_field, str) and display_field.strip() and
                isinstance(value_field, str) and value_field.strip()):
            print(f"Error: control '{element_name}': 'alt_data_source' needs non-empty "
                  f"'table', 'display_field', and 'value_field' {yaml_file}",
                  file=sys.stderr)
            return None
        table = table.strip()
        display_field = display_field.strip()
        value_field = value_field.strip()
        include_blank = ads.get('include_blank', True)
        if not isinstance(include_blank, bool):
            print(f"Warning: control '{element_name}': 'include_blank' must be a bool; "
                  f"defaulting to true {yaml_file}", file=sys.stderr)
            include_blank = True
        blank_text = ads.get('blank_text', '')
        if not isinstance(blank_text, str):
            print(f"Warning: control '{element_name}': 'blank_text' must be a string; "
                  f"defaulting to '' {yaml_file}", file=sys.stderr)
            blank_text = ''
        return {
            'table': table, 'display_field': display_field, 'value_field': value_field,
            'include_blank': include_blank, 'blank_text': blank_text,
        }

    def resolve_member_cpp_type(self, default_name: str, member_def: Dict[str, Any], yaml_file: Path) -> str:
        """Returns the C++ type used for a control's member declaration and construction.
        Identical to extract_control_class()'s control_class unless 'alt_data_source:' is
        present, in which case it's synthesized as '{base_class}<{data_type}, {Tag}DBSource>'
        -- any explicit 'class:' override is ignored (warned) since a generated DBSource
        struct can only be attached to the template itself, not a hand-written subclass."""
        control_class, base_class = self.extract_control_class(default_name, member_def, yaml_file)
        alt_ds = self.extract_alt_data_source(default_name, member_def, yaml_file)
        if alt_ds is None:
            return control_class
        if member_def.get('class'):
            print(f"Warning: '{default_name}': 'class' override ignored because 'alt_data_source' "
                  f"is set {yaml_file}", file=sys.stderr)
        data_type = self.extract_data_type(default_name, member_def, yaml_file)
        tag = self.extract_member_tag(member_def, default_name, yaml_file)
        return f"{base_class}<{data_type}, {tag}DBSource>"

    def collect_alt_data_sources(self, elements: Any, yaml_file: Path) -> List[Tuple[str, str, Dict[str, Any], str]]:
        """Walk elements (same shape as generate_control_declarations) and collect
        (var, tag, alt_data_source, data_type) for every control with an 'alt_data_source:'
        block, so generate_module can emit the corresponding DBSource policy structs
        before the class body."""
        results: List[Tuple[str, str, Dict[str, Any], str]] = []
        if not isinstance(elements, list):
            return results
        for element in elements:
            if not isinstance(element, dict):
                continue
            items = element.get("items", [])
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict) or "control" not in item or not isinstance(item["control"], dict):
                    continue
                md = item["control"]
                var = self.extract_member_variable(md, "alt_data_source scan", yaml_file)
                if not var:
                    continue
                alt_ds = self.extract_alt_data_source(var, md, yaml_file)
                if alt_ds is None:
                    continue
                tag = self.extract_member_tag(md, var, yaml_file)
                data_type = self.extract_data_type(var, md, yaml_file)
                results.append((var, tag, alt_ds, data_type))
        return results

    def collect_refresh_targets(self, elements: Any, yaml_file: Path) -> Tuple[List[Tuple[str, str, str]], List[str]]:
        """Walk elements (same shape as generate_control_declarations) and collect
        (bound_controls [(member, field, cpp_type)], group_members [member]) for
        refreshFromCurrent(). cpp_type is the control's 'contains:' type, used to read the
        field back out of a db::Row as rec->get<optional<cpp_type>>(field)."""
        bound_controls: List[Tuple[str, str, str]] = []
        group_members: List[str] = []
        if not isinstance(elements, list):
            return bound_controls, group_members
        for element in elements:
            if not isinstance(element, dict):
                continue
            items = element.get("items", [])
            if not isinstance(items, list):
                continue
            for item in items:
                if not isinstance(item, dict) or "control" not in item or not isinstance(item["control"], dict):
                    continue
                md = item["control"]
                var = self.extract_member_variable(md, "refresh target", yaml_file)
                if not var:
                    continue
                cflags_list, _, is_group = self.extract_uicreate_flags(var, md, yaml_file)
                if is_group or "Group" in cflags_list or md.get('base_class') == 'Group':
                    group_members.append(var)
                    continue
                tbl = md.get('table')
                fld = md.get('field')
                if not (isinstance(tbl, str) and tbl.strip() and isinstance(fld, str) and fld.strip()):
                    continue
                control_class, _ = self.extract_control_class(var, md, yaml_file)
                if control_class.split('<', 1)[0].strip() in self.multi_row_control_classes:
                    # A multi-row control's "value" (if any) is a selection, not a field
                    # value, and it shows the whole table rather than one row. Skip
                    # initFromField()/where() for it - see multi_row_control_classes.
                    continue
                cpp_type = md.get('contains', 'std::string')
                bound_controls.append((var, fld.strip(), cpp_type))
        return bound_controls, group_members

    def extract_export_module(self, element_name: str, elements: Dict[str, Any], control_name: str,
                              yaml_file: Path) -> str:
        export_module = elements.get('export_module', f'{element_name}.{self.target_class}')
        if not isinstance(export_module, str):
            print(f"Warning: 'export_module' for '{element_name}' must be a string; {yaml_file}", file=sys.stderr)
        else:
            export_module = export_module.strip()

        return export_module

    def extract_group_method_body(self, tag: str, element_name: str, elements: Dict[str, Any],
                                  yaml_file: Path) -> Tuple[bool, Optional[str]]:
        """Extracts a group-level method body (onSetActive/onKillActive).

        Returns (declared, body). `declared` is True whenever the tag key
        (e.g. 'on_set_active') is present in the YAML, regardless of whether it
        carries a body. `body` is the literal block text when a 'body:' key was
        supplied, or None when the method should instead be stubbed out in the
        impl file (mirrors how 'functions:' entries without a 'body:' behave).
        """

        if tag not in elements:
            return False, None

        ablk = elements.get(tag)
        if not isinstance(ablk, dict):
            return True, None

        body = ablk.get("body")
        if isinstance(body, str):
            # ensure that Interface::onSetActive/onKillActive is called somewhere in the group
            if tag == "on_set_active" and "Interface::onSetActive" not in body:
                raise ValueError(
                    f"Interface::onSetActive must be called in widget '{element_name}' {yaml_file}")
            if tag == "on_kill_active" and "Interface::onKillActive" not in body:
                raise ValueError(
                    f"Interface::onKillActive must be called in widget '{element_name}' {yaml_file}")
            return True, body.rstrip("\n")
        if body is not None:
            print(f"Warning: '{tag}.body' must be a string; ignoring {yaml_file}", file=sys.stderr)

        return True, None

    def extract_member_tag(self, member_def: Dict[str, Any], ctx: str, yaml_file: Path) -> str:
        tag = member_def.get("name")
        if isinstance(tag, str) and tag.strip():
            return tag.strip()
        raise ValueError(f"Item '{ctx}' in {yaml_file} must have a 'name'")

    def extract_member_variable(self, member_def: Dict[str, Any], ctx: str, yaml_file: Path) -> str | None:
        var = member_def.get("variable")
        if not isinstance(var, str) or not var.strip():
            print(f"Warning: {ctx} missing required 'variable' string {yaml_file}", file=sys.stderr)
            return None
        return var.strip()

    def extract_needed_modules(self, element_name: str, elements: Dict[str, Any], control_name: str,
                               yaml_file: Path) -> List[str] | None:

        modules: List[str] = None
        if 'modules' in elements:
            if isinstance(elements['modules'], list):
                modules = elements['modules']
            elif isinstance(elements['modules'], str):
                modules.append(elements.get('modules').strip())
            else:
                print(f"Warning: 'modules' for '{element_name}' must be a list or a string; {yaml_file}",
                      file=sys.stderr)
        return modules

    def extract_module(self, element_name: str, elements: Dict[str, Any], control_name: str, yaml_file: Path) -> str:
        module_name = elements.get('module', f'{element_name}.{self.target_class}')
        if not isinstance(module_name, str):
            print(f"Warning: 'module_name' for '{element_name}' must be a string; {yaml_file}", file=sys.stderr)
        else:
            module_name = module_name.strip()

        return module_name

    def resolve_literal_is_var(self, value: str):
        is_a_var = value.startswith('_') and value.endswith('_')
        if is_a_var:
            value = value[1:-1]

        return is_a_var, value

    def extract_name(self, element_name: str, elements: Dict[str, Any], control_name: str, yaml_file: Path) -> str:
        name = elements.get('name', control_name)
        if not isinstance(name, str):
            print(f"Warning: 'name' for '{element_name}' must be a string; {yaml_file}", file=sys.stderr)
        else:
            name = name.strip()

        return name

    def _extract_str_or_list(self, val: Any, ctx: str, yaml_file: Path) -> List[str]:
        """Normalize a 'string, or list of strings' YAML value into a list of stripped strings."""
        out: List[str] = []
        if val is None:
            return out
        if isinstance(val, str):
            if val.strip():
                out.append(val.strip())
        elif isinstance(val, list):
            for v in val:
                if isinstance(v, str) and v.strip():
                    out.append(v.strip())
                else:
                    print(f"Warning: {ctx} list entries must be strings; ignoring {v!r} {yaml_file}",
                          file=sys.stderr)
        else:
            print(f"Warning: {ctx} must be a string or list of strings; ignoring {yaml_file}", file=sys.stderr)
        return out

    def extract_variables_block(self, class_def: Dict[str, Any], yaml_file: Path) -> Dict[str, Dict[str, Any]]:
        """Extract and normalize the class-level 'variables:' block:

           variables:
             <name>:
               type: <cpp type>            # required
               access: public|protected|private   # default: private
               default: <value>            # optional; formatted per `type` via _format_cpp_literal
               module: [ <modules> ]       # optional; string or list, added to the file's imports
               include: [ <headers> ]      # optional; string or list, added to the global module fragment

           Returns a dict keyed by variable name, in declaration order, mapping to
           {type, access, has_default, default, modules, includes}.
        """
        raw = class_def.get('variables')
        if raw is None:
            return {}
        if not isinstance(raw, dict):
            print(f"Warning: 'variables' must be a mapping; ignoring {yaml_file}", file=sys.stderr)
            return {}

        allow = self._allowed_sets()
        result: Dict[str, Dict[str, Any]] = {}
        for var_name, var_def in raw.items():
            if not self._is_identifier(var_name):
                print(f"Warning: variables key '{var_name}' is not a valid C++ identifier; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            if not isinstance(var_def, dict):
                print(f"Warning: variables.'{var_name}' must be a mapping; skipping {yaml_file}", file=sys.stderr)
                continue
            self._warn_unknown_keys(var_def, allow["variable_def"], f"variables.'{var_name}'", yaml_file)

            cpp_type = var_def.get('type')
            if not isinstance(cpp_type, str) or not cpp_type.strip():
                print(f"Error: variables.'{var_name}' missing required 'type' string; skipping {yaml_file}",
                      file=sys.stderr)
                continue
            cpp_type = cpp_type.strip()

            access = var_def.get('access', 'private')
            if not isinstance(access, str) or access.strip().lower() not in ('public', 'protected', 'private'):
                print(f"Warning: variables.'{var_name}'.access must be one of public/protected/private; "
                      f"defaulting to private {yaml_file}", file=sys.stderr)
                access = 'private'
            else:
                access = access.strip().lower()

            result[var_name] = {
                'type': cpp_type,
                'access': access,
                'has_default': 'default' in var_def,
                'default': var_def.get('default'),
                'modules': self._extract_str_or_list(var_def.get('module'), f"variables.'{var_name}'.module",
                                                       yaml_file),
                'includes': self._extract_str_or_list(var_def.get('include'), f"variables.'{var_name}'.include",
                                                        yaml_file),
            }
        return result

    def format_variable_declaration(self, var_name: str, var_def: Dict[str, Any]) -> str:
        """Format one normalized 'variables:' entry as a class member declaration."""
        cpp_type = var_def['type']
        if var_def['has_default']:
            lit = self._format_cpp_literal(var_def['default'], cpp_type, string_style="literal")
            return f"   {cpp_type} {var_name} {{{lit}}};"
        return f"   {cpp_type} {var_name} {{}};"

    def collect_variable_modules(self, variables: Dict[str, Dict[str, Any]]) -> List[str]:
        """Collect, in first-seen order, the deduplicated module imports requested across all variables."""
        mods: List[str] = []
        for var_def in variables.values():
            for m in var_def.get('modules', []):
                if m not in mods:
                    mods.append(m)
        return mods

    def collect_variable_includes(self, variables: Dict[str, Dict[str, Any]]) -> List[str]:
        """Collect, in first-seen order, the deduplicated #include directives requested across all variables.
           Bare header paths are quoted; entries already wrapped in "..." or <...> are used as-is.
        """
        incs: List[str] = []
        for var_def in variables.values():
            for inc in var_def.get('includes', []):
                directive = inc if (inc.startswith('"') or inc.startswith('<')) else f'"{inc}"'
                if directive not in incs:
                    incs.append(directive)
        return incs

    def extract_position(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> str:
        pos = 'wxDefaultPosition'
        if 'pos' in elements:
            if isinstance(elements['pos'], list):
                pos_a = elements['pos']
                x = pos_a[0] if len(pos_a) > 0 else -1
                y = pos_a[1] if len(pos_a) > 1 else -1
                pos = f"wxPoint{{{x}, {y if y != -1 else 'wxDefaultCoord'}}}"
            elif isinstance(elements['pos'], str):
                p = elements['pos'].strip()
                pos = p  # f'{{p}}'
            else:
                print(f"Warning: 'pos' for '{element_name}' must be a string or List[str]; {yaml_file}",
                      file=sys.stderr)
                pos = 'wxDefaultPosition'
        else:
            pos = elements.get('pos', pos)
        return pos

    def extract_size(self, element_name: str, elements: Dict[str, Any], control_class: str, yaml_file: Path) -> str:
        size: str = 'wxDefaultSize'
        if 'size' in elements and isinstance(elements['size'], list):
            size_a = elements['size']
            w = size_a[0] if len(size_a) > 0 else -1
            h = size_a[1] if len(size_a) > 1 else -1
            size = f"wxSize{{{w}, {h if h != -1 else 'wxDefaultCoord'}}}"
        else:
            size_token = elements.get('size', "")
            if size_token != "":
                default_key = size_token
            else:
                # Choose default size token based on control class via size_mapping
                if control_class in ('SpinCtrl', 'SpinCtrlDouble'):
                    default_key = 'sizeCtrlSpin'
                elif control_class in ('ComboBox', 'Choice'):
                    default_key = 'sizeCtrlComboLike'
                elif control_class in ('IntComboBox', 'IntChoice'):
                    default_key = 'sizeCtrlIntComboLike'
                elif control_class in ('Button', 'ToggleButton'):
                    default_key = 'sizeCtrlButton'
                elif self.target_class == 'Group':
                    default_key = 'sizeGroup'
                elif self.target_class == 'Page':
                    default_key = 'sizePage'
                elif self.target_class == 'WizardPage':
                    default_key = 'sizeWizardPage'
                elif control_class in ('StaticText', 'MarkupText'):
                    default_key = 'sizeLabel'
                else:
                    default_key = 'sizeCtrl'

            # Prefer mapped value, fall back to key token
            size_token = self.size_mapping.get(default_key, default_key)
            size = size_token

        return size

    def extract_sizer(self, elements: Dict[str, Any]) -> SizerProperties:

        layout = self.SizerProperties(
            kind=elements.get("kind", "flexgrid"),
            position=tuple(elements["position"]) if "position" in elements else None,
            span=tuple(elements["span"]) if "span" in elements else None,
            rows=elements.get("rows", 1),
            cols=elements.get("cols", 1),
            proportion=elements.get("proportion", 1),
            growable_rows=elements.get("growable_rows", []),
            growable_cols=elements.get("growable_cols", []),
            col_width=elements.get("col_width", 0),
            row_height=elements.get("row_height", 0),
            hgap=elements.get("hgap", 0),
            vgap=elements.get("vgap", 0),
            border=elements.get("border", 0),
            min_size=tuple(elements["min_size"]) if "min_size" in elements else None,
            size=tuple(elements["size"]) if "size" in elements else None)

        return layout

    def extract_style(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> str:
        style = ''
        if 'style' in elements:
            if isinstance(elements['style'], list):
                style = '|'.join(elements['style'])
            elif isinstance(elements['style'], int):
                ss = elements['style']
                style = f'{{ss}}'
            elif isinstance(elements['style'], str):
                style = elements['style']
            else:
                print(
                    f"Warning: 'style' for '{element_name}' must be a list, a string or an integer; {yaml_file}",
                    file=sys.stderr)
        else:
            # Default to wxTAB_TRAVERSAL for Groups and Pages to enable tab navigation
            if self.target_type in ("groups", "pages", "wizardpages"):
                style = 'wxTAB_TRAVERSAL'
            else:
                style = '0'
        return style

    def extract_uicreate_flags(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> Tuple[
        List[str], str, bool]:
        uicf_node = elements.get('uicreateflags', None)
        cflags_list: List[str] = []

        if isinstance(uicf_node, str):
            if uicf_node.strip():
                single_flag = uicf_node.strip()
                if single_flag.startswith('wx::UICreateFlags::'):
                    single_flag = single_flag[slice(len('wx::UICreateFlags::'), len(single_flag))]
                elif single_flag.startswith('UICreateFlags::'):
                    single_flag = single_flag[slice(len('UICreateFlags::'), len(single_flag))]
                cflags_list.append(single_flag)
            else:
                print(f"Warning: 'uicreateflags' for '{element_name}' must be non-empty; {yaml_file}",
                      file=sys.stderr)
        elif isinstance(uicf_node, list):
            for f in uicf_node:
                if isinstance(f, str) and f.strip():
                    single_flag = f.strip()
                    if single_flag.startswith('wx::UICreateFlags::'):
                        single_flag = single_flag[slice(len('wx::UICreateFlags::'), len(single_flag))]
                    elif single_flag.startswith('UICreateFlags::'):
                        single_flag = single_flag[slice(len('UICreateFlags::'), len(single_flag))]
                    cflags_list.append(single_flag)
                else:
                    print(
                        f"Warning: 'uicreateflags' list contains non-string/empty value for '{element_name}' {yaml_file}",
                        file=sys.stderr)

        # Extract is_group: if true, ensure Group flag is included
        is_group = elements.get('is_group', False)
        if not isinstance(is_group, bool):
            print(f"Warning: 'is_group' for '{element_name}' must be hs_bool {yaml_file}",
                  file=sys.stderr)
            is_group = False

        if is_group and "Group" not in cflags_list:
            cflags_list.append("Group")

        if cflags_list == []:
            cflags_list.append("Null")

        cflags = " | ".join([f"UICreateFlags::{f}" for f in cflags_list])

        return cflags_list, cflags, is_group

    def extract_value(self, element_name: str, elements: Dict[str, Any], control_class: str, base_class: str,
                      yaml_file: Path) -> tuple[str, bool]:

        value_is_literal: bool = False
        value: str = ""
        control_contains_value = self.control_contains_value_mapping.get(control_class,
                                                                         self.control_contains_value_mapping.get(
                                                                             base_class, False))
        # tp = elements.get('contains') if self.target_class == 'Group' else 'std::string'
        tp = self.extract_data_type(element_name, elements, yaml_file)
        # Get the initialization value (string) for the control, defaulting to '' if not present.
        if not tp is None and 'value' in elements:
            if isinstance(elements['value'], list):
                # if presented as a list, it is taken to be a variable name
                v = elements['value'][0].strip()
                # value = self._format_cpp_literal(v, tp, string_style="construct")
                value = v
                value_is_literal = False
            else:
                v = elements.get('value')
                # is_a_var, value = self.resolve_literal_is_var(v)
                # if is_a_var:
                #     value_is_literal = False
                # else:
                value = self._format_cpp_literal(v, tp, string_style="construct")
                value_is_literal = True
        elif 'default' in elements:
            # No explicit 'value': fall back to 'default', wrapped as <type> { <default> }
            # instead of the class's generic default (e.g. contains: ID::Type, default: ID::Type::Null
            # -> ID::Type { ID::Type::Null }).
            wrap_type = tp if tp is not None else self.control_value_mapping.get(
                control_class, self.control_value_mapping.get(base_class, ""))
            default_lit = self._format_cpp_literal(elements.get('default'), tp, string_style="construct")
            value = f'{wrap_type} {{ {default_lit} }}'
            value_is_literal = False
        else:
            if tp is None:
                value = f'{self.control_value_mapping.get(control_class, self.control_value_mapping.get(base_class, ""))} {{ {self.control_default_mapping.get(control_class, self.control_default_mapping.get(base_class, ""))} }}'
            else:
                value = f'{tp} {{ {self.control_default_mapping.get(control_class, self.control_default_mapping.get(base_class, ""))} }}'

            value_is_literal = False

        return value, value_is_literal

    def _emit_page_scope_args(self, page_key: str, page_def: Dict[str, Any], yaml_file: Path
                              ) -> Optional[Tuple[List[str], str, List[Tuple[str, str, bool, str, str, Any]]]]:
        """
        Parse this class's class_args: block (if present) and prepare lines for a
        static factory function that builds the args_in default anymap via
        sequential .emplace() calls (see note at call site on why this avoids
        brace-aggregate-initializing an anymap). Returns (emplace_lines, arg_name,
        extract_inside entries), or None if there's no (valid) class_args: block at
        all. emplace_lines may be empty even when non-None (a class_args block with
        only extract_inside and no args_in) -- callers must check emplace_lines
        themselves before treating this class as merge-enabled.
        """
        args_cfg = page_def.get("class_args")
        if args_cfg is None:
            return None
        arg_name, ins, _translate, extracts = self._parse_args_block(args_cfg, page_key, yaml_file, schema="class_args")
        if arg_name is None:
            return None
        inside_entries = extracts.get("inside", [])

        # Build .emplace() statement lines (one std::any construction per statement,
        # never inside a brace-init-list) for the factory function body.
        emplace_lines: List[str] = []
        for name_in, type_in, default_in in ins:
            lit = self._format_cpp_literal(default_in, type_in, string_style="construct")
            emplace_lines.append(f'         m.emplace("{name_in}", std::any({lit}));')

        return emplace_lines, arg_name, inside_entries

    def parse_yaml_file(self, yaml_file: Path) -> Dict[str, Any]:
        """Parse the YAML file and return the group definitions."""
        try:
            with open(yaml_file, 'r', encoding='utf-8') as file:
                return yaml.safe_load(file)
        except yaml.YAMLError as e:
            # Try to provide more helpful error information
            if hasattr(e, 'problem_mark'):
                mark = e.problem_mark
                print(f"YAML parsing error in {yaml_file}:", file=sys.stderr)
                print(f"  Line {mark.line + 1}, Column {mark.column + 1}: {e.problem}", file=sys.stderr)
                if hasattr(e, 'context'):
                    print(f"  Context: {e.context}", file=sys.stderr)
            raise ValueError(f"Invalid YAML format in {yaml_file}: {e}")

    def _generate_event_handler(self, handler: Dict[str, Any], member_name: str, member_def: Dict[str, Any]) -> str:
        """Generate event handler code."""
        event = handler.get('event', 'EVT_TEXT')
        type = handler.get('type', 'wxEvent')
        handler_code = handler.get('handler', 'event.Skip();')

        # Normalize handler code - handle both \n escapes and actual newlines
        if isinstance(handler_code, str):
            handler_code = handler_code.replace('\\n', '\n')
            lines = [line.strip() for line in handler_code.split('\n')]
            handler_code = '\n         '.join(lines)

        # Support a single event or a list of events
        events = event if isinstance(event, (list, tuple)) else [event]
        wx_events = [self._normalize_event_name(e) for e in events]

        # Generate one hook per event; caller decides whether to prefix with '->' or '.'
        hooks = [
            f"hookAndHandle({wx_evt}, [this]({type} &event) {{\n            {handler_code}}})"
            for wx_evt in wx_events
        ]

        # If multiple, chain them with leading '.' for subsequent hooks (the first will be prefixed by caller)
        return ("\n         .").join(hooks)

    def _emit_item_args(self, member_def: Dict[str, Any], parent_args_var: Optional[str], yaml_file: Path,
                        ctx: str) -> tuple[list[str], Optional[str], list[tuple[str, str, bool, str, str, Any]]]:
        """If the item has an args: block, generate local anymap lines -- first insert:
           (index-assignment from the parent args), then translate: (index-assignment via
           param<T>() from each entry's own source anymap), then extract_before (param() reads
           against each entry's own explicit anymap/key, also before construction) -- and return
           (lines, local_map_name, extract_after entries); extract_after is for the caller to
           emit once construction is done, since 'before' and 'after' are positioned relative to
           a construction call this function doesn't itself emit.

           arg_name only matters when insert/translate entries are present (it names the local
           anymap that gets passed as the child's 'args' argument); extract_before/extract_after
           entries carry their own source anymap/key explicitly and don't consult it, so an
           args block containing only extract_before/extract_after doesn't need arg_name
           at all -- local_name stays None and callers fall back to forwarding parent_args_var
           unmodified."""
        lines: list[str] = []
        local_name: Optional[str] = None
        extract_after: list[tuple[str, str, bool, str, str, Any]] = []
        args_block = member_def.get("args")
        if isinstance(args_block, dict):
            arg_name, ins, translate, extracts = self._parse_args_block(args_block, ctx, yaml_file,
                                                                         schema="args")
            extract_after = extracts.get("after", [])
            base = parent_args_var if parent_args_var else "args"

            if ins or translate:
                if not arg_name:
                    print(f"Warning: {ctx}.args has insert/translate entries but no 'arg_name'; "
                          f"ignoring them and forwarding '{base}' unmodified {yaml_file}", file=sys.stderr)
                elif arg_name == base:
                    print(f"Warning: {ctx}.args.arg_name '{arg_name}' must not be the same as the "
                          f"parent args variable '{base}' (would emit a self-shadowing 'anymap {base} = {base};'); "
                          f"ignoring this args block and forwarding '{base}' unmodified {yaml_file}",
                          file=sys.stderr)
                else:
                    local_name = arg_name
                    if ins:
                        lines.append(f"      anymap {local_name} = {base} ;")
                    else:
                        first_src = translate[0][2]
                        lines.append(f"      anymap {local_name} = {first_src} ;")
                    # insert: -- direct index-assignment using type-aware literals
                    for n, ty, v in ins:
                        lit = self._format_cpp_literal(v, ty, string_style="construct")
                        lines.append(f"      {local_name}[\"{n}\"] = {lit};")
                    # translate: -- index-assignment via param<T>() reading from each entry's
                    # own source anymap/key
                    for n, ty, src_map, src_key, default in translate:
                        lit = self._format_cpp_literal(default, ty, string_style="literal")
                        lines.append(f'      {local_name}["{n}"] = param<{ty}>({src_map}, "{src_key}", {lit});')
            elif arg_name:
                print(f"Warning: {ctx}.args 'arg_name' is set but there are no insert/translate "
                      f"entries; ignoring it {yaml_file}", file=sys.stderr)

            # extract_before -- read values out right before construction, from each entry's own
            # explicit anymap/key (commonly local_name, once insert/translate have built it)
            for var_name, ty, no_auto, map_name, entry_name, default in extracts.get("before", []):
                lit = self._format_cpp_literal(default, ty, string_style="construct")
                prefix = "" if no_auto else "auto "
                lines.append(f'      {prefix}{var_name} = param({map_name}, "{entry_name}", {lit});')

        return lines, local_name, extract_after

    def _signature_with_args(self, signature: str, args_var: Optional[str]) -> str:
        """Append ', {args_var}' to signature if args_var is provided and signature doesn't already end with it."""
        if not args_var:
            return signature + ', nullanymap'
        if args_var in signature:
            return signature
        # If user provided a custom signature, we can't reliably infer commas; assume it's comma-separated
        return signature + f", {args_var}"

    def _generate_validator(self, validator: Dict[str, Any], member_name: str, member_def: Dict[str, Any]) -> str:
        """Generate validator code."""
        validator_class = validator.get('class', 'GenericValidator')
        allow_empty = validator.get('allow_empty', True)

        # Get the data type from the control's 'contains' property
        data_type = member_def.get('contains', 'std::string')

        # Helper: map transfer_model yaml to C++ enum token
        def transfer_enum(val: str) -> str:
            v = (val or "").strip()

            if not v:
                return ""
            up = v.lower()
            if up == "byindex":
                return "hs::TransferModel::ByIndex"
            if up == "byclientdata":
                return "hs::TransferModel::ByClientData"
            if up == "bytext":
                return "hs::TransferModel::ByText"
            print(f"Warning: unknown transfer_model '{val}', ignoring", file=sys.stderr)
            return ""

        control_class = member_def.get('class', 'TextCtrl')
        base_class = member_def.get('base_class', '')

        if validator_class == 'CapsValidator':
            return f"addValidator(new CapsValidator({str(allow_empty).lower()}, {member_name}->liveAddr(), [] {{ return settings()->useCaps(); }}))"
        elif validator_class == 'GenericValidator':
            return f"addValidator(new GenericValidator({str(allow_empty).lower()}, {member_name}->liveAddr()))"
        else:
            # Special handling for ComboLike validators' transfer_model + template control class
            if validator_class in ('ComboLikeValidator', 'ComboLikeCapsValidator') and (
                    control_class in ('Combo', 'Choice') or base_class in ('Combo', 'Choice')):
                tm = validator.get('transfer_model', "")

                if tm is None:
                    raise ValueError(
                        f"Warning: 'transfer_model' missing for {validator_class} on {control_class} '{member_name}'")

                tm_enum = transfer_enum(validator.get('transfer_model'))
                if tm_enum == "":
                    raise ValueError(
                        f"Warning: unknown transfer_model '{tm}' for {validator_class} on {control_class} '{member_name}'")

                # Inject template argument with control class
                return f"addValidator(new {validator_class}<{control_class}>({str(allow_empty).lower()}, {member_name}->liveAddr(), {tm_enum}))"

            # All other types/controls: ignore transfer_model, keep original 2-arg form
            return f"addValidator(new {validator_class}({str(allow_empty).lower()}, {member_name}->liveAddr()))"

    def _generate_labels(self, control_identity_or_element: Any, all_elements: Any) -> List[str]:
        """Generate label creation code for the new list-based schema.
           Accepts either:
             - control_identity_or_element: identity string, with all_elements as the full elements list, or
             - control_identity_or_element: the single element dict for this control (recommended), all_elements unused.
        """
        code: List[str] = []

        # Resolve element dict
        element = None
        if isinstance(control_identity_or_element, dict):
            element = control_identity_or_element
        elif isinstance(control_identity_or_element, str) and isinstance(all_elements, list):
            ident = control_identity_or_element
            for el in all_elements:
                if isinstance(el, dict) and (el.get("section") == ident or el.get("Section") == ident):
                    element = el
                    break

        if not isinstance(element, dict):
            self._dbg("_generate_labels: no element dict resolved (identity not found, or bad arg) - "
                      "DROPPED, no labels generated")
            return code

        items = element.get('items', [])
        if not isinstance(items, list):
            self._dbg(f"_generate_labels: section '{element.get('section') or element.get('Section')}' "
                      f"'items' is a {type(items).__name__}, not a list - DROPPED")
            return code

        for item in items:
            if not isinstance(item, dict) or 'labels' not in item:
                continue
            self._dbg(f"_generate_labels: section '{element.get('section') or element.get('Section')}': "
                      f"found 'labels' item with {len(item['labels']) if isinstance(item['labels'], list) else 0} entr(y/ies)")

            labels_seq = item['labels']
            if not isinstance(labels_seq, list):
                continue

            for entry in labels_seq:
                if not isinstance(entry, dict):
                    continue
                label_key = entry.get('key')
                if not isinstance(label_key, str) or not label_key:
                    continue

                label_tag = entry.get('name')
                if not isinstance(label_tag, str) or not label_tag:
                    label_tag = label_key

                if not isinstance(label_tag, str) or not label_tag:
                    label_tag = label_key

                label_value = entry.get('value', "")

                flags = entry.get('style', [])
                flags_str = ' | '.join(flags) if flags else 'wxALIGN_RIGHT | wxALIGN_CENTER_VERTICAL'

                if 'size' in entry and isinstance(entry['size'], list):
                    size_a = entry['size']
                    w = size_a[0] if len(size_a) > 0 else -1
                    h = size_a[1] if len(size_a) > 1 else -1
                    size_str = f"wxSize{{{w}, {h if h != -1 else 'wxDefaultCoord'}}}"
                else:
                    default_key = entry.get('size', '') or 'sizeLabel'
                    size_token = self.size_mapping.get(default_key, default_key)
                    size_str = size_token

                # NOTE NOTE: The below text is no longer true - size and style ARE emitted now

                # NOTE: 'size' and 'style' on label entries are parsed above (size_str,
                # flags_str) but are NOT valid for createLabel() and must not be emitted —
                # see docs/yaml-ui-reference.md "Known limitations". Do not wire these back
                # in without confirming why they were dropped.

                # Size added by adding extra default parameter to createLabel GH 21/7/2026

                if isinstance(label_value, list):
                    # A label 'value:' given as a one-item list (e.g. `value: [ GT ]`) names a
                    # variable/expression to emit unquoted, rather than a literal string.
                    label_value = str(label_value[0]).strip()
                    Q = ''
                else:
                    Q = '"'

                code.append(
                    f"         .createLabel(UICreateFlags::Label, \"{label_tag}\", {Q}{label_value}{Q}, {size_str}, {flags_str})")

                if self.sizer_info:
                    # Get sizer information
                    sizer_def = entry.get('sizer')
                    if sizer_def:
                        sizer_properties: CppGenerator.SizerProperties = self.extract_sizer(sizer_def)
                        code.append(
                            f'         // Sizer information: Position: {sizer_properties.position}, Proportion: {sizer_properties.proportion}, Border: {sizer_properties.border}, Flags: {sizer_properties.flag}')

        return code

    def _format_cpp_literal(self, val: Any, ty: Optional[str], *, string_style: str = "literal") -> str:
        """Format a YAML/Python scalar as a C++ literal or expression, guided by an optional type token.
           Rules:
             - If val is an explicit C++ expression (contains '{'/'}'/'('/')'/'::'), emit as-is.
             - Unless the type is string/std::string: a bare numeric literal carrying a C++
               suffix (-1L, 0x10u, 3.0f, 123ULL) or a bare identifier (wxNOT_FOUND, nullptr)
               is also emitted as-is, rather than being quoted or run through int()/float()
               (which would choke on the suffix / non-numeric text).
             - For bool/hs_bool types, emit true/false (string- and Python-bool aware).
             - If no type is given and val is the string 'true'/'false', emit unquoted.
             - For string/std::string types, quote; string_style="construct" wraps as std::string{"..."}
               instead of a bare literal (needed where an anymap/std::any must disambiguate the type).
             - For numeric types, coerce with a safe fallback; a value that fails to coerce
               (and wasn't already caught by the literal/identifier check above -- e.g. a typo)
               is emitted as-is with a warning rather than silently collapsing to 0/0.0.
             - Otherwise fall back on val's Python runtime type, defaulting to a quoted string.
        """
        t = (ty or "").strip().lower()

        # Allow explicit C++ expressions verbatim (e.g., std::string{"General"}, ID::Null)
        if isinstance(val, str) and ("{" in val or "::" in val or "(" in val or ")" in val):
            return val

        if isinstance(val, str) and t not in ("string", "std::string"):
            s = val.strip()
            if s.lower() not in ("true", "false") and (
                    _CPP_NUMERIC_LITERAL_RE.match(s) or _CPP_IDENTIFIER_RE.match(s)):
                return s

        if t in ("bool", "hs_bool"):
            if isinstance(val, str):
                return "true" if val.strip().lower() in ("1", "true", "yes") else "false"
            return "true" if val else "false"

        if not t and isinstance(val, str) and val.strip().lower() in ("true", "false"):
            return val.strip().lower()

        if t in ("string", "std::string"):
            s = "" if val is None else str(val)
            if string_style == "construct":
                inner = s if (s.startswith('"') and s.endswith('"')) else f'"{s}"'
                return f'std::string{{{inner}}}'
            return f'"{s}"'

        if t in ("double", "float"):
            try:
                return str(float(val))
            except (TypeError, ValueError):
                print(f"Warning: default value {val!r} is not a valid {t} literal; emitting as-is "
                      f"(this will likely fail to compile)", file=sys.stderr)
                return str(val)

        if t in ("int", "long", "long long", "unsigned", "unsigned int"):
            try:
                return str(int(val))
            except (TypeError, ValueError):
                print(f"Warning: default value {val!r} is not a valid {t} literal; emitting as-is "
                      f"(this will likely fail to compile)", file=sys.stderr)
                return str(val)

        # Unrecognized/absent type token: infer from Python runtime type.
        if isinstance(val, bool):
            return "true" if val else "false"
        if isinstance(val, (int, float)):
            return str(val)

        return f'"{"" if val is None else str(val)}"'

    # Which extract_* timing keys are valid for each args schema, and what YAML key
    # spells each one. class_args only offers "inside" (this class's own ctor body is
    # the only code its own YAML can inject into); args only offers "before"/
    # "after" (the referenced control's own ctor body -- if it even has one -- is owned
    # by a different YAML file's class_args, not by whoever references it here);
    # wizard_class_args offers none (Wizard's ctor has no default-args/merge mechanism
    # to extract against). See yaml-generator-reference.md for the full rationale.
    _TIMING_KEYS_BY_SCHEMA = {
        "class_args": {"inside": "extract_inside"},
        "wizard_class_args": {},
        "args": {"before": "extract_before", "after": "extract_after"},
    }

    _KNOWN_ARG_TYPES = {
        "bool", "hs_bool",
        "string", "std::string",
        "int", "long", "long long", "unsigned", "unsigned int",
        "double", "float",
    }

    def _parse_triplets(self, arr: Any, ctx: str, key_name: str, yaml_file: Path) -> list[tuple[str, str, Any]]:
        """Parse a flat [name, type, value, name, type, value, ...] array (insert:/args_in:)
           into (name, type, value) tuples."""
        res: list[tuple[str, str, Any]] = []
        if arr is None:
            return res
        if not isinstance(arr, list):
            print(f"Warning: {ctx}.{key_name} must be a list {yaml_file}", file=sys.stderr)
            return res

        i = 0
        n = len(arr)
        while i < n:
            if i + 2 >= n:
                print(f"Warning: {ctx}.{key_name} has a trailing incomplete (name,type,value) "
                      f"entry starting at index {i} {yaml_file}", file=sys.stderr)
                break
            entry_name, ty, v = arr[i], arr[i + 1], arr[i + 2]
            i += 3

            if not isinstance(entry_name, str) or not entry_name.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 3}] name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            name_clean = entry_name.strip()
            if not self._is_identifier(name_clean):
                print(
                    f"Warning: {ctx}.{key_name}[{i - 3}] '{name_clean}' is not an identifier; allowed [A-Za-z_][A-Za-z0-9_]* {yaml_file}",
                    file=sys.stderr)
            if not isinstance(ty, str) or not ty.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 2}] type must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            ty_clean = ty.strip()
            if ty_clean.lower() not in self._KNOWN_ARG_TYPES:
                print(f"Warning: {ctx}.{key_name}[{i - 2}] unknown type '{ty_clean}' {yaml_file}",
                      file=sys.stderr)
            res.append((name_clean, ty_clean, v))

        # duplicate detection within this list
        seen = set()
        dups = []
        for entry_name, _, _ in res:
            if entry_name in seen:
                dups.append(entry_name)
            else:
                seen.add(entry_name)
        if dups:
            print(f"Warning: {ctx}.{key_name} has duplicate names {sorted(set(dups))} {yaml_file}",
                  file=sys.stderr)
        return res

    def _parse_translate_entries(self, arr: Any, ctx: str, key_name: str, yaml_file: Path
                                 ) -> list[tuple[str, str, str, str, Any]]:
        """Parse a flat [new_arg_name, arg_type, old_anymap_name, old_arg_name, default_value, ...]
           array (translate:) into (new_arg_name, arg_type, old_anymap_name, old_arg_name,
           default_value) tuples. Each entry generates
           `{xxx}["new_arg_name"] = param<arg_type>(old_anymap_name, "old_arg_name", default_value);`."""
        res: list[tuple[str, str, str, str, Any]] = []
        if arr is None:
            return res
        if not isinstance(arr, list):
            print(f"Warning: {ctx}.{key_name} must be a list {yaml_file}", file=sys.stderr)
            return res

        i = 0
        n = len(arr)
        while i < n:
            if i + 4 >= n:
                print(f"Warning: {ctx}.{key_name} has a trailing incomplete (new_arg_name, arg_type, "
                      f"old_anymap_name, old_arg_name, default_value) entry starting at index {i} {yaml_file}",
                      file=sys.stderr)
                break
            name, ty, old_map, old_key, default = arr[i], arr[i + 1], arr[i + 2], arr[i + 3], arr[i + 4]
            i += 5

            if not isinstance(name, str) or not name.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 5}] new_arg_name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            name_clean = name.strip()
            if not self._is_identifier(name_clean):
                print(f"Warning: {ctx}.{key_name}[{i - 5}] '{name_clean}' is not an identifier; "
                      f"allowed [A-Za-z_][A-Za-z0-9_]* {yaml_file}", file=sys.stderr)

            if not isinstance(ty, str) or not ty.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 4}] arg_type must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            ty_clean = ty.strip()
            if ty_clean.lower() not in self._KNOWN_ARG_TYPES:
                print(f"Warning: {ctx}.{key_name}[{i - 4}] unknown type '{ty_clean}' {yaml_file}", file=sys.stderr)

            if not isinstance(old_map, str) or not old_map.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 3}] old_anymap_name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            old_map_clean = old_map.strip()

            if not isinstance(old_key, str) or not old_key.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 2}] old_arg_name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            old_key_clean = old_key.strip()

            res.append((name_clean, ty_clean, old_map_clean, old_key_clean, default))

        seen = set()
        dups = []
        for entry_name, _, _, _, _ in res:
            if entry_name in seen:
                dups.append(entry_name)
            else:
                seen.add(entry_name)
        if dups:
            print(f"Warning: {ctx}.{key_name} has duplicate names {sorted(set(dups))} {yaml_file}",
                  file=sys.stderr)
        return res

    def _parse_extract_entries(self, arr: Any, ctx: str, key_name: str, yaml_file: Path
                               ) -> list[tuple[str, str, bool, str, str, Any]]:
        """Parse a flat [var_type[:no_auto], var_name, anymap_name, anymap_entry_name,
           default_value, ...] array (extract_before:/extract_inside:/extract_after:) into
           (var_name, var_type, no_auto, anymap_name, anymap_entry_name, default_value)
           tuples. Each entry generates
           `auto var_name = param(anymap_name, "anymap_entry_name", var_type{default_value});`
           (or, with the ':no_auto' type suffix, assigns into an already-declared
           local/member instead of declaring a fresh 'auto' local)."""
        res: list[tuple[str, str, bool, str, str, Any]] = []
        if arr is None:
            return res
        if not isinstance(arr, list):
            print(f"Warning: {ctx}.{key_name} must be a list {yaml_file}", file=sys.stderr)
            return res

        i = 0
        n = len(arr)
        while i < n:
            if i + 4 >= n:
                print(f"Warning: {ctx}.{key_name} has a trailing incomplete (var_type[:no_auto], var_name, "
                      f"anymap_name, anymap_entry_name, default_value) entry starting at index {i} {yaml_file}",
                      file=sys.stderr)
                break
            ty_flag, var_name, map_name, entry_name, default = arr[i], arr[i + 1], arr[i + 2], arr[i + 3], arr[i + 4]
            i += 5

            if not isinstance(ty_flag, str) or not ty_flag.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 5}] var_type must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            ty_stripped = ty_flag.strip()
            no_auto = False
            if ty_stripped.endswith(":no_auto"):
                no_auto = True
                ty_clean = ty_stripped[:-len(":no_auto")].strip()
            elif ":" in ty_stripped and not ty_stripped.startswith("std::"):
                bad_flag = ty_stripped.rsplit(":", 1)[1]
                print(f"Warning: {ctx}.{key_name}[{i - 5}] unknown var_type flag '{bad_flag}' "
                      f"(expected 'no_auto') {yaml_file}", file=sys.stderr)
                ty_clean = ty_stripped
            else:
                ty_clean = ty_stripped
            if ty_clean.lower() not in self._KNOWN_ARG_TYPES:
                print(f"Warning: {ctx}.{key_name}[{i - 5}] unknown type '{ty_clean}' {yaml_file}", file=sys.stderr)

            if not isinstance(var_name, str) or not var_name.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 4}] var_name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            var_name_clean = var_name.strip()
            if not self._is_identifier(var_name_clean):
                print(f"Warning: {ctx}.{key_name}[{i - 4}] '{var_name_clean}' is not an identifier; "
                      f"allowed [A-Za-z_][A-Za-z0-9_]* {yaml_file}", file=sys.stderr)

            if not isinstance(map_name, str) or not map_name.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 3}] anymap_name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            map_name_clean = map_name.strip()

            if not isinstance(entry_name, str) or not entry_name.strip():
                print(f"Warning: {ctx}.{key_name}[{i - 2}] anymap_entry_name must be a non-empty string {yaml_file}",
                      file=sys.stderr)
                continue
            entry_name_clean = entry_name.strip()

            res.append((var_name_clean, ty_clean, no_auto, map_name_clean, entry_name_clean, default))

        seen = set()
        dups = []
        for var_name, _, _, _, _, _ in res:
            if var_name in seen:
                dups.append(var_name)
            else:
                seen.add(var_name)
        if dups:
            print(f"Warning: {ctx}.{key_name} has duplicate var_names {sorted(set(dups))} {yaml_file}",
                  file=sys.stderr)
        return res

    def _parse_args_block(self, node: Any, ctx: str, yaml_file: Path, schema: str = "class_args",
                          require_out: bool = False) -> tuple[
        Optional[str], list[tuple[str, str, Any]], list[tuple[str, str, str, str, Any]],
        dict[str, list[tuple[str, str, bool, str, str, Any]]]]:
        """Parse a class_args:/args: block: { arg_name: <str>, args_in: [name, type, value, ...] }
           (class_args/wizard_class_args) or { arg_name: <str>, insert: [name, type, value, ...],
           translate: [name, type, old_anymap_name, old_arg_name, default_value, ...] } (args),
           plus extract_inside|extract_before|extract_after: [var_type[:no_auto], var_name, anymap_name,
           anymap_entry_name, default_value, ...] -- the exact set of keys read/allowed depends on
           'schema' (one of "class_args", "wizard_class_args", "args" -- see
           _TIMING_KEYS_BY_SCHEMA and _allowed_sets()). Validates keys, structure, duplicates, and
           type/name tokens. Returns (arg_name, ins, translate, extracts) where extracts is a dict
           keyed by "before"/"inside"/"after", containing only the timings valid for this schema.
           arg_name is optional for args (only meaningful when insert/translate entries are
           present) and required for class_args/wizard_class_args (names the args_in factory var).
        """
        if not isinstance(node, dict):
            print(f"Warning: {ctx}.{schema} must be a mapping {yaml_file}", file=sys.stderr)
            return None, [], [], {}

        allow = self._allowed_sets()
        self._warn_unknown_keys(node, allow[f"{schema}_def"], f"{schema} block of '{ctx}'", yaml_file)

        # arg_name names the local anymap that insert:/translate: build (args)
        # or the class-scope factory var (class_args/wizard_class_args). It is not
        # consulted by extract_before/extract_inside/extract_after -- those name their
        # own source anymap/key per entry. args may omit it entirely when the
        # block only carries extract_before/extract_after entries; class_args and
        # wizard_class_args still require it (it names the args_in factory).
        arg_name = node.get("arg_name")
        if arg_name is not None:
            if not isinstance(arg_name, str) or not arg_name.strip():
                print(f"Warning: {ctx}.{schema}.arg_name must be a non-empty string {yaml_file}", file=sys.stderr)
                arg_name = None
            else:
                arg_name = arg_name.strip()
                if not self._is_identifier(arg_name):
                    print(
                        f"Warning: {ctx}.{schema}.arg_name '{arg_name}' is not an identifier; consider using [A-Za-z_][A-Za-z0-9_]* {yaml_file}",
                        file=sys.stderr)

        if schema != "args" and arg_name is None:
            print(f"Warning: {ctx}.{schema}.arg_name must be a non-empty string {yaml_file}", file=sys.stderr)
            return None, [], [], {}

        if schema == "args":
            ins = self._parse_triplets(node.get("insert"), ctx, "insert", yaml_file)
            translate = self._parse_translate_entries(node.get("translate"), ctx, "translate", yaml_file)
        else:
            ins = self._parse_triplets(node.get("args_in"), ctx, "args_in", yaml_file)
            translate = []

        timing_keys = self._TIMING_KEYS_BY_SCHEMA.get(schema, {})
        extracts: dict[str, list[tuple[str, str, bool, str, str, Any]]] = {}
        for timing, key in timing_keys.items():
            extracts[timing] = self._parse_extract_entries(node.get(key), ctx, key, yaml_file)

        if require_out and not any(extracts.values()):
            print(f"Warning: {ctx}.{schema} is missing required extract entries for item-level args {yaml_file}",
                  file=sys.stderr)

        # Note: unlike args_in vs. args_out under the old schema, a name appearing in
        # both ins and an extract list is NOT flagged here -- it's the normal, common
        # idiom (a key gets a class/translation default, then the same name is read
        # back out as a local for use elsewhere in the body), not a shadowing mistake.

        return arg_name, ins, translate, extracts

    def _validate_functions(self, functions_def: Any) -> Dict[str, Dict[str, Any]]:
        """Validate and normalize the functions section. Returns a dict of name -> def."""
        if functions_def is None:
            return {}

        if not isinstance(functions_def, dict):
            raise ValueError("'functions' must be a mapping of function_name -> function_def")

        normalized: Dict[str, Dict[str, Any]] = {}
        for fname, fdef in functions_def.items():
            if not isinstance(fname, str) or not fname:
                raise ValueError("Function names must be non-empty strings")
            if not isinstance(fdef, dict):
                raise ValueError(f"Function '{fname}' definition must be a mapping")

            # Validate string fields
            for key in ('args', 'return', 'body'):
                if key in fdef and not isinstance(fdef[key], str):
                    raise ValueError(f"functions.{fname}.{key} must be a string")

            # Validate bool/string fields
            if 'const' in fdef and not isinstance(fdef['const'], bool):
                raise ValueError(f"functions.{fname}.const must be a hs_bool")

            if 'static' in fdef and not isinstance(fdef['static'], bool):
                raise ValueError(f"functions.{fname}.static must be a hs_bool")

            if 'noexcept' in fdef and not (isinstance(fdef['noexcept'], (bool, str))):
                raise ValueError(f"functions.{fname}.noexcept must be a hs_bool or string")

            if 'override' in fdef and not (isinstance(fdef['override'], (bool, str))):
                raise ValueError(f"functions.{fname}.override must be a hs_bool or string")

            # Access
            access = fdef.get('access', 'public')
            if access not in ('public', 'protected', 'private'):
                raise ValueError(f"functions.{fname}.access must be one of: public, protected, private")

            # Defaults
            fdef.setdefault('args', '')
            fdef.setdefault('return', 'void')
            fdef.setdefault('override', False)
            if 'body' not in fdef:
                fdef['body'] = None   # sentinel: declaration-only, stub needed
            fdef.setdefault('const', False)
            fdef.setdefault('static', False)
            fdef['access'] = access

            normalized[fname] = fdef

        return normalized

    def _render_impl_fn(self, class_name: str, fname: str, fdef: Dict[str, Any]) -> List[str]:
        args            = fdef['args']
        ret             = fdef['return']
        const_suffix    = " const"    if fdef['const']    else ""
        noexcept_suffix = self._format_noexcept(fdef.get('noexcept', False))
        # 'override' is a virt-specifier: valid on the in-class declaration, but a
        # compile error on an out-of-line definition — never emit it here.
        body_lines = fdef.get('stub_body') or ["    // TODO: implement"]
        return [
            f"auto {class_name}::{fname} ({args})"
            f"{const_suffix}{noexcept_suffix} -> {ret} {{",
            *body_lines,
            "}",
            "",
        ]

    def _write_impl_stub(self, impl_dir: Path, class_name: str, module_name: str,
                         ns: str, stub_fns: Dict[str, Dict[str, Any]]) -> None:
        """Write (or incrementally extend) a module implementation unit stub.

        Hand-written function bodies are never touched: each function in stub_fns
        is checked for an existing 'ClassName::fname (' definition anywhere in the
        file, and only the functions not yet present get a new TODO stub appended —
        this lets a new function be added to a YAML that already has a hand-edited
        impl file without clobbering the existing implementations.
        """
        impl_dir.mkdir(parents=True, exist_ok=True)
        stub_path = impl_dir / f"{class_name}_impl.cpp"

        if not stub_path.exists():
            lines = [
                "module;",
                "// Module implementation unit — add includes your implementation needs.",
                '#include "Core/Core.h"',
                '#include <wx/event.h>',
                "",
                f"module {module_name};",
                "",
                f"namespace {ns} {{",
                "",
            ]
            for fname, fdef in stub_fns.items():
                lines.extend(self._render_impl_fn(class_name, fname, fdef))
            lines.append(f"}} // namespace {ns}")
            lines.append("")

            stub_path.write_text("\n".join(lines), encoding="utf-8")
            print(f"{stub_path} : Created (stub)")
            return

        existing = stub_path.read_text(encoding="utf-8")
        missing_fns = {
            fname: fdef for fname, fdef in stub_fns.items()
            if not re.search(rf"{re.escape(class_name)}\s*::\s*{re.escape(fname)}\s*\(", existing)
        }
        if not missing_fns:
            return  # every declared function already has a definition in the file

        new_lines: List[str] = []
        for fname, fdef in missing_fns.items():
            new_lines.extend(self._render_impl_fn(class_name, fname, fdef))

        # Insert the new stubs INSIDE the namespace: find the trailing
        # '} // namespace <ns>' line (tolerating whitespace/comment-spacing/CRLF
        # variations) and splice just above it.
        existing_lines = existing.splitlines()
        insert_at = None
        for i in range(len(existing_lines) - 1, -1, -1):
            stripped = existing_lines[i].strip()
            if not stripped:
                continue
            if stripped.startswith("}") and "namespace" in stripped:
                insert_at = i
            break  # only the last non-blank line is a candidate
        if insert_at is not None:
            updated_lines = existing_lines[:insert_at] + [""] + new_lines + existing_lines[insert_at:]
            updated = "\n".join(updated_lines).rstrip("\n") + "\n"
        else:
            # No recognizable namespace close (heavily hand-edited) — reopen the
            # namespace so the stubs still land inside it.
            updated = (existing.rstrip("\n") + f"\n\nnamespace {ns} {{\n\n"
                       + "\n".join(new_lines) + f"\n}} // namespace {ns}\n")

        stub_path.write_text(updated, encoding="utf-8")
        print(f"{stub_path} : Updated (added stub(s) for {', '.join(missing_fns.keys())})")

    def _format_noexcept(self, spec: Any) -> str:
        if spec is True:
            return " noexcept"
        if isinstance(spec, str) and spec.strip():
            return f" noexcept({spec.strip()})"
        return ""

    def generate_from_yaml(self, yaml_file: Path, rel_path: Path, output_file: Path = None) -> str:
        """
        Single entry point: parses yaml_file exactly once and, in that one pass, checks it
        for 'groups', 'pages', 'wizardpages', 'wizard', and 'book' sections, generating
        whichever are present. Output goes under <output_file>/user_interface/ (matching the
        layout generateClasses() expects).

        A `tables:` section, if present, is ignored here -- it is no longer a C++ generation
        input at all. db::TableLoader (Libs/Core/src/Table.cpp) parses `tables:`/`relationships:`
        directly at runtime instead, to CREATE TABLE the schema and CREATE VIEW a joined
        "<table>_detail" view per table with relationships.
        """

        data = self.parse_yaml_file(yaml_file)

        # 'debugging: true' is a topmost key in the YAML document, a sibling of
        # 'groups:'/'pages:'/'wizardpages:'/'book:'/'wizard:'/'tables:' - not nested
        # inside any one of them. It scopes verbose tracing to everything parsed out
        # of this one file for the rest of this call.
        self.debugging = bool(data.get('debugging', False)) if isinstance(data, dict) else False

        if self.debugging:
            self._dbg(f"==== generate_from_yaml: {yaml_file} (debugging=on) ====")

        category_targets = {"groups": "Group", "pages": "Page", "wizardpages": "WizardPage", "wizard": "Wizard",
                            "book": "Book"}
        results: List[str] = []

        # Preliminary scan - is there anything in this file worth generating?
        have_elements = False
        for category in category_targets:
            if not data.get(category, None) == None:
                have_elements = True
                section = data[category]
                if isinstance(section, dict):
                    self._dbg(f"'{category}' section present, top-level keys: {list(section.keys())}")
                else:
                    self._dbg(f"'{category}' section present but is a {type(section).__name__}, not a mapping!")
            else:
                self._dbg(f"no '{category}' section in this file")

        if not have_elements:
            if not self.quiet:
                print(f"{yaml_file} has no useful content")
            return ""

        for category in ("groups", "pages", "wizardpages", "wizard", "book"):
            try:
                if category in category_targets:
                    self.target(category_targets[category])

                self._dbg(f"-- processing category '{category}' --")
                content = self._process_category(category, data, yaml_file, rel_path, output_file / "ui")

                if content:
                    results.append(content)
                    self._dbg(f"category '{category}' produced output ({len(content)} chars)")
                else:
                    self._dbg(f"category '{category}' produced no output")
            except Exception as e:
                self._dbg(f"category '{category}' raised {type(e).__name__}: {e} - "
                          f"rest of this category is DROPPED for {yaml_file}")
                print(f"Error reading {yaml_file}: {e}", file=sys.stderr)

        return ("\n\n").join(results)

    def _process_category(self, category: str, data: Dict[str, Any], yaml_file: Path, rel_path: Path,
                          output_file: Optional[Path]) -> str:
        """
        Shared load/validate/iterate/write pipeline for one top-level YAML section
        ('groups', 'pages', 'wizardpages', 'wizard', or 'book'). Per-item validation and
        generation (which differs per category) is delegated to _generate_category_item().
        """
        items = data.get(category) if isinstance(data, dict) else None
        if not items:
            self._dbg(f"'{category}': section absent or empty - nothing to generate")
            if not self.quiet:
                print(f"(No {category})")
            return ""

        if not isinstance(items, dict):
            raise ValueError(f"'{category}' section must be a non-empty mapping of name -> def")

        self._dbg(f"'{category}': {len(items)} top-level entries found: {list(items.keys())}")

        top_verbatim = ""
        if "verbatim" in items:
            top_verbatim = self._extract_verbatim_body(items)
            self._dbg(f"'{category}': root-level 'verbatim' block found ({len(top_verbatim)} chars)")
            self._warn_unknown_keys(items, self._allowed_sets()["root"] | set(items.keys()),
                                    f"{category} root", yaml_file)

        generated: List[Tuple[str, str]] = []  # (name, module_content)
        for name, item_def in items.items():
            if name == "verbatim":
                continue  # handled above

            # A stray scalar/list sibling at this level (e.g. a misplaced flag that
            # belongs at the document root, not inside 'groups:'/'pages:') used to
            # blow up _generate_category_item's item_def.get(...) calls and abort
            # every remaining entry in this category silently. Warn and skip instead.
            if not isinstance(item_def, dict):
                print(f"Warning: '{category}.{name}' is not a mapping (got {type(item_def).__name__}: "
                      f"{item_def!r}); skipping this entry - did you mean a top-level 'debugging:' key "
                      f"instead? {yaml_file}", file=sys.stderr)
                self._dbg(f"'{category}.{name}': DROPPED (not a mapping)")
                continue

            self._dbg(f"'{category}.{name}': generating...")
            content = self._generate_category_item(category, name, item_def, yaml_file, top_verbatim, output_file)
            if content is not None:
                generated.append((name, content))
                self._dbg(f"'{category}.{name}': generated ({len(content)} chars)")
            else:
                self._dbg(f"'{category}.{name}': DROPPED (see warning above, or run_generator: false)")

        if not generated:
            raise ValueError(f"No valid {category} found to generate")
        suffix = self.target_class

        self._dbg(f"'{category}': {len(generated)}/{len(items)} entries generated: "
                  f"{[n for n, _ in generated]}")
        return self._write_or_concat(generated, suffix, rel_path, output_file, category)

    def _generate_category_item(self, category: str, name: str, item_def: Dict[str, Any], yaml_file: Path,
                                top_verbatim: str, output_file: Optional[Path]) -> Optional[str]:
        """Per-item validation + generation. Returns None to skip an item."""
        if category == "wizard":
            run_gen = item_def.get('run_generator', True)
            if not isinstance(run_gen, bool):
                print(f"Warning: wizard '{name}': 'run_generator' must be hs_bool; defaulting to true",
                      file=sys.stderr)
                run_gen = True
            if not run_gen:
                self._dbg(f"wizard '{name}': run_generator is false - DROPPED")
                return None

            if 'pages' not in item_def or not isinstance(item_def['pages'], list) or not item_def['pages']:
                print(f"Warning: wizard '{name}' has no non-empty 'pages' list", file=sys.stderr)
                self._dbg(f"wizard '{name}': DROPPED (no non-empty 'pages' list)")
                return None

            self._dbg(f"wizard '{name}': {len(item_def['pages'])} page(s) declared")
            return self.generate_wizard_module(name, item_def, yaml_file, output_file)

        if category == "book":
            run_gen = item_def.get('run_generator', True)
            if not isinstance(run_gen, bool):
                print(f"Warning: book '{name}': 'run_generator' must be hs_bool; defaulting to true",
                      file=sys.stderr)
                run_gen = True
            if not run_gen:
                self._dbg(f"book '{name}': run_generator is false - DROPPED")
                return None

            if 'pages' not in item_def or not isinstance(item_def['pages'], list) or not item_def['pages']:
                print(f"Warning: book '{name}' has no non-empty 'pages' list", file=sys.stderr)
                self._dbg(f"book '{name}': DROPPED (no non-empty 'pages' list)")
                return None

            self._dbg(f"book '{name}': {len(item_def['pages'])} page(s) declared")
            return self.generate_book_module(name, item_def, yaml_file, top_verbatim, output_file)

        # groups / pages / wizardpages
        run_gen = item_def.get('run_generator', True)
        if not isinstance(run_gen, bool):
            print(f"Warning: target '{name}': 'run_generator' must be hs_bool; defaulting to true", file=sys.stderr)
            run_gen = True
        if not run_gen:
            self._dbg(f"{self.target_class} '{name}': run_generator is false - DROPPED")
            return None

        if 'elements' not in item_def:
            print(f"Warning: {self.target_class} '{name}' has no 'elements' section", file=sys.stderr)
            self._dbg(f"{self.target_class} '{name}': DROPPED (no 'elements' key present at all)")
            return None

        elements = item_def['elements']
        if not isinstance(elements, list) or len(elements) == 0:
            if not self.quiet:
                print(f"Warning: {self.target_class} '{name}' has empty or invalid elements section",
                      file=sys.stderr)
            self._dbg(f"{self.target_class} '{name}': 'elements' present but empty/invalid "
                      f"({type(elements).__name__}) - generating anyway with no controls")
        else:
            self._dbg(f"{self.target_class} '{name}': {len(elements)} element section(s) found")

        return self.generate_ui_module(name, item_def, yaml_file, top_verbatim, output_file)

    def _write_or_concat(self, generated: List[Tuple[str, str]], suffix: str, rel_path: Path,
                         output_file: Optional[Path], category: str) -> str:
        """Write (name, module_content) pairs to disk - only touching files whose content
           actually changed, to avoid unnecessary rebuilds - or return them concatenated."""
        if not output_file:
            return ("\n\n").join(module for _, module in generated)

        dest_dir = output_file # / rel_path
        dest_dir.mkdir(parents=True, exist_ok=True)

        label = self.target_class

        for name, module_content in generated:
            base_name = name[:-6] if name.endswith('_table') else name
            pascal = self.to_pascal_case(base_name)
            out_path = dest_dir / f"{pascal}{suffix}.ixx"

            try:
                existing = out_path.read_text(encoding='utf-8') if out_path.exists() else None
            except Exception:
                existing = None

            if existing != module_content:
                out_path.parent.mkdir(parents=True, exist_ok=True)
                with open(out_path, 'w', encoding='utf-8') as f:
                    f.write(module_content)
                print(f"{out_path} : {label} OK ({'created' if existing is None else 'updated'})")
            else:
                # Keep timestamp untouched when no changes
                print(f"{out_path} : {label} OK (unchanged)")

        return generated[-1][1]


def scan_and_generate(generator,
                      args: any,
                      output_dir: Path | None) -> int:
    """Scan for *.yaml files, generate corresponding Group/Page/WizardPage .ixx files."""

    # Collect YAML files from all root directories
    yaml_files = []
    roots = args.scan;

    for root in roots:
        if not root.exists():
            print(f"Warning: Scan directory '{root}' does not exist, skipping", file=sys.stderr)
            continue
        yaml_files.extend(sorted(list(root.rglob("*.yaml"))))

    if not yaml_files:
        if not generator.quiet:
            print("No YAML files found in any of the specified directories", file=sys.stderr)
        return 0

    # Remove duplicates while preserving order
    seen = set()
    unique_yaml_files = []
    for f in yaml_files:
        if f not in seen:
            seen.add(f)
            unique_yaml_files.append(f)
    yaml_files = unique_yaml_files

    # Validate output_dir semantics (batch mode rules)
    if output_dir is not None:
        if output_dir.exists() and not output_dir.is_dir():
            print(f"Error: --output must be a directory in batch mode (got file: '{output_dir}')", file=sys.stderr)
            return 1
        if not output_dir.exists() and output_dir.suffix:
            print(f"Error: --output must be a directory in batch mode (looks like a file: '{output_dir}')",
                  file=sys.stderr)
            return 1

        uidir = Path(output_dir / "ui")
        uidir.mkdir(parents=True, exist_ok=True)

    if len(roots) == 1:
        print(f"Processing classes in {len(yaml_files)} YAML files from one directory...")
    else:
        print(f"Processing classes in {len(yaml_files)} YAML files from {len(roots)} directories...")

    for yf in yaml_files:

        full = Path(yf)
        [base] = args.scan
        base = Path(base)

        rel_path = full.relative_to(base)
        rel_path = rel_path.parent

        try:
            generator.generate_from_yaml(yf, rel_path, output_dir)
        except Exception as e:
            print(f"Error reading {yf}: {e}", file=sys.stderr)
            return 1

    return 0

def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Generate C++ Group/Page/WizardPage modules from YAML form definitions')
    parser.add_argument('--impl-dir', type=Path, help='Directory to write hand-editable _impl.cpp stubs to (default: alongside --output, or next to the source YAML)')
    parser.add_argument('--scan', type=Path, action='append', help='Scan this directory recursively for *.yaml (can be used multiple times)')
    parser.add_argument('-a', '--app-target', action='store', help='The CMake target name of the application')
    parser.add_argument('-c', '--cmake', type=Path, help='Update CMakeLists.txt file with generated modules')
    parser.add_argument('-f', '--first-pagetype', action='store', help='First page type to generate')
    parser.add_argument('-o', '--output', type=Path, help='Output directory or file path')
    parser.add_argument('-q', '--quiet', action="store_true", help='Only report important information')
    parser.add_argument('-s', '--sizer-info', action='store_true', help='Show sizer info in the generated UI classes')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-x', '--export-var', action='store', help='The name of the generated export variable like GFX_EXPORT')
    parser.add_argument('input_yaml', type=Path, nargs='?', help='Single input YAML file')

    args = parser.parse_args()
    generator = CppGenerator()
    generator.be_quiet(args.quiet)
    generator.show_sizer_info(args.sizer_info)
    generator.export_var = args.export_var

    if args.impl_dir is not None:
        generator.impl_dir = args.impl_dir

    if not args.first_pagetype is None:
        generator.next_PageType = args.first_pagetype

    if not args.app_target is None:
        generator.app_target = args.app_target

    # Scan mode (batch)
    if args.scan:
        output_dir = args.output if args.output is not None else None
        sys.exit(scan_and_generate(generator, args, output_dir))

    # Single-file mode
    if not args.input_yaml:
        print("Error: input_yaml is required unless --scan is provided", file=sys.stderr)
        sys.exit(1)

    if not args.input_yaml.exists():
        print(f"Error: Input file '{args.input_yaml}' does not exist", file=sys.stderr)
        sys.exit(1)

    try:
        result = generator.generate_from_yaml(args.input_yaml, Path("."), args.output)

        if not args.output:
            print(result)

        return 0

    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        if args.verbose:
            import traceback
            traceback.print_exc()
        return 1


if __name__ == '__main__':
    sys.exit(main())
