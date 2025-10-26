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
             """, "const must be a boolean"),
            ("""
             groups:
               g:
                 controls: {}
                 functions:
                   f1:
                     noexcept: 123
             """, "noexcept must be a boolean or string"),
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
