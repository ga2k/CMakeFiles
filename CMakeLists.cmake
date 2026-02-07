include_guard(GLOBAL)

## HoffSoft build framework delegator (split into global + per-project)
include (cmake/array_enhanced.cmake)
#include (cmake/test_enhanced.cmake)

set(__registeredPackageCallbacks "" CACHE INTERNAL "")
set(__alreadyLocated             "" CACHE INTERNAL "")

function(registerPackageCallback fn)
    if(NOT fn IN_LIST __registeredPackageCallbacks)
        list(APPEND __registeredPackageCallbacks ${fn})
        set(__registeredPackageCallbacks "${__registeredPackageCallbacks}" CACHE INTERNAL "")
        message("${BOLD}Registered${NC} AddPackage callback for ${YELLOW}${fn}${NC}")
    endif ()
endfunction()

macro(savePackageData)
    set(GLOBAL   "${GLOBAL}"   PARENT_SCOPE)
    set(SYSTEM   "${SYSTEM}"   PARENT_SCOPE)
    set(LIBRARY  "${LIBRARY}"  PARENT_SCOPE)
    set(OPTIONAL "${OPTIONAL}" PARENT_SCOPE)
    set(PLUGIN   "${PLUGIN}"   PARENT_SCOPE)
    set(CUSTOM   "${CUSTOM}"   PARENT_SCOPE)
endmacro()

message (NOTICE "\n\t\tProcessing ${APP_NAME}\n")

if ("${APP_FEATURES}" MATCHES "APPEARANCE")
    list(APPEND PLUGINS Appearance)
endif ()

if ("${APP_FEATURES}" MATCHES "LOGGER")
    list(APPEND PLUGINS Logger)
endif ()

if ("${APP_FEATURES}" MATCHES "PRINT")
    list(APPEND PLUGINS Print)
endif ()

if ("${APP_FEATURES}" MATCHES "CORE")
    list(APPEND REQD_LIBS "HoffSoft")
endif ()

if ("${APP_FEATURES}" MATCHES "GFX")
    list(APPEND REQD_LIBS "Gfx")
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
