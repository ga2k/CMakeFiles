# cmake/generate_app_config.cmake

# All variables are passed in via -D flags
# Expected variables:
# - APP_YAML_TEMPLATE_PATH
# - APP_YAML_PATH
# - PLUGIN_PATH
# - PLUGIN_PATH_TYPE
# - PLUGIN_LIST (semicolon-separated)
# - APP_NAME, APP_VENDOR, etc. (all template variables)

# Convert the plugin list to YAML format
set(PLUGIN_YAML_LIST "")
if (PLUGIN_LIST)
    # Convert semicolon-separated list to individual items
    string(REPLACE "&" "\n" PLUGIN_ITEMS "${PLUGIN_LIST}")
    string(REPLACE "\n" "\n  - " PLUGIN_YAML_LIST "${PLUGIN_ITEMS}")
    set(PLUGIN_YAML_LIST "  - ${PLUGIN_YAML_LIST}\n")
else ()
    set(PLUGIN_YAML_LIST "  # No plugins configured\n")
endif ()

# Create the staging directory
file(MAKE_DIRECTORY "${PLUGIN_PATH}")

# Generate the app.yaml file
configure_file(
        "${APP_YAML_TEMPLATE_PATH}"
        "${APP_YAML_PATH}"
        @ONLY
)

message(STATUS "Generated app configuration: ${APP_YAML_PATH}")
message(STATUS "Plugin path: ${PLUGIN_PATH} (${PLUGIN_PATH_TYPE})")
