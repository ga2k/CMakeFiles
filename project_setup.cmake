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
#
## Ensure overrides path is highest priority for build tree
#if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/overrides/magic_enum/include)
#    list(PREPEND extra_IncludePaths ${CMAKE_CURRENT_SOURCE_DIR}/overrides/magic_enum/include)
#endif (
#
#)

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

if(WIN32)
    string(SUBSTRING "${SYSTEM_PATH}" 2 -1 _systemFolder)
else ()
    set(_systemFolder "${SYSTEM_PATH}")
endif ()
set(_stagedFolder "${STAGED_PATH}${_systemFolder}")

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

        if (NOT CMAKE_INSTALL_LIBDIR)
            if (APPLE)
                set(CMAKE_INSTALL_LIBDIR "lib")
            elseif (LINUX)
                set(CMAKE_INSTALL_LIBDIR "lib64")
            elseif (WINDOWS)
                set(CMAKE_INSTALL_LIBDIR "lib")
            endif ()
        endif ()

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

            set(actualSourceFile "${SOURCE_PATH}/${pkgName}")
            if (NOT EXISTS "${actualSourceFile}")
                set(sourceFileFound OFF)
            else ()
                set(sourceFileFound ON)
            endif ()

            set(actualStagedFile "${_stagedFolder}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            if (NOT EXISTS "${actualStagedFile}")
                set(stagedFileFound OFF)
            else ()
                set(stagedFileFound ON)
            endif ()

            set(actualSystemFile "${SYSTEM_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            if (NOT EXISTS "${actualSystemFile}")
                set(systemFileFound OFF)
            else ()
                set(systemFileFound ON)
            endif ()

            set (newestFile)
            set (newOrder)

            list (APPEND filesToCheck "${actualStagedFile}" "${actualSystemFile}" "${actualSourceFile}")
            newestFile(newestFile "${filesToCheck}"  newOrder)

            log(VAR newestFile LIST newOrder)

            # @formatter:off
            if (    NOT "${stagedFileFound}" AND
                    NOT "${systemFileFound}" AND
                    NOT "${sourceFileFound}")
                    message(NOTICE "${APP_NAME} depends on ${pkgName}, which has not been built")
                    message(FATAL_ERROR "Looked for ${actualStagedFile}, ${actualSystemFile}, and ${actualSourceFile}")

            if (        "${sourceFileFound}" AND
                        "${stagedFileFound}" AND
                        "${systemFileFound}")

                if ("${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}" AND "${actualSourceFile}" IS_NEWER_THAN "${actualSystemFile}")
                    message(STATUS "source file is newest. Using ${actualSourceFile}")
                    if ("${actualStagedFile}" IS_NEWER_THAN "${actualSystemFile}")
                        list (APPEND CMAKE_PREFIX_PATH "${actualSourceFile}" "${actualStagedFile}" "${actualSystemFile}")
                    else ()
                        list (APPEND CMAKE_PREFIX_PATH "${actualSourceFile}" "${actualSystemFile}" "${actualStagedFile}")
                    endif ()
                endif ()

            else ()

                if ("${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}" AND "${actualSourceFile}" IS_NEWER_THAN "${actualSystemFile}")


                    if (        "${sourceFileFound}" AND
                        "${stagedFileFound}"
                if (    "${stagedFileFound}" AND
                    NOT "${systemFileFound}")
                    message(STATUS "staged file is newest. Using ${actualStagedFile}")
                    list (APPEND CMAKE_PREFIX_PATH "${_stagedFolder}")
            elseif (NOT "${stagedFileFound}" AND
                        "${systemFileFound}")
                    message(STATUS "system file is newest. Using ${actualSystemFile}")
                    list (APPEND CMAKE_PREFIX_PATH "${SYSTEM_PATH}")
            elseif (    "${stagedFileFound}" AND
                        "${systemFileFound}" AND
                        "${actualStagedFile}" IS_NEWER_THAN "${actualSystemFile}")
                    message(STATUS "staged file is newest. Using ${actualStagedFile}")
                    list (APPEND CMAKE_PREFIX_PATH "${_stagedFolder}")
            elseif (    "${stagedFileFound}" AND
                        "${systemFileFound}" AND
                        "${actualSystemFileFound}" IS_NEWER_THAN "${actualStagedFileFound}")
                    message(STATUS "system file is newest. Using ${actualSystemFile}")
                    list (APPEND CMAKE_PREFIX_PATH "${SYSTEM_PATH}")
            else ()
                message(FATAL_ERROR "Impossible situation exists comparing modification times of staged file / system file")
            endif ()
            # @formatter:on

            message(STATUS "hint before modification : '${hint}'")
            string(REGEX MATCH "PATHS \{.*\}" MATCH_STR "${hint}")
            message(STATUS "matched portion of input : '${MATCH_STR}'")
            string(REPLACE "${MATCH_STR}" "" hint "${hint}")
            message(STATUS "hint  after modification : '${hint}'")

            list(APPEND FIND_PACKAGE_ARGS "${hint}")

        endforeach ()

        list (APPEND CMAKE_PREFIX_PATH "${_stagedFolder}")
        list (APPEND CMAKE_PREFIX_PATH "${SYSTEM_PATH}")


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

#    if(config_DIR)
#        list(APPEND CMAKE_PREFIX_PATH "${config_DIR}")
#    endif ()
#
#    list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)

    list (APPEND CMAKE_PREFIX_PATH "${_stagedFolder}")
    list (APPEND CMAKE_PREFIX_PATH "${SYSTEM_PATH}")

    list(REMOVE_DUPLICATES CMAKE_PREFIX_PATH)

    set (CMAKE_PREFIX_PATH "${CMAKE_PREFIX_PATH}" CACHE FILEPATH "Look here")

    log(LIST CMAKE_PREFIX_PATH)

    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES})
endif ()

if(STAGE_OUTPUT)
    set(CMAKE_INSTALL_PREFIX "${_stagedFolder}" CACHE PATH "CMake Install Prefix" FORCE)
else ()
    set(CMAKE_INSTALL_PREFIX "${SYSTEM_PATH}" CACHE PATH "CMake Install Prefix" FORCE)
endif ()
message(NOTICE "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")

if (MONOREPO AND MONOBUILD)
    return()
endif ()

include(${CMAKE_SOURCE_DIR}/cmake/project_install.cmake)