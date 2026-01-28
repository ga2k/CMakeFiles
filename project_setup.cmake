include(GNUInstallDirs)


# Per-project setup. This file MUST NOT use include_guard(GLOBAL).
# It is intended to be included once for each subproject (Core, Gfx, MyCare).

# Derive common strings for this project scope
string(TOUPPER ${APP_NAME} APP_NAME_UC)
string(TOLOWER ${APP_NAME} APP_NAME_LC)
string(TOUPPER ${APP_VENDOR} APP_VENDOR_UC)
string(TOLOWER ${APP_VENDOR} APP_VENDOR_LC)

# Propagate option-derived flags
if (APP_SHOW_SIZER_INFO_IN_SOURCE)
    set(SHOW_SIZER_INFO_FLAG "--sizer-info")
else ()
    set(SHOW_SIZER_INFO_FLAG "")
endif ()
#
## Project-root (this subproject)
#set(PROJECT_ROOT "${PROJECT_SOURCE_DIR}")
#
## Ensure environment/output dirs are prepared for this specific project
#include(${CMAKE_SOURCE_DIR}/cmake/check_environment.cmake)
#check_environment("${CMAKE_SOURCE_DIR}")

# Feature-scoped extras for this project
if (WIDGETS IN_LIST APP_FEATURES)
    set(extra_wxCompilerOptions)
    set(extra_wxDefines)
    set(extra_wxFrameworks)
    set(extra_wxIncludePaths)
    set(extra_wxLibraries)
    set(extra_wxLibraryPaths)
endif ()

# Base header dirs and include per-project BaseDirs.cmake
list(APPEND HEADER_BASE_DIRS "${OUTPUT_DIR}/include")
if (NOT MONOREPO)
    include("${CMAKE_CURRENT_SOURCE_DIR}/BaseDirs.cmake")
endif ()

# Reset HS_* lists for this project to avoid cross-project leakage
set(HS_CompileOptionsList "")
set(HS_DefinesList "")
set(HS_DependenciesList "")
set(HS_IncludePathsList "")
set(HS_LibrariesList "")
set(HS_LibraryPathsList "")
set(HS_LinkOptionsList "")
set(HS_PrefixPathsList "")

# Platform/environment-driven defines
if (THEY_ARE_INSTALLED)
    list(APPEND extra_Definitions INSTALLED)
endif ()

# Define set: magic_enum override and general include paths
list(APPEND extra_Definitions ${GUI} MAGIC_ENUM_NO_MODULE)
#string(REGEX REPLACE ";" "&" PI "${PLUGINS}")
#list(REMOVE_ITEM extra_Definitions "PLUGINS")
#if (NOT "${PI}" STREQUAL "")
#    list(APPEND extra_Definitions "PLUGINS=${PI}")
#endif ()

list(APPEND extra_IncludePaths
        ${HEADER_BASE_DIRS}
        ${CMAKE_INSTALL_PREFIX}/include
        ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}
)

# Consolidate into HS_* used by addLibrary()
list(PREPEND HS_CompileOptionsList ${extra_CompileOptions})
list(PREPEND HS_DefinesList ${debugFlags} ${extra_Definitions})
list(PREPEND HS_IncludePathsList ${extra_IncludePaths})
list(PREPEND HS_LibrariesList ${extra_LibrariesList})
list(PREPEND HS_LibraryPathsList ${extra_LibraryPaths})
list(PREPEND HS_LinkOptionsList ${extra_LinkOptions})

fetchContents(
        PREFIX HS
        FEATURES ${APP_FEATURES}
)

if(STAGE_OUTPUT)
    set(CMAKE_INSTALL_PREFIX "${STAGED_FOLDER}" CACHE PATH "CMake Install Prefix" FORCE)
else ()
    set(CMAKE_INSTALL_PREFIX "${SYSTEM_PATH}" CACHE PATH "CMake Install Prefix" FORCE)
endif ()
msg(NOTICE "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")

if (MONOREPO AND MONOBUILD)
    return()
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/project_install.cmake)