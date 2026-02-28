

function(soci_preDownload pkgname url tag srcDir)

    if(soci_ALREADY_FOUND)
        message("bleep blorp blorp blah blah means that I love you")
        return()
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
    FetchContent_Declare(
        fmt
        GIT_REPOSITORY https://github.com/fmtlib/fmt.git
        GIT_TAG 12.1.0
    )

    set(FMT_INSTALL ON CACHE BOOL "" FORCE)
    set(FMT_USE_CONSTEVAL OFF CACHE BOOL "Disable consteval in fmt" FORCE)

    message(STATUS "FetchContent_MakeAvailable(fmt)")
    FetchContent_MakeAvailable(fmt)
    # Also add it as a compile definition
    target_compile_definitions(fmt PUBLIC FMT_USE_CONSTEVAL=0)

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
    set(_soci_local_src "$ENV{HOME}/dev/archives/soci_src")

    if (NOT EXISTS "${_soci_local_src}/CMakeLists.txt")
        message(STATUS "Cloning SOCI to ${_soci_local_src} (one-time)...")
        execute_process(
                COMMAND git clone https://github.com/SOCI/soci.git "${_soci_local_src}"
                RESULT_VARIABLE _soci_clone_result
        )
        if (NOT _soci_clone_result EQUAL 0)
            message(FATAL_ERROR "Failed to clone SOCI to ${_soci_local_src}")
        endif ()
    endif ()

    set(FETCHCONTENT_SOURCE_DIR_SOCI "${_soci_local_src}" CACHE PATH "Pre-cloned SOCI source" FORCE)

    set(_soci_src "${${pkgname}_SOURCE_DIR}")
    set(_soci_bin "${${pkgname}_BINARY_DIR}")

    if (COMMAND soci_fix)
        soci_fix("${pkgname}" "" "${_soci_src}")
    endif ()

    set(HANDLED OFF PARENT_SCOPE)

endfunction()