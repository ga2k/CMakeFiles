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
include("${CMAKE_CURRENT_SOURCE_DIR}/BaseDirs.cmake")

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

# Ensure overrides path is highest priority for build tree
list(PREPEND extra_IncludePaths
        ${CMAKE_CURRENT_SOURCE_DIR}/HoffSoft/overrides/magic_enum/include
)

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

# fetchContents per project (after resolving hints using CMAKE_MODULE_PATH)
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
            elseif(LINUX)
                set(CMAKE_INSTALL_LIBDIR "lib64")
            elseif(WINDOWS)
                message(FATAL_ERROR "Fix here")
            endif ()
        endif ()

#        list(PREPEND CMAKE_MODULE_PATH
#                "$ENV{HOME}/dev/stage${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake"
#                "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake")

        # Define the paths to the two configuration files
        set(SYSTEM_PATH   "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake")
        set(STAGED_PATH "$ENV{HOME}/dev/stage${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake")

        foreach (hint IN LISTS FIND_PACKAGE_PATHS)
            string(FIND "${hint}" "{" openBrace)
            string(FIND "${hint}" "}" closeBrace)
            if (${openBrace} LESS 0 OR ${closeBrace} LESS 0)
                message(FATAL_ERROR "FIND_PACKAGE_PATHS in AppSpecific.cmake needs '{packagename}'")
            endif ()

            math(EXPR firstCharOfPkg "${openBrace} + 1")
            math(EXPR pkgNameLen "${closeBrace} - ${openBrace} - 1")
            string(SUBSTRING "${hint}" ${firstCharOfPkg} ${pkgNameLen} pkgName)

            string(REGEX REPLACE "${APP_NAME}" "${pkgName}" SOURCE_PATH "${OUTPUT_DIR}")

            set(pkgName "${pkgName}Config.cmake")

            set (actualSourceFile "${SOURCE_PATH}/${pkgName}")
            if (NOT EXISTS "${actualSourceFile}")
                set (actualSourceFile "(not found)")
            endif ()

            set (actualStagedFile "${STAGED_PATH}/${pkgName}")
            if (NOT EXISTS "${actualStagedFile}")
                set (actualStagedFile "(not found)")
            endif ()

            set (actualSystemFile "${SYSTEM_PATH}/${pkgName}")
            if (NOT EXISTS "${actualSystemFile}")
                set (actualSystemFile "(not found)")
            endif ()

            if ("${actualSourceFile}" STREQUAL "(not found)" AND
                "${actualStagedFile}" STREQUAL "(not found)" AND
                "${actualSystemFile}" STREQUAL "(not found)")
                message(FATAL_ERROR "${APP_NAME} depends on ${pkgName}, which has not been built")
            elseif ("${actualSourceFile}" STREQUAL "(not found)" AND
                    "${actualStagedFile}" STREQUAL "(not found)" AND
                    NOT "${actualSystemFile}" STREQUAL "(not found)")
                message(STATUS "No local ${pkgName} file found. Using ${actualSystemFile}")
                set (config_DIR "${SYSTEM_PATH}")
            else ()
                message(STATUS "Source file is : ${actualSourceFile}")
                message(STATUS "Staged file is : ${actualStagedFile}")
                message(STATUS "System file is : ${actualSystemFile}")
                if ("${actualSourceFile}" STREQUAL "(not found)" AND
                    NOT "${actualStagedFile}" STREQUAL "(not found)" AND
                    NOT "${actualSystemFile}" STREQUAL "(not found)")
                    if ("${actualStagedFile}" IS_NEWER_THAN "${actualSystemFile}")
                        message(STATUS "Staged file is newest. Using ${actualStagedFile}")
                        set (config_DIR "${STAGED_PATH}")
                    else ()
                        message(STATUS "System file is newest. Using ${actualSystemFile}")
                        set (config_DIR "${SYSTEM_PATH}")
                    endif ()
                elseif (NOT "${actualSourceFile}" STREQUAL "(not found)" AND
                        "${actualStagedFile}" STREQUAL "(not found)" AND
                        NOT "${actualSystemFile}" STREQUAL "(not found)")
                    if ("${actualSourceFile}" IS_NEWER_THAN "${actualSystemFile}")
                        message(STATUS "Source file is newest. Using ${actualSourceFile}")
                        set (config_DIR "${SOURCE_PATH}")
                    else ()
                        message(STATUS "System file is newest. Using ${actualSystemFile}")
                        set (config_DIR "${SYSTEM_PATH}")
                    endif ()
                elseif (NOT "${actualSourceFile}" STREQUAL "(not found)" AND
                        NOT "${actualStagedFile}" STREQUAL "(not found)" AND
                        "${actualSystemFile}" STREQUAL "(not found)")
                    if ("${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}")
                        message(STATUS "Source file is newest. Using ${actualSourceFile}")
                        set (config_DIR "${SOURCE_PATH}")
                    else ()
                        message(STATUS "Staged file is newest. Using ${actualStagedFile}")
                        set (config_DIR "${STAGED_PATH}")
                    endif ()
                else ()
                    if ("${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}")
                        if ("${actualSourceFile}" IS_NEWER_THAN "${actualSystemFile}")
                            message(STATUS "Source file is newest. Using ${actualSourceFile}")
                            set (config_DIR "${SOURCE_PATH}")
                        else ()
                            message(STATUS "System file is newest. Using ${actualSystemFile}")
                            set (config_DIR "${SYSTEM_PATH}")
                        endif ()
                    else ()
                        if ("${actualStagedFile}" IS_NEWER_THAN "${actualSystemFile}")
                            message(STATUS "Staged file is newest. Using ${actualStagedFile}")
                            set (config_DIR "${STAGED_PATH}")
                        else ()
                            message(STATUS "System file is newest. Using ${actualSystemFile}")
                            set (config_DIR "${SYSTEM_PATH}")
                        endif ()
                    endif ()
                endif ()
            endif ()
            string(REGEX REPLACE "\{.*\}" "${config_DIR}" hint "${hint}")
            list(APPEND FIND_PACKAGE_ARGS ${hint})
        endforeach ()
    endif ()

    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES}
            FIND_PACKAGE_ARGS ${FIND_PACKAGE_ARGS})
else ()
    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES})
endif ()

message(STATUS "=== Configuring Components ===")

# Track if Core already exists before this project adds sources
set(ALREADY_HAVE_CORE OFF)
if (TARGET HoffSoft::HoffSoft)
    set(ALREADY_HAVE_CORE ON)
endif ()

# Enter the project's src folder (defines targets)
add_subdirectory(src)

# Consumer workaround for yaml-cpp when consuming HoffSoft::HoffSoft install package
if (ALREADY_HAVE_CORE)
    find_package(yaml-cpp CONFIG QUIET)
    if (TARGET yaml-cpp::yaml-cpp)
        message(STATUS "Linking yaml-cpp::yaml-cpp explicitly as a workaround for HoffSoft::HoffSoft package")
        if (TARGET main)
            target_link_libraries(main LINK_PRIVATE yaml-cpp::yaml-cpp)
        endif ()
    endif ()
endif ()

# App configuration (app.yaml) generation paths
if (${APP_TYPE} STREQUAL "Library")
    set(APP_YAML_PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${APP_VENDOR_LC}_${APP_NAME_LC}.yaml")
else ()
    set(APP_YAML_PATH "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${APP_NAME}.yaml")
endif ()
set(APP_YAML_TEMPLATE_PATH "${CMAKE_SOURCE_DIR}/cmake/templates/app.yaml.in")

file(MAKE_DIRECTORY "${OUTPUT_DIR}/bin")
include(${CMAKE_SOURCE_DIR}/cmake/generate_app_config.cmake)

# Ensure no link directories leak to INTERFACE and publish overrides include dir to installed consumers
if (TARGET ${APP_NAME})
    set_property(TARGET ${APP_NAME} PROPERTY INTERFACE_LINK_DIRECTORIES "")
    target_include_directories(${APP_NAME} INTERFACE
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}/overrides/magic_enum/include>
    )
endif ()

# Optional resources fetching per project
include(ExternalProject)
if (APP_INCLUDES_RESOURCES OR APP_SUPPLIES_RESOURCES)
    set(RES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/resources")
    if (APP_SUPPLIES_RESOURCES AND NOT APPLE)
        ExternalProject_Add(${APP_NAME}ResourceRepo
                GIT_REPOSITORY "${APP_SUPPLIES_RESOURCES}"
                GIT_TAG master
                GIT_SHALLOW TRUE
                UPDATE_DISCONNECTED TRUE
                CONFIGURE_COMMAND ""
                BUILD_COMMAND ""
                INSTALL_COMMAND ""
                TEST_COMMAND ""
                SOURCE_DIR "${RES_DIR}"
                BUILD_BYPRODUCTS "${RES_DIR}/.fetched"
                COMMAND ${CMAKE_COMMAND} -E touch "${RES_DIR}/.fetched"
        )
        add_custom_target(fetch_resources DEPENDS ${APP_NAME}ResourceRepo)
        if (TARGET ${APP_NAME})
            add_dependencies(${APP_NAME} fetch_resources)
        endif ()
    endif ()
endif ()

# Code generators (optional)
include(${CMAKE_SOURCE_DIR}/cmake/generator.cmake)
if (APP_GENERATE_RECORDSETS)
    generateRecordsets(
            ${CMAKE_SOURCE_DIR}/src/generated/rs
            ${APP_GENERATE_RECORDSETS})
endif ()
if (APP_GENERATE_UI_CLASSES)
    generateUIClasses(
            ${CMAKE_SOURCE_DIR}/src/generated/ui
            ${APP_GENERATE_UI_CLASSES})
endif ()

# ========================= Install & packaging =========================
#
install(TARGETS                  ${APP_NAME} ${HS_DependenciesList}
        EXPORT                   ${_TARGET}Target
        CONFIGURATIONS           Debug Release
        LIBRARY                  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME                  DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE                  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        CXX_MODULES_BMI          DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILE_SET CXX_MODULES     DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
        FILE_SET HEADERS         DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        INCLUDES                 DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(EXPORT ${_TARGET}Target
        FILE ${_TARGET}Target.cmake
        NAMESPACE ${APP_VENDOR}::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
        CXX_MODULES_DIRECTORY "cxx/${APP_VENDOR}"
)

if (APP_CREATES_PLUGINS)
    install(TARGETS              ${APP_CREATES_PLUGINS}
            EXPORT               ${APP_NAME}PluginTarget
            CONFIGURATIONS       Debug Release
            LIBRARY DESTINATION  ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            RUNTIME DESTINATION  ${CMAKE_INSTALL_BINDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            ARCHIVE DESTINATION  ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            CXX_MODULES_BMI      DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
            FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
            FILE_SET HEADERS     DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            INCLUDES             DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )
endif ()

install(CODE "
  message(WARNING \"Removing $ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}/**/*.ixx\")
  file(GLOB_RECURSE junk \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}/*.ixx\")
  if(junk)
    file(REMOVE ${junk})
  endif()
")

install(DIRECTORY
        ${CMAKE_CURRENT_SOURCE_DIR}/include/overrides
        DESTINATION
        ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR})

# Static libraries (copy built libs)
install(DIRECTORY ${OUTPUT_DIR}/lib/ DESTINATION ${CMAKE_INSTALL_LIBDIR})

# PCM/PCM-like files
install(DIRECTORY ${CMAKE_BUILD_DIR}/src/CMakeFiles/${APP_NAME}.dir/
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILES_MATCHING PATTERN *.pcm)

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
        "${OUTPUT_DIR}/${_TARGET}ConfigVersion.cmake"
        VERSION ${APP_VERSION}
        COMPATIBILITY SameMajorVersion
)

if ("${APP_TYPE}" STREQUAL "Library")
    install(FILES
            "${OUTPUT_DIR}/dll/${APP_VENDOR_LC}_${APP_NAME_LC}.yaml"
            DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
else ()
    install(FILES
            "${OUTPUT_DIR}/bin/${APP_NAME}.yaml"
            DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif ()
set(APP_YAML_PATH "${OUTPUT_DIR}/bin/${APP_NAME}.yaml")

configure_package_config_file(
        ${CMAKE_SOURCE_DIR}/cmake/templates/Config.cmake.in
        "${OUTPUT_DIR}/${_TARGET}Config.cmake"
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

install(FILES
        "${OUTPUT_DIR}/${_TARGET}Config.cmake"
        "${OUTPUT_DIR}/${_TARGET}ConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

include(GNUInstallDirs)

# User guide, if present
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/doc/${_TARGET}")
endif ()

# Resources directory (fonts, images, etc.)
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/resources")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/resources/"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/${APP_VENDOR}/${APP_NAME}/resources")
    file(GLOB _hs_desktop_files "${CMAKE_CURRENT_SOURCE_DIR}/resources/*.desktop")
    if (_hs_desktop_files)
        install(FILES ${_hs_desktop_files}
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
    endif ()
    unset(_hs_desktop_files)
endif ()
