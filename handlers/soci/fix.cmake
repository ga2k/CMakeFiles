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

    # Patch blob.h to move destructor to the .cpp file, fixing the incomplete type error with dllexport
    set(BLOB_H "${EXTERNALS_DIR}/soci/include/soci/blob.h")
    set(BLOB_CPP "${EXTERNALS_DIR}/soci/src/core/blob.cpp")

    # 1. Remove the inline default destructor and constructor from the header
    ReplaceInFile(${BLOB_H} "blob() = default;" "blob();")
    ReplaceInFile(${BLOB_H} "~blob() = default;" "~blob();")
    ReplaceInFile(${BLOB_H} "blob(blob &&other) = default;" "blob(blob &&other);")
    ReplaceInFile(${BLOB_H} "blob &operator=(blob &&other) = default;" "blob &operator=(blob &&other);")

    # 2. Add the implementations to the .cpp file where blob_backend is (usually) included or defined
    ReplaceInFile(${BLOB_CPP} "blob::~blob() = default;\n" "")
    ReplaceInFile(${BLOB_CPP} "soci::blob::blob() {}\n" "")
    ReplaceInFile(${BLOB_CPP} "soci::blob::~blob() {}\n" "")
    ReplaceInFile(${BLOB_CPP} "soci::blob::blob(blob &&other) noexcept {};\n" "")
    ReplaceInFile(${BLOB_CPP} "soci::blob &soci::blob::operator=(blob &&other) noexcept = default;\n" "")

    file(APPEND ${BLOB_CPP}
            "soci::blob::blob() {}\n"
            "soci::blob::~blob() {}\n"
            "soci::blob::blob(blob &&other) noexcept {};\n"
            "soci::blob &soci::blob::operator=(blob &&other) noexcept = default;\n"
    )

endfunction()

soci_fix("${this_pkgname}" "${this_tag}" "${this_src}")
set(HANDLED ON)
