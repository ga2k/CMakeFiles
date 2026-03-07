import json
import os
import subprocess
import platform
import sys

def read_json(file_path):
    """Reads a JSON file and returns the data."""
    with open(file_path, 'r', encoding='utf-8') as file:
        data = json.load(file)
        return data

def is_cross_compile_preset(preset):
    """
    Returns True if this preset is a cross-compile preset that should always
    be visible on the current host (e.g. WinX presets on Linux).
    Cross-compile presets are identified by having 'Cross' in their name.
    """
    return "Cross" in preset.get("name", "")


def process_presets(presets):
    """
    Process presets to separate hidden, conditional, and inherited conditions.
    Cross-compile presets (e.g. 'WinX') are always included on the
    current host platform regardless of their condition, since they are
    intentionally run from a different host OS.
    """
    hidden_presets = []
    conditional_presets = {}
    processed_presets = []

    for preset in presets:
        if preset.get("hidden"):
            hidden_presets.append(preset)
            if "condition" in preset:
                # Cross-compile hidden base presets: always register their
                # condition so inheriting presets resolve correctly, but also
                # mark them as cross-compile so we skip condition filtering.
                conditional_presets[preset["name"]] = preset["condition"]
        else:
            if is_cross_compile_preset(preset):
                # Cross-compile visible presets: include unconditionally,
                # strip any inherited conditions so they survive filtering.
                preset.pop("condition", None)
                processed_presets.append(preset)
            else:
                inherited_conditions = [
                    conditional_presets[inherited]
                    for inherited in preset.get("inherits", [])
                    if inherited in conditional_presets
                    and not is_cross_compile_preset({"name": inherited})
                ]
                if inherited_conditions:
                    preset["condition"] = (
                        {"type": "allOf", "conditions": inherited_conditions}
                        if len(inherited_conditions) > 1
                        else inherited_conditions[0]
                    )
                processed_presets.append(preset)

    return hidden_presets, processed_presets, conditional_presets

def evaluate_expression(expression):
    """
    Evaluate an expression (e.g., variables like ${hostSystemName}).
    # Check for ${hostSystemName}, which requires executing `uname`
    """
    if expression == "${hostSystemName}":
        this_platform = platform.system()  # Returns "Windows", "Linux", "Darwin", etc.
        return this_platform

    # Check for environment variable patterns like $env{VAR_NAME}
    elif expression.startswith("$env{") and expression.endswith("}"):
        env_var = expression[5:-1]  # Extract the environment variable name
        return os.getenv(env_var, "")  # Return its value or an empty string if not found

    # Default: return the expression as is
    return expression

def evaluate_condition(condition):
    """
    Evaluate a condition object.
    :param condition: Condition object with 'type', 'lhs', 'rhs', etc.
    :return: True if the condition is met, False otherwise.
    """
    condition_type = condition.get("type")

    # Handle 'equals' condition
    if condition_type == "equals":
        lhs = evaluate_expression(condition["lhs"])
        rhs = evaluate_expression(condition["rhs"])
        return lhs == rhs

    # Handle 'anyOf' condition
    elif condition_type == "anyOf":
        return any(evaluate_condition(cond) for cond in condition["conditions"])

    # Handle 'allOf' condition
    elif condition_type == "allOf":
        return all(evaluate_condition(cond) for cond in condition["conditions"])

    # Unknown condition type
    return False


def filter_presets_by_conditions(presets):
    """Filters presets based on their conditions."""
    filtered_presets = []

    for preset in presets:
        condition = preset.get("condition")
        if condition is None or evaluate_condition(condition):
            filtered_presets.append(preset)

    return filtered_presets


def save_json(file_path, data):
    """Writes the data to a JSON file."""
    with open(file_path, "w", encoding="utf-8") as file:
        json.dump(data, file, indent=2)


def main(in_file, out_file):
    """Process the presets from the input file and save to the output file."""
    data = read_json(in_file)

    # Process configurePresets
    presets = data.get("configurePresets", [])  # Access the correct section

    # Combine steps 1 and 2 into a single step
    hidden_presets, presets, conditional_presets = process_presets(presets)

    # Step 3: Filter presets based on their conditions
    presets = filter_presets_by_conditions(presets)

    # Step 3.5: Rename visible configure presets to readable names that retain
    # the platform prefix, replacing "Platform (Variant)" with "Platform Variant".
    # Examples:
    #   "Linux (Debug Shared)"          -> "Linux Debug Shared"
    #   "WinX (Debug Shared)"           -> "WinX Debug Shared"
    #   "MacOS (Staged Release Shared)" -> "MacOS Staged Release Shared"
    #   "Windows (VS Debug Shared)"     -> "Windows VS Debug Shared"
    # We also keep a name mapping to update buildPresets accordingly.
    import re
    name_map = {}
    # Match "Prefix (Variant)" — capture prefix and variant separately
    concise_pattern = re.compile(r"^(.+?)\s*\(\s*(.+)\s*\)$")
    for preset in presets:
        orig_name = preset.get("name", "")
        m = concise_pattern.match(orig_name)
        if m:
            prefix = m.group(1).strip()
            variant = m.group(2).strip()
            new_name = f"{prefix} {variant}"
            if new_name != orig_name:
                name_map[orig_name] = new_name
                preset["name"] = new_name
                preset["displayName"] = new_name

    # Step 4: Add the hidden presets back to the final list
    final_presets = hidden_presets + presets

    # Step 5: Save the new JSON to the output file
    data["configurePresets"] = final_presets  # Update the presets section

    # Process buildPresets if they exist
    if "buildPresets" in data:
        build_presets = data.get("buildPresets", [])

        # Update build presets' configurePreset names according to the rename map
        for bp in build_presets:
            cfg = bp.get("configurePreset")
            if cfg in name_map:
                bp["configurePreset"] = name_map[cfg]

        # Ensure build preset names align with their configurePreset names.
        concise_pattern = re.compile(r"^(.+?)\s*\(\s*(.+)\s*\)$")
        for bp in build_presets:
            bp_name = bp.get("name", "")
            if bp_name in name_map:
                new_name = name_map[bp_name]
            else:
                m = concise_pattern.match(bp_name)
                if m:
                    new_name = f"{m.group(1).strip()} {m.group(2).strip()}"
                else:
                    new_name = bp.get("configurePreset", bp_name)
            bp["name"] = new_name
            bp["displayName"] = new_name

        # Get the names of the filtered (and possibly renamed) configurePresets (non-hidden)
        valid_configure_preset_names = [preset["name"] for preset in presets]

        # Filter buildPresets to only include those whose configurePreset is in the valid list
        filtered_build_presets = [
            bp for bp in build_presets
            if bp.get("configurePreset") in valid_configure_preset_names
        ]

        data["buildPresets"] = filtered_build_presets

    save_json(out_file, data)


if len(sys.argv) != 3 or sys.argv[1] is None or sys.argv[1] == '' or sys.argv[2] is None or sys.argv[2] == '' :
    print("Usage: Preset-Template Output-Name")
    sys.exit(1)

if len(sys.argv) >= 2 and not sys.argv[1] is None and not sys.argv[1] == '':
    input_file = sys.argv[1]
else:
    input_file = "cmake/templates/CMakePresets.in"

if len(sys.argv) >= 3 and not sys.argv[2] is None and not sys.argv[2] == '':
    output_file = sys.argv[2]
else:
    output_file = "CMakePresets.json"

main(input_file, output_file)