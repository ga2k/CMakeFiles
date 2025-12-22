#!/usr/bin/env python3
"""
YAML to C++ Module Generator
Generates C++ module files from YAML table definitions.
"""

import sys
import subprocess
import argparse
from pathlib import Path
from typing import Dict, Any, List, Tuple
import datetime

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

class CppModuleGenerator:
    now: str = datetime.datetime.now().date().isoformat() + " " + datetime.datetime.now().time().strftime("%H:%M:%S")

    quiet = False

    def __init__(self):
        self.type_mapping = {
            'integer': 'int',
            'string': 'std::string',
            'boolean': 'boolean',
            'float': 'float',
            'double': 'double',
            'text': 'std::string',
            'datetime': 'std::tm',
            'date': 'std::tm'
        }
        # Two-pass processing: first collect all tables, then resolve relationships
        self.all_tables: Dict[str, Dict[str, Any]] = {}  # table_name -> table_def
        self.table_files: Dict[str, Path] = {}  # table_name -> yaml_file_path
        self.max_join_depth = 3  # Default maximum depth for nested joins
        self._relationship_cache: Dict[str, List[Tuple[str, str, str]]] = {}  # Cache to prevent infinite recursion

    def be_quiet(self, _quiet: bool) -> None:
        self.quiet = bool(_quiet)

    def to_pascal_case(self, snake_str: str) -> str:
        """Convert snake_case to PascalCase, preserving existing capitalization when appropriate."""
        if not snake_str:
            return ""

        # If the string doesn't contain underscores, check if it's already in a reasonable format
        if '_' not in snake_str:
            # If it's already capitalized (like XMLHttpRequest), return as-is
            if snake_str[0].isupper():
                return snake_str
            # Otherwise, just capitalize the first letter
            return snake_str[0].upper() + snake_str[1:] if len(snake_str) > 1 else snake_str.upper()

        # Handle underscore-separated words
        components = snake_str.split('_')
        return ''.join(word.capitalize() for word in components if word)




    def set_max_join_depth(self, depth: int) -> None:
        """Set the maximum depth for nested joins (default is 3)."""
        self.max_join_depth = max(1, depth)  # Minimum depth is 1

    def resolve_relationship_fields(self, relationships: List[Dict[str, Any]],
                                    current_table_name: str = "",
                                    prefix: str = "",
                                    depth: int = 0) -> List[Tuple[str, str, str]]:
        """
        Recursively resolve relationship fields using collected table data.

        Args:
            relationships: List of relationship definitions
            current_table_name: Name of the current table (for cycle detection)
            prefix: Current prefix for field names (for nested relationships)
            depth: Current recursion depth

        Returns:
            List of (field_name, cpp_type, required) tuples
        """
        if depth >= self.max_join_depth:
            return []

        resolved_fields = []

        for rel in relationships or []:
            if not isinstance(rel, dict) or rel.get("type") != "many_to_one":
                continue

            ref_table = rel.get("references_table")
            if not ref_table:
                continue

            # Normalize referenced table name
            normalized_ref = ref_table
            if ref_table.endswith('_table'):
                normalized_ref = ref_table[:-6]

            # Prevent infinite recursion by checking if we've already processed this table in the current chain
            cache_key = f"{current_table_name}->{normalized_ref}@{depth}"
            if cache_key in self._relationship_cache:
                continue

            # Look up the referenced table in our collected tables
            if normalized_ref not in self.all_tables:
                print(f"Warning: Referenced table '{ref_table}' not found at depth {depth}", file=sys.stderr)
                continue

            ref_table_def = self.all_tables[normalized_ref]
            ref_fields = ref_table_def.get('fields', {})

            rel_name = rel.get('name', ref_table)
            current_prefix = f"{prefix}__{rel_name}" if prefix else rel_name

            # Add all direct fields from the referenced table
            direct_fields = []
            for field_name, field_def in ref_fields.items():
                cpp_type = self.map_yaml_type_to_cpp(field_def.get('type', 'string'))
                prefixed_name = f"{current_prefix}__{field_name}"
                direct_fields.append((prefixed_name, cpp_type, False))  # All relationship fields are optional

            resolved_fields.extend(direct_fields)

            # Cache this level to prevent cycles
            self._relationship_cache[cache_key] = direct_fields

            # Recursively process nested relationships
            nested_relationships = ref_table_def.get('relationships', [])
            if nested_relationships and depth < self.max_join_depth - 1:
                nested_fields = self.resolve_relationship_fields(
                    nested_relationships,
                    normalized_ref,  # This becomes the current table for the next level
                    current_prefix,  # Pass down the accumulated prefix
                    depth + 1
                )
                resolved_fields.extend(nested_fields)

        return resolved_fields

    def generate_nested_joins(self, table_name: str, relationships: List[Dict[str, Any]],
                              base_alias: str = "our", depth: int = 0,
                              used_aliases: set = None) -> Tuple[List[str], Dict[str, List[str]]]:
        """
        Generate nested JOIN clauses and select columns for relationships.

        New behavior:
          - If a relationship block contains 'as', use it as the SQL alias; otherwise use a unique tN.
          - Preserve recursion, max depth, alias uniqueness, and nested name prefixing.
        """
        if used_aliases is None:
            used_aliases = {base_alias}

        if depth >= self.max_join_depth:
            return [], {}

        join_lines = []
        select_cols_by_alias = {}
        alias_counter = len(used_aliases)

        def next_auto_alias(counter: int) -> Tuple[str, int]:
            alias = f"t{counter}"
            while alias in used_aliases:
                counter += 1
                alias = f"t{counter}"
            return alias, counter + 1

        for rel in relationships or []:
            if not isinstance(rel, dict) or rel.get("type") != "many_to_one":
                continue

            fk = rel.get("foreign_key")
            ref_table = rel.get("references_table")
            ref_field = rel.get("references_field")
            if not (fk and ref_table and ref_field):
                continue

            # Determine alias: prefer explicit 'as', else allocate tN
            explicit_alias = rel.get("as")
            if explicit_alias:
                alias = explicit_alias
                # Ensure global uniqueness; if taken, fall back to auto
                if alias in used_aliases:
                    alias, alias_counter = next_auto_alias(alias_counter)
            else:
                alias, alias_counter = next_auto_alias(alias_counter)

            used_aliases.add(alias)

            rel_name = rel.get('name', ref_table)

            # Determine JOIN type
            join_override = (rel.get("join") or "").lower()
            if join_override in ("inner", "left"):
                join_kw = "INNER" if join_override == "inner" else "LEFT"
            else:
                join_kw = "LEFT"

            # Add this level's JOIN
            join_lines.append(f"{join_kw} JOIN {ref_table} {alias} ON {base_alias}.{fk} = {alias}.{ref_field}")

            # Get fields from referenced table
            normalized_ref = ref_table[:-6] if ref_table.endswith('_table') else ref_table
            if normalized_ref in self.all_tables:
                ref_fields = self.all_tables[normalized_ref].get('fields', {})
                select_cols_by_alias[alias] = [
                    f"{alias}.{col_name} AS {rel_name}__{col_name}"
                    for col_name in ref_fields.keys()
                ]

                # Recursively process nested relationships
                nested_relationships = self.all_tables[normalized_ref].get('relationships', [])
                if nested_relationships and depth < self.max_join_depth - 1:
                    nested_joins, nested_cols = self.generate_nested_joins(
                        ref_table, nested_relationships, alias, depth + 1, used_aliases
                    )
                    join_lines.extend(nested_joins)

                    # Merge nested select columns with proper prefixing
                    for nested_alias, cols in nested_cols.items():
                        prefixed_cols = []
                        for col in cols:
                            if " AS " in col:
                                select_part, as_part = col.split(" AS ", 1)
                                prefixed_cols.append(f"{select_part} AS {rel_name}__{as_part}")
                            else:
                                prefixed_cols.append(col)
                        select_cols_by_alias[nested_alias] = prefixed_cols

        return join_lines, select_cols_by_alias

    def generate_select_impl(self, table_name: str, fields: dict, relationships: list, yaml_file: Path) -> str:
        """
        Generate a C++ select_impl with support for nested JOINs.
        """
        base_alias = "our"

        # Base table columns
        base_select_cols = [f"{base_alias}.{col} AS {col}" for col in fields.keys()]

        # Generate nested JOINs and select columns
        join_lines, select_cols_by_alias = self.generate_nested_joins(table_name, relationships, base_alias)

        # Flatten all select columns
        rel_select_cols = []
        for cols in select_cols_by_alias.values():
            rel_select_cols.extend(cols)

        # Compose SQL
        select_clause = "SELECT " + ", ".join(base_select_cols + rel_select_cols)
        from_clause = f"FROM {table_name} {base_alias}"

        # Build the method body
        if join_lines:
            joins_block = "\\n".join(join_lines)
            joins_emit = f'        sql.append("{joins_block}\\n");'
        else:
            joins_emit = ""

        cpp = f"""
            std::string selectRecords_impl(std::string where = std::string{{}}, std::string order_by = std::string{{}}, std::string limit_offset = std::string{{}}) {{
                std::string sql;
                sql.reserve(2048);  // Larger buffer for nested joins
                sql.append("{select_clause}\\n");
                sql.append("{from_clause}\\n");
        {joins_emit}
                if (!where.empty()) {{
                    sql.append("WHERE ");
                    sql.append(where);
                    sql.append("\\n");
                }}
                if (!order_by.empty()) {{
                    sql.append("ORDER BY ");
                    sql.append(order_by);
                    sql.append("\\n");
                }}
                if (!limit_offset.empty()) {{
                    sql.append(std::string(limit_offset));
                }}
                return sql;
            }}
        """
        return cpp

    def _collect_relationship_map(self, relationships: list) -> list:
        """
        Normalize relationship entries and extract replace_with/as/replace_as if present.
        Returns a list of dicts with keys:
          - name
          - type
          - foreign_key
          - references_table
          - references_field
          - replace_with (list[str] or None)
          - as_alias (str|None)
          - replace_as (str|None)
        """
        rels = []
        if not relationships:
            return rels
        for rel in relationships:
            rw = rel.get("replace_with")
            if isinstance(rw, list):
                rw_list = [str(x) for x in rw]
            elif isinstance(rw, str):
                rw_list = [rw]
            else:
                rw_list = None
            rels.append({
                "name": rel.get("name"),
                "type": rel.get("type"),
                "foreign_key": rel.get("foreign_key"),
                "references_table": rel.get("references_table"),
                "references_field": rel.get("references_field"),
                "replace_with": rw_list,
                "as_alias": rel.get("as"),
                "replace_as": rel.get("replace_as"),
            })
        return rels

    def generate_get_rowset_impl(self, table_name: str, fields: dict, relationships: list) -> str:
        """
        Generate Recordset::getRowset_impl SQL that replaces foreign-key fields
        using 'replace_with'. Supports:
          - 'as' for join alias name
          - 'replace_as' to rename the resulting SQL field (alias) instead of the FK name
        """
        base_alias = "our"

        # Build join lines with aliasing (uses 'as' if provided)
        join_lines, _ = self.generate_nested_joins(table_name, relationships, base_alias)

        # Prepare relationship metadata and alias map
        rel_infos = self._collect_relationship_map(relationships)

        # Build alias map for FK -> alias honoring 'as'; fallback to t1.. if missing
        used_aliases = set([base_alias])
        alias_for_fk = {}
        auto_n = 1
        def next_auto_alias(n):
            a = f"t{n}"
            while a in used_aliases:
                n += 1
                a = f"t{n}"
            return a, n

        for rel in rel_infos:
            alias = rel["as_alias"]
            if not alias or alias in used_aliases:
                alias, auto_n = next_auto_alias(auto_n)
            used_aliases.add(alias)
            alias_for_fk[rel["foreign_key"]] = alias

        # Start with the list of base fields in order
        base_field_order = list(fields.keys())

        # Build projection with replacements
        projected_cols = []
        for col in base_field_order:
            rel = next((r for r in rel_infos if r["foreign_key"] == col and r.get("replace_with")), None)
            if rel is None:
                projected_cols.append(f"{base_alias}.{col} AS {col}")
                continue

            alias = alias_for_fk.get(col)
            rw_list = rel["replace_with"] or []
            out_name = rel.get("replace_as") or col

            if not alias or not rw_list:
                projected_cols.append(f"{base_alias}.{col} AS {out_name}")
                continue

            if len(rw_list) == 1:
                repl = rw_list[0]
                projected_cols.append(f"{alias}.{repl} AS {out_name}")
            else:
                concat_expr = " || ' ' || ".join([f"{alias}.{c}" for c in rw_list])
                projected_cols.append(f"{concat_expr} AS {out_name}")

        select_clause = "SELECT " + ", ".join(projected_cols)
        from_clause = f"FROM {table_name} {base_alias}"

        if join_lines:
            joins_block = "\\n".join(join_lines)
            joins_emit = f'        sql.append("{joins_block}\\n");'
        else:
            joins_emit = ""

        cpp = f"""
            std::string getRowset_impl(std::string where = std::string{{}}, std::string order_by = std::string{{}}, std::string limit_offset = std::string{{}}) {{
                std::string sql;
                sql.reserve(2048);
                sql.append("{select_clause}\\n");
                sql.append("{from_clause}\\n");
        {joins_emit}
                if (!where.empty()) {{
                    sql.append("WHERE ");
                    sql.append(where);
                    sql.append("\\n");
                }}
                if (!order_by.empty()) {{
                    sql.append("ORDER BY ");
                    sql.append(order_by);
                    sql.append("\\n");
                }}
                if (!limit_offset.empty()) {{
                    sql.append(std::string(limit_offset));
                }}
                return sql;
            }}
        """
        return cpp

    def generate_recordset_impl(self, table_name: str, fields: dict, relationships: list, yaml_file: Path) -> str:
        """
        Top-level generator that emits all impl functions for a table.
        """
        content = []
        content.append(self.generate_select_impl(table_name, fields, relationships, yaml_file))
        content.append(self.generate_get_rowset_impl(table_name, fields, relationships))
        return "\n".join(content)

    def generate_module(self, table_name: str, fields: Dict[str, Any], yaml_file: Path,
                        relationships: List[Dict[str, Any]] | None = None) -> str:
        """Generate the complete C++ module file with nested relationship support."""

        if table_name.endswith('_table'):
            proposed_name = table_name.replace('_table', '')
        else:
            proposed_name = table_name

        pascal = self.to_pascal_case(proposed_name)
        class_name = f"{pascal}RS"
        record_name = f"{pascal}Record"

        # Clear relationship cache for each table generation
        self._relationship_cache.clear()

        field_declarations = self.generate_field_declarations(fields)

        # Use the enhanced nested relationship resolver
        normalized_table = table_name[:-6] if table_name.endswith('_table') else table_name
        related_decls, related_reads = self._generate_related_declarations_and_reads_nested(relationships or [],
                                                                                            normalized_table)

        constructor_params, _constructor_initializers = self.generate_constructor_params(fields)
        row_assignments = self.generate_row_assignments(fields)

        constructor_params_str = ",\n".join(constructor_params)

        # Build ctor body: copy ctor params into this->in_.*
        ctor_body_lines: List[str] = []
        for field_name, field_def in fields.items():
            if field_def.get('auto_increment', False):
                continue
            camel = self.to_camel_case(field_name)
            ctor_body_lines.append(f"        this->in_.{field_name.ljust(24)} = {camel};")
        ctor_body = "\n".join(ctor_body_lines)

        # Generate safe insertRecord_impl
        insert_impl = self.generate_insert_impl(table_name, fields)
        # Use YAML file modification time for deterministic headers (prevents needless rebuilds)
        try:
            _mt = datetime.datetime.fromtimestamp(yaml_file.stat().st_mtime)
            _mts = _mt.isoformat(sep=' ', timespec='seconds')
        except Exception:
            _mts = 'unknown'

        module_content = f'''module;

// Auto-generated from
// file://{yaml_file} (mtime: {_mts})

// Make any changes there. This file will be overwritten.

//
// Generated from {yaml_file.name} (nested joins: depth {self.max_join_depth})
//

#include "HoffSoft/CoreData.h"
#include "HoffSoft/HoffSoft.h"

#include <soci/soci.h>
#include <string>

export module {pascal}.RS;
export import DB.RS;
export import DB.Table;

import Types;
import Util;
import DDT;

export namespace mc {{
using namespace db;
using namespace std::string_literals;

// clang-format off
struct {record_name} {{
{chr(10).join(field_declarations + related_decls)}

   {record_name} () = default;
   explicit {record_name} (const soci::row &row) {{
      in (row);
   }}
   void in (const soci::row &row) {{
{chr(10).join(row_assignments + related_reads)}
   }}
}};

class {class_name} : public RecordSet<{class_name}, {record_name}> {{
  public:
   using Record = {record_name};

    explicit {class_name} (Table &table)
        : RecordSet<{class_name}, Record> (table)
        {{}}

    explicit {class_name} (Table &table,
{constructor_params_str})
    : RecordSet (table) {{
{ctor_body}
    }}

    ~{class_name}() override = default;
{insert_impl}
{self.generate_recordset_impl(table_name, fields, relationships or [], yaml_file)}
}};
}} // namespace mc
'''
        return module_content

    def _generate_related_declarations_and_reads_nested(self, relationships: List[Dict[str, Any]],
                                                        current_table: str) -> tuple[List[str], List[str]]:
        """
        Create declarations and row reads for nested joined columns.
        """
        decls: list[str] = []
        reads: list[str] = []

        # Use the new nested resolution method
        resolved_fields = self.resolve_relationship_fields(relationships, current_table)

        if not resolved_fields:
            return decls, reads

        max_name_len = max(len(name) for name, _, _ in resolved_fields)
        max_type_len = max(len(f"optional<{cpp_type}>") for _, cpp_type, _ in resolved_fields)

        for name, cpp_type, required in resolved_fields:
            type_str = f"optional<{cpp_type}>"
            decls.append(f"    {type_str.ljust(max_type_len)}     {name.ljust(max_name_len)} {{nullopt}};")
            reads.append(
                f'      {name.ljust(max_name_len)} = row.get<optional<{cpp_type}>>{" " * max(0, 15 - len(cpp_type))}("{name}");'
            )

        return decls, reads

    def collect_all_tables(self, yaml_files: List[Path]) -> None:
        """First pass: collect all table definitions from all YAML files."""

        for yaml_file in yaml_files:
            try:
                data = self.parse_yaml_file(yaml_file)
                if 'tables' not in data or not isinstance(data['tables'], dict):
                    if not self.quiet:
                        print(f"no 'tables' section in {yaml_file}")
                    continue

                for table_name, table_def in data['tables'].items():
                    if 'fields' not in table_def:
                        print(f"Warning: Table '{table_name}' in {yaml_file} has no fields", file=sys.stderr)
                        continue

                    # Normalize table name (remove _table suffix if present)
                    normalized_name = table_name
                    if table_name.endswith('_table'):
                        normalized_name = table_name[:-6]

                    self.all_tables[normalized_name] = table_def
                    self.table_files[normalized_name] = yaml_file

            except Exception as e:
                print(f"Error parsing {yaml_file}: {e}", file=sys.stderr)

    def generate_from_yaml(self, yaml_file: Path, output_file: Path = None) -> str:
        """Generate C++ module from YAML file."""
        data = self.parse_yaml_file(yaml_file)

        if 'tables' not in data:
            if not self.quiet:
                print(f"no 'tables' section in {yaml_file}")
            return ""

        tables = data['tables']
        if not isinstance(tables, dict) or len(tables) == 0:
            raise ValueError("'tables' section must be a non-empty mapping of table_name -> table_def")

        # Generate all modules
        generated: list[tuple[str, str]] = []  # (table_name, module_content)
        for table_name, table_def in tables.items():
            if 'fields' not in table_def:
                raise ValueError(f"Table '{table_name}' must have a 'fields' section")

            fields = table_def['fields']
            relationships = table_def.get('relationships', [])

            module_content = self.generate_module(table_name, fields, yaml_file, relationships)
            generated.append((table_name, module_content))

        # Handle output
        if output_file:
            # If output_file is a directory, write there; else use its parent.
            dest_dir = output_file
            try:
                # Treat as directory if it exists and is directory
                if not dest_dir.exists() or not dest_dir.is_dir():
                    dest_dir = output_file.parent
            except Exception:
                dest_dir = Path(output_file).parent

            dest_dir.mkdir(parents=True, exist_ok=True)

            for table_name, module_content in generated:
                if table_name.endswith('_table'):
                    table_name = table_name.replace('_table', '')

                pascal = self.to_pascal_case(table_name)
                out_path = dest_dir / f"{pascal}RS.ixx"
                with open(out_path, 'w', encoding='utf-8') as f:
                    f.write(module_content)

                print(f"{out_path} : Ok")

            # Return the last generated content to preserve return type
            return generated[-1][1]

        # No output file specified: return concatenated modules
        return ("\n\n").join(module for _, module in generated)

    # ... existing code ...
    def format_default_value(self, field_def: Dict[str, Any], cpp_type: str) -> str:
        """Format the default value based on the field definition and C++ type."""
        if 'default' not in field_def:
            return 'nullopt'

        default_val = field_def['default']

        # Format the default value based on the C++ type
        if cpp_type == 'std::string':
            return f'"{default_val}"'
        elif cpp_type == 'boolean':
            return 'boolean(true)' if default_val else 'boolean(false)'
        elif cpp_type == 'hs_id':
            return str(default_val)
        elif cpp_type in ['int', 'float', 'double']:
            return str(default_val)
        elif cpp_type == 'std::tm':  # Handle datetime defaults
            if default_val in ('now', 'current_timestamp'):
                return 'std::tm{}'
            else:
                return 'std::tm{}'
        else:
            return str(default_val)

    def map_yaml_type_to_cpp(self, yaml_type: str) -> str:
        """Convert YAML type to C++ type."""
        return self.type_mapping.get(yaml_type.lower(), 'std::string')

    def to_camel_case(self, snake_str: str) -> str:
        """Convert snake_case to camelCase."""
        components = snake_str.split('_')
        return components[0] + ''.join(word.capitalize() for word in components[1:])

    def parse_yaml_file(self, yaml_file: Path) -> Dict[str, Any]:
        """Parse the YAML file and return the table definitions."""
        with open(yaml_file, 'r') as file:
            return yaml.safe_load(file)

    def _generate_related_declarations_and_reads(self, relationships: List[Dict[str, Any]]) -> tuple[
        List[str], List[str]]:
        """
        Create declarations and row reads for joined columns using resolved table data.
        All related fields are optional. Names are <prefix>__<col>.
        """
        decls: list[str] = []
        reads: list[str] = []

        # Use the new resolution method
        resolved_fields = self.resolve_relationship_fields(relationships)

        if not resolved_fields:
            return decls, reads

        max_name_len = max(len(name) for name, _, _ in resolved_fields)
        max_type_len = max(len(f"optional<{cpp_type}>") for _, cpp_type, _ in resolved_fields)

        for name, cpp_type, required in resolved_fields:
            type_str = f"optional<{cpp_type}>"
            decls.append(f"    {type_str.ljust(max_type_len)}     {name.ljust(max_name_len)} {{nullopt}};")
            reads.append(
                f'      {name.ljust(max_name_len)} = row.get<optional<{cpp_type}>>{" " * max(0, 15 - len(cpp_type))}("{name}");'
            )

        return decls, reads

    def _resolve_related_fields(self, base_yaml: Path, ref_table: str) -> Dict[str, Any]:
        """
        Try to locate the YAML for a referenced table and return its fields dict.
        Search alongside the base yaml using common naming patterns.
        """
        search_dir = base_yaml.parent
        candidates = [
            search_dir / f"{ref_table}.yaml",
            search_dir / f"{self.to_pascal_case(ref_table)}.yaml",
            base_yaml  # check the current YAML last (multi-table YAMLs)
        ]
        for cand in candidates:
            if cand.exists():
                data = self.parse_yaml_file(cand)
                # Prefer exact (or normalized) match inside this YAML
                if "tables" in data and isinstance(data["tables"], dict):
                    # normalize names to compare (strip trailing '_table', lowercase)
                    def _norm(s: str) -> str:
                        s = s or ""
                        s = s.strip()
                        s = s[:-6] if s.lower().endswith("_table") else s
                        return s.lower()

                    wanted = _norm(ref_table)
                    for key, tdef in data["tables"].items():
                        if _norm(key) == wanted and isinstance(tdef, dict):
                            if "fields" in tdef and isinstance(tdef["fields"], dict):
                                return tdef["fields"]

                    # Only use fallback if this is NOT the base_yaml file
                    # Fallback: if ref_table key differs (e.g., PascalCase) but there is only one table
                    if cand != base_yaml and len(data["tables"]) == 1:
                        _, tdef = next(iter(data["tables"].items()))
                        if "fields" in tdef and isinstance(tdef["fields"], dict):
                            return tdef["fields"]
        return {}

    def _resolve_related_fields0(self, base_yaml: Path, ref_table: str) -> Dict[str, Any]:
        """
        Try to locate the YAML for a referenced table and return its fields dict.
        Search alongside the base yaml using common naming patterns.
        """
        search_dir = base_yaml.parent
        candidates = [
            base_yaml,  # check the current YAML first (multi-table YAMLs)
            search_dir / f"{ref_table}.yaml",
            search_dir / f"{self.to_pascal_case(ref_table)}.yaml"
        ]
        for cand in candidates:
            if cand.exists():
                data = self.parse_yaml_file(cand)
                # Prefer exact (or normalized) match inside this YAML
                if "tables" in data and isinstance(data["tables"], dict):
                    # normalize names to compare (strip trailing '_table', lowercase)
                    def _norm(s: str) -> str:
                        s = s or ""
                        s = s.strip()
                        s = s[:-6] if s.lower().endswith("_table") else s
                        return s.lower()

                    wanted = _norm(ref_table)
                    for key, tdef in data["tables"].items():
                        if _norm(key) == wanted and isinstance(tdef, dict):
                            if "fields" in tdef and isinstance(tdef["fields"], dict):
                                return tdef["fields"]

                    # Fallback: if ref_table key differs (e.g., PascalCase) but there is only one table
                    if len(data["tables"]) == 1:
                        _, tdef = next(iter(data["tables"].items()))
                        if "fields" in tdef and isinstance(tdef["fields"], dict):
                            return tdef["fields"]
        return {}

    def _collect_join_columns(self, yaml_file: Path, relationships: list) -> list[dict]:
        """
        For each many_to_one relationship, return:
        {
          'rel': <relationship dict>,
          'alias': tN,
          'prefix': <name|references_table>,
          'columns': [{ 'name': <col>, 'cpp_type': <mapped>, 'required': False }]
        }
        """
        collected = []
        alias_index = 1
        for rel in relationships or []:
            if not isinstance(rel, dict) or rel.get("type") != "many_to_one":
                continue
            ref_table = rel.get("references_table")
            if not ref_table:
                continue
            alias = f"t{alias_index}"
            alias_index += 1
            prefix = rel.get("name") or ref_table
            ref_fields = self._resolve_related_fields(yaml_file, ref_table)
            cols = []
            for col_name, col_def in ref_fields.items():
                cpp_type = self.map_yaml_type_to_cpp(col_def.get("type", "string"))
                cols.append({"name": col_name, "cpp_type": cpp_type, "required": False})
            collected.append({"rel": rel, "alias": alias, "prefix": prefix, "columns": cols})
        return collected

    def is_required_field(self, field_def: Dict[str, Any]) -> bool:
        """Check if a field is required (not_null, primary_key, or auto_increment primary keys)."""
        if field_def.get('primary_key', False):
            return True
        return field_def.get('not_null', False) and not field_def.get('auto_increment', False)

    def generate_field_declarations(self, fields: Dict[str, Any]) -> List[str]:
        """Generate C++ field declarations (for Record struct)."""
        declarations = []
        max_type_len = 0
        max_name_len = 0

        # Calculate max lengths for alignment
        for field_name, field_def in fields.items():
            cpp_type = self.map_yaml_type_to_cpp(field_def['type'])
            type_str = cpp_type if self.is_required_field(field_def) else f"optional<{cpp_type}>"
            max_type_len = max(max_type_len, len(type_str))
            max_name_len = max(max_name_len, len(field_name))

        # Generate declarations with alignment
        for field_name, field_def in fields.items():
            cpp_type = self.map_yaml_type_to_cpp(field_def['type'])

            if self.is_required_field(field_def):
                type_str = cpp_type
                if 'default' in field_def:
                    init_value = f"{{{self.format_default_value(field_def, cpp_type)}}}"
                else:
                    if cpp_type == 'boolean':
                        init_value = "{boolean(false)}"
                    elif cpp_type == 'hs_id':
                        init_value = "{hs_id(ID::Null)}"
                    else:
                        init_value = "{}"
            else:
                type_str = f"optional<{cpp_type}>"
                if 'default' in field_def:
                    init_value = f"{{{self.format_default_value(field_def, cpp_type)}}}"
                else:
                    init_value = "{{nullopt}}".format()

            padded_type = type_str.ljust(max_type_len)
            padded_name = field_name.ljust(max_name_len)
            declarations.append(f"    {padded_type}     {padded_name} {init_value};")

        return declarations

    def get_required_fields(self, fields: Dict[str, Any]) -> List[str]:
        """Get list of required field names."""
        required = []
        for field_name, field_def in fields.items():
            if self.is_required_field(field_def):
                required.append(field_name)
        return required

    def generate_constructor_params(self, fields: Dict[str, Any]) -> Tuple[List[str], List[str]]:
        """Generate constructor parameter list and initializer list."""
        required_fields = self.get_required_fields(fields)
        params = []
        initializers = []

        # Required parameters first (no optional wrapper)
        for field_name in required_fields:
            field_def = fields[field_name]
            cpp_type = self.map_yaml_type_to_cpp(field_def['type'])
            camel_name = self.to_camel_case(field_name)
            params.append(f"        {cpp_type}                    {camel_name}")
            initializers.append(f"        {field_name.ljust(16)} ({camel_name})")

        # Optional parameters (with optional wrapper and default values)
        for field_name, field_def in fields.items():
            if field_name not in required_fields and not field_def.get('auto_increment', False):
                cpp_type = self.map_yaml_type_to_cpp(field_def['type'])
                camel_name = self.to_camel_case(field_name)

                if 'default' in field_def:
                    default_val = self.format_default_value(field_def, cpp_type)
                    params.append(f"        optional<{cpp_type}>         {camel_name.ljust(16)} = {default_val}")
                else:
                    params.append(f"        optional<{cpp_type}>         {camel_name.ljust(16)} = nullopt")

                initializers.append(f"        {field_name.ljust(16)} ({camel_name})")

        return params, initializers

    def generate_insert_params(self, fields: Dict[str, Any]) -> List[str]:
        """Generate insertRecord_impl parameter list."""
        required_fields = self.get_required_fields(fields)
        params: List[str] = []

        # Required parameters first (skip auto-increment)
        for field_name in required_fields:
            field_def = fields[field_name]
            if field_def.get('auto_increment', False):
                continue
            cpp_type = self.map_yaml_type_to_cpp(field_def['type'])
            camel_name = self.to_camel_case(field_name)

            # Prefer const ref for strings
            if cpp_type == 'std::string':
                params.append(f"        const std::string&          {camel_name}")
            else:
                params.append(f"        {cpp_type}                    {camel_name}")

        # Optional parameters (skip auto-increment and required)
        for field_name, field_def in fields.items():
            if field_def.get('auto_increment', False) or field_name in required_fields:
                continue
            cpp_type = self.map_yaml_type_to_cpp(field_def['type'])
            camel_name = self.to_camel_case(field_name)
            if 'default' in field_def:
                default_val = self.format_default_value(field_def, cpp_type)
                params.append(f"        std::optional<{cpp_type}>     {camel_name} = {default_val}")
            else:
                params.append(f"        std::optional<{cpp_type}>     {camel_name} = nullopt")

        return params

    def generate_prepare_insert_pairs(self, fields: Dict[str, Any]) -> List[str]:
        """Generate pair(...) items for prepareInsertStatement bound to this->in_.<field> to ensure stable storage."""
        pairs = []
        for field_name, field_def in fields.items():
            if field_def.get('auto_increment', False):
                continue
            pad = " " * max(0, 16 - len(field_name))
            pairs.append(f'           pair ("{field_name}"s,{pad}this->in_.{field_name})')
        return pairs

    def generate_row_assignments(self, fields: Dict[str, Any]) -> List[str]:
        """Generate row assignment statements (Record::in) for base table only."""
        assignments = []
        max_name_len = max(len(name) for name in fields.keys()) if fields else 0
        for field_name, field_def in fields.items():
            cpp_type = self.map_yaml_type_to_cpp(field_def['type'])
            padded_name = field_name.ljust(max_name_len)
            if self.is_required_field(field_def):
                assignments.append(
                    f'      {padded_name} = row.get<{cpp_type}>{" " * max(0, 23 - len(cpp_type))}("{field_name}");'
                )
            else:
                assignments.append(
                    f'      {padded_name} = row.get<optional<{cpp_type}>>{" " * max(0, 15 - len(cpp_type))}("{field_name}");'
                )
        return assignments

    def _cpp_type_default(self, cpp_type: str) -> str:
        """Default literal for a mapped C++ type."""
        if cpp_type in ("int", "long", "long long", "unsigned long long", "unsigned int", "double", "float"):
            return "0"
        if cpp_type == "boolean":
            return "boolean(false)"
        if cpp_type == "std::tm":
            return "{}"
        if cpp_type == "hs_id":
            return "hs_id(ID::Null)"
        return "std::string{}"

    def _field_order_for_insert(self, fields: Dict[str, Any]) -> List[str]:
        """Return non-AI field names in declaration order for INSERT column list."""
        cols: List[str] = []
        for fname, fdef in fields.items():
            if fdef.get("auto_increment", False) and fdef.get("primary_key", False):
                continue
            cols.append(fname)
        return cols

    def _assignment_lines_for_insert(self, fields: Dict[str, Any]) -> List[str]:
        """
        Build lines assigning ctor params into this->in_.<field>.
        Required fields assign directly; optional use value_or(default).
        """
        lines: List[str] = []
        required = set(self.get_required_fields(fields))
        for fname, fdef in fields.items():
            if fdef.get("auto_increment", False) and fdef.get("primary_key", False):
                continue
            cpp_type = self.map_yaml_type_to_cpp(fdef["type"])
            camel = self.to_camel_case(fname)
            if fname in required:
                lines.append(f"        this->in_.{fname.ljust(24)} = {camel};")
            else:
                if "default" in fdef:
                    dflt = self.format_default_value(fdef, cpp_type)
                else:
                    dflt = self._cpp_type_default(cpp_type)
                dflt_expr = "std::tm{}" if cpp_type == "std::tm" and dflt == "{}" else dflt
                # lines.append(f"        this->in_.{fname.ljust(24)} = {camel}.value_or({dflt_expr});")
                lines.append(f"        this->in_.{fname.ljust(24)} = {camel};")
        return lines

    def generate_insert_impl(self, table_name: str, fields: Dict[str, Any]) -> str:
        """
        Generate insertRecord_impl using SOCI prepared statements bound to this->in_.*
        Executes immediately to ensure lifetimes are valid.
        """
        params = self.generate_insert_params(fields)
        params_sig = ",\n".join(params) if params else "        /* no fields to insert */"

        assigns = self._assignment_lines_for_insert(fields)
        cols = self._field_order_for_insert(fields)
        placeholders = ", ".join([f":{c}" for c in cols])
        uses_lines = ",\n               ".join([f"soci::use(this->in_.{c})" for c in cols])

        return f"""
    int insertRecord_impl (
{params_sig}) {{
{chr(10).join(assigns)}

        auto session = table_.getSession();
        soci::statement stmt = (session->prepare
            << "INSERT INTO {table_name} ({', '.join(cols)}) VALUES ({placeholders})",
               {uses_lines});

        auto rowID = table_.insertRecordStmt (stmt);
        return rowID;
        // auto r = selectRecords(std::format("t0.ID = {{}}", rowID));
        // return r.begin() == r.end() ? 0 : records_[0]->id;
    }}
"""


# --- Build integration helpers ---

AUTO_BEGIN = "# AUTOGEN RS MODULES BEGIN"
AUTO_END = "# AUTOGEN RS MODULES END"


def update_cmake_modules(cmake_path: Path, module_paths: List[Path]) -> None:
    """Ensure cmake has an auto-managed block listing generated RS .ixx paths."""
    if not cmake_path.exists():
        print(f"Warning: CMake file '{cmake_path}' not found; skipping CMake update", file=sys.stderr)
        return

    text = cmake_path.read_text()
    rel_paths = [str(p) for p in module_paths]

    block = "\n".join([AUTO_BEGIN] + rel_paths + [AUTO_END])

    if AUTO_BEGIN in text and AUTO_END in text:
        # replace existing block
        pre, rest = text.split(AUTO_BEGIN, 1)
        _, post = rest.split(AUTO_END, 1)
        new_text = pre + block + post
    else:
        # inject before first target_sources or at end
        insert_at = text.find("target_sources(")
        if insert_at == -1:
            new_text = text.rstrip() + "\n" + block + "\n"
        else:
            new_text = text[:insert_at] + block + "\n" + text[insert_at:]

    if new_text != text:
        cmake_path.write_text(new_text)
        print(f"Updated CMake modules in: {cmake_path}")


def scan_and_generate(generator, roots: List[Path], cmake_path: Path | None, output_dir: Path | None) -> int:
    """Scan for *.yaml and *.yaml, generate corresponding *RS.ixx files using two-pass approach."""
    gen = generator
    generated: List[Path] = []

    # Collect YAML files from all root directories
    yaml_files = []
    for root in roots:
        if not root.exists():
            print(f"Warning: Scan directory '{root}' does not exist, skipping", file=sys.stderr)
            continue
        # Path.rglob doesn't support union patterns. Collect both.
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


    print(f"Processing DB tables in {len(yaml_files)} YAML files from {len(roots)} directories...")

    # FIRST PASS: Collect all table definitions

    if not gen.quiet:
        print(f"First pass: Collecting all table definitions from {len(yaml_files)} files in {len(roots)} directories...")

    gen.collect_all_tables(yaml_files)

    # SECOND PASS: Generate modules with resolved relationships
    if not gen.quiet:
        print("Second pass: Generating modules with resolved relationships...")

    for yf in yaml_files:
        # Load YAML and discover tables
        try:
            data = gen.parse_yaml_file(yf)
        except Exception as e:
            print(f"Error reading {yf}: {e}", file=sys.stderr)
            return 1

        tables = data.get("tables")
        if not isinstance(tables, dict) or not tables:
            # Nothing to generate from this YAML; skip
            continue

        # Decide destination directory for outputs of this YAML
        dest_dir = output_dir if output_dir is not None else yf.parent
        try:
            dest_dir.mkdir(parents=True, exist_ok=True)
        except Exception as e:
            print(f"Error creating output directory '{dest_dir}': {e}", file=sys.stderr)
            return 1

        # Determine if any table-specific output is missing or stale
        any_regen_needed = False
        expected_outputs: List[Path] = []
        for table_name in tables.keys():

            if table_name.endswith('_table'):
                base_name = table_name.replace('_table', '')
            else:
                base_name = table_name

            pascal = gen.to_pascal_case(base_name)
            out_path = dest_dir / f"{pascal}RS.ixx"
            expected_outputs.append(out_path)

            needs_regen = (not out_path.exists()) or (yf.stat().st_mtime > out_path.stat().st_mtime)
            if needs_regen:
                any_regen_needed = True

        # Generate if needed (writing all tables in the YAML to dest_dir)
        if any_regen_needed:
            try:
                # Pass a directory path to write one file per table
                gen.generate_from_yaml(yf, dest_dir)
            except Exception as e:
                print(f"Error generating from {yf}: {e}", file=sys.stderr)
                return 1

        # Collect any outputs that now exist
        for out_path in expected_outputs:
            if out_path.exists():
                generated.append(out_path)

    if cmake_path is not None:
        try:
            rels: List[Path] = []
            for p in generated:
                try:
                    rels.append(p.relative_to(cmake_path.parent))
                except ValueError:
                    rels.append(p)
            update_cmake_modules(cmake_path, [Path(str(r)) for r in rels])
        except Exception as e:
            print(f"Warning: could not update CMake: {e}", file=sys.stderr)

    return 0


def main():
    """Main entry point for the script."""
    parser = argparse.ArgumentParser(description='Generate C++ modules from YAML table definitions')
    parser.add_argument('input_yaml', type=Path, nargs='?', help='Single input YAML file')
    parser.add_argument('-o', '--output', type=Path, help='Output directory or file path')
    parser.add_argument('--scan', type=Path, action='append', help='Scan this directory recursively for *.yaml (can be used multiple times)')
    parser.add_argument('-c', '--cmake', type=Path, help='Update CMakeLists.txt file with generated modules')
    parser.add_argument('-v', '--verbose', action='store_true', help='Enable verbose output')
    parser.add_argument('-d', '--depth', type=int, default=3, help='Maximum depth for nested joins (default: 3)')
    parser.add_argument('-q', '--quiet', action="store_true", help='Only report important information')

    args = parser.parse_args()
    generator = CppModuleGenerator()
    generator.set_max_join_depth(args.depth)
    generator.be_quiet(args.quiet)

    # Scan mode (batch)
    if args.scan:
        output_dir = args.output if args.output is not None else None
        sys.exit(scan_and_generate(generator, args.scan, args.cmake, output_dir))

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

if __name__ == "__main__":
    main()
