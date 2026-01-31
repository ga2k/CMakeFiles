## HoffSoft build framework delegator (split into global + per-project)
include (cmake/array.cmake)

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
if (NOT MONOREPO OR DEFINED MONOREPO_PROCESSED)
    include(${CMAKE_SOURCE_DIR}/cmake/project_setup.cmake)
endif ()
