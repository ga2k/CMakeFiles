# cmake/generate_app_config.cmake

# PLUGIN_PATH is stored in the embedded YAML as a path relative to
# CMAKE_INSTALL_PREFIX.  At runtime Util.cpp resolves it from the
# inferred install prefix (exe dir parent, or bundle parent on macOS).
if (APP_CONSUMES_PLUGINS OR APP_CREATES_PLUGINS)
    if (${APP_VENDOR}_PLUGIN_DIR)
        # ${APP_VENDOR}_PLUGIN_DIR is an absolute staging path.
        # Both it and CMAKE_INSTALL_PREFIX share the staging root, so
        # file(RELATIVE_PATH) produces the correct prefix-relative fragment.
        file(RELATIVE_PATH PLUGIN_PATH
            "${CMAKE_INSTALL_PREFIX}"
            "${${APP_VENDOR}_PLUGIN_DIR}")
    elseif (WIN32)
        # Windows plugins are DLLs: RUNTIME DESTINATION → bin/
        set(PLUGIN_PATH "${CMAKE_INSTALL_BINDIR}")
    elseif (APPLE AND APP_TYPE MATCHES "Executable")
        # macOS bundle: plugins live in Contents/PlugIns inside the bundle
        set(PLUGIN_PATH "${APP_NAME}.app/Contents/PlugIns")
    else ()
        # Linux / macOS non-bundle: LIBRARY DESTINATION → lib[64]/
        set(PLUGIN_PATH "${CMAKE_INSTALL_LIBDIR}")
    endif ()
endif ()

set(PLUGIN_YAML_LIST "")
if (APP_CONSUMES_PLUGINS)
    list(REMOVE_DUPLICATES APP_CONSUMES_PLUGINS)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" PLUGIN_ITEMS "${APP_CONSUMES_PLUGINS}")
    string(REPLACE "\n" "\n    - " PLUGIN_YAML_LIST "${PLUGIN_ITEMS}")
    # Start list on a new line so YAML is valid under the key, with 4-space indent under the key
    set(PLUGIN_YAML_LIST "\n    - ${PLUGIN_YAML_LIST}\n")
else ()
    # Emit an explicit empty list to remain valid YAML on a single line
    set(PLUGIN_YAML_LIST "[]")
endif ()

set(FEATURES_YAML_LIST "")
if (APP_FEATURES)
    list(REMOVE_DUPLICATES APP_FEATURES)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" FEATURES_ITEMS "${APP_FEATURES}")
    string(REPLACE "\n" "\n    - " FEATURES_YAML_LIST "${FEATURES_ITEMS}")
    set(FEATURES_YAML_LIST "\n    - ${FEATURES_YAML_LIST}\n")
else ()
    set(FEATURES_YAML_LIST "[]")
endif ()

set(CREATES_PLUGINS_YAML_LIST "")
if (APP_CREATES_PLUGINS)
    list(REMOVE_DUPLICATES APP_CREATES_PLUGINS)
    # Convert semicolon-separated list to individual items
    string(REPLACE ";" "\n" CREATES_PLUGINS_ITEMS "${APP_CREATES_PLUGINS}")
    string(REPLACE "\n" "\n    - " CREATES_PLUGINS_YAML_LIST "${CREATES_PLUGINS_ITEMS}")
    set(CREATES_PLUGINS_YAML_LIST "\n    - ${CREATES_PLUGINS_YAML_LIST}\n")
else ()
    set(CREATES_PLUGINS_YAML_LIST "[]")
endif ()

if (APP_LOCAL_RESOURCES)
    if (APPLE AND APP_TYPE MATCHES "Executable")
        # macOS bundle: resources live inside Contents/Resources
        set(YAML_LOCAL_RESOURCES "${APP_NAME}.app/Contents/Resources")
    else ()
        # Linux / Windows: standard share layout (CMAKE_INSTALL_DATADIR is already relative)
        set(YAML_LOCAL_RESOURCES "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_NAME}")
    endif ()
endif ()

if (APP_GLOBAL_RESOURCES)
    if (APPLE AND APP_TYPE MATCHES "Executable")
        # macOS bundle: resources live inside Contents/Resources
        set(GLOBAL_RESOURCES_DIR "Library/Application Support/${APP_VENDOR}/Resources/${APP_VENDOR}")
    else ()
        # Linux / Windows: standard share layout (CMAKE_INSTALL_DATADIR is already relative)
        set(GLOBAL_RESOURCES_DIR "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_VENDOR}")
    endif ()
endif ()

# Generate the app.yaml body first (without checksum)
message(STATUS "APP_YAML_TEMPLATE_PATH = ${APP_YAML_TEMPLATE_PATH}")
message(STATUS "is file = $<BOOL:$<IS_FILE:${APP_YAML_TEMPLATE_PATH}>>")
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

