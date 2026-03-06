# PresetFallback.cmake
# Replicates any Debug/Release × Shared/Static configure preset for macOS, Windows, and Linux.
# Include this file early in your root CMakeLists.txt, then call fixPresetMess()
# if you detect that CLion has dropped the preset.
#
# Usage:
#   include(PresetFallback.cmake)
#   if(NOT DEFINED buildType)   # or however you detect the missing preset
#       fixPresetMess("Debug" "Shared")
#   endif()
#
# Arguments:
#   ARG_BUILD_TYPE  – "Debug" or "Release"
#   ARG_LINK_TYPE   – "Shared" or "Static"

macro(fixPresetMess ARG_BUILD_TYPE ARG_LINK_TYPE)

    # --- Validate arguments ---
    if(NOT ARG_BUILD_TYPE STREQUAL "Debug" AND NOT ARG_BUILD_TYPE STREQUAL "Release")
        message(FATAL_ERROR "fixPresetMess: ARG_BUILD_TYPE must be 'Debug' or 'Release', got '${ARG_BUILD_TYPE}'")
    endif()
    if(NOT ARG_LINK_TYPE STREQUAL "Shared" AND NOT ARG_LINK_TYPE STREQUAL "Static")
        message(FATAL_ERROR "fixPresetMess: ARG_LINK_TYPE must be 'Shared' or 'Static', got '${ARG_LINK_TYPE}'")
    endif()

    # --- Compute paths from arguments (mirrors preset inheritance) ---
    string(TOLOWER "${ARG_BUILD_TYPE}" _buildPathSuffix)   # "debug" or "release"
    string(TOLOWER "${ARG_LINK_TYPE}"  _linkPathSuffix)    # "shared" or "static"
    set(_buildPath "/${_buildPathSuffix}")                 # e.g. /debug
    set(_linkPath  "/${_linkPathSuffix}")                  # e.g. /shared
    set(_stemPath  "${_buildPath}${_linkPath}")            # e.g. /debug/shared

    # ------------------------------------------------------------------
    # macOS  –  inherits: macOS + ${ARG_BUILD_TYPE} + ${ARG_LINK_TYPE}
    # ------------------------------------------------------------------
    if(CMAKE_HOST_SYSTEM_NAME STREQUAL "Darwin")

        # --- ENV vars (macOS base) ---
        set(ENV{hostType}   "macOS")
        set(ENV{hostPath}   "/macos")
        set(ENV{archType}   "arm64")
        set(ENV{archPath}   "/arm64")
        set(ENV{CMAKE_NINJA_FLAGS} "-k 0")

        # --- ENV vars (build type) ---
        set(ENV{buildType}  "${ARG_BUILD_TYPE}")
        set(ENV{buildPath}  "${_buildPath}")

        # --- ENV vars (link type) ---
        set(ENV{linkType}   "${ARG_LINK_TYPE}")
        set(ENV{linkPath}   "${_linkPath}")

        # --- Derived ENV (binaryDir / stemPath equivalent) ---
        set(ENV{stemPath}   "${_stemPath}")   # $buildPath$linkPath

        # --- CACHE vars (macOS base) ---
        set(CMAKE_C_COMPILER        "/opt/homebrew/opt/llvm/bin/clang"   CACHE STRING "" FORCE)
        set(CMAKE_CXX_COMPILER      "/opt/homebrew/opt/llvm/bin/clang++" CACHE STRING "" FORCE)
        set(CMAKE_OSX_SYSROOT       "macosx"                             CACHE STRING "" FORCE)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "26.0"                           CACHE STRING "" FORCE)
        set(CMAKE_SHARED_LINKER_FLAGS
            "-L/opt/homebrew/Cellar/llvm/21.1.5/lib/c++ -Wl,-rpath,/opt/homebrew/Cellar/llvm/21.1.5/lib/c++ /opt/homebrew/Cellar/llvm/21.1.5/lib/c++/libc++.1.0.dylib /opt/homebrew/Cellar/llvm/21.1.5/lib/c++/libc++abi.dylib"
            CACHE STRING "" FORCE)
        set(CMAKE_EXE_LINKER_FLAGS
            "-L/opt/homebrew/Cellar/llvm/21.1.5/lib/c++ -Wl,-rpath,/opt/homebrew/Cellar/llvm/21.1.5/lib/c++ /opt/homebrew/Cellar/llvm/21.1.5/lib/c++/libc++.1.0.dylib /opt/homebrew/Cellar/llvm/21.1.5/lib/c++/libc++abi.dylib"
            CACHE STRING "" FORCE)
        set(OPENSSL_ROOT_DIR        "/opt/local"                                              CACHE PATH   "" FORCE)
        set(OPENSSL_PATH            "/opt/local/libexec/openssl3/lib/cmake/OpenSSL"           CACHE PATH   "" FORCE)
        set(OPENSSL_INCLUDE_DIR     "/opt/local/include/openssl-3"                            CACHE PATH   "" FORCE)
        set(OPENSSL_CRYPTO_LIBRARY  "/opt/local/lib/openssl-3/libcrypto.dylib"                CACHE FILEPATH "" FORCE)
        set(OPENSSL_SSL_LIBRARY     "/opt/local/lib/openssl-3/libssl.dylib"                   CACHE FILEPATH "" FORCE)
        set(BUILD_WX_FROM_SOURCE    "ON"                                 CACHE BOOL   "" FORCE)

        # --- CACHE vars (build/link type) ---
        set(buildType  "${ARG_BUILD_TYPE}" CACHE STRING "" FORCE)
        set(linkType   "${ARG_LINK_TYPE}"  CACHE STRING "" FORCE)

        # --- CACHE var (stemPath – set by the named preset itself) ---
        set(stemPath   "${_stemPath}" CACHE STRING "" FORCE)

        # --- PARENT_SCOPE vars (mirror of the above for callers) ---
        set(hostType   "macOS"            PARENT_SCOPE)
        set(hostPath   "/macos"           PARENT_SCOPE)
        set(archType   "arm64"            PARENT_SCOPE)
        set(archPath   "/arm64"           PARENT_SCOPE)
        set(buildType  "${ARG_BUILD_TYPE}" PARENT_SCOPE)
        set(buildPath  "${_buildPath}"     PARENT_SCOPE)
        set(linkType   "${ARG_LINK_TYPE}"  PARENT_SCOPE)
        set(linkPath   "${_linkPath}"      PARENT_SCOPE)
        set(stemPath   "${_stemPath}"      PARENT_SCOPE)

    # ------------------------------------------------------------------
    # Windows  –  inherits: Windows (Ninja/LLVM) + ${ARG_BUILD_TYPE} + ${ARG_LINK_TYPE}
    # ------------------------------------------------------------------
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Windows")

        # --- ENV vars (Windows base) ---
        set(ENV{hostType}   "Windows")
        set(ENV{hostPath}   "/winllvm")
        set(ENV{archType}   "x64")
        set(ENV{archPath}   "/x64")
        set(ENV{CMAKE_NINJA_FLAGS} "-k 0")

        # --- ENV vars (build type) ---
        set(ENV{buildType}  "${ARG_BUILD_TYPE}")
        set(ENV{buildPath}  "${_buildPath}")

        # --- ENV vars (link type) ---
        set(ENV{linkType}   "${ARG_LINK_TYPE}")
        set(ENV{linkPath}   "${_linkPath}")

        # --- Derived ENV ---
        set(ENV{stemPath}   "${_stemPath}")

        # --- CACHE vars (Windows base) ---
        set(BUILD_WX_FROM_SOURCE "ON" CACHE BOOL "" FORCE)
        set(CMAKE_CXX_COMPILER
            "C:/Program Files/LLVM/bin/clang++.exe"          CACHE FILEPATH "" FORCE)
        set(CMAKE_CXX_COMPILER_CLANG_SCAN_DEPS
            "C:/Program Files/LLVM/bin/clang-scan-deps.exe"  CACHE FILEPATH "" FORCE)
        set(CMAKE_C_COMPILER
            "C:/Program Files/LLVM/bin/clang.exe"            CACHE FILEPATH "" FORCE)
        set(CMAKE_LINKER
            "C:/Program Files/LLVM/bin/lld-link.exe"         CACHE FILEPATH "" FORCE)
        set(CMAKE_RC_COMPILER
            "C:/Program Files/LLVM/bin/llvm-rc.exe"          CACHE FILEPATH "" FORCE)
        set(CMAKE_SYSTEM_NAME      "Windows" CACHE STRING "" FORCE)
        set(CMAKE_SYSTEM_PROCESSOR "AMD64"   CACHE STRING "" FORCE)

        # --- CACHE vars (build/link type) ---
        set(buildType  "${ARG_BUILD_TYPE}" CACHE STRING "" FORCE)
        set(linkType   "${ARG_LINK_TYPE}"  CACHE STRING "" FORCE)

        # --- CACHE var (stemPath) ---
        set(stemPath   "${_stemPath}" CACHE STRING "" FORCE)

        # --- PARENT_SCOPE vars ---
        set(hostType   "Windows"           PARENT_SCOPE)
        set(hostPath   "/winllvm"          PARENT_SCOPE)
        set(archType   "x64"               PARENT_SCOPE)
        set(archPath   "/x64"              PARENT_SCOPE)
        set(buildType  "${ARG_BUILD_TYPE}" PARENT_SCOPE)
        set(buildPath  "${_buildPath}"     PARENT_SCOPE)
        set(linkType   "${ARG_LINK_TYPE}"  PARENT_SCOPE)
        set(linkPath   "${_linkPath}"      PARENT_SCOPE)
        set(stemPath   "${_stemPath}"      PARENT_SCOPE)

    # ------------------------------------------------------------------
    # Linux  –  inherits: Linux + ${ARG_BUILD_TYPE} + ${ARG_LINK_TYPE}
    # ------------------------------------------------------------------
    elseif(CMAKE_HOST_SYSTEM_NAME STREQUAL "Linux")

        # --- ENV vars (Linux base) ---
        set(ENV{hostType}   "Linux")
        set(ENV{hostPath}   "/linux")
        set(ENV{archType}   "x64")
        set(ENV{archPath}   "/x64")
        set(ENV{CMAKE_NINJA_FLAGS} "-k 0")

        # --- ENV vars (build type) ---
        set(ENV{buildType}  "${ARG_BUILD_TYPE}")
        set(ENV{buildPath}  "${_buildPath}")

        # --- ENV vars (link type) ---
        set(ENV{linkType}   "${ARG_LINK_TYPE}")
        set(ENV{linkPath}   "${_linkPath}")

        # --- Derived ENV ---
        set(ENV{stemPath}   "${_stemPath}")

        # --- CACHE vars (Linux base) ---
        set(CMAKE_C_COMPILER   "/usr/bin/clang"   CACHE FILEPATH "" FORCE)
        set(CMAKE_CXX_COMPILER "/usr/bin/clang++" CACHE FILEPATH "" FORCE)
        set(BUILD_WX_FROM_SOURCE "ON"             CACHE BOOL     "" FORCE)

        # --- CACHE vars (build/link type) ---
        set(buildType  "${ARG_BUILD_TYPE}" CACHE STRING "" FORCE)
        set(linkType   "${ARG_LINK_TYPE}"  CACHE STRING "" FORCE)

        # --- CACHE var (stemPath) ---
        set(stemPath   "${_stemPath}" CACHE STRING "" FORCE)

        # --- PARENT_SCOPE vars ---
        set(hostType   "Linux"             PARENT_SCOPE)
        set(hostPath   "/linux"            PARENT_SCOPE)
        set(archType   "x64"               PARENT_SCOPE)
        set(archPath   "/x64"              PARENT_SCOPE)
        set(buildType  "${ARG_BUILD_TYPE}" PARENT_SCOPE)
        set(buildPath  "${_buildPath}"     PARENT_SCOPE)
        set(linkType   "${ARG_LINK_TYPE}"  PARENT_SCOPE)
        set(linkPath   "${_linkPath}"      PARENT_SCOPE)
        set(stemPath   "${_stemPath}"      PARENT_SCOPE)

    else()
        message(WARNING "fixPresetMess: unrecognised host platform '${CMAKE_HOST_SYSTEM_NAME}' – no variables set.")
    endif()

endmacro()
