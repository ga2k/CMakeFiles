function(soci_preDownload pkgname url tag srcDir)

    # @formatter:off
    set(CMAKE_POLICY_DEFAULT_CMP0077 "NEW")
    # This is the critical fix for the export set error
    set(SOCI_INSTALL         OFF PARENT_SCOPE)
    set(SOCI_INSTALL         OFF CACHE BOOL "Disable SOCI internal install"   FORCE)

    set(SOCI_SQLITE3_BUILTIN  ON PARENT_SCOPE)
    set(SOCI_SQLITE3_BUILTIN  ON CACHE BOOL "Prefer using built-in SQLite3"   FORCE)
    set(SOCI_FMT_BUILTIN      ON PARENT_SCOPE)
    set(SOCI_FMT_BUILTIN      ON CACHE BOOL "Prefer using built-in fmt"       FORCE)

    set(WITH_BOOST           OFF PARENT_SCOPE)
    set(WITH_BOOST           OFF CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_TESTS           OFF PARENT_SCOPE)
    set(SOCI_TESTS           OFF CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_HAVE_BOOST      OFF PARENT_SCOPE)
    set(SOCI_HAVE_BOOST      OFF CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_SHARED           ON PARENT_SCOPE)
    set(SOCI_SHARED           ON CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_STATIC          OFF PARENT_SCOPE)
    set(SOCI_STATIC          OFF CACHE BOOL "Allow this feature"              FORCE)

    # Disable all SOCI backends by default
    set(SOCI_SQLITE3          ON PARENT_SCOPE)
    set(SOCI_SQLITE3          ON CACHE BOOL "Allow this feature"              FORCE)
    set(SOCI_EMPTY           OFF PARENT_SCOPE)
    set(SOCI_EMPTY           OFF CACHE BOOL "Disable SOCI Empty backend"      FORCE)
    set(SOCI_DB2             OFF PARENT_SCOPE)
    set(SOCI_DB2             OFF CACHE BOOL "Disable SOCI DB2 backend"        FORCE)
    set(SOCI_FIREBIRD        OFF PARENT_SCOPE)
    set(SOCI_FIREBIRD        OFF CACHE BOOL "Disable SOCI Firebird backend"   FORCE)
    set(SOCI_MYSQL           OFF PARENT_SCOPE)
    set(SOCI_MYSQL           OFF CACHE BOOL "Disable SOCI MySQL backend"      FORCE)
    set(SOCI_ODBC            OFF PARENT_SCOPE)
    set(SOCI_ODBC            OFF CACHE BOOL "Disable SOCI ODBC backend"       FORCE)
    set(SOCI_ORACLE          OFF PARENT_SCOPE)
    set(SOCI_ORACLE          OFF CACHE BOOL "Disable SOCI Oracle backend"     FORCE)
    set(SOCI_POSTGRESQL      OFF PARENT_SCOPE)
    set(SOCI_POSTGRESQL      OFF CACHE BOOL "Disable SOCI PostgreSQL backend" FORCE)

    set(HANDLED              OFF PARENT_SCOPE)
    # @formatter:on

endfunction()
