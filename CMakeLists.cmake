## HoffSoft build framework delegator (split into global + per-project)
include (cmake/array.cmake)

message (NOTICE "\n\t\tProcessing ${APP_NAME}\n")

unset (PLUGINS)

if ("${APP_FEATURES}" MATCHES "APPEARANCE")
    record(APPEND PLUGINS Appearance)
endif ()

if ("${APP_FEATURES}" MATCHES "LOGGER")
    record(APPEND PLUGINS Logger)
endif ()

if ("${APP_FEATURES}" MATCHES "PRINT")
    record(APPEND PLUGINS Print)
endif ()

if ("${APP_FEATURES}" MATCHES "CORE")
    record(APPEND REQD_LIBS "HoffSoft")
    record(APPEND FIND_PACKAGE_PATHS "CORE REQUIRED CONFIG PATHS {HoffSoft}" )
endif ()

if ("${APP_FEATURES}" MATCHES "GFX")
    record(APPEND REQD_LIBS "Gfx")
    record(APPEND FIND_PACKAGE_PATHS "GFX REQUIRED CONFIG PATHS {Gfx}" )
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
# TODO: FOR NOW if (NOT MONOREPO OR DEFINED MONOREPO_PROCESSED)
    include(${CMAKE_SOURCE_DIR}/cmake/project_setup.cmake)
# TODO: FOR NOW endif ()
