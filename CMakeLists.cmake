## HoffSoft build framework delegator (split into global + per-project)

message (NOTICE "\n\t\tProcessing ${APP_NAME}\n")

include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/project_setup.cmake)

return()
