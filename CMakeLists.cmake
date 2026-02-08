include_guard(GLOBAL)

## HoffSoft build framework delegator (split into global + per-project)
include (cmake/array_enhanced.cmake)
#include (cmake/test_enhanced.cmake)

record(CREATE __regPkgCB        "APD_CALLBACKS")
set(__regPkgCB                  "${__regPkgCB}"     CACHE INTERNAL "")

array(CREATE __regLibs         "CALLBACKS"         RECORDS)
set(__regLibs                  "${__regLibs}"     CACHE INTERNAL "")

record(CREATE __regPlug         "PLUGINS"           RECORDS)
set(__regPlug                  "${__regPlug}"       CACHE INTERNAL "")

set(__alreadyLocated           ""                   CACHE INTERNAL "")

function(registerPackageCallback fn)
    record(CONVERT __regPkgCB)
    if(NOT fn IN_LIST __regPkgCB)
        list(APPEND __regPkgCB ${fn})
        record(CONVERT __regPkgCB)
        message("${BOLD}Registered${NC} AddPackage callback for ${YELLOW}${fn}${NC}")
    endif ()
endfunction()

set(LIXNamespace 0)
set(LIXLibName 1)
set(LIXFeatureName 2)
function(registerLibrary namespace libName nameAsFeature)
    array(GET __regLibs EQUAL "${namespace}_${libName}" lib)
    if(NOT lib)
        record(CREATE lib "${namespace}_${libName}")
        record(APPEND lib ${namespace} ${libName} ${nameAsFeature})
        array(APPEND __regLibs RECORD "${lib}")
    else ()
        record(SET lib 0 ${namespace} ${libName} ${nameAsFeature})
        array(SET regLibs ${namespace}_${libName} "${lib}")
    endif ()
    set(__regLibs "${__regLibs}" CACHE INTERNAL "")
endfunction()
function(getLibraryComponentPart namespace libName LIX value)
    array(GET __regLibs EQUAL ${namespace}_${libName} lib)
    if(NOT lib)
        set(${value} PARENT_SCOPE)
        return()
    endif ()
    record(GET lib ${LIX} v)
    set(${value} ${v} PARENT_SCOPE)
endfunction()

function(registerPlugin pi)
    record(CONVERT __regPlug)
    if(NOT fn IN_LIST __regPlug)
        list(APPEND __regPlug ${fn})
        record(CONVERT __regPlug)))
        set(__regPlug "${__regPlug}" CACHE INTERNAL "")
        message("${BOLD}Registered${NC} Plugin for ${YELLOW}${fn}${NC}")
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

# Get rid of this and find dynamically!
set(KNOWN_LIBS HoffSoft Gfx)

foreach(known_lib IN LISTS KNOWN_LIBS)

    if (${known_lib} MATCHES "HoffSoft" AND "CORE" IN_LIST APP_FEATURES OR
            ${known_lib} MATCHES "Gfx" AND "GFX" IN_LIST APP_FEATURES)

        file(GLOB_RECURSE _inc "${CMAKE_SOURCE_DIR}/../${known_lib}/*/${known_lib}.inc")
        if(_inc)
            list(GET _inc 0 _inc)
            get_filename_component(_inc "${_inc}" ABSOLUTE)
            include("${_inc}")
            set(fn "init${known_lib}")
            cmake_language(CALL "${fn}")

            list(APPEND REQD_LIBS "${known_lib}")

        endif ()
    endif ()

endforeach ()

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
