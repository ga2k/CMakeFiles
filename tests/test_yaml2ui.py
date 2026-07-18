import importlib.util
import tempfile
import textwrap
import unittest
from pathlib import Path

class TestYaml2Group(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        tools_dir = Path(__file__).resolve().parents[1]
        yaml2ui_path = tools_dir / "yaml2ui.py"
        if not yaml2ui_path.exists():
            raise RuntimeError(f"Could not find yaml2ui.py at {yaml2ui_path}")

        spec = importlib.util.spec_from_file_location("yaml2ui", yaml2ui_path)
        mod = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(mod)
        cls.mod = mod
        cls.gen = mod.CppGroupGenerator()

    def _write_temp_yaml(self, content: str) -> Path:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".yaml", mode="w", encoding="utf-8")
        tmp.write(textwrap.dedent(content))
        tmp.flush()
        tmp.close()
        return Path(tmp.name)

    def test_size_defaults_to_wxDefaultSize(self):
        yaml_content = """
        groups:
          sample:
            controls:
              "LabelOnly":
                has_labels: true
                has_control: false
                items:
                  - labels:
                      "LIX::Main":
                        type: "MarkupText"
                        value: "Hello"
              "Text":
                has_labels: false
                has_control: true
                items:
                  - control:
                      "m_text":
                        type: "TextCtrl"
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("wxDefaultSize", out, "Controls/labels without size should use wxDefaultSize")
        finally:
            path.unlink(missing_ok=True)

    def test_functions_generation_with_qualifiers_and_access(self):
        yaml_content = """
        groups:
          sample:
            controls: {}
            functions:
              aFunction:
                args: "wxEvent &event"
                const: true
                noexcept: true
                return: void
                body: |
                  (void)event;
                  // body
              staticFunction:
                args: ""
                static: true
                return: int
                body: |
                  return 42;
              protFn:
                access: protected
                args: "int x"
                return: int
                body: |
                  return x + 1;
              privFn:
                access: private
                args: ""
                return: void
                noexcept: "no_throw"
                body: |
                  // private!
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("public:\n   auto aFunction (wxEvent &event) const noexcept -> void {", out)
            self.assertIn("public:\n   static auto staticFunction () -> int {", out)
            self.assertIn("protected:\n   auto protFn (int x) -> int {", out)
            self.assertIn("private:\n   auto privFn () noexcept(no_throw) -> void {", out)
        finally:
            path.unlink(missing_ok=True)

    def test_functions_validation_errors(self):
        bads = [
            ("""
             groups:
               g:
                 controls: {}
                 functions: []
             """, "'functions' must be a mapping"),
            ("""
             groups:
               g:
                 controls: {}
                 functions:
                   f1: "not a mapping"
             """, "definition must be a mapping"),
            ("""
             groups:
               g:
                 controls: {}
                 functions:
                   f1:
                     const: "yes"
             """, "const must be a hs_bool"),
            ("""
             groups:
               g:
                 controls: {}
                 functions:
                   f1:
                     noexcept: 123
             """, "noexcept must be a hs_bool or string"),
            ("""
             groups:
               g:
                 controls: {}
                 functions:
                   f1:
                     access: internal
             """, "access must be one of"),
        ]
        for yaml_content, exp in bads:
            path = self._write_temp_yaml(yaml_content)
            try:
                with self.assertRaises(ValueError) as ctx:
                    self.gen.generate_from_yaml(path)
                self.assertIn(exp, str(ctx.exception))
            finally:
                path.unlink(missing_ok=True)

    def test_impl_stub_appended_inside_namespace(self):
        import tempfile as _tf
        stub_fn = {'newFn': {'args': '', 'return': 'void', 'const': False, 'override': False}}

        # 1) canonical close, 2) respaced comment + trailing blank, 3) no namespace close
        variants = [
            "module Foo.Group;\n\nnamespace wx {\n\nauto FooGroup::oldFn () -> void {\n}\n} // namespace wx\n",
            "module Foo.Group;\n\nnamespace wx {\n\nauto FooGroup::oldFn () -> void {\n}\n}  //  namespace wx  \n\n",
            "module Foo.Group;\n\nnamespace wx {\n\nauto FooGroup::oldFn () -> void {\n}\n",
        ]
        for content in variants:
            with _tf.TemporaryDirectory() as td:
                impl_dir = Path(td)
                impl = impl_dir / "FooGroup_impl.cpp"
                impl.write_text(content, encoding="utf-8")
                self.gen._write_impl_stub(impl_dir, "FooGroup", "Foo.Group", "wx", dict(stub_fn))
                out = impl.read_text(encoding="utf-8")
                self.assertIn("FooGroup::newFn", out)
                # the stub must sit before a namespace-closing line
                stub_pos = out.index("FooGroup::newFn")
                closes = [i for i in (out.find("} // namespace wx", stub_pos),
                                      out.find("//  namespace wx", stub_pos),
                                      out.find("} // namespace wx", stub_pos)) if i != -1]
                self.assertTrue(closes, f"no namespace close after stub in:\n{out}")
                # hand-written body untouched
                self.assertIn("FooGroup::oldFn", out)

    def test_recordset_page_scaffolding(self):
        yaml_content = """
        pages:
          alert_settings:
            title: "Alerts"
            layout: "AlertSettingsPage"
            base_class: Page
            module: Page
            recordset:
              module: Settings.RS
              class:  mc::SettingsRS
            elements:
              - identity: "PopupAlerts"
                items:
                  - widget:
                      variable: "m_popupAlerts"
                      tag: "PopupAlerts"
                      value: "Popup Alerts"
                      class: "PopupAlertsGroup"
                      base_class: "Group"
                      uicreateflags: "Group"
                      module: [ "PopupAlerts.Group" ]
              - identity: "Enabled"
                items:
                  - widget:
                      variable: "m_enabled"
                      tag: "Enabled"
                      class: CheckBox
                      module: CheckBox
                      contains: bool
                      table: settings
                      field: fUseAlerts
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("import Settings.RS;", out)
            self.assertIn("std::shared_ptr<mc::SettingsRS> m_rs;", out)
            self.assertIn("size_t m_moveHandle{};", out)
            self.assertIn("db::recordSetSignal().Unsubscribe(m_moveHandle);", out)
            # Subscribe block must sit before the loadLayout VERIFY
            self.assertIn("db::recordSetSignal().Subscribe([this](auto) { refreshFromCurrent(); },", out)
            self.assertIn("db::recordSetSignal().suspendSignals(m_moveHandle);", out)
            self.assertLess(out.index("db::recordSetSignal().Subscribe"),
                            out.index("VERIFY_MSG(this->loadLayout"))
            # refreshFromCurrent: record derived from class, bound control + guarded group call
            self.assertIn("auto refreshFromCurrent () -> void {", out)
            self.assertIn("const mc::SettingsRecord *rec = m_rs ? m_rs->current() : nullptr;", out)
            self.assertIn("wx::initFromField(m_enabled, rec->fUseAlerts);", out)
            self.assertIn('m_enabled->where("id = " + std::to_string(rec->id));', out)
            self.assertIn("if constexpr (requires { m_popupAlerts->refreshFromCurrent(rec); })", out)
            self.assertIn("m_popupAlerts->refreshFromCurrent(rec);", out)
        finally:
            path.unlink(missing_ok=True)

    def test_recordset_group_refresh_from_bindings(self):
        yaml_content = """
        groups:
          popup_alerts:
            title: "Popup Alerts"
            layout: PopupAlertsGroup
            recordset:
              module: Settings.RS
              class:  mc::SettingsRS
            elements:
              - identity: "Use Popup Alerts"
                items:
                  - widget:
                      variable: m_usePopup
                      tag: "Use Popup Alerts"
                      class: CheckBox
                      module: CheckBox
                      contains: bool
                      table: settings
                      field: fUsePopupAlerts
              - identity: "Test Popup"
                items:
                  - widget:
                      variable: m_popupTestButton
                      tag: "Popup Test Button"
                      class: Button
                      module: Button
                      value: "Test"
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("import Settings.RS;", out)
            self.assertIn("auto refreshFromCurrent (const mc::SettingsRecord *rec) -> void {", out)
            self.assertIn("wx::initFromField(m_usePopup, rec->fUsePopupAlerts);", out)
            self.assertIn('m_usePopup->where("id = " + std::to_string(rec->id));', out)
            # unbound button must not appear in the refresh body
            self.assertNotIn("initFromField(m_popupTestButton", out)
            self.assertNotIn("m_popupTestButton->where", out)
            # groups don't own the recordset or subscription
            self.assertNotIn("m_rs", out)
            self.assertNotIn("m_moveHandle", out)
        finally:
            path.unlink(missing_ok=True)

    def test_recordset_record_override_and_bad_class(self):
        # explicit record: wins over derivation
        yaml_content = """
        groups:
          g:
            layout: G
            recordset:
              module: Foo.RS
              class:  mc::FooRS
              record: mc::SpecialRecord
            elements: []
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("auto refreshFromCurrent (const mc::SpecialRecord *rec) -> void {", out)
        finally:
            path.unlink(missing_ok=True)

        # class not ending in RS and no record: -> no scaffolding generated
        yaml_content = """
        groups:
          g:
            layout: G
            recordset:
              module: Foo.RS
              class:  mc::FooThing
            elements: []
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertNotIn("refreshFromCurrent", out)
        finally:
            path.unlink(missing_ok=True)

    def test_alt_data_source_generates_dbsource_and_load_call(self):
        yaml_content = """
        groups:
          brief_user:
            layout: BriefUserGroup
            elements:
              - identity: "Title"
                items:
                  - widget:
                      variable: m_title
                      tag: "Title"
                      base_class: "Choice"
                      module: [ "Choice" ]
                      contains: "ID::Type"
                      alt_data_source:
                        module: "Titles.RS"
                        class: "mc::TitlesRS"
                        table: "titles"
                        display_field: "fAbbreviation"
                        value_field: "id"
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("import Titles.RS;", out)
            self.assertIn("struct TitleDBSource {", out)
            self.assertIn("using RS = mc::TitlesRS;", out)
            self.assertIn("using Record = mc::TitlesRecord;", out)
            self.assertIn('static auto table() -> std::string { return "titles"; }', out)
            self.assertIn(
                "static auto displayText(const Record &r) -> std::string { return r.fAbbreviation; }", out)
            self.assertIn("static auto value(const Record &r) -> ID::Type { return ID::Type(r.id); }", out)
            self.assertIn("static constexpr auto includeBlank() -> bool { return true; }", out)
            self.assertIn('static auto blankText() -> std::string { return ""; }', out)
            self.assertIn("Choice<ID::Type, TitleDBSource>* m_title {};", out)
            self.assertIn("new Choice<ID::Type, TitleDBSource>(", out)
            self.assertIn("m_title->loadFromDB();", out)
        finally:
            path.unlink(missing_ok=True)

    def test_alt_data_source_value_field_not_assumed_to_be_id(self):
        yaml_content = """
        groups:
          email_alerts:
            layout: EmailAlertsGroup
            elements:
              - identity: "Authority"
                items:
                  - widget:
                      variable: m_authority
                      tag: "Authority"
                      base_class: "Combo"
                      module: [ "Combo" ]
                      contains: "ID::Type"
                      alt_data_source:
                        module: "EmailAuthority.RS"
                        class: "mc::EmailAuthorityRS"
                        table: "email_authority"
                        display_field: "fName"
                        value_field: "fValue"
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertIn("static auto value(const Record &r) -> ID::Type { return ID::Type(r.fValue); }", out)
            self.assertIn("Combo<ID::Type, AuthorityDBSource>* m_authority {};", out)
        finally:
            path.unlink(missing_ok=True)

    def test_alt_data_source_missing_required_field_falls_back(self):
        yaml_content = """
        groups:
          brief_user:
            layout: BriefUserGroup
            elements:
              - identity: "Title"
                items:
                  - widget:
                      variable: m_title
                      tag: "Title"
                      base_class: "Choice"
                      module: [ "Choice" ]
                      contains: "ID::Type"
                      alt_data_source:
                        module: "Titles.RS"
                        class: "mc::TitlesRS"
                        table: "titles"
                        display_field: "fAbbreviation"
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            out = self.gen.generate_from_yaml(path)
            self.assertNotIn("struct TitleDBSource", out)
            self.assertIn("Choice* m_title {};", out)
            self.assertNotIn("m_title->loadFromDB();", out)
        finally:
            path.unlink(missing_ok=True)
