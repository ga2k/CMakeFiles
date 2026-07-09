#!/usr/bin/env python3
"""Merge compile_commands.json from all module build directories into MCA root."""

import json
import sys
from pathlib import Path

MODULES = ["Libs", "MyHealthGuru"]
ROOT = Path(__file__).parent.parent.parent


def find_compile_commands(module_dir: Path) -> list[Path]:
    """Return all compile_commands.json files found under a module's build/ dir."""
    return sorted(module_dir.glob("build/**/compile_commands.json"))


def main() -> int:
    merged: list[dict] = []
    found_any = False

    for module in MODULES:
        module_dir = ROOT / module
        candidates = find_compile_commands(module_dir)
        if not candidates:
            print(f"  [{ROOT}/{module}] no compile_commands.json found (run make config-all first)")
            continue
        # Use the most recently modified one (in case of multiple presets)
        db_path = max(candidates, key=lambda p: p.stat().st_mtime)
        entries = json.loads(db_path.read_text())
        print(f"  [{module}] {len(entries):4d} entries  ({db_path.relative_to(ROOT)})")
        merged.extend(entries)
        found_any = True

    if not found_any:
        print("No compile_commands.json files found. Run 'make config-all' first.")
        return 1

    for module in MODULES:
        out = ROOT / module / "compile_commands.json"
        out.write_text(json.dumps(merged, indent=2))
        print(f"\n  Wrote {len(merged)} total entries -> {out.relative_to(ROOT)}")

    return 0


if __name__ == "__main__":
    sys.exit(main())
