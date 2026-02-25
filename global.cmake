# ==================================================================================================
# GlobalInspector.cmake
#
# Interactive inspector / debugger for the HS_OBJ global object store (global.cmake).
# All globals in this project use the HS_OBJ::<varName> property key convention, which
# means we can track, diff, and dump them precisely without any manual registration.
#
# REQUIRES: global.cmake must be included before this file.
#
# FUNCTIONS:
#   globalInspect([varName...])          — pretty-print one or more named globals
#   globalDumpAll([FILTER <regex>])      — dump every HS_OBJ:: global currently registered
#   globalSnapshot(<label>)             — save the current state of all globals
#   globalDiff(<labelA> <labelB>)       — show what changed between two snapshots
#   globalExportOverrides(<file>)       — write an editable .cmake override file
#   globalApplyOverrides([FILE <path>]) — apply a previously exported override file
#   globalAssert(<varName> <expected>)  — assert a global equals a value (fails loudly)
#
# TRACKING:
#   Every globalObjSet / globalObjAppendUnique call auto-registers the varName.
#   The registry is persisted to ${CMAKE_BINARY_DIR}/_hs_obj_registry.txt so it
#   survives reconfigures and accumulates across the full cmake run.
# ==================================================================================================

include_guard(GLOBAL)

# --- registry file -----------------------------------------------------------
set(_HS_INSPECTOR_REGISTRY_FILE "${CMAKE_BINARY_DIR}/_hs_obj_registry.txt")

if(EXISTS "${_HS_INSPECTOR_REGISTRY_FILE}")
    file(REMOVE "${_HS_INSPECTOR_REGISTRY_FILE}")
    set(_HS_OBJ_REGISTRY "")
else()
    get_filename_component(_dir "${_HS_INSPECTOR_REGISTRY_FILE}" PATH)
    file(MAKE_DIRECTORY "${_dir}")
    set(_HS_OBJ_REGISTRY "")
endif()

# -----------------------------------------------------------------------------
# Internal: register a varName (not the key, the logical name)
# -----------------------------------------------------------------------------
function(_hsobj_register varName)
    set(_HS_OBJ_REGISTRY $CACHE{_HS_OBJ_REGISTRY})
    if(NOT "${varName}" IN_LIST _HS_OBJ_REGISTRY)
        list(APPEND _HS_OBJ_REGISTRY "${varName}")
        set(_HS_OBJ_REGISTRY ${_HS_OBJ_REGISTRY} CACHE INTERNAL "")
        list(SORT   _HS_OBJ_REGISTRY)
        list(JOIN   _HS_OBJ_REGISTRY "\n" _reg_str)
        file(WRITE "${_HS_INSPECTOR_REGISTRY_FILE}" "${_reg_str}\n")
    endif()
endfunction()

# -----------------------------------------------------------------------------
# Overrides for global.cmake functions — identical behaviour, adds registration
# (Include this file AFTER global.cmake to shadow the originals)
# -----------------------------------------------------------------------------
function(globalObjSet varName value)
    _globalObjSet(${varName} "${value}")
    _hsobj_register("${varName}")
endfunction()

function(globalObjUnset varName)
    _globalObjUnset(${varName})
    _hsobj_register("${varName}")   # keep in registry so dumps show it as empty
endfunction()

function(globalObjAppendUnique varName value)
    _globalObjAppendUnique(${varName} "${value}")
    _hsobj_register("${varName}")
endfunction()

function(globalObjSync varName)
    _globalObjSync(${varName})
endfunction()

# -----------------------------------------------------------------------------
# globalInspect(<varName> [varName2 ...])
#
#   Pretty-print one or more globals by their logical name.
# -----------------------------------------------------------------------------
function(globalInspect)
    foreach(_name IN LISTS ARGN)
        globalObjKey("${_name}" _k)
        get_property(_is_set GLOBAL PROPERTY "${_k}" SET)
        get_property(_val    GLOBAL PROPERTY "${_k}")

        message(STATUS "┌─ HS_OBJ  \"${_name}\"  (key: ${_k})")
        if(_is_set)
            if("${_val}" STREQUAL "")
                message(STATUS "│  status : SET (empty / unset via globalObjUnset)")
            else()
                # Format lists nicely
                string(REPLACE ";" "\n│           " _pretty "${_val}")
                message(STATUS "│  status : SET")
                message(STATUS "│  value  : ${_pretty}")
            endif()
        else()
            message(STATUS "│  status : NOT SET  (never written)")
        endif()
        message(STATUS "└────────────────────────────────────────────────")
    endforeach()
endfunction()

# -----------------------------------------------------------------------------
# globalDumpAll([FILTER <regex>])
#
#   Dump every registered HS_OBJ global, sorted alphabetically.
#   FILTER  — optional ERE regex applied to the logical varName
# -----------------------------------------------------------------------------
function(globalDumpAll)
    cmake_parse_arguments(ARG "" "FILTER" "" ${ARGN})

    # Reload registry in case new entries were added by other includes
    if(EXISTS "${_HS_INSPECTOR_REGISTRY_FILE}")
        file(STRINGS "${_HS_INSPECTOR_REGISTRY_FILE}" _names)
    else()
        set(_names "${_HS_OBJ_REGISTRY}")
    endif()
    list(SORT _names)
    list(REMOVE_DUPLICATES _names)

    list(LENGTH _names _total)

    message(STATUS "")
    message(STATUS "╔══════════════════════════════════════════════════════════════════╗")
    if(_total EQUAL 1)
        string(LENGTH   "  HS_OBJ GLOBAL STORE DUMP  (1 registered name)"           __current)
    else ()
        string(LENGTH   "  HS_OBJ GLOBAL STORE DUMP  (${_total} registered names)"           __current)
    endif ()
    string(LENGTH   "══════════════════════════════════════════════════════════════════" __total)
    math(EXPR __sp "${__total} / 3 - ${__current}")
    string(REPEAT " " ${__sp} __o)
    if(_total EQUAL 1)
        message(STATUS "║  HS_OBJ GLOBAL STORE DUMP  (1 registered name)${__o}║")
    else ()
        message(STATUS "║  HS_OBJ GLOBAL STORE DUMP  (${_total} registered names)${__o}║")
    endif ()
    if(ARG_FILTER)
        string(LENGTH  "║  Filter: \"${ARG_FILTER}\""           __current)
        math(EXPR __sp "${__total} / 3 - ${__current}")
        string(REPEAT " " ${__sp} __o)
        message(STATUS "║     Filter: \"${ARG_FILTER}\"${__o}║")
    endif()
    message(STATUS "╚══════════════════════════════════════════════════════════════════╝")
    message(STATUS "")

    set(_shown 0)
    foreach(_name IN LISTS _names)
        if(ARG_FILTER AND NOT "${_name}" MATCHES "${ARG_FILTER}")
            continue()
        endif()

        globalObjKey("${_name}" _k)
        get_property(_is_set GLOBAL PROPERTY "${_k}" SET)
        get_property(_val    GLOBAL PROPERTY "${_k}")

        if(_is_set AND NOT "${_val}" STREQUAL "")
            string(REPLACE ";" "  |  " _inline "${_val}")
            message(STATUS "  [SET]   ${_name}")
            message(STATUS "          = \"${_inline}\"")
        elseif(_is_set)
            message(STATUS "  [EMPT]  ${_name}  (set but empty)")
        else()
            message(STATUS "  [----]  ${_name}  (never written)")
        endif()

        math(EXPR _shown "${_shown} + 1")
    endforeach()

    message(STATUS "")
    message(STATUS "  Shown: ${_shown} / ${_total}")
    message(STATUS "")
endfunction()

# -----------------------------------------------------------------------------
# globalSnapshot(<label>)
#
#   Captures current value of every registered global into a CACHE variable.
#   Use with globalDiff() to spot what a block of code changed.
# -----------------------------------------------------------------------------
function(globalSnapshot label)
    if(EXISTS "${_HS_INSPECTOR_REGISTRY_FILE}")
        file(STRINGS "${_HS_INSPECTOR_REGISTRY_FILE}" _names)
    else()
        set(_names "${_HS_OBJ_REGISTRY}")
    endif()
    list(REMOVE_DUPLICATES _names)

    set(_snap "")
    foreach(_name IN LISTS _names)
        globalObjKey("${_name}" _k)
        get_property(_is_set GLOBAL PROPERTY "${_k}" SET)
        get_property(_val    GLOBAL PROPERTY "${_k}")
        if(_is_set)
            # Store as "name\x1fvalue" using a safe delimiter unlikely in values
            list(APPEND _snap "${_name}>>>HS_SEP<<<${_val}")
        endif()
    endforeach()

    set("_HS_SNAP_${label}" "${_snap}" CACHE INTERNAL "HS_OBJ snapshot: ${label}" FORCE)
    list(LENGTH _snap _cnt)
    message(STATUS "[GlobalInspector] Snapshot \"${label}\" saved  (${_cnt} set globals)")
endfunction()

# -----------------------------------------------------------------------------
# globalDiff(<labelA> <labelB>)
#
#   Compare two snapshots produced by globalSnapshot() and report changes.
# -----------------------------------------------------------------------------
function(globalDiff labelA labelB)
    set(_snapA "${_HS_SNAP_${labelA}}")
    set(_snapB "${_HS_SNAP_${labelB}}")

    # Build lookup: name -> value for A
    set(_mapA_keys "")
    foreach(_entry IN LISTS _snapA)
        string(REPLACE ">>>HS_SEP<<<" ";" _parts "${_entry}")
        list(GET _parts 0 _n)
        list(GET _parts 1 _v)
        set("_A_${_n}" "${_v}")
        list(APPEND _mapA_keys "${_n}")
    endforeach()

    set(_mapB_keys "")
    foreach(_entry IN LISTS _snapB)
        string(REPLACE ">>>HS_SEP<<<" ";" _parts "${_entry}")
        list(GET _parts 0 _n)
        list(GET _parts 1 _v)
        set("_B_${_n}" "${_v}")
        list(APPEND _mapB_keys "${_n}")
    endforeach()

    # Union of keys
    set(_all_keys ${_mapA_keys} ${_mapB_keys})
    list(REMOVE_DUPLICATES _all_keys)
    list(SORT _all_keys)

    message(STATUS "")
    message(STATUS "╔══════════════════════════════════════════════════════════════════╗")
    message(STATUS "║  HS_OBJ DIFF  \"${labelA}\"  →  \"${labelB}\"")
    message(STATUS "╚══════════════════════════════════════════════════════════════════╝")
    message(STATUS "")

    set(_changed 0)
    set(_added   0)
    set(_removed 0)

    foreach(_name IN LISTS _all_keys)
        set(_in_a FALSE)
        set(_in_b FALSE)
        if("${_name}" IN_LIST _mapA_keys)
            set(_in_a TRUE)
        endif()
        if("${_name}" IN_LIST _mapB_keys)
            set(_in_b TRUE)
        endif()

        if(_in_a AND _in_b)
            if(NOT "${_A_${_name}}" STREQUAL "${_B_${_name}}")
                message(STATUS "  [CHANGED]  ${_name}")
                message(STATUS "             was: \"${_A_${_name}}\"")
                message(STATUS "             now: \"${_B_${_name}}\"")
                math(EXPR _changed "${_changed} + 1")
            endif()
        elseif(_in_b)
            message(STATUS "  [ADDED]    ${_name} = \"${_B_${_name}}\"")
            math(EXPR _added "${_added} + 1")
        else()
            message(STATUS "  [REMOVED]  ${_name}  (was: \"${_A_${_name}}\")")
            math(EXPR _removed "${_removed} + 1")
        endif()
    endforeach()

    if(_changed EQUAL 0 AND _added EQUAL 0 AND _removed EQUAL 0)
        message(STATUS "  (no changes between \"${labelA}\" and \"${labelB}\")")
    else()
        message(STATUS "")
        message(STATUS "  Added: ${_added}  |  Changed: ${_changed}  |  Removed: ${_removed}")
    endif()
    message(STATUS "")
endfunction()

# -----------------------------------------------------------------------------
# globalExportOverrides(<output_file>)
#
#   Write an editable cmake file. Uncomment and edit values, then call
#   globalApplyOverrides() on the next configure pass (or immediately).
# -----------------------------------------------------------------------------
function(globalExportOverrides output_file)
    if(EXISTS "${_HS_INSPECTOR_REGISTRY_FILE}")
        file(STRINGS "${_HS_INSPECTOR_REGISTRY_FILE}" _names)
    else()
        set(_names "${_HS_OBJ_REGISTRY}")
    endif()
    list(SORT _names)
    list(REMOVE_DUPLICATES _names)

    set(_content
            "# ==============================================================================
# HS_OBJ Global Store — Override File
# Generated by GlobalInspector.cmake at configure time.
#
# HOW TO USE:
#   1. Uncomment and edit any globalObjSet() lines below.
#   2. In your CMakeLists.txt, after including GlobalInspector.cmake, call:
#        globalApplyOverrides()          # reads this file by default
#      OR pass a custom path:
#        globalApplyOverrides(FILE \"/path/to/this_file.cmake\")
#   3. Re-run cmake.  Your edits will override the values set elsewhere.
# ==============================================================================

include_guard(GLOBAL)

")

    foreach(_name IN LISTS _names)
        globalObjKey("${_name}" _k)
        get_property(_is_set GLOBAL PROPERTY "${_k}" SET)
        get_property(_val    GLOBAL PROPERTY "${_k}")

        if(_is_set AND NOT "${_val}" STREQUAL "")
            string(REPLACE ";" "  |  " _inline "${_val}")
            string(APPEND _content "# current: \"${_inline}\"\n")
            string(APPEND _content "globalObjSet(${_name}  \"${_val}\")\n\n")
        elseif(_is_set)
            string(APPEND _content "# ${_name}  — set but empty\n")
            string(APPEND _content "# globalObjSet(${_name}  \"your_value\")\n\n")
        else()
            string(APPEND _content "# ${_name}  — never written\n")
            string(APPEND _content "# globalObjSet(${_name}  \"your_value\")\n\n")
        endif()
    endforeach()

    file(WRITE "${output_file}" "${_content}")
    message(STATUS "[GlobalInspector] Override file written → ${output_file}")
endfunction()

# -----------------------------------------------------------------------------
# globalApplyOverrides([FILE <path>])
#
#   Include the override file.  Default path:
#   ${CMAKE_BINARY_DIR}/hs_obj_overrides.cmake
# -----------------------------------------------------------------------------
function(globalApplyOverrides)
    cmake_parse_arguments(ARG "" "FILE" "" ${ARGN})
    if(NOT ARG_FILE)
        set(ARG_FILE "${CMAKE_BINARY_DIR}/hs_obj_overrides.cmake")
    endif()

    if(NOT EXISTS "${ARG_FILE}")
        message(WARNING "[GlobalInspector] Override file not found: ${ARG_FILE}")
        message(WARNING "  Run globalExportOverrides(\"${ARG_FILE}\") first.")
        return()
    endif()

    message(STATUS "[GlobalInspector] Applying overrides from: ${ARG_FILE}")
    include("${ARG_FILE}")
    message(STATUS "[GlobalInspector] Done.")
endfunction()

# -----------------------------------------------------------------------------
# globalAssert(<varName> <expected>)
#
#   Hard-fail the configure if a global doesn't equal the expected value.
#   Great for sanity-checking state at key points in your CMake logic.
# -----------------------------------------------------------------------------
function(globalAssert varName expected)
    globalObjGet("${varName}" _actual)
    if(NOT "${_actual}" STREQUAL "${expected}")
        message(FATAL_ERROR
                "[GlobalInspector] ASSERTION FAILED\n"
                "  Variable : ${varName}\n"
                "  Expected : \"${expected}\"\n"
                "  Actual   : \"${_actual}\"\n"
        )
    else()
        message(STATUS "[GlobalInspector] ✓ assert  ${varName} == \"${expected}\"")
    endif()
endfunction()
















# ==================================================================================================
# Global object store
#   - One object (string) per handle (variable name)
#   - Backed by GLOBAL properties, not cache, so no scoping headaches
# ==================================================================================================
function(globalObjKey varName outKey)
    if(NOT varName OR "${varName}" STREQUAL "")
        message(FATAL_ERROR "globalObjKey: varName is required")
    endif()
    if ("${varName}" MATCHES "^HS_OBJ::.*")
        set(${outKey} "${varName}" PARENT_SCOPE)
    else ()
        set(${outKey} "HS_OBJ::${varName}" PARENT_SCOPE)
    endif ()
endfunction()

function(globalObjIsSet varName outBool)
    globalObjKey("${varName}" _k)
    get_property(_isSet GLOBAL PROPERTY "${_k}" SET)
    if(_isSet)
        set(${outBool} ON PARENT_SCOPE)
    else()
        set(${outBool} OFF PARENT_SCOPE)
    endif()
endfunction()

function(globalObjGet varName outVar)
    globalObjKey("${varName}" _k)
    get_property(_v GLOBAL PROPERTY "${_k}")
    if(NOT _v)
        set(_v "")
    endif()
    set(${outVar} "${_v}" PARENT_SCOPE)
endfunction()

function(_globalObjSet varName value)
    globalObjKey("${varName}" _k)
    set_property(GLOBAL PROPERTY "${_k}" "${value}")
endfunction()

function(_globalObjUnset varName)
    globalObjKey("${varName}" _k)
    set_property(GLOBAL PROPERTY "${_k}" "")
endfunction()

function(_globalObjAppendUnique varName value)
    globalObjKey("${varName}" _k)
    get_property(_list GLOBAL PROPERTY "${_k}")
    if(NOT _list)
        set(_list "")
    endif()

    if(NOT value IN_LIST _list)
        set_property(GLOBAL APPEND PROPERTY "${_k}" "${value}")
    endif()
endfunction()

# Load global object into the *current scope variable* named varName, if present.
function(globalObjLoadIfSet varName)
    globalObjIsSet("${varName}" _isSet)
    if(_isSet)
        globalObjGet("${varName}" _v)
        set(${varName} "${_v}" PARENT_SCOPE)
    endif()
endfunction()

# Sync current scope variable into global backing store.
function(_globalObjSync varName)
    if(NOT DEFINED ${varName})
        message(FATAL_ERROR "_globalObjSync: '${varName}' is not defined in this scope")
    endif()
    _globalObjSet("${varName}" "${${varName}}")
endfunction()
