function(soci_init)

    # @formatter:off
    set(CMAKE_POLICY_DEFAULT_CMP0077 "NEW")
    # This is the critical fix for the export set error
    set(SOCI_INSTALL         OFF CACHE BOOL "Disable SOCI internal install"     FORCE)

    set(SOCI_SQLITE3_BUILTIN  ON CACHE STRING "Prefer using built-in SQLite3"   FORCE)
    set(SOCI_FMT_BUILTIN      ON CACHE STRING "Prefer using built-in fmt"       FORCE)

    set(WITH_BOOST           OFF CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_TESTS           OFF CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_HAVE_BOOST      OFF CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_ODBC            OFF CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_SQLITE3          ON CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_MYSQL           OFF CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_SHARED           ON CACHE BOOL   "Allow this feature"              FORCE)
    set(SOCI_STATIC          OFF CACHE BOOL   "Allow this feature"              FORCE)

    # Disable all SOCI backends by default
    set(SOCI_EMPTY           OFF CACHE BOOL   "Disable SOCI Empty backend"      FORCE)
    set(SOCI_DB2             OFF CACHE BOOL   "Disable SOCI DB2 backend"        FORCE)
    set(SOCI_FIREBIRD        OFF CACHE BOOL   "Disable SOCI Firebird backend"   FORCE)
    set(SOCI_MYSQL           OFF CACHE BOOL   "Disable SOCI MySQL backend"      FORCE)
    set(SOCI_ODBC            OFF CACHE BOOL   "Disable SOCI ODBC backend"       FORCE)
    set(SOCI_ORACLE          OFF CACHE BOOL   "Disable SOCI Oracle backend"     FORCE)
    set(SOCI_POSTGRESQL      OFF CACHE BOOL   "Disable SOCI PostgreSQL backend" FORCE)

    # Enable only the backends you want
    set(SOCI_SQLITE3          ON CACHE BOOL "Enable SOCI SQLite3 backend"       FORCE)

    set(HANDLED              OFF PARENT_SCOPE)
    # @formatter:on

endfunction()
