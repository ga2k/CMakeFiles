function(soci_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of soci")
    endif ()

    set(p0 ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${p0} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${p0} 0 ${subLength} p0)

    message("Applying local patches to ${p0}...")

    message(CHECK_START "SOCI FMT: Patching system headers with local overrides...")
    list(APPEND CMAKE_MESSAGE_INDENT "\t")

    set(OVERRIDE_PATH "${CMAKE_SOURCE_DIR}/include/overrides/soci/3rdparty/fmt/include")
    if (EXISTS ${OVERRIDE_PATH})

        set(local_includes "${${pkglc}_SOURCE_DIR}/3rdparty/fmt/include")

        # 1. Find all files in your override folder
        file(GLOB_RECURSE override_files RELATIVE "${OVERRIDE_PATH}" "${OVERRIDE_PATH}/*")

        foreach(file_rel_path IN LISTS override_files)
            message(CHECK_START "Patching ${file_rel_path}")

            set(system_file_path "${${pkglc}_SOURCE_DIR}/3rdparty/fmt/include/${file_rel_path}")
            set(override_file_path "${OVERRIDE_PATH}/${file_rel_path}")

            if (EXISTS "${system_file_path}")
                # Overwrite the system file instead of deleting it
                # This keeps the CMake file list valid while giving us the fixed code
                file(COPY_FILE "${override_file_path}" "${system_file_path}")
                message(CHECK_PASS "Patching: ${file_rel_path}")
            else ()
                message(CHECK_FAIL "Patching: ${file_rel_path}")
            endif()
        endforeach()

        # 2. We no longer need to mess with PREPEND or target_include_directories
        # because we have physically patched the files in the wxWidgets source tree.
        message(STATUS "SOCI FMT: Source tree patched successfully.")
        include_directories(BEFORE SYSTEM "${local_includes}")
        set(_wxIncludePaths ${local_includes} PARENT_SCOPE)
        message(CHECK_PASS "SOCI FMT: Patching system headers passed")
    else ()
        message(CHECK_FAIL "SOCI FMT: Patching system headers failed")
    endif ()
    list(POP_BACK CMAKE_MESSAGE_INDENT)

    set(OVERRIDE_PATH "${CMAKE_SOURCE_DIR}/include/overrides/soci/include")
    message(CHECK_START "SOCI: Patching system headers with local overrides...")
    if (EXISTS ${OVERRIDE_PATH})

        set(local_includes "${${pkglc}_SOURCE_DIR}/include")
        file(GLOB_RECURSE override_files RELATIVE "${OVERRIDE_PATH}" "${OVERRIDE_PATH}/*")

        foreach(file_rel_path IN LISTS override_files)
            set(system_file_path "${${pkglc}_SOURCE_DIR}/include/${file_rel_path}")
            set(override_file_path "${OVERRIDE_PATH}/${file_rel_path}")

            if (EXISTS "${system_file_path}")
                message(STATUS "  Patching: ${file_rel_path}")
                file(COPY_FILE "${override_file_path}" "${system_file_path}")
            endif()
        endforeach()

        include_directories(BEFORE SYSTEM "${local_includes}")
        set(_wxIncludePaths ${local_includes} PARENT_SCOPE)
        message(CHECK_PASS "SOCI: Patching system headers passes...")
    else ()
        message(CHECK_FAIL "SOCI: Patching system headers failed...")
    endif ()

#    ReplaceInFile("${sourceDir}/3rdparty/fmt/include/fmt/base.h" "define FMT_CONSTEVAL consteval"   "define FMT_CONSTEVAL")
#    ReplaceInFile("${sourceDir}/3rdparty/fmt/include/fmt/base.h" "define FMT_CONSTEXPR constexpr"   "define FMT_CONSTEXPR")
#    ReplaceInFile("${sourceDir}/3rdparty/fmt/include/fmt/base.h" "define FMT_CONSTEXPR20 constexpr" "define FMT_CONSTEXPR20")

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
#    ReplaceInFile(${BLOB_H} "blob() = default;" "blob();")
#    ReplaceInFile(${BLOB_H} "~blob() = default;" "~blob();")
#    ReplaceInFile(${BLOB_H} "blob(blob &&other) = default;" "blob(blob &&other) noexcept;")
#    ReplaceInFile(${BLOB_H} "blob &operator=(blob &&other) = default;" "blob &operator=(blob &&other) noexcept;")

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
