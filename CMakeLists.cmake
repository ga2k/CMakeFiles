## HoffSoft build framework delegator (split into global + per-project)

message (NOTICE "\n\t\tProcessing ${APP_NAME}\n")

if ("${APP_NAME}" STREQUAL "Core")
    set(_TARGET ${APP_VENDOR})
else ()
    set(_TARGET ${APP_NAME})
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/project_setup.cmake)
return()
#
#include_guard(GLOBAL)