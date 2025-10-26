function(soci_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of soci")
    endif ()

    set(p0 ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${p0} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${p0} 0 ${subLength} p0)

    message("Applying local patches to ${p0}...")

    ReplaceInFile("${sourceDir}/CMakeLists.txt" "VERSION 2.8 FATAL_ERROR" "VERSION 3.5 FATAL_ERROR")
    ReplaceInFile("${sourceDir}/CMakeLists.txt" "option(SOCI_TESTS \"Enable build of collection of SOCI tests\" ON)" "option(SOCI_TESTS \"Enable build of collection of SOCI tests\" OFF)")

    ReplaceInFile("${sourceDir}/src/backends/sqlite3/statement.cpp" "if (ssize(columns_) < colNum)" "if (soci::ssize(columns_) < colNum)")
    ReplaceInFile("${sourceDir}/src/backends/sqlite3/statement.cpp" " ssize" " soci::ssize")
    ReplaceInFile("${sourceDir}/src/backends/sqlite3/vector-into-type.cpp" " ssize" " soci::ssize")
    ReplaceInFile("${sourceDir}/src/core/soci-simple.cpp" " ssize" " soci::ssize")
    ReplaceInFile("${sourceDir}/src/core/statement.cpp" " ssize" " soci::ssize")

endfunction()

soci_fix("${this_pkgname}" "${this_tag}" "${this_src}")
set(HANDLED ON)
