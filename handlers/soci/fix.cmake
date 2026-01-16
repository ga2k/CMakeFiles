function(soci_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of soci")
    endif ()

    set(p0 ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${p0} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${p0} 0 ${subLength} p0)

    message("Applying local patches to ${p0}...")

    # --- Strip installation/export logic that causes conflicts in bundled builds ---
    ReplaceInFile("${sourceDir}/src/core/CMakeLists.txt" "install(EXPORT \"SOCICoreTargets\"" "# install(EXPORT \"SOCICoreTargets\"")
    ReplaceInFile("${sourceDir}/src/core/CMakeLists.txt" "install(TARGETS soci_core" "# install(TARGETS soci_core")
    ReplaceInFile("${sourceDir}/src/core/CMakeLists.txt" "EXPORT \"SOCICoreTargets\"" "")

    # Do the same for the sqlite3 backend
    if(EXISTS "${sourceDir}/src/backends/sqlite3/CMakeLists.txt")
        ReplaceInFile("${sourceDir}/src/backends/sqlite3/CMakeLists.txt" "install(EXPORT \"SOCISQLite3Targets\"" "# install(EXPORT \"SOCISQLite3Targets\"")
        ReplaceInFile("${sourceDir}/src/backends/sqlite3/CMakeLists.txt" "install(TARGETS soci_sqlite3" "# install(TARGETS soci_sqlite3")
        ReplaceInFile("${sourceDir}/src/backends/sqlite3/CMakeLists.txt" "EXPORT \"SOCISQLite3Targets\"" "")
    endif()

    ReplaceInFile("${sourceDir}/CMakeLists.txt" "VERSION 2.8 FATAL_ERROR" "VERSION 4.0 FATAL_ERROR")
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
    ReplaceInFile(${BLOB_H} "blob(blob &&other) = default;" "blob(blob &&other) noexcept;")
    ReplaceInFile(${BLOB_H} "blob &operator=(blob &&other) = default;" "blob &operator=(blob &&other) noexcept;")

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
    set(HANDLED ON PARENT_SCOPE)

endfunction()
