include_guard(GLOBAL)

# Shared feature/platform setup and environment checks
include(${cmake_root}/tools.cmake)
include(${cmake_root}/fetchContents.cmake)
include(${cmake_root}/addLibrary.cmake)
include(${cmake_root}/check_environment.cmake)
include(${cmake_root}/sqlish.cmake)

# The environment check validates OUTPUT_DIR etc.; call once globally
check_environment("${CMAKE_SOURCE_DIR}")

# Derivations of common metadata (safe globally)
string(TOUPPER ${APP_NAME} APP_NAME_UC)
string(TOLOWER ${APP_NAME} APP_NAME_LC)
string(TOUPPER ${APP_VENDOR} APP_VENDOR_UC)
string(TOLOWER ${APP_VENDOR} APP_VENDOR_LC)

# Capture compiler version information (used for flags below)
execute_process(
        COMMAND ${CMAKE_CXX_COMPILER} -v
        ERROR_VARIABLE compiler_version
        OUTPUT_QUIET
)

# Global policy/verbosity/tooling
set(CMAKE_WARN_UNINITIALIZED ON)
set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE CACHE STRING "Log Level")

# Disable automatic RPATH to avoid circular dependencies
set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)

# Set explicit RPATH for build and install
set(CMAKE_BUILD_RPATH "${OUTPUT_DIR}/bin;${OUTPUT_DIR}/lib;${OUTPUT_DIR}/dll")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -g")
#set(CMAKE_CXX_SCAN_FOR_MODULES ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if (APPLE)
    set(CMAKE_CXX_VISIBILITY_PRESET default)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)
else()
    set(CMAKE_CXX_VISIBILITY_PRESET hidden)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
endif()
set(CMAKE_VERBOSE_MAKEFILE ON)

# Global accumulators provided by framework users
set(extra_CompileOptions)
set(extra_Definitions)
set(extra_IncludePaths)
set(extra_LibrariesList)
set(extra_LibraryPaths)
set(extra_LinkOptions)

# Optional backtrace library for std::stacktrace
find_library(BACKTRACE_LIB backtrace)
find_library(STDCXX_BACKTRACE_LIB stdc++_libbacktrace)
if (BACKTRACE_LIB)
    list(APPEND extra_LibrariesList ${BACKTRACE_LIB})
elseif (STDCXX_BACKTRACE_LIB)
    list(APPEND extra_LibrariesList ${STDCXX_BACKTRACE_LIB})
endif ()

# Extra compile flags for clang module handling
if ("${compiler_version}" MATCHES "clang")
    list(APPEND extra_CompileOptions
            -fno-implicit-modules
            -fno-implicit-module-maps
            -Wno-unused-command-line-argument
            -Wno-enum-compare-switch
    )
endif ()

include(${cmake_root}/platform.cmake)

# Make CMake find_package prefer our install libdir
list(PREPEND CMAKE_MODULE_PATH
        ${CMAKE_INSTALL_LIBDIR})

# Testing helpers available globally
include(GoogleTest)

function(commonInit pkg discovery_phase)

    string(TOUPPER "${pkg}" _PKG)
    set(findex -1)
    set(foundFind -1)
    set(foundUse -1)

    globalObjGet(GLOBAL_FEATURES _FEATURES)
    if(discovery_phase)

        foreach (feet IN LISTS _FEATURES)
            math(EXPR findex "${findex} + 1")

            separate_arguments(_feet NATIVE_COMMAND "${feet}")
            cmake_parse_arguments("AAZ" "REQUIRED;OPTIONAL" "PACKAGE;NAMESPACE" "PATHS;HINTS" ${_feet})
            if (AAZ_UNPARSED_ARGUMENTS)
                list(GET AAZ_UNPARSED_ARGUMENTS 0 AAZ_FEATURE)
                if (AAZ_FEATURE STREQUAL _PKG AND AAZ_PACKAGE STREQUAL Find${pkg})
                    set(foundFind ${findex})
                elseif (AAZ_FEATURE STREQUAL _PKG AND AAZ_PACKAGE STREQUAL ${pkg})
                    set(foundUse ${findex})
                endif ()
            endif ()
        endforeach ()

        if(foundFind GREATER_EQUAL 0 AND foundFind GREATER foundUse)
            list(REMOVE_AT _FEATURES ${foundFind})
            if (foundUse GREATER_EQUAL 0)
                list(REMOVE_AT _FEATURES ${foundUse})
            endif ()
        elseif(foundUse GREATER_EQUAL 0 AND foundUse GREATER foundFind)
            list(REMOVE_AT _FEATURES ${foundUse})
            if(foundFind GREATER_EQUAL 0)
                list(REMOVE_AT _FEATURES ${foundFind})
            endif ()
        else ()
            # They can only be the same if they are both -1, and in that case we do nothing
        endif ()

        if (foundFind GREATER_EQUAL 0 AND foundUse LESS 0)
            list(INSERT _FEATURES ${foundFind} "${_PKG} PACKAGE ${pkg} ARGS PATHS {${pkg}}")
#            list(PREPEND _FEATURES "${_PKG} PACKAGE ${pkg} ARGS PATHS {${pkg}}")
        endif ()

        globalObjSet(GLOBAL_FEATURES "${_FEATURES}")

        set(fn "add${pkg}Features")
        cmake_language(CALL registerPackageCallback "${fn}" ${discovery_phase})
    endif ()
    set(HANDLED ON)

endfunction()
