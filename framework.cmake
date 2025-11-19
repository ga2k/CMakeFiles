include_guard(GLOBAL)

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
set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE CACHE STRING "Log Level" FORCE)

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -g")
set(CMAKE_CXX_SCAN_FOR_MODULES ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_VISIBILITY_PRESET hidden)
set(CMAKE_VERBOSE_MAKEFILE ON)
set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)

# Shared CMake module paths (stage + repo cmake directory)
set(staged "$ENV{HOME}/dev/stage/usr/local/lib64/cmake")
list(APPEND CMAKE_MODULE_PATH
        ${CMAKE_SOURCE_DIR}/cmake
        ${staged}
)

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

# Shared feature/platform setup and environment checks
include(${CMAKE_SOURCE_DIR}/cmake/tools.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/check_environment.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/fetchContents.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/addLibrary.cmake)

# The environment check validates OUTPUT_DIR etc.; call once globally
check_environment("${CMAKE_SOURCE_DIR}")

include(${CMAKE_SOURCE_DIR}/cmake/platform.cmake)
initialiseFeatureHandlers()

# Make CMake find_package prefer our install libdir
list(APPEND CMAKE_PREFIX_PATH ${CMAKE_INSTALL_LIBDIR})

# Fetch common third-party dependencies controlled by APP_FEATURES from each project
# We leave the actual fetchContents() call to per-project setup so projects can pass hints.

# Testing helpers available globally
include(GoogleTest)
