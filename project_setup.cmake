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

# Project-root (this subproject)
set(PROJECT_ROOT "${PROJECT_SOURCE_DIR}")

# Ensure environment/output dirs are prepared for this specific project
include(${CMAKE_SOURCE_DIR}/cmake/check_environment.cmake)
check_environment("${CMAKE_SOURCE_DIR}")

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
string(REGEX REPLACE ";" "&" PI "${PLUGINS}")
list(REMOVE_ITEM extra_Definitions "PLUGINS")
if (NOT "${PI}" STREQUAL "")
    list(APPEND extra_Definitions "PLUGINS=${PI}")
endif ()

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

if (FIND_PACKAGE_HINTS OR FIND_PACKAGE_PATHS)
    set(FIND_PACKAGE_ARGS)
    if (FIND_PACKAGE_HINTS)
        string(REPLACE ";" " " escapedModulePath "${CMAKE_MODULE_PATH}")
        foreach (hint IN LISTS FIND_PACKAGE_HINTS)
            string(REPLACE "{}" "${escapedModulePath}" hint "${hint}")
            list(APPEND FIND_PACKAGE_ARGS ${hint})
        endforeach ()
    endif ()

    if (FIND_PACKAGE_PATHS)

        # Define the paths to the two configuration files
        foreach (hint IN LISTS FIND_PACKAGE_PATHS)
            string(FIND "${hint}" "{" openBrace)
            string(FIND "${hint}" "}" closeBrace)
            if (${openBrace} LESS 0 OR ${closeBrace} LESS 0)
                message(FATAL_ERROR "FIND_PACKAGE_PATHS in AppSpecific.cmake needs '{packagename}'")
            endif ()

            math(EXPR firstCharOfPkg "${openBrace} + 1")
            math(EXPR pkgNameLen "${closeBrace} - ${openBrace} - 1")
            string(SUBSTRING "${hint}" ${firstCharOfPkg} ${pkgNameLen} pkgName)

            if (MONOREPO AND MONOBUILD)
                set(SOURCE_PATH "${OUTPUT_DIR}")
            else ()
                string(REGEX REPLACE "${APP_NAME}/" "${pkgName}/" SOURCE_PATH "${OUTPUT_DIR}")
            endif ()

            list (APPEND CMAKE_PREFIX_PATH "${SOURCE_PATH}")

            set(pkgName "${pkgName}Config.cmake")

            set(candidates)
            set(conditionals)

            set(actualSourceFile "${SOURCE_PATH}/${pkgName}")
            if (EXISTS "${actualSourceFile}")
                message(NOTICE "  Found ${actualSourceFile}")
                list(APPEND candidates "${actualSourceFile}")
                set(sourceFileFound ON)
            else ()
                message(NOTICE "Missing ${actualSourceFile}")
                set(sourceFileFound OFF)
            endif ()

            set(actualStagedFile "${STAGED_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            if (EXISTS "${actualStagedFile}")
                message(NOTICE "  Found ${actualStagedFile}")
                list(APPEND conditionals "${actualStagedFile}")
                set(stagedFileFound ON)
            else ()
                message(NOTICE "Missing ${actualStagedFile}")
                set(stagedFileFound OFF)
            endif ()

            set(actualSystemFile "${SYSTEM_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            if (EXISTS "${actualSystemFile}")
                message(NOTICE "  Found ${actualSystemFile}")
                list(APPEND conditionals "${actualSystemFile}")
                set(systemFileFound ON)
            else ()
                message(NOTICE "Missing ${actualSystemFile}")
                set(systemFileFound OFF)
            endif ()

            # Staged and Source files are the same?
            if (sourceFileFound AND stagedFileFound
                    AND ${actualSourceFile} IS_NEWER_THAN ${actualStagedFile}
                    AND ${actualStagedFile} IS_NEWER_THAN ${actualSourceFile})

                message(NOTICE "Source and Staged are the same. We'll use Staged.")
                set (candidates "${actualStagedFile}")
            else ()
                newestFile("${conditionals}" inOrder)
                list(APPEND candidates "${inOrder}")
            endif ()

            log(LIST candidates)

            set(listOfFolders)
            foreach (candidate IN LISTS candidates)
                get_filename_component(candidate "${candidate}" PATH)
                list(APPEND listOfFolders "${candidate}")
            endforeach ()

            list (PREPEND CMAKE_PREFIX_PATH "${listOfFolders}")

            message(STATUS "hint before modification : '${hint}'")
            string(REGEX MATCH "PATHS \{.*\}" MATCH_STR "${hint}")
            message(STATUS "matched portion of input : '${MATCH_STR}'")
            string(REPLACE "${MATCH_STR}" "" hint "${hint}")
            message(STATUS "hint  after modification : '${hint}'")

            list(APPEND FIND_PACKAGE_ARGS "${hint}")

        endforeach ()

        list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)
        set (CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" CACHE FILEPATH "Look here")
#
    endif ()

    log(LIST CMAKE_PREFIX_PATH)

    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES}
            FIND_PACKAGE_ARGS ${FIND_PACKAGE_ARGS})
else ()

    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES})
endif ()

if(STAGE_OUTPUT)
    set(CMAKE_INSTALL_PREFIX "${STAGED_FOLDER}" CACHE PATH "CMake Install Prefix" FORCE)
else ()
    set(CMAKE_INSTALL_PREFIX "${SYSTEM_PATH}" CACHE PATH "CMake Install Prefix" FORCE)
endif ()
message(NOTICE "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")

if (MONOREPO AND MONOBUILD)
    return()
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/project_install.cmake)