#!/usr/bin/env python3
"""
YAML to C++ Group Generator
Generates C++ Group module files from YAML form definitions.
"""

import yaml
import sys
import argparse
from pathlib import Path
from typing import Dict, Any, List, Tuple, Optional
import datetime
from dataclasses import dataclass


class CppGroupGenerator:
    quiet: bool = False
    verbose: bool = False
    sizer_info = False
    target_type: str = "groups"
    target_class: str = "Group"
    app_target: str = "pass_the_name_of_your_app_target_to_yaml2ui"
    now: str = datetime.datetime.now().date().isoformat() + " " + datetime.datetime.now().time().strftime("%H:%M:%S")
    next_PageType: int = 1000

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
            # Text
            'EVT_TEXT': 'wxEVT_TEXT',
            'EVT_TEXT_ENTER': 'wxEVT_TEXT_ENTER',
            'EVT_TEXT_MAXLEN': 'wxEVT_TEXT_MAXLEN',
            'EVT_TEXT_URL': 'wxEVT_TEXT_URL',

            # Buttons / toggles / check / radio
            'EVT_BUTTON': 'wxEVT_BUTTON',
            'EVT_COMMAND_BUTTON_CLICKED': 'wxEVT_COMMAND_BUTTON_CLICKED',  # legacy alias kept for compatibility
            'EVT_TOGGLEBUTTON': 'wxEVT_TOGGLEBUTTON',
            'EVT_COMMAND_TOGGLEBUTTON_CLICKED': 'wxEVT_TOGGLEBUTTON',  # normalize to modern name
            'EVT_CHECKBOX': 'wxEVT_CHECKBOX',
            'EVT_RADIOBUTTON': 'wxEVT_RADIOBUTTON',
            'EVT_RADIOBOX': 'wxEVT_RADIOBOX',

            # Choice / combo
            'EVT_CHOICE': 'wxEVT_CHOICE',
            'EVT_COMBOBOX': 'wxEVT_COMBOBOX',
            'EVT_COMBOBOX_DROPDOWN': 'wxEVT_COMBOBOX_DROPDOWN',
            'EVT_COMBOBOX_CLOSEUP': 'wxEVT_COMBOBOX_CLOSEUP',

            # Spin / slider / scrollbar
            'EVT_SLIDER': 'wxEVT_SLIDER',
            'EVT_SPINCTRL': 'wxEVT_SPINCTRL',
            'EVT_SPINCTRLDOUBLE': 'wxEVT_SPINCTRLDOUBLE',
            'EVT_SCROLL_TOP': 'wxEVT_SCROLL_TOP',
            'EVT_SCROLL_BOTTOM': 'wxEVT_SCROLL_BOTTOM',
            'EVT_SCROLL_LINEUP': 'wxEVT_SCROLL_LINEUP',
            'EVT_SCROLL_LINEDOWN': 'wxEVT_SCROLL_LINEDOWN',
            'EVT_SCROLL_PAGEUP': 'wxEVT_SCROLL_PAGEUP',
            'EVT_SCROLL_PAGEDOWN': 'wxEVT_SCROLL_PAGEDOWN',
            'EVT_SCROLL_THUMBTRACK': 'wxEVT_SCROLL_THUMBTRACK',
            'EVT_SCROLL_THUMBRELEASE': 'wxEVT_SCROLL_THUMBRELEASE',
            'EVT_SCROLL_CHANGED': 'wxEVT_SCROLL_CHANGED',

            # Date
            'EVT_DATE_CHANGED': 'wxEVT_DATE_CHANGED',

            # List / tree basics
            'EVT_LISTBOX': 'wxEVT_LISTBOX',
            'EVT_LISTBOX_DCLICK': 'wxEVT_LISTBOX_DCLICK',
            'EVT_TREE_SEL_CHANGED': 'wxEVT_TREE_SEL_CHANGED',
            'EVT_TREE_ITEM_ACTIVATED': 'wxEVT_TREE_ITEM_ACTIVATED',

            # Menu / toolbar
            'EVT_MENU': 'wxEVT_MENU',
            'EVT_UPDATE_UI': 'wxEVT_UPDATE_UI',
            'EVT_TOOL': 'wxEVT_TOOL',
            'EVT_TOOL_RCLICKED': 'wxEVT_TOOL_RCLICKED',

            # Window/general
            'EVT_SIZE': 'wxEVT_SIZE',
            'EVT_MOVE': 'wxEVT_MOVE',
            'EVT_PAINT': 'wxEVT_PAINT',
            'EVT_IDLE': 'wxEVT_IDLE',
            'EVT_TIMER': 'wxEVT_TIMER',
            'EVT_SET_FOCUS': 'wxEVT_SET_FOCUS',
            'EVT_KILL_FOCUS': 'wxEVT_KILL_FOCUS',

            # Keyboard
            'EVT_KEY_DOWN': 'wxEVT_KEY_DOWN',
            'EVT_KEY_UP': 'wxEVT_KEY_UP',
            'EVT_CHAR': 'wxEVT_CHAR',
            'EVT_CHAR_HOOK': 'wxEVT_CHAR_HOOK',

            # Mouse
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

    def be_verbose(self, _verbose: bool) -> None:
        self.verbose = bool(_verbose)

    def show_sizer_info(self, _show: bool) -> None:
        self.sizer_info = bool(_show)

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
        else:
            raise ValueError(f"Unknown target '{_targets}'")

    def generate_module(self, target_name: str, class_def: Dict[str, Any], yaml_file: Path, top_verbatim: str) -> str:
        """Generate the complete C++ group/page/wizardpage module file (list-based schema)."""
        allow = self._allowed_sets()
        self._warn_unknown_keys(class_def, allow["class_def"], f"widget class_def '{target_name}'", yaml_file)

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
        code.append(f'// file://{yaml_file} (mtime: {_mts})')
        code.append('')
        code.append('// Make any changes there. This file will be overwritten.')
        code.append('')
        code.append('#include "HoffSoft/HoffSoft.h"')

        code.append('#include "HoffSoft/CoreData.h"')
        code.append('')
        code.append('#include "HoffSoft/Util.h"')
        code.append('#include "Gfx/Widgets.h"')
        code.append('#include "Gfx/wx.h"')
        code.append('')
        code.append(f'#include "{self.app_target}/Sizes.h"')
        code.append('')
        code.append('#include <unordered_set>')
        code.append('')

        layout_key = target_name

        pascal_name = self.to_pascal_case(target_name)
        class_name = f"{pascal_name}{self.target_class}"

        # Elements are a list in the new schema
        elements = class_def.get('elements', [])
        if not isinstance(elements, list):
            elements = []

        cpp_class = class_def.get("class_name") or self.to_pascal_case(target_name) + self.target_class

        # Required imports
        required_imports = self.get_required_imports(elements, yaml_file)
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
                print(f'export_module {export_module} cannot be imported: {target_name} (file://{yaml_file})')

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

        # Determine base class (Page/Group/WizardPage)
        _, top_base_class = self.extract_control_class(target_name, class_def, yaml_file)

        code.append(f"namespace {ns} {{")
        code.append("")
        self.next_PageType += 1

        # Placement 1: top-level verbatim (inside namespace, before class)
        if isinstance(top_verbatim, str) and top_verbatim.strip():
            for line in top_verbatim.rstrip().splitlines():
                code.append(f"{line}")

        code.append(f"export class GFX_EXPORT {cpp_class} : public {top_base_class} {{")
        code.append("   std::filesystem::path layoutPath;")
        code.append("   std::string layoutKey;")

        parent_args_var_for_children: Optional[str] = None
        page_args_out_triplets: List[Tuple[str, str, Any]] = []

        # Page-level args map and outs at top of ctor
        # if top_base_class == "Page":
        packed_args_in = self._emit_page_scope_args(target_name, class_def)
        if packed_args_in is not None:
            static_lines, page_args_var, page_args_out_triplets = packed_args_in
            if static_lines is not None:
                code.append(f"   static inline anymap {page_args_var} {{")
                currentAssignLine = 0
                for line in static_lines:
                    currentAssignLine += 1
                    if currentAssignLine == len(static_lines):
                        code.append(line)
                    else:
                        code.append(line + ",")

                code.append("   };")
                parent_args_var_for_children = page_args_var

        on_kill_active = self.extract_group_method_body('on_kill_active', target_name, class_def, yaml_file)
        on_set_active = self.extract_group_method_body('on_set_active', target_name, class_def, yaml_file)
        if on_kill_active is not None or on_set_active is not None:
            code.append("")
            code.append("protected:")
            code.append("   // OnKillActive/SetActive overrides")
            if on_kill_active is not None:
                code.append(f"   auto onKillActive(bool autoDisable) -> void override;")
            if on_set_active is not None:
                code.append(f"   auto onSetActive(bool autoEnable) -> void override;")

        # Declarations
        control_decls = self.generate_control_declarations(elements, yaml_file)
        code.append("")
        code.append('\n'.join(control_decls) if control_decls else '   // No elements defined')

        # Functions (group/page level) inside class
        functions_all = self._validate_functions(class_def.get('functions'))
        access_groups = {'public': [], 'protected': [], 'private': []}
        for fname, fdef in functions_all.items():
            args = fdef['args']
            ret = fdef['return']
            body = fdef['body'].replace('\r\n', '\n').replace('\r', '\n')
            body_lines = body.split('\n')
            indented_body = '\n'.join(f"      {line}" if line else "" for line in body_lines)
            const_suffix = " const" if fdef['const'] else ""
            static_prefix = "static " if fdef['static'] else ""
            override_suffix = " override" if fdef['override'] else ""
            noexcept_suffix = self._format_noexcept(fdef.get('noexcept', False))
            fn_text = (
                f"   {static_prefix}auto {fname} ({args}){const_suffix}{noexcept_suffix} -> {ret}{override_suffix} {{\n"
                f"{indented_body}"
                f"   }}"
            )
            access_groups[fdef['access']].append(fn_text)

        def format_access_block(access_name: str, fns: List[str]) -> str:
            if not fns:
                return ""
            return f"\n{access_name}:\n" + ''.join(fns)

        public_access_block = format_access_block('public', access_groups['public'])
        protected_access_block = format_access_block('protected', access_groups['protected'])
        private_access_block = format_access_block('private', access_groups['private'])

        if public_access_block:     code.append(public_access_block)
        if protected_access_block:  code.append(protected_access_block)
        if private_access_block:    code.append(private_access_block)

        code.append("")
        code.append("public:")
        code.append(f"   ~{cpp_class}() override = default;")
        code.append("")

        # Constructor signature and base ctor call
        default_args_expr = (parent_args_var_for_children or "nullanymap")
        value_default = "PageType::Null" if top_base_class == "Page" else "std::string{}"
        pad1: str = " " * len(f"   explicit {cpp_class} ( ")
        if self.target_type == "pages":
            code.append(f"   explicit {cpp_class} ( Book *book, ")
            code.append(f"{pad1}wxWindowIDRef id, ")
            code.append(f"{pad1}const std::string& name,")
            code.append(f"{pad1}PageType::Type type = PageType::{cpp_class},")
            code.append(f"{pad1}int imageIndex = -1,")
            code.append(f"{pad1}const anymap &args = {default_args_expr})")
            code.append(f"      : {top_base_class} (book, id, name, type, imageIndex, args) {{")
        else:
            code.append(f"   explicit {cpp_class} ( UICreateFlags cflags, ")
            code.append(f"{pad1}std::string name, ")
            code.append(f"{pad1}wxWindow *pParent, ")
            code.append(f"{pad1}value_t value = {value_default},")
            code.append(f"{pad1}anymap &args = {default_args_expr},")
            code.append(f"{pad1}long style = 0)")
            code.append(f"      : {top_base_class} (cflags, name, pParent, value, args, style) {{")

    # Page args_out at ctor top
        # if top_base_class == "Page" and page_args_out_triplets:
        if page_args_out_triplets:
            for name_out, type_out, default_out in page_args_out_triplets:
                lit = self._format_default_literal(type_out, default_out)
                code.append(f'      auto {name_out} = hs::param({parent_args_var_for_children}, "{name_out}", {lit});')
            # code.append("")

        # Layout boilerplate
        code.append(
            f'      layoutPath = Util::getInstance().resourceName(UIType::GeneratorSource, "{layout_class_name}", false, nullptr);')
        code.append(
            '      ASSERT_MSG(!layoutPath.empty(), "Couldn\'t find layout resource file://" + layoutPath.string());')
        code.append(f'      layoutKey = "{layout_key}";')
        code.append("")

        # # Page-level sizer properties. Needed before any placement calls.

        if self.sizer_info:
            # Get sizer information
            sizer_def = class_def.get('sizer')
            if sizer_def:
                sizer_properties: CppGroupGenerator.SizerProperties = self.extract_sizer(sizer_def)
                code.append(f'      /*')
                code.append(f'       * Sizer information for {self.target_class}:')
                code.append(f'       *')
                code.append(f'       *        border : {sizer_properties.border}')
                code.append(f'       *     col_width : {sizer_properties.col_width}')
                code.append(f'       *          cols : {sizer_properties.cols}')
                code.append(f'       *          flag : {sizer_properties.flag}')
                code.append(f'       * growable_cols : {sizer_properties.growable_cols}')
                code.append(f'       * growable_rows : {sizer_properties.growable_rows}')
                code.append(f'       *          hgap : {sizer_properties.hgap}')
                code.append(f'       *          kind : {sizer_properties.kind}')
                code.append(f'       *      min_size : {sizer_properties.min_size}')
                code.append(f'       *      position : {sizer_properties.position}')
                code.append(f'       *    proportion : {sizer_properties.proportion}')
                code.append(f'       *    row_height : {sizer_properties.row_height}')
                code.append(f'       *          rows : {sizer_properties.rows}')
                code.append(f'       *          size : {sizer_properties.size}')
                code.append(f'       *          span : {sizer_properties.span}')
                code.append(f'       *          vgap : {sizer_properties.vgap}')
                code.append(f'       */')
                code.append(f'')

        # sizer_def = class_def.get('sizer')
        # if sizer_def:
        #     sizer_properties: CppGroupGenerator.SizerProperties = self.extract_sizer(sizer_def)
        #     if sizer_properties.kind == 'gridbag' or sizer_properties.kind == 'flexgrid':
        #         code.append(
        #             f'      setSizerType("{sizer_properties.kind}", {sizer_properties.rows}, {sizer_properties.cols}, {sizer_properties.row_height}, {sizer_properties.col_width}, {sizer_properties.vgap}, {sizer_properties.hgap});')
        #         code.append("")
        # else:
        #     raise RuntimeError(f"sizer properties missing")

        # Creation code for list-based elements
        creation_code, target_parent = self.generate_control_creation(target_name, elements, layout_class_name,
                                                                      yaml_file,
                                                                      parent_args_var_for_children)

        if creation_code:

            code.append(f'      auto targetParent = {target_parent};')
            code.append('')
            code.append('\n'.join(creation_code))

        else:
            code.append('      // No control creation code\n')

        code.append(
            '      VERIFY_MSG(this->loadLayout(layoutPath, layoutKey), "Error loading layout resource file://" + layoutPath.string());')

        if self.target_type == 'wizardpages':
            code.append("      GetPageSizer().Add(&grid(), 1, wxALL | wxGROW, borderWidth);")
            code.append('      SetSizerAndFit(&GetPageSizer(), true);')
        elif self.target_type == 'pages':
            code.append('      if (getForm())')
            code.append('         getForm()->SetSizerAndFit(&grid(), true);')

        # Placement: finally (end of ctor)
        finally_block = self._extract_finally_begin(class_def)
        if isinstance(finally_block, str) and finally_block.strip():
            for line in finally_block.rstrip().splitlines():
                code.append(f"      {line}")

        code.append("   }")
        code.append("};")

        if on_kill_active is not None or on_set_active is not None:
            code.append("")
            if on_kill_active is not None:
                code.append(f"auto {cpp_class}::onKillActive(bool autoDisable) -> void {{")
                code.append(f"{on_kill_active}")
                code.append(f"}}")
            if on_set_active is not None:
                code.append(f"auto {cpp_class}::onSetActive(bool autoEnable) -> void {{")
                code.append(f"{on_set_active}")
                code.append(f"}}")

        code.append(f"}} // namespace {ns}")
        return "\n".join(code)

    def generate_control_creation(self, group_name: str, elements: Any, layout_path: str, yaml_file: Path,
                                  parent_args_var: Optional[str]) -> Tuple[List[str], str]:
        """Build creation code from list-based elements[*].items."""
        creation_code: List[str] = []
        target_parent: str = ""

        allow = self._allowed_sets()

        if not isinstance(elements, list):
            return creation_code, target_parent

        for element in elements:
            if not isinstance(element, dict):
                continue

            # Element-level verbatim (Placement: before this element's items)
            elements_verbatim = self._extract_verbatim_body(element)
            if elements_verbatim:
                for line in elements_verbatim.rstrip().splitlines():
                    creation_code.append(f"      {line}")

            identity = element.get('identity') or element.get('Identity') or ""
            tool_tip = element.get('tool_tip', '')
            items = element.get('items', [])
            if not isinstance(items, list):
                continue

            if self.target_type == "groups":
                target_parent = "getSBSizer()->GetStaticBox();"
            elif self.target_type == "pages":
                target_parent = "getForm()"
            elif self.target_type == "wizardpages":
                target_parent = "this"
            else:
                target_parent = "pParent"

            for item in items:
                if not isinstance(item, dict):
                    continue

                # Controls in groups; groups in pages
                if self.target_type == "groups" and "widget" in item and isinstance(item["widget"], dict):
                    md = item["widget"]
                    var = self.extract_member_variable(md, f"widget '{identity}'", yaml_file)
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
                      and "widget" in item and isinstance(item["widget"], dict)):

                    md = item["widget"]
                    var = self.extract_member_variable(md, f"widget '{identity}'", yaml_file)
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

        return creation_code, target_parent

    def _generate_single_control(self, member_name: str, member_def: Dict[str, Any],
                                 control_name: str, tool_tip: str, all_elements: Dict[str, Any], yaml_file: Path,
                                 parent_args_var: Optional[str],
                                 controlset_verbatim: str = "") -> List[str]:
        """Generate creation code for a single control (new list schema)."""
        code: List[str] = []

        # args_in before allocation
        args_lines, local_args_var = self._emit_item_args(member_def, parent_args_var, yaml_file,
                                                          f"widget '{member_name}'")

        code.extend(args_lines)

        control_class, base_class = self.extract_control_class(member_name, member_def, yaml_file)
        cpp_class = control_class
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
                sizer_properties: CppGroupGenerator.SizerProperties = self.extract_sizer(sizer_def)
                code.append(f'      // Sizer information: Position: {sizer_properties.position}, Proportion: {sizer_properties.proportion}, Border: {sizer_properties.border}, Flags: {sizer_properties.flag}')

        # chain
        member_accessor = '->'
        if value and not value == "hs::NullValue::Null" and signature.find('value') == -1:
            code.append(f"         ->set <{data_type}> ({value if not value_is_literal else repr(value)})")
            member_accessor = '.'

        validator = member_def.get('validator', {})
        if validator:
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

        if table and field and signature.find('table') == -1 and signature.find('field') == -1:
            db_chain = f'dbInfo({table}, {field})'
            code.append(f"         {member_accessor}{db_chain}")
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

        # add to map
        if is_group:
            code.append(f"      addGroup({member_name});")
        else:
            code.append(f"      addControl({member_name});")

        # args_out after construction
        args_block = member_def.get("args")
        if isinstance(args_block, dict):
            _, outs, _ins = self._parse_args_block(args_block, f"widget '{member_name}'", yaml_file, require_out=False)
            if outs:
                arg_var = local_args_var or parent_args_var or "args"
                for n, ty, v in outs:
                    lit = self._format_cpp_literal(v, ty)
                    code.append(f'      auto {n} = hs::param({arg_var}, "{n}", {lit});')

        code.append("")

        return code

    def _generate_single_group(self, member_name: str, member_def: Dict[str, Any],
                               control_name: str, tool_tip: str, all_elements: Dict[str, Any], yaml_file: Path,
                               parent_args_var: Optional[str],
                               controlset_verbatim: str = "") -> List[str]:
        """Generate creation code for a single nested widget (used when target is Page/WizardPage)."""
        code: List[str] = []

        # args_in before allocation
        args_lines, local_args_var = self._emit_item_args(member_def, parent_args_var, yaml_file,
                                                          f"widget '{member_name}'")
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
                sizer_properties: CppGroupGenerator.SizerProperties = self.extract_sizer(sizer_def)
                code.append(f'      // Sizer information: Position: {sizer_properties.position}, Proportion: {sizer_properties.proportion}, Border: {sizer_properties.border}, Flags: {sizer_properties.flag}')

        # Placement: per-member verbatim before addGroup
        if controlset_verbatim:
            for line in controlset_verbatim.rstrip().splitlines():
                code.append(f"      {line}")

        code.append(f"      addGroup({member_name});")

        # args_out after construction
        args_cfg = member_def.get('args', {})
        outs = args_cfg.get('args_out', [])
        if outs:
            triplets = []
            if outs and isinstance(outs[0], str):
                for i in range(0, len(outs), 3):
                    triplets.append((outs[i], outs[i + 1], outs[i + 2]))
            else:
                for entry in outs:
                    if isinstance(entry, (list, tuple)) and len(entry) >= 3:
                        triplets.append((entry[0], entry[1], entry[2]))

            arg_var = local_args_var or parent_args_var or "args"
            for name_out, type_out, default_out in triplets:
                default_literal = self._format_default_literal(type_out, default_out)
                code.append(f'      auto {name_out} = hs::param({arg_var}, "{name_out}", {default_literal});')

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
                        self.target_type == "pages" or self.target_type == "wizardpages") and "widget" in item and isinstance(
                    item["widget"], dict):
                    md = item["widget"]
                    var = self.extract_member_variable(md, "widget declaration", yaml_file)
                    ctrl_class, base_class = self.extract_control_class(var or "Group", md, yaml_file)
                    decls.append(f"   {ctrl_class}* {var} {{}};")
                elif self.target_type == "groups" and "widget" in item and isinstance(item["widget"], dict):
                    md = item["widget"]
                    var = self.extract_member_variable(md, "control declaration", yaml_file)
                    ctrl_class, base_class = self.extract_control_class(var or "Ctrl", md, yaml_file)
                    decls.append(f"   {ctrl_class}* {var} {{}};")
        return decls

    # -------- helpers for debugging unknown keys --------
    def _warn_unknown_keys(self, obj: Any, allowed: set[str], context: str, yamlfile: Path) -> None:
        if isinstance(obj, dict):
            unknown = [k for k in obj.keys() if k not in allowed]
            if unknown:
                print(f"Warning: unknown keys {unknown} in {context} file://{yamlfile}", file=sys.stderr)

    def _allowed_sets(self):

        return {
            "root": {
                "verbatim",
            },
            "class_def": {
                "args",
                "base_class",
                "class",
                "elements",
                "export_module",
                "finally",
                "functions",
                "layout",
                "module",
                "modules",
                "on_kill_active",
                "on_set_active",
                "pos",
                "run_generator",
                "size",
                "sizer",
                "style",
                "title",
                "value",
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
            "args_def": {
                "arg_name",
                "args_in",
                "args_out",
            },
            "elements_root": {
                "verbatim",
            },
            "control_set": {
                "identity",
                "items",
                "size",
                "sizer",
                "tool_tip",
                "verbatim",
            },
            "item_entry": {
                "labels",
                "widget",
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
                "name",
                "pos",
                "signature",
                "size",
                "sizer",
                "style",
                "table",
                "tag",
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
                "tag",
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
                ['Ctrl', 'Database', 'DDT', 'Interface', 'Group', 'StringUtil', 'Validator', 'wxTypes', 'wxUtil',
                 'Page'])
        elif self.target_type == "pages":
            used_modules.update(
                ['Ctrl', 'Database', 'DDT', 'Interface', 'Group', 'Page', 'StringUtil', 'wxTypes', 'wxUtil'])
        elif self.target_type == "wizardpages":
            used_modules.update(
                ['Ctrl', 'Database', 'DDT', 'Interface', 'Group', 'WizardPage', 'StringUtil', 'wxTypes', 'wxUtil'])

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

                control_map_key = "widget" if self.target_type == "groups" else "widget"
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

                    # validator modules (controls only)
                    if control_map_key == "widget":
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
                f"Warning: '{element_name}': base_class missing/invalid; defaulting to {self.target_class} ({yaml_file})",
                file=sys.stderr)
            base_class = self.target_class
        else:
            base_class = base_class.strip()

        control_class = elements.get('class') or base_class
        if not isinstance(control_class, str) or not control_class.strip():
            print(f"Warning: '{element_name}': class missing/invalid; defaulting to {base_class} ({yaml_file})",
                  file=sys.stderr)
            control_class = base_class
        else:
            control_class = control_class.strip()

        return control_class, base_class

    def extract_data_type(self, element_name: str, elements: Dict[str, Any], yaml_file: Path) -> str:
        data_type = elements.get('contains', 'std::string')
        if not isinstance(data_type, str) and data_type is not None:
            print(f"Warning: 'data_type' for '{element_name}' must be a string; ({yaml_file})",
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
                f"Error: widget '{element_name}': both or neither 'table' and 'field' must be provided ({yaml_file})",
                file=sys.stderr)
        elif tbl is not None and fld is not None:
            if isinstance(tbl, str) and tbl.strip() and isinstance(fld, str) and fld.strip():
                table = f'db::TableName {{"{tbl.strip()}"}}'
                field = f'db::FieldName {{"{fld.strip()}"}}'
            else:
                print(f"Error: widget '{element_name}': 'table' and 'field' must be non-empty strings ({yaml_file})",
                      file=sys.stderr)

        return table, field

    def extract_export_module(self, element_name: str, elements: Dict[str, Any], control_name: str,
                              yaml_file: Path) -> str:
        export_module = elements.get('export_module', f'{element_name}.{self.target_class}')
        if not isinstance(export_module, str):
            print(f"Warning: 'export_module' for '{element_name}' must be a string; ({yaml_file})", file=sys.stderr)
        else:
            export_module = export_module.strip()

        return export_module

    def extract_group_method_body(self, tag: str, element_name: str, elements: Dict[str, Any],
                                  yaml_file: Path) -> str | None:
        """Extracts a group-level method body (onSetActive/onKillActive) as literal block text."""

        if tag in elements:
            ablk = elements.get(tag)
            if isinstance(ablk, dict):
                body = ablk.get("body")
                if isinstance(body, str):
                    # ensure that Interface::onSetActive/onKillActive is called somewhere in the group
                    if tag == "on_set_active" and "Interface::onSetActive" not in body:
                        raise ValueError(
                            f"Interface::onSetActive must be called in widget '{element_name}' ({yaml_file})")
                    if tag == "on_kill_active" and "Interface::onKillActive" not in body:
                        raise ValueError(
                            f"Interface::onKillActive must be called in widget '{element_name}' ({yaml_file})")
                    return body.rstrip("\n")
                if body is not None:
                    print(f"Warning: '{tag}.body' must be a string; ignoring ({yaml_file})", file=sys.stderr)

        return None
        #
        # if isinstance(val, str) and val.strip():
        #     # ensure that Interface::onSetActive/onKillActive is called somewhere in the group
        #     if tag == "on_set_active" and "Interface::onSetActive" not in val:
        #         raise ValueError(f"Interface::onSetActive must be called in group '{element_name}' ({yaml_file})")
        #     if tag == "on_kill_active" and "Interface::OnKillActive" not in val:
        #         raise ValueError(f"Interface::onKillActive must be called in group '{element_name}' ({yaml_file})")
        #
        #     # Keep as-is; caller will indent/place appropriately
        #     return val.rstrip("\n")
        # if val is not None and not isinstance(val, str):
        #     print(f"Warning: group-level '{tag}' must be a string block (|). Ignoring. ({yaml_file})", file=sys.stderr)
        # return None

    def extract_identity(self, element: Dict[str, Any]) -> str | None:
        ident = element.get("identity", "")
        if ident == '':
            return None

        return ident.strip()

    def extract_member_tag(self, member_def: Dict[str, Any], ctx: str, yaml_file: Path) -> str:
        tag = member_def.get("tag")
        if isinstance(tag, str) and tag.strip():
            return tag.strip()
        raise ValueError(f"Item '{ctx}' in file://{yaml_file} must have a tag")

    def extract_member_variable(self, member_def: Dict[str, Any], ctx: str, yaml_file: Path) -> str | None:
        var = member_def.get("variable")
        if not isinstance(var, str) or not var.strip():
            print(f"Warning: {ctx} missing required 'variable' string ({yaml_file})", file=sys.stderr)
            return None
        return var.strip()

    def extract_needed_modules(self, element_name: str, elements: Dict[str, Any], control_name: str,
                       yaml_file: Path) -> List[str] | None:

        modules: List[str] = [] or None
        if 'modules' in elements:
            if isinstance(elements['modules'], list):
                modules = elements['modules']
            elif isinstance(elements['modules'], str):
                modules.append(elements.get('modules').strip())
            else:
                print(f"Warning: 'modules' for '{element_name}' must be a list or a string; ({yaml_file})",
                      file=sys.stderr)
        return modules

    def extract_module(self, element_name: str, elements: Dict[str, Any], control_name: str, yaml_file: Path) -> str:
        module_name = elements.get('module', f'{element_name}.{self.target_class}')
        if not isinstance(module_name, str):
            print(f"Warning: 'module_name' for '{element_name}' must be a string; ({yaml_file})", file=sys.stderr)
        else:
            module_name = module_name.strip()

        return module_name

    def extract_name(self, element_name: str, elements: Dict[str, Any], control_name: str, yaml_file: Path) -> str:
        name = elements.get('name', control_name)
        if not isinstance(name, str):
            print(f"Warning: 'name' for '{element_name}' must be a string; ({yaml_file})", file=sys.stderr)
        else:
            name = name.strip()

        return name

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
                print(f"Warning: 'pos' for '{element_name}' must be a string or List[str]; ({yaml_file})",
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
                # Choose default size token based on widget class via size_mapping
                if control_class in ('SpinCtrl', 'SpinCtrlDouble'):
                    default_key = 'sizeCtrlSpin'
                # elif control_class == 'CheckBox':
                #     default_key = 'sizeCtrlCheckBox'
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
                print(f"Warning: 'style' for '{element_name}' must be a list, a string or an integer; ({yaml_file})",
                      file=sys.stderr)
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
                print(f"Warning: 'uicreateflags' for '{element_name}' must be non-empty; ({yaml_file})",
                      file=sys.stderr)
                # cflags_list = ["Null"]
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
                        f"Warning: 'uicreateflags' list contains non-string/empty value for '{element_name}' ({yaml_file})",
                        file=sys.stderr)

        # Extract is_group: if true, ensure Group flag is included
        is_group = elements.get('is_group', False)
        if not isinstance(is_group, bool):
            print(f"Warning: 'is_group' for '{element_name}' must be boolean ({yaml_file})",
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
        # Get the initialization value (string) for the widget, defaulting to '' if not present.
        if not tp is None and 'value' in elements:
            if isinstance(elements['value'], list):
                # if presented as a list, it is taken to be a variable name
                v = elements['value'][0].strip()
                value = self._format_default_literal(tp, v)
                # value = f'{v}'
                value_is_literal = False
            else:
                v = elements.get('value')
                value = self._format_default_literal(tp, v)
                # value = f'"{v}"'
                value_is_literal = True
        else:
            if tp is None:
                value = f'{self.control_value_mapping.get(control_class, self.control_value_mapping.get(base_class, ""))} {{ {self.control_default_mapping.get(control_class, self.control_default_mapping.get(base_class, ""))} }}'
            else:
                value = f'{tp} {{ {self.control_default_mapping.get(control_class, self.control_default_mapping.get(base_class, ""))} }}'

            value_is_literal = False

        return value, value_is_literal

    def _format_default_literal(self, tp: str, val: Any) -> str:
        """Format a Python/YAML value as a valid C++ literal based on a declared type string.
           Rules:
             - If val is an explicit C++ expression (contains '{' or '::' or parentheses), emit as-is.
             - For string types, always emit std::string{"..."} with quotes around the inner literal.
             - For booleans, emit true/false.
             - For integers/floats, emit numeric literal.
             - Fallback: stringize.
        """
        t = (tp or "").strip().lower()

        # Allow explicit C++ expressions verbatim (e.g., std::string{"General"})
        if isinstance(val, str) and ("{" in val or "::" in val or "(" in val or ")" in val):
            return val

        if "string" in t:
            s = "" if val is None else str(val)
            # Ensure quoted inner string for std::string{"..."}
            if s.startswith('"') and s.endswith('"'):
                inner = s
            else:
                inner = f'"{s}"'
            return f'std::string{{{inner}}}'

        if t in ("bool", "boolean"):
            v = str(val).strip().lower()
            return "true" if v in ("1", "true", "yes") else "false"

        if t in ("int", "long", "long long", "unsigned", "unsigned int"):
            try:
                return str(int(val))
            except Exception:
                return "0"

        if t in ("double", "float"):
            try:
                return str(float(val))
            except Exception:
                return "0.0"

    def _emit_page_scope_args(self, page_key: str, page_def: Dict[str, Any]) -> Tuple[List[str], str, List[
        Tuple[str, str, Any]]] | None:
        """
        Prepare lines for a static inline anymap <arg_name> holding args_in triplets,
        and return args_out triplets for later emission inside the constructor body.
        """
        args_cfg = (page_def.get("args") or {})
        arg_name = args_cfg.get("arg_name") or f"{page_key}Args"
        ins = args_cfg.get("args_in", [])
        outs = args_cfg.get("args_out", [])

        # Normalize args_in triplets
        in_triplets: List[Tuple[str, str, Any]] = []
        if ins and isinstance(ins[0], str):
            for i in range(0, len(ins), 3):
                in_triplets.append((ins[i], ins[i + 1], ins[i + 2]))
        else:
            for entry in ins or []:
                if isinstance(entry, (list, tuple)) and len(entry) >= 3:
                    in_triplets.append((entry[0], entry[1], entry[2]))

        # Normalize args_out triplets
        out_triplets: List[Tuple[str, str, Any]] = []
        if outs and isinstance(outs[0], str):
            for i in range(0, len(outs), 3):
                out_triplets.append((outs[i], outs[i + 1], outs[i + 2]))
        else:
            for entry in outs or []:
                if isinstance(entry, (list, tuple)) and len(entry) >= 3:
                    out_triplets.append((entry[0], entry[1], entry[2]))

        # Build static inline anymap lines
        static_lines: List[str] = []

        if len(in_triplets) == 0:
            return None

        for name_in, type_in, default_in in in_triplets:
            lit = self._format_default_literal(type_in, default_in)
            static_lines.append(f'            {{"{name_in}", {lit}}}')

        return static_lines, arg_name, out_triplets

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
        handler_code = handler.get('handler', 'event.Skip();')

        # Normalize handler code - handle both \n escapes and actual newlines
        if isinstance(handler_code, str):
            handler_code = handler_code.replace('\\n', '\n')
            lines = [line.strip() for line in handler_code.split('\n')]
            handler_code = '\n            '.join(lines)

        # Support a single event or a list of events
        events = event if isinstance(event, (list, tuple)) else [event]
        wx_events = [self._normalize_event_name(e) for e in events]

        # Generate one hook per event; caller decides whether to prefix with '->' or '.'
        hooks = [
            f"hookAndHandle({wx_evt}, [this](wxEvent &event) {{\n            {handler_code}\n         }})"
            for wx_evt in wx_events
        ]

        # If multiple, chain them with leading '.' for subsequent hooks (the first will be prefixed by caller)
        return ("\n         .").join(hooks)

    def _emit_item_args(self, member_def: Dict[str, Any], parent_args_var: Optional[str], yaml_file: Path,
                        ctx: str) -> tuple[list[str], Optional[str]]:
        """If the item has an args: block, generate local anymap lines and return (lines, local_map_name)."""
        lines: list[str] = []
        local_name: Optional[str] = None
        args_block = member_def.get("args")
        if isinstance(args_block, dict):
            # Parse both outs and ins (outs are NOT applied here; only ins belong before construction)
            local_name, outs, ins = self._parse_args_block(args_block, ctx, yaml_file, require_out=False)
            base = parent_args_var if parent_args_var else "args"
            if local_name:
                lines.append(f"      anymap {local_name} = {base} ;")
                # Apply args_in before allocation using type-aware literals
                for n, ty, v in ins:
                    lit = self._format_default_literal(ty, v)
                    lines.append(f"      {local_name}[\"{n}\"] = {lit};")
        return lines, local_name

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

        # Get the data type from the widget's 'contains' property
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
                if isinstance(el, dict) and (el.get("identity") == ident or el.get("Identity") == ident):
                    element = el
                    break

        if not isinstance(element, dict):
            return code

        items = element.get('items', [])
        if not isinstance(items, list):
            return code

        for item in items:
            if not isinstance(item, dict) or 'labels' not in item:
                continue

            labels_seq = item['labels']
            if not isinstance(labels_seq, list):
                continue

            for entry in labels_seq:
                if not isinstance(entry, dict):
                    continue
                label_key = entry.get('key')
                if not isinstance(label_key, str) or not label_key:
                    continue

                label_tag = entry.get('tag')
                if not isinstance(label_tag, str) or not label_tag:
                    label_tag = label_key

                label_value = entry.get('value', "")
                flags = entry.get('style', [])
                flags_str = ' | '.join(flags) if flags else 'wxALIGN_RIGHT | wxALIGN_CENTER_VERTICAL'

                # Size
                if 'size' in entry and isinstance(entry['size'], list):
                    size_a = entry['size']
                    w = size_a[0] if len(size_a) > 0 else -1
                    h = size_a[1] if len(size_a) > 1 else -1
                    size_str = f"wxSize{{{w}, {h if h != -1 else 'wxDefaultCoord'}}}"
                else:
                    default_key = entry.get('size', '') or 'sizeLabel'
                    size_token = self.size_mapping.get(default_key, default_key)
                    size_str = size_token

                    # f"         .createLabel(UICreateFlags::Label, \"{label_tag}\", targetParent, nextID(), \"{label_value}\", {size_str}, {flags_str})")
                code.append(
                    f"         .createLabel(UICreateFlags::Label, \"{label_tag}\", \"{label_value}\")")

                if self.sizer_info:
                    # Get sizer information
                    sizer_def = entry.get('sizer')
                    if sizer_def:
                        sizer_properties: CppGroupGenerator.SizerProperties = self.extract_sizer(sizer_def)
                        code.append(
                            f'         // Sizer information: Position: {sizer_properties.position}, Proportion: {sizer_properties.proportion}, Border: {sizer_properties.border}, Flags: {sizer_properties.flag}')

        return code

    def _format_cpp_literal(self, val: Any, ty: Optional[str]) -> str:

        """Format a YAML scalar as a C++ literal guided by optional type token.
           Rules:
             - If type is 'bool' (case-insensitive), emit true/false.
             - If no type is provided and value is a string 'true'/'false' (any case), emit true/false.
             - If type is a numeric, coerce accordingly with safe fallback.
             - If type is 'string' or explicit string desired, quote.
             - Fallback by Python type (bool -> true/false, int/float -> number, else -> quoted string).
        """
        t = (ty or "").strip().lower()

        # Explicit boolean type
        if t == "bool":
            return "true" if bool(val) else "false"

        # If type not explicitly provided, infer common boolean strings
        if not t and isinstance(val, str):
            s = val.strip().lower()
            if s in ("true", "false"):
                return s  # unquoted boolean literal

        # Strings
        if t in ("string", "std::string"):
            s = "" if val is None else str(val)
            return f'"{s}"'

        # Floating point
        if t in ("double", "float"):
            try:
                return str(float(val))
            except Exception:
                return "0.0"

        # Integers
        if t in ("int", "long", "long long", "unsigned", "unsigned int"):
            try:
                return str(int(val))
            except Exception:
                return "0"

        # Fallbacks by Python runtime type
        if isinstance(val, bool):
            return "true" if val else "false"
        if isinstance(val, int):
            return str(val)
        if isinstance(val, float):
            return str(val)

        # Default: quote as string
        return f'"{"" if val is None else str(val)}"'

    def _parse_args_block(self, node: Any, ctx: str, yaml_file: Path, require_out: bool = False) -> tuple[
        Optional[str], list[tuple[str, str, Any]], list[tuple[str, str, Any]]]:
        """Parse args: { arg_name: <str>, args_out: [name, type, value, ...], args_in: [name, type, default, ...] }
           Validates keys, structure, duplicates, and type/name tokens.
        """
        if not isinstance(node, dict):
            print(f"Warning: {ctx}.args must be a mapping ({yaml_file})", file=sys.stderr)
            return None, [], []

        allow = self._allowed_sets()
        self._warn_unknown_keys(node, allow["args_def"], f"args_def args block of '{ctx}'", yaml_file)
        #
        #
        # # Unknown key detection
        # allowed_keys = {"arg_name", "args_out", "args_in"}
        # unknown = [k for k in node.keys() if k not in allowed_keys]
        # if unknown:
        #     print(f"Warning: {ctx}.args has unknown keys {unknown} ({yaml_file})", file=sys.stderr)

        # arg_name
        arg_name = node.get("arg_name")
        if not isinstance(arg_name, str) or not arg_name.strip():
            print(f"Warning: {ctx}.args.arg_name must be a non-empty string ({yaml_file})", file=sys.stderr)
            return None, [], []
        arg_name = arg_name.strip()
        if not self._is_identifier(arg_name):
            print(
                f"Warning: {ctx}.args.arg_name '{arg_name}' is not an identifier; consider using [A-Za-z_][A-Za-z0-9_]* ({yaml_file})",
                file=sys.stderr)

        known_types = {
            "bool", "boolean",
            "string", "std::string",
            "int", "long", "long long", "unsigned", "unsigned int",
            "double", "float",
        }

        def _triples(arr: Any, key_name: str) -> list[tuple[str, str, Any]]:
            res: list[tuple[str, str, Any]] = []
            if arr is None:
                return res
            if not isinstance(arr, list):
                print(f"Warning: {ctx}.args.{key_name} must be a list ({yaml_file})", file=sys.stderr)
                return res
            if len(arr) % 3 != 0:
                print(f"Warning: {ctx}.args.{key_name} length must be a multiple of 3 (name,type,value) ({yaml_file})",
                      file=sys.stderr)
            for i in range(0, len(arr) - (len(arr) % 3), 3):
                n, ty, v = arr[i], arr[i + 1], arr[i + 2]
                if not isinstance(n, str) or not n.strip():
                    print(f"Warning: {ctx}.args.{key_name}[{i}] name must be a non-empty string ({yaml_file})",
                          file=sys.stderr)
                    continue
                name_clean = n.strip()
                if not self._is_identifier(name_clean):
                    print(
                        f"Warning: {ctx}.args.{key_name}[{i}] '{name_clean}' is not an identifier; allowed [A-Za-z_][A-Za-z0-9_]* ({yaml_file})",
                        file=sys.stderr)
                if not isinstance(ty, str) or not ty.strip():
                    print(f"Warning: {ctx}.args.{key_name}[{i + 1}] type must be a non-empty string ({yaml_file})",
                          file=sys.stderr)
                    continue
                ty_clean = ty.strip()
                if ty_clean.lower() not in known_types:
                    print(f"Warning: {ctx}.args.{key_name}[{i + 1}] unknown type '{ty_clean}' ({yaml_file})",
                          file=sys.stderr)
                res.append((name_clean, ty_clean, v))
            # duplicate detection within this list
            seen = set()
            dups = []
            for n, _, _ in res:
                if n in seen:
                    dups.append(n)
                else:
                    seen.add(n)
            if dups:
                print(f"Warning: {ctx}.args.{key_name} has duplicate names {sorted(set(dups))} ({yaml_file})",
                      file=sys.stderr)
            return res

        outs = _triples(node.get("args_out"), "args_out")
        ins = _triples(node.get("args_in"), "args_in")

        if require_out and not outs:
            print(f"Warning: {ctx}.args is missing required 'args_out' entries for item-level args ({yaml_file})",
                  file=sys.stderr)

        # cross duplicates (same key in outs and ins)
        out_names = {n for n, _, _ in outs}
        in_names = {n for n, _, _ in ins}
        cross = sorted(out_names & in_names)
        if cross:
            print(f"Warning: {ctx}.args has names present in both args_out and args_in {cross} ({yaml_file})",
                  file=sys.stderr)

        return arg_name, outs, ins

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
                raise ValueError(f"functions.{fname}.const must be a boolean")

            if 'static' in fdef and not isinstance(fdef['static'], bool):
                raise ValueError(f"functions.{fname}.static must be a boolean")

            if 'noexcept' in fdef and not (isinstance(fdef['noexcept'], (bool, str))):
                raise ValueError(f"functions.{fname}.noexcept must be a boolean or string")

            if 'override' in fdef and not (isinstance(fdef['override'], (bool, str))):
                raise ValueError(f"functions.{fname}.override must be a boolean or string")

            # Access
            access = fdef.get('access', 'public')
            if access not in ('public', 'protected', 'private'):
                raise ValueError(f"functions.{fname}.access must be one of: public, protected, private")

            # Defaults
            fdef.setdefault('args', '')
            fdef.setdefault('return', 'void')
            fdef.setdefault('override', False)
            fdef.setdefault('body', '')
            fdef.setdefault('const', False)
            fdef.setdefault('static', False)
            fdef['access'] = access

            normalized[fname] = fdef

        return normalized

    def _format_noexcept(self, spec: Any) -> str:
        if spec is True:
            return " noexcept"
        if isinstance(spec, str) and spec.strip():
            return f" noexcept({spec.strip()})"
        return ""

    def _do_generate_from_yaml(self, yaml_file: Path, output_file: Path) -> str:

        data = self.parse_yaml_file(yaml_file)

        if self.target_type not in data:
            if self.verbose:
                print(f"{yaml_file} : no {self.target_type} section")
            return ""

        targets = data[self.target_type]
        if not isinstance(targets, dict) or len(targets) == 0:
            raise ValueError("{self.target_type} section must be a non-empty mapping of group_name -> class_def")

        # Extract placement 1: top-level verbatim if present
        top_verbatim = ""
        if "verbatim" in targets:
            top_verbatim = self._extract_verbatim_body(targets)
            # unknown key check at root
            self._warn_unknown_keys(targets, self._allowed_sets()["root"] | set(targets.keys()),
                                    f"{self.target_type} root", yaml_file)

        # Generate all modules
        generated: List[Tuple[str, str]] = []  # (group_name, module_content)
        for target_name, class_def in targets.items():
            if target_name == "verbatim":
                continue  # handled above/later

            # Honor run_generator flag (default true)
            run_gen = class_def.get('run_generator', True)
            if not isinstance(run_gen, bool):
                print(f"Warning: target '{target_name}': 'run_generator' must be boolean; defaulting to true",
                      file=sys.stderr)
                run_gen = True
            if not run_gen:
                # Skip generation for this widget
                continue

            if 'elements' not in class_def:
                print(f"Warning: {self.target_class} '{target_name}' has no 'elements' section", file=sys.stderr)
                continue

            elements = class_def['elements']
            if (not isinstance(elements, list) or len(elements) == 0):
                elements = {}
                if not self.quiet:
                    print(f"Warning: {self.target_class} '{target_name}' has empty or invalid elements section", file=sys.stderr)

            module_content = self.generate_module(target_name, class_def, yaml_file, top_verbatim)

            generated.append((target_name, module_content))

        if not generated:
            raise ValueError(f"No valid {self.target_type} found to generate")

        # Handle output (unchanged)
        if output_file:
            dest_dir = output_file
            dest_dir.mkdir(parents=True, exist_ok=True)

            for target_name, module_content in generated:
                pascal = self.to_pascal_case(target_name)
                out_path = dest_dir / f"{pascal}{self.target_class}.ixx"

                # Only update the file if content actually changed to avoid unnecessary rebuilds
                try:
                    existing = out_path.read_text(encoding='utf-8') if out_path.exists() else None
                except Exception:
                    existing = None

                if existing != module_content:
                    out_path.parent.mkdir(parents=True, exist_ok=True)
                    with open(out_path, 'w', encoding='utf-8') as f:
                        f.write(module_content)
                    print(f"{out_path} : Updated")
                else:
                    # Keep timestamp untouched when no changes
                    if not self.quiet:
                        print(f"{out_path} : Unchanged")

            return generated[-1][1]

        # No output file specified: return concatenated modules
        return ("\n\n").join(module for _, module in generated)

    def generate_from_yaml(self, yaml_file: Path, output_file: Path = None) -> str:
        """Generate C++ group module from YAML file."""

        thing: str = ''
        for cat in ["Group", "Page", "WizardPage"]:
            self.target(cat)
            try:

                s: str = self._do_generate_from_yaml(yaml_file, output_file)
                thing = s if thing.strip() == '' else thing + "\n" + s

            except Exception as e:
                print(f"Error reading {yaml_file}: {e}", file=sys.stderr)

        return thing


def scan_and_generate(generator, roots: List[Path], output_dir: Path | None) -> int:
    """Scan for *.yaml files, generate corresponding Group.ixx files."""
    gen = generator

    # Collect YAML files from all root directories
    yaml_files = []
    for root in roots:
        if not root.exists():
            print(f"Warning: Scan directory '{root}' does not exist, skipping", file=sys.stderr)
            continue
        yaml_files.extend(sorted(list(root.rglob("*.yaml"))))

    if not yaml_files:
        if not gen.quiet:
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
        output_dir.mkdir(parents=True, exist_ok=True)

    print(f"Processing UI classes in {len(yaml_files)} YAML files from {len(roots)} directories...")

    for yf in yaml_files:

        try:
            gen.generate_from_yaml(yf, output_dir)
        except Exception as e:
            print(f"Error reading {yf}: {e}", file=sys.stderr)
            return 1

    return 0


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(
        description='Generate C++ Group/Page/WizardPage modules from YAML form definitions')
    parser.add_argument('-a', '--app-target', action='store', help='The CMake target name of the application')
    parser.add_argument('input_yaml', type=Path, nargs='?', help='Single input YAML file')
    parser.add_argument('-o', '--output', type=Path, help='Output directory or file path')
    parser.add_argument('--scan', type=Path, action='append',
                        help='Scan this directory recursively for *.yaml (can be used multiple times)')
    parser.add_argument('-f', '--first-pagetype', action='store', help='First page type to generate')
    parser.add_argument('-q', '--quiet', action="store_true", help='Only report important information')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-s', '--sizer-info', action='store_true', help='Show sizer info in the generated UI classes')

    args = parser.parse_args()
    generator = CppGroupGenerator()
    generator.be_quiet(args.quiet)
    generator.be_verbose(args.verbose)
    generator.show_sizer_info(args.sizer_info)

    if not args.first_pagetype is None:
        generator.next_PageType = args.first_pagetype

    if not args.app_target is None:
        generator.app_target = args.app_target

    # Scan mode (batch)
    if args.scan:
        output_dir = args.output if args.output is not None else None
        sys.exit(scan_and_generate(generator, args.scan, output_dir))

    # Single-file mode
    if not args.input_yaml:
        print("Error: input_yaml is required unless --scan is provided", file=sys.stderr)
        sys.exit(1)

    if not args.input_yaml.exists():
        print(f"Error: Input file '{args.input_yaml}' does not exist", file=sys.stderr)
        sys.exit(1)

    try:
        result = generator.generate_from_yaml(args.input_yaml, args.output)

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
