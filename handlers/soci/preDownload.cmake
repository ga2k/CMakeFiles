function(soci_preDownload pkgname url tag srcDir)
    set(CMAKE_POLICY_DEFAULT_CMP0077 "NEW")

    forceSet(WITH_BOOST "" OFF BOOL)
    forceSet(SOCI_TESTS "" OFF BOOL)
    forceSet(SOCI_HAVE_BOOST "" OFF BOOL)
    forceSet(SOCI_ODBC "" OFF BOOL)
    forceSet(SOCI_SQLITE3 "" ON BOOL)
    forceSet(SOCI_MYSQL "" OFF BOOL)
    forceSet(SOCI_SHARED "" ON BOOL)
    forceSet(SOCI_STATIC "" OFF BOOL)

    # Disable all SOCI backends by default
    set(SOCI_EMPTY OFF CACHE BOOL "Disable SOCI Empty backend" FORCE)
    set(SOCI_DB2 OFF CACHE BOOL "Disable SOCI DB2 backend" FORCE)
    set(SOCI_FIREBIRD OFF CACHE BOOL "Disable SOCI Firebird backend" FORCE)
    set(SOCI_MYSQL OFF CACHE BOOL "Disable SOCI MySQL backend" FORCE)
    set(SOCI_ODBC OFF CACHE BOOL "Disable SOCI ODBC backend" FORCE)
    set(SOCI_ORACLE OFF CACHE BOOL "Disable SOCI Oracle backend" FORCE)
    set(SOCI_POSTGRESQL OFF CACHE BOOL "Disable SOCI PostgreSQL backend" FORCE)

    # Enable only the backends you want
    set(SOCI_SQLITE3 ON CACHE BOOL "Enable SOCI SQLite3 backend" FORCE)

endfunction()

soci_preDownload(${this_pkgname} ${this_url} ${this_tag} "${EXTERNALS_DIR}/${this_pkgname}")
set(HANDLED OFF)
