

function(soci_preDownload pkgname url tag srcDir)

    if (soci_ALREADY_FOUND)
        message("bleep blorp blorp blah blah means that I love you")
        return()
    endif ()

    # CMake 4.0 requires CMAKE_C_COMPILER in cache before SOCI's project(LANGUAGES C CXX)
    # runs EnableLanguage(C) via FetchContent. It detects the compiler fine but then errors
    # "CMAKE_C_COMPILER not set, after EnableLanguage" if the cache entry was never written.
    # Pre-populate it from the CXX compiler (both are Clang on this system).
    if (NOT CMAKE_C_COMPILER)
        string(REGEX REPLACE "clang\\+\\+" "clang" _soci_c_compiler "${CMAKE_CXX_COMPILER}")
        if (NOT EXISTS "${_soci_c_compiler}")
            find_program(_soci_c_compiler NAMES clang gcc cc)
        endif ()
        if (_soci_c_compiler)
            set(CMAKE_C_COMPILER "${_soci_c_compiler}" CACHE FILEPATH "C compiler (required by SOCI)" FORCE)
        endif ()
        unset(_soci_c_compiler)
    endif ()

    # @formatter:off
    set(CMAKE_POLICY_DEFAULT_CMP0077 "NEW")
    # This is the critical fix for the export set error
    # We set these to OFF to avoid SOCI's internal install() calls which cause export conflicts.
    # However, since SOCI doesn't seem to have a single master SOCI_INSTALL flag, 
    # we might need to rely on the fact that if we aren't careful, it will install anyway.
    set(SOCI_INSTALL         OFF CACHE BOOL "Disable SOCI internal install"   FORCE)
    set(SOCI_CORE_INSTALL    OFF CACHE BOOL "" FORCE)
    set(SOCI_SQLITE3_INSTALL OFF CACHE BOOL "" FORCE)
    set(SOCI_STATIC          OFF CACHE BOOL "" FORCE)
    # Patch SOCI to respect SOCI_INSTALL if it doesn't already
    set(SOCI_SKIP_INSTALL    ON  CACHE BOOL "" FORCE)
    set(SOCI_TESTS           OFF CACHE BOOL "" FORCE)

    set(SOCI_SQLITE3_BUILTIN ON CACHE BOOL "Prefer using built-in SQLite3"   FORCE)
    set(SOCI_FMT_BUILTIN    OFF CACHE BOOL "Prefer using built-in fmt"       FORCE)

    set(WITH_BOOST          OFF CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_TESTS          OFF CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_HAVE_BOOST     OFF CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_SHARED          ON CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_STATIC         OFF CACHE BOOL "Allow this feature"              FORCE)

    # Disable all SOCI backends by default
    set(SOCI_SQLITE3         ON CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_EMPTY          OFF CACHE BOOL "Disable SOCI Empty backend"      FORCE)
    set(SOCI_DB2            OFF CACHE BOOL "Disable SOCI DB2 backend"        FORCE)
    set(SOCI_FIREBIRD       OFF CACHE BOOL "Disable SOCI Firebird backend"   FORCE)
    set(SOCI_MYSQL          OFF CACHE BOOL "Disable SOCI MySQL backend"      FORCE)
    set(SOCI_ODBC           OFF CACHE BOOL "Disable SOCI ODBC backend"       FORCE)
    set(SOCI_ORACLE         OFF CACHE BOOL "Disable SOCI Oracle backend"     FORCE)
    set(SOCI_POSTGRESQL     OFF CACHE BOOL "Disable SOCI PostgreSQL backend" FORCE)

    # 1. Fetch fmt first with install enabled
    message(STATUS [=[
    FetchContent_Declare(
            fmt
            GIT_REPOSITORY https://github.com/fmtlib/fmt.git
            GIT_TAG 12.1.0
    )]=])
    # Use tarball URL instead of git to avoid the git ≥2.47 lazy objects/pack/
    # creation bug (index-pack fails when pack/ dir doesn't exist yet).
    FetchContent_Declare(
        fmt
        URL https://github.com/fmtlib/fmt/archive/refs/tags/12.1.0.tar.gz
    )

    # Libraries (Core) must install fmt so it lands in the stage dir.
    # Consumer apps (Executables) get fmt through the staged HoffSoft::Core — installing it
    # again would fail because the library was never compiled in the app's build tree.
    if (APP_TYPE STREQUAL "Library")
        set(FMT_INSTALL ON CACHE BOOL "" FORCE)
    else()
        set(FMT_INSTALL OFF CACHE BOOL "" FORCE)
    endif()
    set(FMT_USE_CONSTEVAL OFF CACHE BOOL "Disable consteval in fmt" FORCE)

    message(STATUS "FetchContent_MakeAvailable(fmt)")
    FetchContent_MakeAvailable(fmt)

    # 2. Point SOCI to our fmt installation
    set(fmt_DIR "${fmt_BINARY_DIR}" CACHE PATH "" FORCE)

    # 3. Now fetch SOCI and tell it to use the external fmt
    set(SOCI_INSTALL  OFF CACHE BOOL "Disable SOCI internal install" FORCE)
    set(SOCI_SQLITE3_BUILTIN ON CACHE BOOL "Prefer using built-in SQLite3" FORCE)
    set(SOCI_EXTERNAL_FMT ON CACHE BOOL "Use external fmt library" FORCE)
    set(SOCI_FMT_BUILTIN OFF CACHE BOOL "Use external fmt library" FORCE)

    # Love it like our own
    handleTarget("fmt")

    # @formatter:on

    # Use a persistent local clone so SOCI survives `make clean`
    set(_soci_local_src "${ARCHIVE_DIR}/soci/source")

    if (EXISTS "${_soci_local_src}" AND NOT EXISTS "${_soci_local_src}/CMakeLists.txt")
        file(REMOVE_RECURSE "${_soci_local_src}")
    endif ()

    if (NOT EXISTS "${_soci_local_src}/CMakeLists.txt")
        # Download as a tarball — avoids the git ≥2.47 lazy objects/pack/ bug that
        # causes index-pack to fail on any fresh git clone on this system.
        message(STATUS "Downloading SOCI to ${_soci_local_src} (one-time)...")
        file(MAKE_DIRECTORY "${ARCHIVE_DIR}/soci")
        set(_soci_tar "${ARCHIVE_DIR}/soci/soci-master.tar.gz")
        file(DOWNLOAD
            "https://github.com/SOCI/soci/archive/refs/heads/master.tar.gz"
            "${_soci_tar}"
            STATUS _dl_status
        )
        list(GET _dl_status 0 _dl_result)
        if (NOT _dl_result EQUAL 0)
            message(FATAL_ERROR "Failed to download SOCI: ${_dl_status}")
        endif ()
        if (NOT EXISTS "${_soci_tar}")
            message(FATAL_ERROR "SOCI download produced no file (status was ${_dl_status})")
        endif ()
        file(SIZE "${_soci_tar}" _soci_tar_size)
        if (_soci_tar_size LESS 65536)
            file(READ "${_soci_tar}" _soci_tar_head LIMIT 256 HEX)
            message(FATAL_ERROR "SOCI download too small (${_soci_tar_size} bytes) — HTTP error or rate-limit? First bytes: ${_soci_tar_head}")
        endif ()
        set(_soci_tmp "${ARCHIVE_DIR}/soci/_extract_tmp")
        file(MAKE_DIRECTORY "${_soci_tmp}")
        file(ARCHIVE_EXTRACT INPUT "${_soci_tar}" DESTINATION "${_soci_tmp}")
        file(GLOB _soci_extracted LIST_DIRECTORIES true "${_soci_tmp}/soci-*")
        if (NOT _soci_extracted)
            message(FATAL_ERROR "Could not find extracted SOCI dir in ${_soci_tmp}")
        endif ()
        list(GET _soci_extracted 0 _soci_extracted)
        file(RENAME "${_soci_extracted}" "${_soci_local_src}")
        file(REMOVE_RECURSE "${_soci_tmp}")
        file(REMOVE "${_soci_tar}")
    endif ()

    # Populate the sqlite3 amalgamation submodule — GitHub tarballs don't include
    # submodule content, so 3rdparty/sqlite3/ arrives empty from the archive.
    set(_sqlite3_dir "${_soci_local_src}/3rdparty/sqlite3")
    if (NOT EXISTS "${_sqlite3_dir}/sqlite3.c")
        message(STATUS "Downloading SQLite3 amalgamation for SOCI built-in...")
        file(MAKE_DIRECTORY "${ARCHIVE_DIR}/soci")
        set(_sqlite3_tar "${ARCHIVE_DIR}/soci/sqlite3-amalgamation.tar.gz")
        file(DOWNLOAD
            "https://github.com/vadz/sqlite-amalgamation/archive/refs/heads/master.tar.gz"
            "${_sqlite3_tar}"
            STATUS _dl_status
        )
        list(GET _dl_status 0 _dl_result)
        if (NOT _dl_result EQUAL 0)
            message(FATAL_ERROR "Failed to download SQLite3 amalgamation: ${_dl_status}")
        endif ()
        if (NOT EXISTS "${_sqlite3_tar}")
            message(FATAL_ERROR "SQLite3 amalgamation download produced no file (status was ${_dl_status})")
        endif ()
        file(SIZE "${_sqlite3_tar}" _sqlite3_tar_size)
        if (_sqlite3_tar_size LESS 4096)
            file(READ "${_sqlite3_tar}" _sqlite3_tar_head LIMIT 256 HEX)
            message(FATAL_ERROR "SQLite3 amalgamation download too small (${_sqlite3_tar_size} bytes) — HTTP error or rate-limit? First bytes: ${_sqlite3_tar_head}")
        endif ()
        set(_sqlite3_tmp "${ARCHIVE_DIR}/soci/_sqlite3_tmp")
        file(MAKE_DIRECTORY "${_sqlite3_tmp}")
        file(ARCHIVE_EXTRACT INPUT "${_sqlite3_tar}" DESTINATION "${_sqlite3_tmp}")
        file(GLOB _sqlite3_extracted LIST_DIRECTORIES true "${_sqlite3_tmp}/sqlite-amalgamation-*")
        if (NOT _sqlite3_extracted)
            message(FATAL_ERROR "Could not find extracted sqlite3 dir in ${_sqlite3_tmp}")
        endif ()
        list(GET _sqlite3_extracted 0 _sqlite3_extracted)
        file(COPY "${_sqlite3_extracted}/" DESTINATION "${_sqlite3_dir}")
        file(REMOVE_RECURSE "${_sqlite3_tmp}")
        file(REMOVE "${_sqlite3_tar}")
    endif ()

    if (NOT soci_PATCHED)
        unset(patches)
        list(APPEND patches
                # Test whole folder
                "soci/3rdparty|${_soci_local_src}/3rdparty"
                # Test single file
                "soci/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/fmt-src/include/fmt/"

                "soci/include|${_soci_local_src}/include"

                "soci/CMakeLists.txt|${_soci_local_src}"
                "soci/src/core/CMakeLists.txt|${_soci_local_src}/src/core"

                "soci/cmake/soci_define_backend_target.cmake|${_soci_local_src}/cmake"

                "soci/src|${_soci_local_src}/src"
        )
        replaceFiles(soci "${patches}")
    endif ()
    set(soci_PATCHED ON PARENT_SCOPE)

#    if (NOT soci_PATCHED)
#        unset(patches)
#        list(APPEND patches
##                "soci/3rdparty/fmt/include|${_soci_local_src}"
##                "soci/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/fmt-src/include/fmt/"
##
##                "soci/include|${_soci_local_src}"
##
##                "soci/CMakeLists.txt|${_soci_local_src}"
##                "soci/cmake/soci_define_backend_target.cmake|${_soci_local_src}"
##
#                #            "soci/src/core/CMakeLists.txt|${sourceDir}"
##                "soci/src|${_soci_local_src}"
#        )
#
#        replaceFile(soci "${patches}")
#    endif ()
    set(soci_PATCHED ON PARENT_SCOPE)

    set(FETCHCONTENT_SOURCE_DIR_SOCI "${_soci_local_src}" CACHE PATH "Pre-cloned SOCI source" FORCE)

    set(_soci_src "${${pkgname}_SOURCE_DIR}")
    set(_soci_bin "${${pkgname}_BINARY_DIR}")

    set(HANDLED OFF)
    set(HANDLED ${HANDLED} PARENT_SCOPE)

endfunction()