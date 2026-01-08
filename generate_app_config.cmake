# cmake/generate_app_config.cmake

if (HoffSoft_PLUGIN_DIR)
    set(PLUGIN_PATH "${HoffSoft_PLUGIN_DIR}")
endif ()

set(PLUGIN_YAML_LIST "")
if (PLUGINS)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" PLUGIN_ITEMS "${PLUGINS}")
    string(REPLACE "\n" "\n    - " PLUGIN_YAML_LIST "${PLUGIN_ITEMS}")
    # Start list on a new line so YAML is valid under the key, with 4-space indent under the key
    set(PLUGIN_YAML_LIST "\n    - ${PLUGIN_YAML_LIST}\n")
else ()
    # Emit an explicit empty list to remain valid YAML on a single line
    set(PLUGIN_YAML_LIST "[]")
endif ()

set(FEATURES_YAML_LIST "")
if (APP_FEATURES)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" FEATURES_ITEMS "${APP_FEATURES}")
    string(REPLACE "\n" "\n    - " FEATURES_YAML_LIST "${FEATURES_ITEMS}")
    set(FEATURES_YAML_LIST "\n    - ${FEATURES_YAML_LIST}\n")
else ()
    set(FEATURES_YAML_LIST "[]")
endif ()

set(HOFFSOFT_LIBS_YAML_LIST "")
if (REQD_LIBS)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" HOFFSOFT_LIBS_ITEMS "${REQD_LIBS}")
    string(REPLACE "\n" "\n    - " HOFFSOFT_LIBS_YAML_LIST "${HOFFSOFT_LIBS_ITEMS}")
    set(HOFFSOFT_LIBS_YAML_LIST "\n    - ${HOFFSOFT_LIBS_YAML_LIST}\n")
else ()
    set(HOFFSOFT_LIBS_YAML_LIST "[]")
endif ()

set(CREATES_PLUGINS_YAML_LIST "")
if (APP_CREATES_PLUGINS)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" CREATES_PLUGINS_ITEMS "${APP_CREATES_PLUGINS}")
    string(REPLACE "\n" "\n    - " CREATES_PLUGINS_YAML_LIST "${CREATES_PLUGINS_ITEMS}")
    set(CREATES_PLUGINS_YAML_LIST "\n    - ${CREATES_PLUGINS_YAML_LIST}\n")
else ()
    set(CREATES_PLUGINS_YAML_LIST "[]")
endif ()

# Generate the app.yaml body first (without checksum)
set(_APP_YAML_BODY_PATH "${APP_YAML_PATH}.body")
configure_file(
        "${APP_YAML_TEMPLATE_PATH}"
        "${_APP_YAML_BODY_PATH}"
        @ONLY
)

# Compute SHA-256 checksum of the body
file(SHA256 "${_APP_YAML_BODY_PATH}" APP_YAML_BODY_SHA256)

# Write final app.yaml: first line is the checksum, then the original body
file(WRITE "${APP_YAML_PATH}" "checksum_sha256: ${APP_YAML_BODY_SHA256}\n")
file(READ "${_APP_YAML_BODY_PATH}" _APP_YAML_BODY_CONTENT)
file(APPEND "${APP_YAML_PATH}" "${_APP_YAML_BODY_CONTENT}")

# Clean up temporary body file
file(REMOVE "${_APP_YAML_BODY_PATH}")

message(STATUS "Generated app configuration with checksum: ${APP_YAML_PATH}")
if (PLUGIN_PATH)
    message(STATUS "Plugin path: ${PLUGIN_PATH}")
endif ()