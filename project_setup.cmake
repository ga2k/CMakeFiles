include(GNUInstallDirs)

function(replacePositionalParameters tokenString outputVar ignoreFoundState)

    set(hints)

    # Define the paths to the two configuration files
    foreach (hint IN LISTS tokenString)
        string(FIND "${hint}" "{" openBrace)
        string(FIND "${hint}" "}" closeBrace)
        if (${openBrace} LESS 0 AND ${closeBrace} LESS 0)
            list(APPEND hints "${hint}")
            continue()
        endif ()

        math(EXPR firstCharOfPkg "${openBrace} + 1")
        math(EXPR pkgNameLen "${closeBrace} - ${openBrace} - 1")
        string(SUBSTRING "${hint}" ${firstCharOfPkg} ${pkgNameLen} pkgName)

        if (MONOREPO AND MONOBUILD)
            set(SOURCE_PATH "${OUTPUT_DIR}")
        else ()
            string(REGEX REPLACE "${APP_NAME}/" "${pkgName}/" SOURCE_PATH "${OUTPUT_DIR}")
        endif ()

        set(pkgName "${pkgName}Config.cmake")

        set(candidates)
        set(conditionals)

        set(actualSourceFile "${SOURCE_PATH}/${pkgName}")
        if (EXISTS "${actualSourceFile}" OR ignoreFoundState)
            if (EXISTS "${actualSourceFile}")
                msg(NOTICE "  Found ${actualSourceFile}")
                set(sourceFileFound ON)
            else ()
                msg(NOTICE "Missing ${actualSourceFile} but still added it to list")
                set(sourceFileFound OFF)
            endif ()
            list(APPEND candidates "${actualSourceFile}")
        else ()
            msg(NOTICE "Missing ${actualSourceFile}")
            set(sourceFileFound OFF)
        endif ()

        set(actualStagedFile "${STAGED_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
        if (EXISTS "${actualStagedFile}" OR ignoreFoundState)
            if (EXISTS "${actualStagedFile}")
                msg(NOTICE "  Found ${actualStagedFile}")
                set(stagedFileFound ON)
                list(APPEND conditionals "${actualStagedFile}")
            else ()
                msg(NOTICE "Missing ${actualStagedFile} but still added it to list")
                set(stagedFileFound OFF)
                list(APPEND candidates "${actualStagedFile}")
            endif ()
        else ()
            msg(NOTICE "Missing ${actualStagedFile}")
            set(stagedFileFound OFF)
        endif ()

        set(actualSystemFile "${SYSTEM_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
        if (EXISTS "${actualSystemFile}" OR ignoreFoundState)
            if (EXISTS "${actualSystemFile}")
                msg(NOTICE "  Found ${actualSystemFile}")
                set(systemFileFound ON)
                list(APPEND conditionals "${actualSystemFile}")
            else ()
                msg(NOTICE "Missing ${actualSystemFile} but still added it to list")
                set(systemFileFound OFF)
                list(APPEND candidates "${actualSystemFile}")
            endif ()
        else ()
            msg(NOTICE "Missing ${actualSystemFile}")
            set(systemFileFound OFF)
        endif ()

        # Staged and Source files are the same?
        if (NOT ignoreFoundState)
            if (sourceFileFound AND stagedFileFound
                    AND ${actualSourceFile} IS_NEWER_THAN ${actualStagedFile}
                    AND ${actualStagedFile} IS_NEWER_THAN ${actualSourceFile})

                msg(NOTICE "Source and Staged are the same. We'll use Staged.")
                set (candidates "${actualStagedFile}")
            else ()
                newestFile("${conditionals}" inOrder)
                list(APPEND candidates "${inOrder}")
            endif ()
        endif ()

        set(listOfFolders)
        foreach (candidate IN LISTS candidates)
            get_filename_component(candidate "${candidate}" PATH)
            list(APPEND listOfFolders "${candidate}")
        endforeach ()

        list(APPEND hints "${listOfFolders}")

    endforeach ()

    list(REMOVE_DUPLICATES hints)
    set (${outputVar} ${hints} PARENT_SCOPE)
endfunction()

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

unset(revised_features)
set(_switches "OVERRIDE_FIND_PACKAGE")
set(_single_args "PACKAGE")
set(_multi_args "FIND_PACKAGE_ARGS;COMPONENTS")
set(_prefix "AA")

macro (_)

    set (_pkg)
    set (_ns)
    set (_kind)
    set (_method)
    set (_url)
    set (_tag)
    set (_incdir)
    set (_components)
    set (_hints)
    set (_paths)
    set (_args)
    set (_required)
    set (_prerequisites)
    set (_first_hint)
    set (_first_path)
    set (_first_component)

endmacro()

foreach(feature IN LISTS APP_FEATURES)

    _()

    separate_arguments(feature NATIVE_COMMAND "${feature}")
    cmake_parse_arguments(${_prefix} "${_switches}" "${_single_args}" "${_multi_args}" ${feature})
    list (POP_FRONT AA_UNPARSED_ARGUMENTS _feature)
    # Sanity check

    if (AA_OVERRIDE_FIND_PACKAGE AND (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES))
        msg(ALWAYS FATAL_ERROR "APP_FEATURES: Cannot combine OVERRIDE_FIND_PACKAGE with FIND_PACKAGE_ARGS")
    endif ()

    if (AA_PACKAGE OR "PACKAGE" IN_LIST AA_KEYWORDS_MISSING_VALUES)
        if (NOT "${AA_PACKAGE}" STREQUAL "")
            set (_pkg "${AA_PACKAGE}")
        else ()
            msg(ALWAYS WARNING "APP_FEATURES: PACKAGE keyword given with no package name")
            list(REMOVE_ITEM AA_UNPARSED_ARGUMENTS "PACKAGE")
        endif ()
    endif ()

    if (AA_OVERRIDE_FIND_PACKAGE)
        set(_args "OVERRIDE_FIND_PACKAGE")
    elseif (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
        set(_args "FIND_PACKAGE_ARGS")
        if (NOT "${AA_FIND_PACKAGE_ARGS}" STREQUAL "")
            set (featureless ${feature})
            list (REMOVE_ITEM featureless "${_feature}" "FIND_PACKAGE_ARGS")
            cmake_parse_arguments("AA1" "REQUIRED;OPTIONAL" "" "COMPONENTS;PATHS;HINTS" ${featureless}) #${AA_FIND_PACKAGE_ARGS})

            if (AA1_HINTS OR "HINTS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
                if (NOT "${AA1_HINTS}" STREQUAL "")
                    replacePositionalParameters("${AA1_HINTS}" _hints OFF)
                    if (_hints)
                        string(JOIN " " _hints "HINTS" ${_hints})
                    else ()
                        msg(ALWAYS "APP_FEATURES: No files found for HINTS in FIND_PACKAGE_ARGS HINTS")
                    endif ()
                else ()
                    msg(ALWAYS WARNING "APP_FEATURES: FIND_PACKAGE_ARGS HINTS has no hints")
                    set (_hints)
                    list (REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "HINTS")
                endif ()
            endif ()

            if (AA1_PATHS OR "PATHS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
                if (NOT "${AA1_PATHS}" STREQUAL "")
                    replacePositionalParameters("${AA1_PATHS}" _paths ON)
                    if (_paths)
                        string(JOIN " " _paths "PATHS" ${_paths})
                    else ()
                        msg(ALWAYS "APP_FEATURES: No files found for PATHS in FIND_PACKAGE_ARGS PATHS")
                    endif ()
                else ()
                    msg(ALWAYS WARNING "APP_FEATURES: FIND_PACKAGE_ARGS PATHS has no paths")
                    set (_paths)
                    list (REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "PATHS")
                endif ()
            endif ()

            if (AA1_REQUIRED AND AA1_OPTIONAL)
                msg(ALWAYS FATAL_ERROR "APP_FEATURES: FIND_PACKAGE_ARGS cannot contain both REQUIRED,OPTIONAL")
            endif ()

            if (AA1_REQUIRED)
                set (_required "REQUIRED")
            endif ()

            if (AA1_OPTIONAL)
                set (_required "OPTIONAL")
            endif ()

            if (AA1_COMPONENTS)
                if (NOT "${AA1_COMPONENTS}" STREQUAL "")
                    string (JOIN " " _components "COMPONENTS" ${AA1_COMPONENTS})
                else ()
                    msg(ALWAYS WARNING "APP_FEATURES: FIND_PACKAGE_ARGS COMPONENTS given with no components")
                endif ()
                unset(AA_COMPONENTS)
                list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "COMPONENTS")
            endif ()
        else ()
            list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "FIND_PACKAGE_ARGS")
        endif ()
        string(JOIN " " _args "${_args}" ${_required} ${_hints} ${_paths} ${_components} ${AA1_UNPARSED_ARGUMENTS})
    endif ()

    if (AA_COMPONENTS OR "COMPONENTS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
        if (NOT "${AA_COMPONENTS}" STREQUAL "")
            #            string (POP_FRONT "${AA_COMPONENTS}" _first_component)
            #            string (JOIN "," _components "COMPONENTS=${_first_component}" ${AA_COMPONENTS})
            string (JOIN "," _components ${AA_COMPONENTS})
        else ()
            msg(ALWAYS WARNING "APP_FEATURES: COMPONENTS keyword given with no components")
        endif ()
    endif ()

#    FEATURE | PKGNAME | [NAMESPACE] | KIND | METHOD | URL or SRCDIR | [GIT_TAG] or BINDIR | [INCDIR] | [COMPONENT [COMPONENT [ COMPONENT ... ]]]  | [ARG [ARG [ARG ... ]]] | [PREREQ | [PREREQ | [PREREQ ... ]]]
    set (_prerequisites "")

    string (JOIN "|" feature
            "${_feature}"
            "${_pkg}"
            "${_ns}"
            "${_kind}"
            "${_method}"
            "${_url}"
            "${_tag}"
            "${_incdir}"
            "${_components}"
            "${_args}"
            "${_prereqiusites}"
    )

    list(APPEND revised_features "${feature}")


endforeach ()
_()

replacePositionalParameters("" "" OFF)

fetchContents(
        PREFIX HS
        USE ${revised_features})

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