## HoffSoft build framework delegator (split into global + per-project)

message (NOTICE "\n\t\tProcessing ${APP_NAME}\n")

unset (PLUGINS)

if ("${APP_FEATURES}" MATCHES "APPEARANCE")
    list(REMOVE_ITEM APP_FEATURES APPEARANCE)
    list(APPEND PLUGINS Appearance)
endif ()

if ("${APP_FEATURES}" MATCHES "LOGGER")
    list(REMOVE_ITEM APP_FEATURES LOGGER)
    list(APPEND PLUGINS Logger)
endif ()

if ("${APP_FEATURES}" MATCHES "PRINT")
    list(REMOVE_ITEM APP_FEATURES PRINT)
    list(APPEND PLUGINS Print)
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
if (NOT MONOREPO OR DEFINED MONOREPO_PROCESSED)
    include(${CMAKE_SOURCE_DIR}/cmake/project_setup.cmake)
endif ()
