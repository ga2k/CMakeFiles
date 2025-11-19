## HoffSoft build framework delegator (split into global + per-project)
## Do not guard globally; we want this to run for each subproject.
include(${CMAKE_SOURCE_DIR}/cmake/framework.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/project_setup.cmake)
return()
#
#include_guard(GLOBAL)