function(soci_preDownload pkgname url tag srcDir)

    # @formatter:off
    set(CMAKE_POLICY_DEFAULT_CMP0077 "NEW")
    # This is the critical fix for the export set error
    set(SOCI_INSTALL        "OFF" CACHE STRING "Disable SOCI internal install"   FORCE)

    set(SOCI_SQLITE3_BUILTIN "ON" CACHE STRING "Prefer using built-in SQLite3"   FORCE)
    set(SOCI_FMT_BUILTIN     "ON" CACHE STRING "Prefer using built-in fmt"       FORCE)

    set(WITH_BOOST          "OFF" CACHE STRING "Allow this feature"              FORCE)
    set(SOCI_TESTS          "OFF" CACHE STRING "Allow this feature"              FORCE)
    set(SOCI_HAVE_BOOST     "OFF" CACHE STRING "Allow this feature"              FORCE)
    set(SOCI_SHARED          "ON" CACHE STRING "Allow this feature"              FORCE)
    set(SOCI_STATIC         "OFF" CACHE STRING "Allow this feature"              FORCE)

    # Disable all SOCI backends by default
    set(SOCI_SQLITE3         "ON" CACHE STRING "Allow this feature"              FORCE)
    set(SOCI_EMPTY          "OFF" CACHE STRING "Disable SOCI Empty backend"      FORCE)
    set(SOCI_DB2            "OFF" CACHE STRING "Disable SOCI DB2 backend"        FORCE)
    set(SOCI_FIREBIRD       "OFF" CACHE STRING "Disable SOCI Firebird backend"   FORCE)
    set(SOCI_MYSQL          "OFF" CACHE STRING "Disable SOCI MySQL backend"      FORCE)
    set(SOCI_ODBC           "OFF" CACHE STRING "Disable SOCI ODBC backend"       FORCE)
    set(SOCI_ORACLE         "OFF" CACHE STRING "Disable SOCI Oracle backend"     FORCE)
    set(SOCI_POSTGRESQL     "OFF" CACHE STRING "Disable SOCI PostgreSQL backend" FORCE)

    # 1. Fetch fmt first with install enabled
    message(STATUS [=[

    FetchContent_Declare(
            fmt
            GIT_REPOSITORY https://github.com/fmtlib/fmt.git
            GIT_TAG 10.2.1
    )]=])
    FetchContent_Declare(
        fmt
        GIT_REPOSITORY https://github.com/fmtlib/fmt.git
        GIT_TAG 10.2.1
    )

    set(FMT_INSTALL ON CACHE BOOL "" FORCE)

    message(STATUS "FetchContent_MakeAvailable(fmt)")
    FetchContent_MakeAvailable(fmt)

    # 2. Point SOCI to our fmt installation
    set(fmt_DIR "${fmt_BINARY_DIR}" CACHE PATH "" FORCE)

    # 3. Now fetch SOCI and tell it to use the external fmt
    set(SOCI_INSTALL OFF CACHE BOOL "Disable SOCI internal install" FORCE)
    set(SOCI_SQLITE3_BUILTIN ON CACHE BOOL "Prefer using built-in SQLite3" FORCE)
    set(SOCI_EXTERNAL_FMT ON CACHE BOOL "Use external fmt library" FORCE)
    set(SOCI_FMT_BUILTIN OFF CACHE BOOL "Use external fmt library" FORCE)

    # @formatter:on

endfunction()
