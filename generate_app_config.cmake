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
    SplitAt("${APP_LOCAL_RESOURCES}" "," _lrFolder, _lrUUID)
    set(YAML_LOCAL_RESOURCES_UUID "${_lrUUID}")
    if (APPLE AND APP_TYPE MATCHES "Executable")
        # macOS bundle: resources live inside Contents/Resources
        set(YAML_LOCAL_RESOURCES "${APP_NAME}.app/Contents/Resources")
    else ()
        # Linux / Windows: standard share layout (CMAKE_INSTALL_DATADIR is already relative)
        set(YAML_LOCAL_RESOURCES "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_NAME}")
    endif ()
endif ()

if (APP_GLOBAL_RESOURCES)
    SplitAt("${APP_GLOBAL_RESOURCES}" "," _grFolder, _grUUID)
    set(YAML_GLOBAL_RESOURCES_UUID "${_grUUID}")
    if (APPLE AND APP_TYPE MATCHES "Executable")
        # macOS bundle: resources live inside Contents/Resources
        set(GLOBAL_RESOURCES_DIR "Library/Application Support/${APP_VENDOR}/Resources/${APP_VENDOR}")
    else ()
        # Linux / Windows: standard share layout (CMAKE_INSTALL_DATADIR is already relative)
        set(GLOBAL_RESOURCES_DIR "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_VENDOR}")
    endif ()
endif ()

<<<<<<< HEAD
# XOR-encode a string with the given decimal key, output lowercase 2-digit hex per byte.
# Replicates the hs::ObfuscatedString algorithm so the YAML never contains plaintext.
# Uses a lookup table to avoid 0x hex literals, which CMake math() does not support.
function(obfuscate_string_to_hex input key output_var)
    set(_t "0;1;2;3;4;5;6;7;8;9;a;b;c;d;e;f")
    string(HEX "${input}" _hex)
    string(LENGTH "${_hex}" _hlen)
    math(EXPR _nbytes "${_hlen} / 2")
    set(_result "")
    if(_nbytes GREATER 0)
        math(EXPR _last "${_nbytes} - 1")
        foreach(i RANGE 0 ${_last})
            math(EXPR _pos "${i} * 2")
            string(SUBSTRING "${_hex}" ${_pos} 1 _dhi)
            math(EXPR _pos1 "${_pos} + 1")
            string(SUBSTRING "${_hex}" ${_pos1} 1 _dlo)
            list(FIND _t "${_dhi}" _vhi)
            list(FIND _t "${_dlo}" _vlo)
            math(EXPR _byte  "${_vhi} * 16 + ${_vlo}")
            math(EXPR _xored "${_byte} ^ ${key}")
            math(EXPR _ohi "${_xored} / 16")
            math(EXPR _olo "${_xored} % 16")
            list(GET _t ${_ohi} _hhi)
            list(GET _t ${_olo} _hlo)
            string(APPEND _result "${_hhi}${_hlo}")
        endforeach()
    endif()
    set(${output_var} "${_result}" PARENT_SCOPE)
endfunction()

set(_TRAC_KEY 90)   # 0x5A — matches kXorKey in LicenseManager.cpp
obfuscate_string_to_hex("${APP_TRAC_URL}"    ${_TRAC_KEY} APP_TRAC_URL_OBF)
obfuscate_string_to_hex("${APP_TRAC_USER}"   ${_TRAC_KEY} APP_TRAC_USER_OBF)
obfuscate_string_to_hex("${APP_TRAC_PASSWD}" ${_TRAC_KEY} APP_TRAC_PASSWD_OBF)
obfuscate_string_to_hex("${APP_TRAC_API}"    ${_TRAC_KEY} APP_TRAC_API_OBF)

=======
>>>>>>> f25e86b322e791ed4453d9228caac1ebe833cda4
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

