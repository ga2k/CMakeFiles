
string(TOUPPER ${APP_NAME}   APP_NAME_UC)
string(TOLOWER ${APP_NAME}   APP_NAME_LC)
string(TOUPPER ${APP_VENDOR} APP_VENDOR_UC)
string(TOLOWER ${APP_VENDOR} APP_VENDOR_LC)

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
list(APPEND CMAKE_MODULE_PATH
        ${CMAKE_SOURCE_DIR}/cmake
        /tmp/stage/usr/local)

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

set(PROJECT_ROOT "${CMAKE_SOURCE_DIR}")

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

if (INSTALLED)
    list(APPEND extra_Definitions DEVEL)
endif ()

list(APPEND HEADER_BASE_DIRS "${OUTPUT_DIR}/include")
include("${CMAKE_SOURCE_DIR}/BaseDirs.cmake")

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

#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
include (cmake/platform.cmake) #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#project(${APP_NAME} VERSION "${APP_VERSION}" DESCRIPTION "${DESCRIPTION}" LANGUAGES CXX) #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
initialiseFeatureHandlers() #$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$
#$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$

list(APPEND CMAKE_PREFIX_PATH ${CMAKE_INSTALL_LIBDIR})

# Add any extra definitions to "extra_Definitions" here
list(APPEND extra_Definitions ${INSTALLED} MAGIC_ENUM_NO_MODULE)
list(APPEND extra_Definitions ${GUI})
string(REGEX REPLACE ";" "&" PI "${PLUGINS}")
list(APPEND extra_Definitions "PLUGINS=${PI}")

# Ensure our header overrides (e.g., patched magic_enum headers) take precedence in include search order.
# Keep this path at the very front so it survives cache clears and external refetches.
list(PREPEND extra_IncludePaths
        ${CMAKE_SOURCE_DIR}/HoffSoft/overrides/magic_enum/include
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
# string(REPLACE <match_string> <replace_string> <output_variable> <input> [<input>...])
# Replace all occurrences of <match_string> in the <input> with <replace_string> and store the result in the <output_variable>.
string(REPLACE ";" " " escapedPath "${CMAKE_MODULE_PATH}")
fetchContents(
        PREFIX HS
        USE ${APP_FEATURES}
#        FIND_PACKAGE_ARGS "CORE HINTS ${escapedPath};GFX HINTS ${escapedPath}"
)
########################################################################################################################
include(GoogleTest)
########################################################################################################################
message(STATUS "=== Configuring Components ===")
add_subdirectory(src)
########################################################################################################################

# Set plugin paths based on build type
if (NOT INSTALLED)
    # Development build
    set(PLUGIN_PATH "${OUTPUT_DIR}/plugins")
    set(PLUGIN_PATH_TYPE "development")
else ()
    # Install build
    set(PLUGIN_PATH "${CMAKE_INSTALL_PREFIX}/lib64")
    set(PLUGIN_PATH_TYPE "installed")
endif ()

########################################################################################################################
# Appropriate include paths
if(TARGET ${APP_NAME})
    # Ensure no link directories leak into INTERFACE to satisfy CMake export validation
    set_property(TARGET ${APP_NAME} PROPERTY INTERFACE_LINK_DIRECTORIES "")
    # Expose the overrides include folder (e.g., patched magic_enum headers) for installed consumers
    target_include_directories(${APP_NAME} INTERFACE
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}/overrides/magic_enum/include>
    )
endif()

#
# End of Configure !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
# Start of Install !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
#
# Need to tweak some locations. We'll keep it limited
if ("${APP_NAME}" STREQUAL "Core")
    set (_TARGET ${APP_VENDOR})
else ()
    set (_TARGET ${APP_NAME})
endif ()

install(TARGETS ${APP_NAME}
        EXPORT ${APP_NAME}Target
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} NAMELINK_SKIP
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} NAMELINK_SKIP
        CXX_MODULES_BMI
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_NAME}${CURRENT_GFX_LIB_PATH}
        FILE_SET CXX_MODULES
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}${CURRENT_GFX_LIB_PATH}
        FILE_SET HEADERS
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        INCLUDES
            DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(TARGETS ${APP_NAME}
        LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} NAMELINK_ONLY
        RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} NAMELINK_ONLY
)

if (BUILDING_APPEARANCE)
    install(TARGETS Appearance Print Logger
            EXPORT ${APP_NAME}Target
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME} NAMELINK_SKIP
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}/${APP_VENDOR}/${APP_NAME}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME} NAMELINK_SKIP
            CXX_MODULES_BMI
                DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_NAME}${CURRENT_GFX_LIB_PATH}
            FILE_SET CXX_MODULES
                DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_NAME}${CURRENT_GFX_LIB_PATH}
            FILE_SET HEADERS
                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
            INCLUDES
                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
    )

    install(TARGETS Appearance Print Logger
            LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME} NAMELINK_ONLY
            RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}/${APP_VENDOR}/${APP_NAME}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME} NAMELINK_ONLY
    )
endif ()

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
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_NAME}${CURRENT_GFX_LIB_PATH}
        FILES_MATCHING PATTERN *.pcm)

# Install export set for consumers (enabled by default)
option(HS_INSTALL_EXPORT "Install ${APP_NAME} export set" ON)
if(HS_INSTALL_EXPORT)
    install(EXPORT ${APP_NAME}Target
            FILE ${_TARGET}Target.cmake
            NAMESPACE ${APP_VENDOR}::
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
            CXX_MODULES_DIRECTORY .
    )
endif()

# Package config and target exports for find_package
include(CMakePackageConfigHelpers)
write_basic_package_version_file(
        "${CMAKE_CURRENT_BINARY_DIR}/${_TARGET}ConfigVersion.cmake"
        VERSION ${APP_VERSION}
        COMPATIBILITY SameMajorVersion
)

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

install(CODE [[
  set(_root "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}")
  message("Removing ${_root}/lib64/cmake/cxx")
  file(REMOVE_RECURSE "${_root}/lib64/cmake/cxx")
]])

# Install end-user documentation and resources (Linux only for now)
if(UNIX AND NOT APPLE)
    include(GNUInstallDirs)

    # User guide
    if(EXISTS "${CMAKE_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
        install(FILES "${CMAKE_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/doc/${_TARGET}")
    endif()
    # Resources directory (fonts, images, etc.)
    if(EXISTS "${CMAKE_SOURCE_DIR}/resources")
        install(DIRECTORY "${CMAKE_SOURCE_DIR}/resources/"
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/${APP_VENDOR}/${APP_NAME}/resources")
    endif()
    # If any desktop files are provided under resources/, install them to share/applications
    file(GLOB _hs_desktop_files "${CMAKE_SOURCE_DIR}/resources/*.desktop")
    if(_hs_desktop_files)
        install(FILES ${_hs_desktop_files}
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
    endif()
    unset(_hs_desktop_files)
endif()
