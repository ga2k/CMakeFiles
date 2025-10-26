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

def process_presets(presets):
    """
    Process presets to separate hidden, conditional, and inherited conditions.
    """
    hidden_presets = []
    conditional_presets = {}
    processed_presets = []

    for preset in presets:
        if preset.get("hidden"):
            hidden_presets.append(preset)
            if "condition" in preset:
                conditional_presets[preset["name"]] = preset["condition"]
        else:
            inherited_conditions = [
                conditional_presets[inherited]
                for inherited in preset.get("inherits", [])
                if inherited in conditional_presets
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

        # platform = return platform.system()  # Returns "Windows", "Linux", "Darwin", etc.
        # try:
        #     # Use uname to get the OS name (valid for Unix/Linux/BSD/macOS)
        #     result = subprocess.run(["uname"], capture_output=True, text=True, check=True)
        #     return result.stdout.strip()
        # except (subprocess.CalledProcessError, FileNotFoundError):
        #     # uname is not available on Windows, so default to 'Windows'
        #     return 'Windows'

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
    presets = data.get("configurePresets", [])  # Access the correct section

    # Combine steps 1 and 2 into a single step
    hidden_presets, presets, conditional_presets = process_presets(presets)

    # Step 3: Filter presets based on their conditions
    presets = filter_presets_by_conditions(presets)

    # Step 4: Add the hidden presets back to the final list
    final_presets = hidden_presets + presets

    # Step 5: Save the new JSON to the output file
    data["configurePresets"] = final_presets  # Update the presets section
    save_json(out_file, data)


if (len(sys.argv) >= 2 and not sys.argv[1] is None and not sys.argv[1] == ''):
    input_file = sys.argv[1]
else:
    input_file = 'CMakePresets.in'

if (len(sys.argv) >= 3 and not sys.argv[2] is None and not sys.argv[2] == ''):
    output_file = sys.argv[2]
else:
    output_file = 'CMakePresets.json'

main(input_file, output_file)

