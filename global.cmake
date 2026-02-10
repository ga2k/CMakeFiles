# Add an item to a GLOBAL property list (unique)
function(globalAppendUnique prop value)
    get_property(_list GLOBAL PROPERTY "${prop}")
    if(NOT _list)
        set(_list "")
    endif()

    if(NOT value IN_LIST _list)
        set_property(GLOBAL APPEND PROPERTY "${prop}" "${value}")
    endif()
endfunction()

# Add or update an item to a GLOBAL property list (unique)
function(globalSet prop value)
    get_property(_list GLOBAL PROPERTY "${prop}")
    if(NOT _list)
        set(_list "")
    endif()

    if(NOT value IN_LIST _list)
        set_property(GLOBAL APPEND PROPERTY "${prop}" "${value}")
    else ()
        set_property(GLOBAL PROPERTY "${prop}" "${value}")
    endif()
endfunction()

# Read a GLOBAL property list
function(globalGet prop outVar)
    get_property(_list GLOBAL PROPERTY "${prop}")
    if(NOT _list)
        set(_list "")
    endif()
    set(${outVar} "${_list}" PARENT_SCOPE)
endfunction()

# ... existing code ...

# ==================================================================================================
# Global object store
#   - One object (string) per handle (variable name)
#   - Backed by GLOBAL properties, not cache, so no scoping headaches
# ==================================================================================================
function(globalObjKey varName outKey)
    if(NOT varName OR "${varName}" STREQUAL "")
        message(FATAL_ERROR "globalObjKey: varName is required")
    endif()
    set(${outKey} "HS_OBJ::${varName}" PARENT_SCOPE)
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

# ----------------------------------------------------------------------------------
# Optional alias detection: warn if identical object values are stored under
# multiple handles. This catches "copied handle state" mistakes early.
# ----------------------------------------------------------------------------------
set(HS_GLOBAL_ALIAS_DETECT OFF)

function(_hs__alias_index_add handle value)
    if(NOT HS_GLOBAL_ALIAS_DETECT)
        return()
    endif()

    if("${value}" STREQUAL "")
        return()
    endif()

    string(SHA256 _h "${value}")
    set(_idxProp "HS_OBJ_HASHIDX::${_h}")

    get_property(_handles GLOBAL PROPERTY "${_idxProp}")
    if(NOT _handles)
        set(_handles "")
    endif()

    if(NOT handle IN_LIST _handles)
        list(APPEND _handles "${handle}")
        set_property(GLOBAL PROPERTY "${_idxProp}" "${_handles}")

        list(LENGTH _handles _n)
        if(_n GREATER 1)
            message(WARNING
                    "HoffSoft global store: potential aliasing: handle '${handle}' now shares the same object blob as: ${_handles}"
            )
        endif()
    endif()
endfunction()

function(globalObjSet varName value)
    globalObjKey("${varName}" _k)
    set_property(GLOBAL PROPERTY "${_k}" "${value}")
    _hs__alias_index_add("${varName}" "${value}")
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
function(globalObjSync varName)
    if(NOT DEFINED ${varName})
        message(FATAL_ERROR "globalObjSync: '${varName}' is not defined in this scope")
    endif()
    globalObjSet("${varName}" "${${varName}}")
endfunction()
