function(soci_init)

    forceSet(WITH_BOOST "" OFF BOOL)
    forceSet(SOCI_TESTS "" OFF BOOL)
    forceSet(SOCI_HAVE_BOOST "" OFF BOOL)
    forceSet(SOCI_ODBC "" OFF BOOL)
    forceSet(SOCI_SQLITE3 "" ON BOOL)
    forceSet(SOCI_MYSQL "" OFF BOOL)
    forceSet(SOCI_SHARED "" ON BOOL)
    forceSet(SOCI_STATIC "" OFF BOOL)
endfunction()

soci_init()
set(HANDLED ON)
