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
    list(APPEND extra_CompileOptions "-fno-implicit-modules;-fno-implicit-module-maps")
endif ()

include(${cmake_root}/platform.cmake)

# Make CMake find_package prefer our install libdir
list(PREPEND CMAKE_MODULE_PATH
        ${CMAKE_INSTALL_LIBDIR})

# Testing helpers available globally
include(GoogleTest)

function(fittest)

    set(flags ADD_ALWAYS)
    set(options PACKAGE FILENAME OUTPUT SOURCE_DIR STAGED_DIR SYSTEM_DIR)
    set(lists "")

    cmake_parse_arguments("AA" "${flags}" "${options}" "${lists}" ${ARGN})

    set(candidates)
    set(conditionals)

    set(actualSourceFile "${SOURCE_DIR}/${AA_FILENAME}")
    set(actualStagedFile "${STAGED_DIR}/${AA_FILENAME}")
    set(actualSystemFile "${SYSTEM_DIR}/${AA_FILENAME}")

    foreach (f IN ITEMS "actualStagedFile" "actualSourceFile" "actualSystemFile")
        set(file "${f}")
        if (EXISTS "${file}" OR AA_ADD_ALWAYS)
            if (EXISTS "${file}")
                msg("  Found ${file}")
                set(${f}Found ON)
                list(PREPEND candidates "${file}")
            else ()
                msg("Missing ${file} but still added it to list")
                set(${f}Found OFF)
                list(APPEND conditionals "${file}")
            endif ()
        else ()
            msg("Missing ${${file}}")
            set(${f}Found OFF)
        endif ()
    endforeach ()
    msg()

    # Staged and Source files are the same?
    if (actualSourceFileFound AND actualStagedFileFound
            AND "${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}"
            AND "${actualStagedFile}" IS_NEWER_THAN "${actualSourceFile}")

        msg("Source and Staged are the same. We'll use Staged.")
        list(REMOVE_ITEM candidates "${actualStagedFileFound}")
        list(INSERT candidates 0 "${actualStagedFileFound}")
    endif ()

    list(APPEND candidates "${conditionals}")

    set(listOfFolders)
    foreach (candidate IN LISTS candidates)
        get_filename_component(candidate "${candidate}" PATH)
        list(APPEND listOfFolders "${candidate}")
    endforeach ()

    set(${outList} ${listOfFolders} PARENT_SCOPE)

endfunction()
