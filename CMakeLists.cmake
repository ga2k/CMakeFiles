include_guard(GLOBAL)

## Core build framework delegator (split into global + per-project)
include (${cmake_root}/global.cmake)

function(registerPackageCallback fn)
    if(NOT COMMAND "${fn}")
        message(FATAL_ERROR "registerPackageCallback(): '${fn}' is not a command")
    endif()
    msg("package Callback registration for \"${fn}\" ${GREEN}successful${NC}\n")

    globalObjAppendUnique("HS_REG_PKG_CALLBACKS" "${fn}")
endfunction()

function(runPackageCallbacks)
    globalObjGet("HS_REG_PKG_CALLBACKS" _cbs)
    foreach(cb IN LISTS _cbs)
        cmake_language(CALL "${cb}" "${ARGV}") # pass-through args if you want
    endforeach()
endfunction()

function(registerLibrary libID namespace libName path)
    string(TOUPPER ${libID} LIBID)
    globalObjAppendUnique("HS_REG_LIB_${LIBID}_NAMESPACE" "${namespace}")
    globalObjAppendUnique("HS_REG_LIB_${LIBID}_NAME"      "${libName}")
    globalObjAppendUnique("HS_REG_LIB_${LIBID}_PATH"      "${path}")
    if(NOT EXISTS "${path}")
        msg(ALWAYS FATAL_ERROR "library registration path \"${RED}${BOLD}${path}${NC}\" does not exist")
    else ()
        msg("Library registration path \"${path}\" ${GREEN}successful${NC}\n")
    endif ()
    include("${path}")
endfunction()

function(getLibraryInfo libID obj)
    string(TOUPPER ${libID} LIBID)
    globalObjGet("HS_REG_LIB_${LIBID}" local_object)
    set(${obj} ${local_object} PARENT_SCOPE)
endfunction()

function(registerPlugin pi)
    string(TOUPPER ${libID} LIBID)
    globalObjAppendUnique("HS_REG_PI_${LIBID}" "${pi}")
endfunction()
#
#function(savePackageData)
#    set(DATA   "${DATA}"   PARENT_SCOPE)
#    set(SYSTEM   "${SYSTEM}"   PARENT_SCOPE)
#    set(LIBRARY  "${LIBRARY}"  PARENT_SCOPE)
#    set(OPTIONAL "${OPTIONAL}" PARENT_SCOPE)
#    set(PLUGIN   "${PLUGIN}"   PARENT_SCOPE)
#    set(CUSTOM   "${CUSTOM}"   PARENT_SCOPE)
#endfunction()

message (NOTICE "\t\tProcessing ${APP_NAME}\n")

include(${cmake_root}/framework.cmake)
