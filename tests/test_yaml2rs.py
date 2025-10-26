# tools/tests/test_yaml2rs.py
import unittest
from pathlib import Path
import tempfile
import textwrap
import importlib.util

class TestYaml2Rs(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        # Load tools/yaml2rs.py by file path
        tools_dir = Path(__file__).resolve().parents[1]
        yaml2rs_path = tools_dir / "yaml2rs.py"
        if not yaml2rs_path.exists():
            raise RuntimeError(f"Could not find yaml2rs.py at {yaml2rs_path}")

        spec = importlib.util.spec_from_file_location("yaml2rs", yaml2rs_path)
        mod = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(mod)
        cls.mod = mod

        # Find a generator class with required API (generate_from_yaml/parse_yaml_file)
        gen = None
        for name in dir(mod):
            obj = getattr(mod, name)
            if isinstance(obj, type) and hasattr(obj, "generate_from_yaml") and hasattr(obj, "parse_yaml_file"):
                try:
                    gen = obj()
                    break
                except Exception:
                    continue
        if gen is None:
            raise RuntimeError("Could not locate generator class with generate_from_yaml/parse_yaml_file in tools/yaml2rs.py")
        cls.gen = gen

    def _write_temp_yaml(self, content: str) -> Path:
        tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".yaml", mode="w", encoding="utf-8")
        tmp.write(textwrap.dedent(content))
        tmp.flush()
        tmp.close()
        return Path(tmp.name)

    def test_parse_yaml_file_basic(self):
        yaml_content = """
        tables:
          states:
            fields:
              id:
                type: integer
                primary_key: true
              fName:
                type: string
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            data = self.gen.parse_yaml_file(path)
            self.assertIsInstance(data, dict)
            self.assertIn("tables", data)
            self.assertIn("states", data["tables"])
        finally:
            path.unlink(missing_ok=True)

    # def test_generate_from_yaml_requires_tables(self):
    #     yaml_content = """
    #     not_tables:
    #       x: y
    #     """
    #     path = self._write_temp_yaml(yaml_content)
    #     try:
    #         with self.assertRaises(ValueError) as ctx:
    #             self.gen.generate_from_yaml(path)
    #         self.assertIn("must contain a 'tables' section", str(ctx.exception))
    #     finally:
    #         path.unlink(missing_ok=True)

    def test_generate_from_yaml_requires_fields(self):
        yaml_content = """
        tables:
          states:
            relationships: []
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            with self.assertRaises(ValueError) as ctx:
                self.gen.generate_from_yaml(path)
            self.assertIn("must have a 'fields' section", str(ctx.exception))
            self.assertIn("states", str(ctx.exception))
        finally:
            path.unlink(missing_ok=True)

    # Test two-pass processing and table collection
    def test_collect_all_tables_basic(self):
        """Test that collect_all_tables properly gathers table definitions."""
        yaml_content1 = """
        tables:
          users:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
        """
        yaml_content2 = """
        tables:
          posts:
            fields:
              id: { type: integer, primary_key: true }
              title: { type: string }
        """
        path1 = self._write_temp_yaml(yaml_content1)
        path2 = self._write_temp_yaml(yaml_content2)
        try:
            self.gen.collect_all_tables([path1, path2])
            # Check that both tables were collected
            self.assertIn('users', self.gen.all_tables)
            self.assertIn('posts', self.gen.all_tables)
            # Check table normalization (removing _table suffix)
            self.assertEqual(self.gen.all_tables['users']['fields']['name']['type'], 'string')
        finally:
            path1.unlink(missing_ok=True)
            path2.unlink(missing_ok=True)

    def test_collect_all_tables_normalizes_table_names(self):
        """Test that table names ending with _table are normalized."""
        yaml_content = """
        tables:
          users_table:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            self.gen.collect_all_tables([path])
            # Should be stored under normalized name
            self.assertIn('users', self.gen.all_tables)
            self.assertNotIn('users_table', self.gen.all_tables)
        finally:
            path.unlink(missing_ok=True)

    # Test nested join depth configuration
    def test_set_max_join_depth(self):
        """Test that max join depth can be configured."""
        self.assertEqual(self.gen.max_join_depth, 3)  # Default
        self.gen.set_max_join_depth(5)
        self.assertEqual(self.gen.max_join_depth, 5)
        # Test minimum depth enforcement
        self.gen.set_max_join_depth(0)
        self.assertEqual(self.gen.max_join_depth, 1)

    # Test simple relationships
    def test_resolve_relationship_fields_basic(self):
        """Test basic relationship field resolution."""
        # First collect tables
        users_yaml = """
        tables:
          users:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
              email: { type: string }
        """
        posts_yaml = """
        tables:
          posts:
            fields:
              id: { type: integer, primary_key: true }
              title: { type: string }
              author_id: { type: integer }
            relationships:
              - name: author
                type: many_to_one
                foreign_key: author_id
                references_table: users
                references_field: id
        """
        users_path = self._write_temp_yaml(users_yaml)
        posts_path = self._write_temp_yaml(posts_yaml)

        try:
            self.gen.collect_all_tables([users_path, posts_path])

            # Test relationship resolution
            relationships = [{
                'name': 'author',
                'type': 'many_to_one',
                'foreign_key': 'author_id',
                'references_table': 'users',
                'references_field': 'id'
            }]

            resolved = self.gen.resolve_relationship_fields(relationships, 'posts')

            # Should have user fields with author prefix
            field_names = [field[0] for field in resolved]
            self.assertIn('author__id', field_names)
            self.assertIn('author__name', field_names)
            self.assertIn('author__email', field_names)

            # Check types
            for field_name, cpp_type, required in resolved:
                if field_name == 'author__id':
                    self.assertEqual(cpp_type, 'int')
                elif field_name in ['author__name', 'author__email']:
                    self.assertEqual(cpp_type, 'std::string')
                # All relationship fields should be optional
                self.assertFalse(required)

        finally:
            users_path.unlink(missing_ok=True)
            posts_path.unlink(missing_ok=True)

    # Test nested relationships
    def test_resolve_relationship_fields_nested(self):
        """Test nested relationship field resolution."""
        # Users -> Departments -> Companies
        companies_yaml = """
        tables:
          companies:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
              country: { type: string }
        """
        departments_yaml = """
        tables:
          departments:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
              company_id: { type: integer }
            relationships:
              - name: company
                type: many_to_one
                foreign_key: company_id
                references_table: companies
                references_field: id
        """
        users_yaml = """
        tables:
          users:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
              dept_id: { type: integer }
            relationships:
              - name: department
                type: many_to_one
                foreign_key: dept_id
                references_table: departments
                references_field: id
        """

        companies_path = self._write_temp_yaml(companies_yaml)
        departments_path = self._write_temp_yaml(departments_yaml)
        users_path = self._write_temp_yaml(users_yaml)

        try:
            self.gen.set_max_join_depth(3)  # Allow 3 levels
            self.gen.collect_all_tables([companies_path, departments_path, users_path])

            relationships = [{
                'name': 'department',
                'type': 'many_to_one',
                'foreign_key': 'dept_id',
                'references_table': 'departments',
                'references_field': 'id'
            }]

            resolved = self.gen.resolve_relationship_fields(relationships, 'users')
            field_names = [field[0] for field in resolved]

            # Should have department fields
            self.assertIn('department__id', field_names)
            self.assertIn('department__name', field_names)

            # Should have nested company fields
            self.assertIn('department__company__id', field_names)
            self.assertIn('department__company__name', field_names)
            self.assertIn('department__company__country', field_names)

        finally:
            companies_path.unlink(missing_ok=True)
            departments_path.unlink(missing_ok=True)
            users_path.unlink(missing_ok=True)

    def test_resolve_relationship_fields_depth_limit(self):
        """Test that nested relationships respect depth limits."""
        # Create a 4-level chain: A -> B -> C -> D
        yaml_a = """
        tables:
          table_a:
            fields:
              id: { type: integer, primary_key: true }
              b_id: { type: integer }
            relationships:
              - name: b_ref
                type: many_to_one
                foreign_key: b_id
                references_table: table_b
                references_field: id
        """
        yaml_b = """
        tables:
          table_b:
            fields:
              id: { type: integer, primary_key: true }
              c_id: { type: integer }
            relationships:
              - name: c_ref
                type: many_to_one
                foreign_key: c_id
                references_table: table_c
                references_field: id
        """
        yaml_c = """
        tables:
          table_c:
            fields:
              id: { type: integer, primary_key: true }
              d_id: { type: integer }
            relationships:
              - name: d_ref
                type: many_to_one
                foreign_key: d_id
                references_table: table_d
                references_field: id
        """
        yaml_d = """
        tables:
          table_d:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
        """

        path_a = self._write_temp_yaml(yaml_a)
        path_b = self._write_temp_yaml(yaml_b)
        path_c = self._write_temp_yaml(yaml_c)
        path_d = self._write_temp_yaml(yaml_d)

        try:
            self.gen.set_max_join_depth(2)  # Limit to 2 levels
            self.gen.collect_all_tables([path_a, path_b, path_c, path_d])

            relationships = [{
                'name': 'b_ref',
                'type': 'many_to_one',
                'foreign_key': 'b_id',
                'references_table': 'table_b',
                'references_field': 'id'
            }]

            resolved = self.gen.resolve_relationship_fields(relationships, 'table_a')
            field_names = [field[0] for field in resolved]

            # Should have level 1: b_ref__*
            self.assertIn('b_ref__id', field_names)

            # Should have level 2: b_ref__c_ref__*
            self.assertIn('b_ref__c_ref__id', field_names)

            # Should NOT have level 3: b_ref__c_ref__d_ref__* (exceeds depth limit)
            nested_d_fields = [f for f in field_names if f.startswith('b_ref__c_ref__d_ref__')]
            self.assertEqual(len(nested_d_fields), 0)

        finally:
            path_a.unlink(missing_ok=True)
            path_b.unlink(missing_ok=True)
            path_c.unlink(missing_ok=True)
            path_d.unlink(missing_ok=True)

    def test_resolve_relationship_fields_prevents_cycles(self):
        """Test that circular relationships don't cause infinite recursion."""
        # Create circular reference: A -> B -> A
        yaml_a = """
        tables:
          table_a:
            fields:
              id: { type: integer, primary_key: true }
              name_a: { type: string }
              b_id: { type: integer }
            relationships:
              - name: b_ref
                type: many_to_one
                foreign_key: b_id
                references_table: table_b
                references_field: id
        """
        yaml_b = """
        tables:
          table_b:
            fields:
              id: { type: integer, primary_key: true }
              name_b: { type: string }
              a_id: { type: integer }
            relationships:
              - name: a_ref
                type: many_to_one
                foreign_key: a_id
                references_table: table_a
                references_field: id
        """

        path_a = self._write_temp_yaml(yaml_a)
        path_b = self._write_temp_yaml(yaml_b)

        try:
            self.gen._relationship_cache.clear()  # Clear any previous cache
            self.gen.collect_all_tables([path_a, path_b])

            relationships = [{
                'name': 'b_ref',
                'type': 'many_to_one',
                'foreign_key': 'b_id',
                'references_table': 'table_b',
                'references_field': 'id'
            }]

            # Should not hang or throw, should return finite result
            resolved = self.gen.resolve_relationship_fields(relationships, 'table_a')
            self.assertIsInstance(resolved, list)

            # Should have some fields from the relationships (both direct and nested)
            field_names = [field[0] for field in resolved]

            # Should have direct fields from table_b
            self.assertIn('b_ref__id', field_names)
            self.assertIn('b_ref__name_b', field_names)

            # Should have a finite, reasonable number of fields (not infinite due to cycles)
            self.assertGreater(len(resolved), 0)
            self.assertLess(len(resolved), 50)  # Should be much less than 50 with depth limits

        finally:
            path_a.unlink(missing_ok=True)
            path_b.unlink(missing_ok=True)

    # Test missing referenced tables
    def test_resolve_relationship_fields_missing_table_warning(self):
        """Test that missing referenced tables generate warnings but don't crash."""
        relationships = [{
            'name': 'missing_ref',
            'type': 'many_to_one',
            'foreign_key': 'missing_id',
            'references_table': 'nonexistent_table',
            'references_field': 'id'
        }]

        # Clear any existing tables
        self.gen.all_tables.clear()

        # Should return empty list without crashing
        resolved = self.gen.resolve_relationship_fields(relationships, 'some_table')
        self.assertEqual(len(resolved), 0)

    # Test JOIN generation
    def test_generate_nested_joins_basic(self):
        """Test basic JOIN SQL generation."""
        # Setup tables
        users_yaml = """
        tables:
          users:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
        """
        posts_yaml = """
        tables:
          posts:
            fields:
              id: { type: integer, primary_key: true }
              author_id: { type: integer }
        """

        users_path = self._write_temp_yaml(users_yaml)
        posts_path = self._write_temp_yaml(posts_yaml)

        try:
            self.gen.collect_all_tables([users_path, posts_path])

            relationships = [{
                'name': 'author',
                'type': 'many_to_one',
                'foreign_key': 'author_id',
                'references_table': 'users',
                'references_field': 'id'
            }]

            fields = {'id': {'type': 'integer'}, 'author_id': {'type': 'integer'}}
            join_lines, select_cols = self.gen.generate_nested_joins('posts', relationships, 'our')

            # Should have one JOIN
            self.assertEqual(len(join_lines), 1)
            self.assertIn('LEFT JOIN users t1 ON our.author_id = t1.id', join_lines[0])

            # Should have select columns
            self.assertGreater(len(select_cols), 0)

        finally:
            users_path.unlink(missing_ok=True)
            posts_path.unlink(missing_ok=True)

    # Test complete module generation with relationships
    def test_generate_module_with_relationships(self):
        """Test complete module generation including relationships."""
        users_yaml = """
        tables:
          users:
            fields:
              id: { type: integer, primary_key: true }
              name: { type: string }
              email: { type: string }
        """
        posts_yaml = """
        tables:
          posts:
            fields:
              id: { type: integer, primary_key: true }
              title: { type: string }
              author_id: { type: integer }
            relationships:
              - name: author
                type: many_to_one
                foreign_key: author_id
                references_table: users
                references_field: id
        """

        users_path = self._write_temp_yaml(users_yaml)
        posts_path = self._write_temp_yaml(posts_yaml)

        try:
            self.gen.collect_all_tables([users_path, posts_path])

            fields = {
                'id': {'type': 'integer', 'primary_key': True},
                'title': {'type': 'string'},
                'author_id': {'type': 'integer'}
            }
            relationships = [{
                'name': 'author',
                'type': 'many_to_one',
                'foreign_key': 'author_id',
                'references_table': 'users',
                'references_field': 'id'
            }]

            module = self.gen.generate_module('posts', fields, posts_path, relationships)

            # Should contain relationship fields in struct
            self.assertIn('author__id', module)
            self.assertIn('author__name', module)
            self.assertIn('author__email', module)

            # Should contain JOIN in SQL
            self.assertIn('LEFT JOIN users', module)
            self.assertIn('ON our.author_id = t1.id', module)

            # Should contain proper module structure
            self.assertIn('export module Posts.RS', module)
            self.assertIn('struct PostsRecord', module)
            self.assertIn('class PostsRS', module)

        finally:
            users_path.unlink(missing_ok=True)
            posts_path.unlink(missing_ok=True)

    # Test field type mapping
    def test_field_type_mapping(self):
        """Test that YAML field types are correctly mapped to C++ types."""
        mappings = [
            ('integer', 'int'),
            ('string', 'std::string'),
            ('boolean', 'boolean'),
            ('float', 'float'),
            ('double', 'double'),
            ('text', 'std::string'),
            ('datetime', 'std::tm'),
            ('date', 'std::tm'),
            ('unknown_type', 'std::string')  # Default fallback
        ]

        for yaml_type, expected_cpp in mappings:
            with self.subTest(yaml_type=yaml_type):
                cpp_type = self.gen.map_yaml_type_to_cpp(yaml_type)
                self.assertEqual(cpp_type, expected_cpp)

    # Test table name normalization
    def test_table_name_normalization(self):
        """Test table name normalization and PascalCase conversion."""
        test_cases = [
            ('users', 'Users'),
            ('user_profiles', 'UserProfiles'),
            ('users_table', 'Users'),  # Should remove _table suffix
            ('email_security_table', 'EmailSecurity'),
        ]

        for input_name, expected_pascal in test_cases:
            with self.subTest(input_name=input_name):
                # Test normalization (removing _table)
                normalized = input_name[:-6] if input_name.endswith('_table') else input_name
                # Test PascalCase conversion
                pascal = self.gen.to_pascal_case(normalized)
                self.assertEqual(pascal, expected_pascal)

    # Test SQL generation with depth comment
    def test_generated_module_includes_depth_comment(self):
        """Test that generated modules include depth information in comments."""
        yaml_content = """
        tables:
          test_table:
            fields:
              id: { type: integer, primary_key: true }
        """
        path = self._write_temp_yaml(yaml_content)

        try:
            self.gen.set_max_join_depth(5)
            output = self.gen.generate_from_yaml(path)
            # Should include depth in comment
            self.assertIn('nested joins: depth 5', output)
        finally:
            path.unlink(missing_ok=True)
    def test_generate_from_yaml_single_table_ok(self):
        yaml_content = """
        tables:
          states:
            fields:
              id:             { type: integer, primary_key: true }
              fSearchable:    { type: string }
              fAbbreviation:  { type: string }
              fName:          { type: string }
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            output = self.gen.generate_from_yaml(path)
            self.assertIsInstance(output, str)
            self.assertGreater(len(output), 0)
            self.assertIn("export module", output)
            self.assertIn("struct StatesRecord", output)
        finally:
            path.unlink(missing_ok=True)

    def test_generate_from_yaml_multiple_tables_returns_concatenated_output(self):
        yaml_content = """
        tables:
          states:
            fields:
              id:             { type: integer, primary_key: true }
              fName:          { type: string }
          titles:
            fields:
              id:             { type: integer, primary_key: true }
              fTitle:         { type: string }
        """
        path = self._write_temp_yaml(yaml_content)
        try:
            output = self.gen.generate_from_yaml(path)  # no output_file
            self.assertIsInstance(output, str)
            # Should contain both modules
            self.assertIn("struct StatesRecord", output)
            self.assertIn("struct TitlesRecord", output)
            # Two exports for modules
            self.assertIn("export module States.RS", output)
            self.assertIn("export module Titles.RS", output)
        finally:
            path.unlink(missing_ok=True)

    def test_generate_from_yaml_multiple_tables_writes_files_to_directory(self):
        yaml_content = """
        tables:
          states:
            fields:
              id:             { type: integer, primary_key: true }
              fName:          { type: string }
          titles:
            fields:
              id:             { type: integer, primary_key: true }
              fTitle:         { type: string }
        """
        yaml_path = self._write_temp_yaml(yaml_content)
        with tempfile.TemporaryDirectory() as td:
            out_dir = Path(td)
            try:
                # Pass a directory as output_file to trigger per-table writes
                result = self.gen.generate_from_yaml(yaml_path, out_dir)
                # Return type remains str (last generated content), but files should exist
                self.assertTrue((out_dir / "StatesRS.ixx").exists())
                self.assertTrue((out_dir / "TitlesRS.ixx").exists())
                self.assertIsInstance(result, str)
                self.assertIn("export module", result)
            finally:
                yaml_path.unlink(missing_ok=True)
# ... existing code ...

if __name__ == "__main__":
    unittest.main()