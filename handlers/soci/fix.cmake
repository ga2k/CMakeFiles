function(patchExternals banner patchBranch externalTrunk)
    string(ASCII 27 ESC)
    set(BOLD "${ESC}[1m")
    set(RED "${ESC}[31m${BOLD}")
    set(GREEN "${ESC}[32m${BOLD}")
    set(OFF "${ESC}[0m")

    message(CHECK_START "${banner}")
    list(APPEND CMAKE_MESSAGE_INDENT "\t")

    message("       patchBranch=${patchBranch}")
    message("     externalTrunk=${externalTrunk}")

    set(from_path "${CMAKE_SOURCE_DIR}/include/overrides/${patchBranch}")
    message("         from_path=${from_path}")

    if (EXISTS ${from_path})

        get_filename_component(to_path "${externalTrunk}/../${patchBranch}" ABSOLUTE)
        message("           to_path=${to_path}")

        file(GLOB_RECURSE override_files RELATIVE "${from_path}" "${from_path}/*")

        foreach(file_rel_path IN LISTS override_files)
            message(CHECK_START "${BOLD}Patching${OFF} ${file_rel_path}")
            list(APPEND CMAKE_MESSAGE_INDENT "\t")

            set(system_file_path "${to_path}/${file_rel_path}")
            message("  system_file_path=${system_file_path}")
            set(override_file_path "${from_path}/${file_rel_path}")
            message("override_file_path=${override_file_path}")

            if (EXISTS "${system_file_path}")
                # Overwrite the system file instead of deleting it
                # This keeps the CMake file list valid while giving us the fixed code
                file(COPY_FILE "${override_file_path}" "${system_file_path}")
                list(POP_BACK CMAKE_MESSAGE_INDENT)
                message(CHECK_PASS "${GREEN}OK${OFF}")
            else ()
                list(POP_BACK CMAKE_MESSAGE_INDENT)
                message(CHECK_FAIL "${RED}[FAILED]${OFF} ${system_file_path} doesn't exist")
            endif()
        endforeach()
    endif ()
endfunction()

function(soci_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of soci")
    endif ()

    set(p0 ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${p0} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${p0} 0 ${subLength} p0)

    message("Applying local patches to ${p0}...")


    patchExternals("Patching  fmt system headers" "soci/3rdparty/fmt/include" "${sourceDir}")
#    message(CHECK_START "Patching  fmt system headers")
#    list(APPEND CMAKE_MESSAGE_INDENT "\t")
#
#    set(OVERRIDE_PATH "${CMAKE_SOURCE_DIR}/include/overrides/soci/3rdparty/fmt/include")
#    if (EXISTS ${OVERRIDE_PATH})
#
#        set(local_includes "${sourceDir}/3rdparty/fmt/include")
#
#        file(GLOB_RECURSE override_files RELATIVE "${OVERRIDE_PATH}" "${OVERRIDE_PATH}/*")
#
#        foreach(file_rel_path IN LISTS override_files)
#            message(CHECK_START "Patching ${file_rel_path}")
#            list(APPEND CMAKE_MESSAGE_INDENT "\t")
#
#            set(system_file_path "${sourceDir}/3rdparty/fmt/include/${file_rel_path}")
#            set(override_file_path "${OVERRIDE_PATH}/${file_rel_path}")
#
#            if (EXISTS "${system_file_path}")
#                # Overwrite the system file instead of deleting it
#                # This keeps the CMake file list valid while giving us the fixed code
#                file(COPY_FILE "${override_file_path}" "${system_file_path}")
#                list(POP_BACK CMAKE_MESSAGE_INDENT)
#                message(CHECK_PASS "OK")
#            else ()
#                list(POP_BACK CMAKE_MESSAGE_INDENT)
#                message(CHECK_FAIL "FAILED because ${system_file_path} doesn't exist")
#            endif()
#        endforeach()
#
#        include_directories(BEFORE SYSTEM "${local_includes}")
#        set(_wxIncludePaths ${local_includes} PARENT_SCOPE)
#        list(POP_BACK CMAKE_MESSAGE_INDENT)
#        message(CHECK_PASS "OK")
#    else ()
#        list(POP_BACK CMAKE_MESSAGE_INDENT)
#        message(CHECK_FAIL "FAILED because override path ${OVERRIDE_PATH} doesn't exist")
#    endif ()

    message(CHECK_START "Patching soci system headers")
    list(APPEND CMAKE_MESSAGE_INDENT "\t")

    set(OVERRIDE_PATH "${CMAKE_SOURCE_DIR}/include/overrides/soci/include")
    if (EXISTS ${OVERRIDE_PATH})

        set(local_includes "${sourceDir}/include")

        file(GLOB_RECURSE override_files RELATIVE "${OVERRIDE_PATH}" "${OVERRIDE_PATH}/*")

        foreach(file_rel_path IN LISTS override_files)
            message(CHECK_START "Patching ${file_rel_path}")
            list(APPEND CMAKE_MESSAGE_INDENT "\t")

            set(system_file_path "${sourceDir}/include/${file_rel_path}")
            set(override_file_path "${OVERRIDE_PATH}/${file_rel_path}")

            if (EXISTS "${system_file_path}")
                # Overwrite the system file instead of deleting it
                # This keeps the CMake file list valid while giving us the fixed code
                file(COPY_FILE "${override_file_path}" "${system_file_path}")
                list(POP_BACK CMAKE_MESSAGE_INDENT)
                message(CHECK_PASS "OK")
            else ()
                list(POP_BACK CMAKE_MESSAGE_INDENT)
                message(CHECK_FAIL "FAILED because ${system_file_path} doesn't exist")
            endif()
        endforeach()

        include_directories(BEFORE SYSTEM "${local_includes}")
        set(_wxIncludePaths ${local_includes} PARENT_SCOPE)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "OK")
    else ()
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_FAIL "FAILED because override path ${OVERRIDE_PATH} doesn't exist")
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
