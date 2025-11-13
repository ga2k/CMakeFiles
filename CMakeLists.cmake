
string(TOUPPER ${APP_NAME} APP_NAME_UC)
string(TOLOWER ${APP_NAME} APP_NAME_LC)
string(TOUPPER ${APP_VENDOR} APP_VENDOR_UC)
string(TOLOWER ${APP_VENDOR} APP_VENDOR_LC)

set(CMAKE_GENERATOR Ninja)

execute_process(
        COMMAND ${CMAKE_CXX_COMPILER} -v
        ERROR_VARIABLE compiler_version
        OUTPUT_QUIET
)

if (APP_SHOW_SIZER_INFO_IN_SOURCE)
    set(SHOW_SIZER_INFO_FLAG "--sizer-info")
else ()
    set(SHOW_SIZER_INFO_FLAG "")
endif ()

set(CMAKE_WARN_UNINITIALIZED ON) #                                                                      No pain, no gain
set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE CACHE STRING "Log Level" FORCE) #              So we get some preset variable output

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=c++23")
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -g")
set(CMAKE_CXX_SCAN_FOR_MODULES ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Include the directory containing addLibrary and tools, etc
set(staged "$ENV{HOME}/dev/stage/usr/local/lib64/cmake")
list(APPEND CMAKE_MODULE_PATH
        ${CMAKE_SOURCE_DIR}/cmake
        ${staged}
)

set(extra_CompileOptions)
set(extra_Definitions)
set(extra_IncludePaths)
set(extra_LibrariesList)
set(extra_LibraryPaths)
set(extra_LinkOptions)

# Link libbacktrace when available for std::stacktrace support
find_library(BACKTRACE_LIB backtrace)
find_library(STDCXX_BACKTRACE_LIB stdc++_libbacktrace)
if (BACKTRACE_LIB)
    list(APPEND extra_LibrariesList ${BACKTRACE_LIB})
elseif (STDCXX_BACKTRACE_LIB)
    list(APPEND extra_LibrariesList ${STDCXX_BACKTRACE_LIB})
endif ()

set(PROJECT_ROOT "${CMAKE_CURRENT_SOURCE_DIR}")

if (WIDGETS IN_LIST APP_FEATURES)
    set(extra_wxCompilerOptions)
    set(extra_wxDefines)
    set(extra_wxFrameworks)
    set(extra_wxIncludePaths)
    set(extra_wxLibraries)
    set(extra_wxLibraryPaths)
endif ()

# Add subdirectories
###############################################################################################
add_subdirectory(cmake)
check_environment("${PROJECT_ROOT}")
###############################################################################################

if (THEY_ARE_INSTALLED)
    list(APPEND extra_Definitions INSTALLED)
endif ()

list(APPEND HEADER_BASE_DIRS "${OUTPUT_DIR}/include")
include("${CMAKE_CURRENT_SOURCE_DIR}/BaseDirs.cmake")

set(HS_CompileOptionsList "")
set(HS_DefinesList "")
set(HS_DependenciesList "")
set(HS_IncludePathsList "")
set(HS_LibrariesList "")
set(HS_LibraryPathsList "")
set(HS_LinkOptionsList "")
set(HS_PrefixPathsList "")

list(APPEND extra_LibraryPaths
        "${OUTPUT_DIR}/bin"
        "${OUTPUT_DIR}/lib"
        "${OUTPUT_DIR}/dll"
        "${OUTPUT_DIR}/bin/plugins"
        "${OUTPUT_DIR}/lib/plugins"
        "${OUTPUT_DIR}/dll/plugins"
)

list(APPEND extra_LibraryPaths
        "${CMAKE_INSTALL_PREFIX}"
        "${CMAKE_INSTALL_PREFIX}/lib64"
        "${CMAKE_INSTALL_PREFIX}/lib"
)

if ("${compiler_version}" MATCHES "clang")
    list(APPEND extra_CompileOptions "-fno-implicit-modules;-fno-implicit-module-maps")
endif ()

#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
include(cmake/platform.cmake) #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#project(${APP_NAME} VERSION "${APP_VERSION}" DESCRIPTION "${DESCRIPTION}" LANGUAGES CXX) #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
initialiseFeatureHandlers() #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

list(APPEND CMAKE_PREFIX_PATH ${CMAKE_INSTALL_LIBDIR})

# Add any extra definitions to "extra_Definitions" here
list(APPEND extra_Definitions ${THEY_ARE_INSTALLED} MAGIC_ENUM_NO_MODULE)
list(APPEND extra_Definitions ${GUI})
string(REGEX REPLACE ";" "&" PI "${PLUGINS}")
list(APPEND extra_Definitions "PLUGINS=${PI}")

# Ensure our header overrides (e.g., patched magic_enum headers) take precedence in include search order.
# Keep this path at the very front so it survives cache clears and external refetches.
list(PREPEND extra_IncludePaths
        ${CMAKE_CURRENT_SOURCE_DIR}/HoffSoft/overrides/magic_enum/include
)

list(APPEND extra_IncludePaths
        ${HEADER_BASE_DIRS}
        ${CMAKE_INSTALL_PREFIX}/include
        ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}
)

########################################################################################################################
list(PREPEND HS_CompileOptionsList ${extra_CompileOptions})
list(PREPEND HS_DefinesList ${debugFlags} ${extra_Definitions})
list(PREPEND HS_IncludePathsList ${extra_IncludePaths})
list(PREPEND HS_LibrariesList ${extra_LibrariesList})
list(PREPEND HS_LibraryPathsList ${extra_LibraryPaths})
list(PREPEND HS_LinkOptionsList ${extra_LinkOptions})
########################################################################################################################
# Replace all occurrences of <match_string> in the <input> with <replace_string> and store the result in the <output_variable>.
string(REPLACE ";" " " escapedModulePath "${CMAKE_MODULE_PATH}")
if (FIND_PACKAGE_HINTS)
    set(FIND_PACKAGE_ARGS)
    foreach (hint IN LISTS FIND_PACKAGE_HINTS)
        string(REPLACE "{escapedModulePath}" ${escapedModulePath} hint ${hint})
        list(APPEND FIND_PACKAGE_ARGS ${hint})
    endforeach ()
    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES}
            FIND_PACKAGE_ARGS ${FIND_PACKAGE_ARGS})
else ()
    fetchContents(
            PREFIX HS
            USE ${APP_FEATURES})
endif ()
########################################################################################################################
include(GoogleTest)
########################################################################################################################
message(STATUS "=== Configuring Components ===")

# Note - we need this for after the main library/app creaation, so save it here
set(ALREADY_HAVE_CORE OFF)
if (TARGET HoffSoft::Core)
    set(ALREADY_HAVE_CORE ON)
endif ()

add_subdirectory(src)
########################################################################################################################

# Temporary consumer-side workaround for missing transitive yaml-cpp from HoffSoft::Core install package
# When using the installed HoffSoft::Core, its package currently does not declare yaml-cpp as a dependency,
# which can lead to unresolved symbols during linking. Until that package is fixed upstream, we try to
# locate yaml-cpp here and link it explicitly to ensure stable linkage in both build and install scenarios.

# Note - we only do this "down-stream" from Core, so if THIS is core - skip altogether
if (ALREADY_HAVE_CORE)
    find_package(yaml-cpp CONFIG QUIET)
    if (TARGET yaml-cpp::yaml-cpp)
        message(STATUS "Linking yaml-cpp::yaml-cpp explicitly as a workaround for HoffSoft::Core package")
        if (TARGET ${APP_NAME})
            #        target_link_libraries(${APP_NAME} LINK_PRIVATE yaml-cpp::yaml-cpp)
        endif ()
        if (TARGET main)
            target_link_libraries(main LINK_PRIVATE yaml-cpp::yaml-cpp)
        endif ()
    endif ()
endif ()
#
########################################################################################################################
# Define the path to the app.yaml file (match executable name, beside the exe)
#
if (${APP_TYPE} STREQUAL "Library")
    set(APP_YAML_PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${APP_VENDOR_LC}_${APP_NAME_LC}.yaml")
else ()
    set(APP_YAML_PATH "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${APP_NAME}.yaml")
endif ()
set(APP_YAML_TEMPLATE_PATH "${CMAKE_SOURCE_DIR}/cmake/templates/app.yaml.in")

# Generate app.yaml at configure time
# Ensure output directory exists
file(MAKE_DIRECTORY "${OUTPUT_DIR}/bin")

# Execute the generator script now (configure-time). It uses the variables
# defined above and in AppSpecific.cmake to render the template.
include(${CMAKE_SOURCE_DIR}/cmake/generate_app_config.cmake)
#
########################################################################################################################
# Appropriate include paths
#
if (TARGET ${APP_NAME})
    # Ensure no link directories leak into INTERFACE to satisfy CMake export validation
    set_property(TARGET ${APP_NAME} PROPERTY INTERFACE_LINK_DIRECTORIES "")
    # Expose the overrides include folder (e.g., patched magic_enum headers) for installed consumers
    target_include_directories(${APP_NAME} INTERFACE
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}/overrides/magic_enum/include>
    )
endif ()
########################################################################################################################
include(ExternalProject)

if (APP_INCLUDES_RESOURCES OR APP_SUPPLIES_RESOURCES)

    set(RES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/resources")

    if (APP_SUPPLIES_RESOURCES)

        set(RES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/resources")

        ExternalProject_Add(${APP_NAME}ResourceRepo
                GIT_REPOSITORY "${APP_SUPPLIES_RESOURCES}"
                GIT_TAG master
                GIT_SHALLOW TRUE
                UPDATE_DISCONNECTED TRUE

                # We only want sources; skip configure/build/install
                CONFIGURE_COMMAND ""
                BUILD_COMMAND ""
                INSTALL_COMMAND ""
                TEST_COMMAND ""

                # Where to put the sources
                SOURCE_DIR "${RES_DIR}"

                # Create a marker so builds see a byproduct
                BUILD_BYPRODUCTS "${RES_DIR}/.fetched"
                COMMAND ${CMAKE_COMMAND} -E touch "${RES_DIR}/.fetched"
        )

        # Make a convenient target to trigger the download:
        add_custom_target(fetch_resources DEPENDS ${APP_NAME}ResourceRepo) # use ALL to fetch every build
        add_dependencies(${APP_NAME} fetch_resources)
        # Or omit ALL and run: cmake --build . --target fetch_resources
    endif ()
endif ()

#
# End of Configure !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Start of Install !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# Need to tweak some locations. We'll keep it limited
if ("${APP_NAME}" STREQUAL "Core")
    set(_TARGET ${APP_VENDOR})
else ()
    set(_TARGET ${APP_NAME})
endif ()

# @formatter:off
install(TARGETS                  ${APP_NAME}
        EXPORT                   ${APP_NAME}Target
        CONFIGURATIONS           Debug Release
        LIBRARY                  DESTINATION ${CMAKE_INSTALL_LIBDIR} # NAMELINK_SKIP
        RUNTIME                  DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE                  DESTINATION ${CMAKE_INSTALL_LIBDIR} # NAMELINK_SKIP
        CXX_MODULES_BMI          DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_NAME}
        FILE_SET CXX_MODULES     DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}
        FILE_SET HEADERS         DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        INCLUDES                 DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

if (APP_CREATES_PLUGINS)
    install(TARGETS              ${APP_CREATES_PLUGINS}
            EXPORT               ${APP_NAME}PluginTarget
            CONFIGURATIONS       Debug Release
            LIBRARY DESTINATION  ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/plugins
            RUNTIME DESTINATION  ${CMAKE_INSTALL_BINDIR}/${APP_VENDOR}/plugins
            ARCHIVE DESTINATION  ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/plugins
            CXX_MODULES_BMI      DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_NAME}
            FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}
            FILE_SET HEADERS     DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            INCLUDES             DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )
endif ()
# @formatter:on

install(CODE "
  message(STATUS \"Removing \$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}/**/*.ixx\")
  file(GLOB_RECURSE junk \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}/*.ixx\")
  if(junk)
    file(REMOVE \${junk})
  endif()
")

## Inline CMake code
#install(CODE "
#  file(GLOB to_remove \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}/*.ixx\")
#  if(\"${to_remove}\" STREQUAL \"\")
#    message(FATAL_ERROR \"no files in $ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}\")
#  endif()
#  message(STATUS \"Removing ${to_remove} from $ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}...\")
#  file(REMOVE ${to_remove})
#")

# Manual copy because CMake won't
install(DIRECTORY
        ${CMAKE_CURRENT_SOURCE_DIR}/include/overrides
        DESTINATION
        ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR})

# Static libraries
install(DIRECTORY
        ${OUTPUT_DIR}/lib
        DESTINATION
        ${CMAKE_INSTALL_PREFIX})

## PCM files for modules
install(DIRECTORY ${CMAKE_BUILD_DIR}/src/CMakeFiles/${APP_NAME}.dir/
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_NAME}
        FILES_MATCHING PATTERN *.pcm)

install(EXPORT ${APP_NAME}Target
        FILE ${_TARGET}Target.cmake
        NAMESPACE ${APP_VENDOR}::
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
        CXX_MODULES_DIRECTORY "cxx/${APP_NAME}"
)

# Package config and target exports for find_package
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET}ConfigVersion.cmake"
        VERSION ${APP_VERSION}
        COMPATIBILITY SameMajorVersion
)

# our {appname}.yaml file
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
        cmake/templates/Config.cmake.in
        "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET}Config.cmake"
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

install(FILES
        "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET}Config.cmake"
        "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET}ConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

include(GNUInstallDirs)

# User guide
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/doc/${_TARGET}")
endif ()

# Resources directory (fonts, images, etc.)
if (RES_DIR)
#if ((APP_SUPPLIES_RESOURCES OR APP_INCLUDES_RESOURCES) AND EXISTS "${RES_DIR}")
    install(DIRECTORY "${RES_DIR}/"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/${APP_VENDOR}/${APP_NAME}/resources")
    # If any desktop files are provided under resources/, install them to share/applications
    file(GLOB _hs_desktop_files "${CMAKE_CURRENT_SOURCE_DIR}/resources/*.desktop")
    if (_hs_desktop_files)
        install(FILES ${_hs_desktop_files}
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
    endif ()
    unset(_hs_desktop_files)
endif ()
