
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

function(globalObjSet varName value)
    globalObjKey("${varName}" _k)
    set_property(GLOBAL PROPERTY "${_k}" "${value}")
endfunction()

function(globalObjUnset varName)
    globalObjKey("${varName}" _k)
    set_property(GLOBAL PROPERTY "${_k}" "")
endfunction()

function(globalObjAppendUnique varName value)
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
function(globalObjSync varName)
    if(NOT DEFINED ${varName})
        message(FATAL_ERROR "globalObjSync: '${varName}' is not defined in this scope")
    endif()
    globalObjSet("${varName}" "${${varName}}")
endfunction()
