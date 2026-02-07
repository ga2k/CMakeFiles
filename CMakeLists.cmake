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

# Get rid of this and find dynamically!
set(KNOWN_LIBS HoffSoft Gfx)

foreach(known_lib IN LISTS KNOWN_LIBS)

    if (${known_lib} MATCHES "HoffSoft" AND "CORE" MATCHES ${APP_FEATURES} OR
            ${known_lib} MATCHES "Gfx" AND "GFX" MATCHES ${APP_FEATURES})

        file(GLOB_RECURSE _inc "${CMAKE_SOURCE_DIR}/${known_lib}.inc")
        include("${_inc}")
        set(fn "init${known_lib}")
        cmake_language(CALL "${fn}")

        list(APPEND REQD_LIBS "${known_lib}")
    endif ()

endforeach ()

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
