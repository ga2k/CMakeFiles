import json, os, re, sys

def get_preset_with_inheritance(presets, name, visited=None):
    if visited is None:
        visited = set()
    if name in visited:
        return {}
    visited.add(name)
    preset = next((p for p in presets if p.get("name") == name), None)
    if not preset:
        return {}
    result = {"environment": {}, "cacheVariables": {}}
    for parent_name in preset.get("inherits", []):
        parent = get_preset_with_inheritance(presets, parent_name, visited)
        result["environment"].update(parent.get("environment", {}))
        result["cacheVariables"].update(parent.get("cacheVariables", {}))
    result["environment"].update(preset.get("environment", {}))
    result["cacheVariables"].update(preset.get("cacheVariables", {}))
    result["binaryDir"] = preset.get("binaryDir", "")
    return result

preset_name = sys.argv[1] if len(sys.argv) > 1 else ""

# Walk up from CWD to find CMakePresets.json, mirroring how cmake --preset works.
def find_presets_file():
    d = os.getcwd()
    while True:
        candidate = os.path.join(d, "CMakePresets.json")
        if os.path.isfile(candidate):
            return candidate
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent

presets_file = find_presets_file()
if presets_file is None:
    print("", end="")
    sys.exit(0)

try:
    with open(presets_file) as f:
        data = json.load(f)
except Exception:
    print("", end="")
    sys.exit(0)

preset = get_preset_with_inheritance(data["configurePresets"], preset_name)
binary_dir = preset.get("binaryDir", "")

def resolve_env(match):
    return preset["environment"].get(match.group(1), "")

binary_dir = re.sub(r"\$env\{([^}]+)\}", resolve_env, binary_dir)
print(binary_dir, end="")
