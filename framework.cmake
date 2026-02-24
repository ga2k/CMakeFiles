include_guard(GLOBAL)

# Shared feature/platform setup and environment checks
include(${cmake_root}/tools.cmake)
include(${cmake_root}/fetchContents.cmake)
include(${cmake_root}/addLibrary.cmake)
include(${cmake_root}/check_environment.cmake)
include(${cmake_root}/sqlish.cmake)

# The environment check validates OUTPUT_DIR etc.; call once globally
check_environment("${CMAKE_SOURCE_DIR}")

# Derivations of common metadata (safe globally)
string(TOUPPER ${APP_NAME} APP_NAME_UC)
string(TOLOWER ${APP_NAME} APP_NAME_LC)
string(TOUPPER ${APP_VENDOR} APP_VENDOR_UC)
string(TOLOWER ${APP_VENDOR} APP_VENDOR_LC)

# Capture compiler version information (used for flags below)
execute_process(
        COMMAND ${CMAKE_CXX_COMPILER} -v
        ERROR_VARIABLE compiler_version
        OUTPUT_QUIET
)

# Global policy/verbosity/tooling
set(CMAKE_WARN_UNINITIALIZED ON)
set(CMAKE_MESSAGE_LOG_LEVEL VERBOSE CACHE STRING "Log Level")

# Disable automatic RPATH to avoid circular dependencies
set(CMAKE_SKIP_BUILD_RPATH FALSE)
set(CMAKE_BUILD_WITH_INSTALL_RPATH FALSE)
set(CMAKE_INSTALL_RPATH_USE_LINK_PATH FALSE)

# Set explicit RPATH for build and install
set(CMAKE_BUILD_RPATH "${OUTPUT_DIR}/bin;${OUTPUT_DIR}/lib;${OUTPUT_DIR}/dll")
set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}")

set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_CXX_FLAGS_RELEASE "${CMAKE_CXX_FLAGS_RELEASE} -g")
#set(CMAKE_CXX_SCAN_FOR_MODULES ON)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
if (APPLE)
    set(CMAKE_CXX_VISIBILITY_PRESET default)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN OFF)
else()
    set(CMAKE_CXX_VISIBILITY_PRESET hidden)
    set(CMAKE_VISIBILITY_INLINES_HIDDEN ON)
endif()
set(CMAKE_VERBOSE_MAKEFILE ON)

# Global accumulators provided by framework users
set(extra_CompileOptions)
set(extra_Definitions)
set(extra_IncludePaths)
set(extra_LibrariesList)
set(extra_LibraryPaths)
set(extra_LinkOptions)

# Optional backtrace library for std::stacktrace
find_library(BACKTRACE_LIB backtrace)
find_library(STDCXX_BACKTRACE_LIB stdc++_libbacktrace)
if (BACKTRACE_LIB)
    list(APPEND extra_LibrariesList ${BACKTRACE_LIB})
elseif (STDCXX_BACKTRACE_LIB)
    list(APPEND extra_LibrariesList ${STDCXX_BACKTRACE_LIB})
endif ()

# Extra compile flags for clang module handling
if ("${compiler_version}" MATCHES "clang")
    list(APPEND extra_CompileOptions "-fno-implicit-modules;-fno-implicit-module-maps")
endif ()

include(${cmake_root}/platform.cmake)

# Make CMake find_package prefer our install libdir
list(PREPEND CMAKE_MODULE_PATH
        ${CMAKE_INSTALL_LIBDIR})

# Testing helpers available globally
include(GoogleTest)

function(fittest)

    set(flags ADD_ALWAYS)
    set(options PACKAGE FILENAME OUTPUT SOURCE_DIR STAGED_DIR SYSTEM_DIR)
    set(lists "")

    cmake_parse_arguments("AA" "${flags}" "${options}" "${lists}" ${ARGN})

    set(candidates)
    set(conditionals)

    get_filename_component(actualSourceFile "${AA_SOURCE_DIR}/${AA_FILENAME}" ABSOLUTE)
    get_filename_component(actualStagedFile "${AA_STAGED_DIR}/${AA_FILENAME}" ABSOLUTE)
    get_filename_component(actualSystemFile "${AA_SYSTEM_DIR}/${AA_FILENAME}" ABSOLUTE)

    foreach (f IN ITEMS "actualStagedFile" "actualSourceFile" "actualSystemFile")
        set(file "${${f}}")
        if (EXISTS "${file}" OR AA_ADD_ALWAYS)
            if (EXISTS "${file}")
                msg("  Found ${file}")
                set(${f}Found ON)
                list(APPEND candidates "${file}")
            else ()
                msg("Missing ${file} but still added it to list")
                set(${f}Found OFF)
                list(APPEND conditionals "${file}")
            endif ()
        else ()
            msg("Missing ${file}")
            set(${f}Found OFF)
        endif ()
    endforeach ()
    msg()

    # Staged and Source files are the same?
    if (actualSourceFileFound AND actualStagedFileFound
            AND "${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}"
            AND "${actualStagedFile}" IS_NEWER_THAN "${actualSourceFile}")

        msg("Source and Staged are the same. We'll use Staged.")
        list(REMOVE_ITEM candidates "${actualStagedFileFound}")
        list(INSERT candidates 0 "${actualStagedFileFound}")
    endif ()

    list(APPEND candidates ${conditionals})

    set(listOfFolders)
    foreach (candidate IN LISTS candidates)
        get_filename_component(candidate "${candidate}" PATH)
        list(APPEND listOfFolders "${candidate}")
    endforeach ()

    set(${AA_OUTPUT} ${listOfFolders} PARENT_SCOPE)

endfunction()


function(commonInit pkg)

    string(TOUPPER "${pkg}" _PKG)
    set(findex -1)
    set(foundFind -1)
    set(foundUse -1)

    foreach (feet IN LISTS AUE_FEATURES)
        math(EXPR findex "${findex} + 1")

        separate_arguments(_feet NATIVE_COMMAND "${feet}")
        cmake_parse_arguments("AAZ" "REQUIRED;OPTIONAL" "PACKAGE;NAMESPACE" "PATHS;HINTS" ${_feet})
        if (AAZ_UNPARSED_ARGUMENTS)
            list(GET AAZ_UNPARSED_ARGUMENTS 0 AAZ_FEATURE)
            if (AAZ_FEATURE STREQUAL _PKG AND AAZ_PACKAGE STREQUAL Find${pkg})
                set(foundFind ${findex})
            elseif (AAZ_FEATURE STREQUAL _PKG AND AAZ_PACKAGE STREQUAL ${pkg})
                set(foundUse ${findex})
            endif ()
        endif ()
    endforeach ()

    if(foundFind GREATER_EQUAL 0 AND foundFind GREATER foundUse)
        list(REMOVE_AT AUE_FEATURES ${foundFind})
        if (foundUse GREATER_EQUAL 0)
            list(REMOVE_AT AUE_FEATURES ${foundUse})
        endif ()
    elseif(foundUse GREATER_EQUAL 0 AND foundUse GREATER foundFind)
        list(REMOVE_AT AUE_FEATURES ${foundUse})
        if(foundFind GREATER_EQUAL 0)
            list(REMOVE_AT AUE_FEATURES ${foundFind})
        endif ()
    else ()
        # They can only be the same if they are both -1, and in that case we do nothing
    endif ()

    if (foundFind GREATER_EQUAL 0 AND foundUse LESS 0)
        list(PREPEND AUE_FEATURES "${_PKG} PACKAGE ${pkg} ARGS PATHS {${pkg}}")
    endif ()

    set(AUE_FEATURES "${AUE_FEATURES}" PARENT_SCOPE)

    set(fn "add${pkg}Features")
    cmake_language(CALL registerPackageCallback "${fn}")

    set(HANDLED ON)

endfunction()

function(columnarTextOutEx ID FIELDS TEMPLATE DRY_RUN)
    list(LENGTH FIELDS nFields)
    if(nFields EQUAL 6)
        columnarTextOut(${FIELDS} "${TEMPLATE}" ${DRY_RUN})
        return()
    endif ()

endfunction()
function(columnarTextOut ID FIELD0 FIELD1 FIELD2 FIELD3 FIELD4 FIELD5 TEMPLATE DRY_RUN)

    set(outstr "${TEMPLATE}")

    string(REGEX MATCHALL "\\[[_A-Z0-9]+:[^]]+\\]" placeholders "${TEMPLATE}")

    foreach (item ${placeholders})
        if (item MATCHES "\\[([_A-Z0-9]+):([LCR])\\]")
            set(current_tag ${CMAKE_MATCH_1}) # e.g. FIELD0
            set(current_align ${CMAKE_MATCH_2}) # e.g. R

            if (current_align STREQUAL "L")
                set(JUSTIFY "LEFT")
            elseif (current_align STREQUAL "C")
                set(JUSTIFY "CENTRE")
            elseif (current_align STREQUAL "R")
                set(JUSTIFY "RIGHT")
            else ()
                unset(JUSTIFY)
            endif ()

            set(rowName "${ID}_${current_tag}")

            set(SELECT_OK OFF)
            SELECT(longest AS _longest FROM tbl_LongestStrings WHERE ROW = "${rowName}")
            longest(${JUSTIFY} CURRENT ${_longest} TEXT "${${current_tag}}" PADDED ${current_tag} LONGEST __longest)
            if(SELECT_OK)
                UPDATE(tbl_LongestStrings SET longest = "${__longest}" WHERE ROW = "${rowName}")
            else ()
                INSERT(INTO tbl_LongestStrings ROW = "${rowName}" VALUES (${__longest}))
            endif ()

            if (current_tag STREQUAL "FIELD0")
                if("${${current_tag}}" MATCHES "^([ \t]*)([^ \t]+)([ \t]+)([^ \t]+)([ \t]*)$")
                    set(leading_ws   "${CMAKE_MATCH_1}")
                    set(word1        "${CMAKE_MATCH_2}")
                    set(inter_ws     "${CMAKE_MATCH_3}")
                    set(word2        "${CMAKE_MATCH_4}")
                    set(trailing_ws  "${CMAKE_MATCH_5}")
                endif ()
                if (word1 MATCHES "created")
                    set(word1 "${YELLOW}${word1}${NC}")
                elseif (word1 MATCHES "added")
                    set(word1 "${WHITE}${word1}${NC}")
                elseif (word1 MATCHES "replaced")
                    set(word1 "${RED}${word1}${NC}")
                elseif (word1 MATCHES "extended")
                    set(word1 "${CYAN}${word1}${NC}")
                elseif (word1 MATCHES "skipped")
                    set(word1 "${BLUE}${word1}${NC}")
                elseif (word1 MATCHES "calling")
                    set(word1 "${GREEN}${word1}${NC}")
                endif ()

                if (word2 MATCHES "package")
                    set(word2 "${CYAN}${word2}${NC}")
                elseif (word2 MATCHES "feature")
                    set(word2 "${BLUE}${word2}${NC}")
                endif ()
                set(${current_tag} "${leading_ws}${word1}${inter_ws}${word2}${trailing_ws}")
            elseif (current_tag STREQUAL "FIELD1")
                #                _doLine(FIELD1)
                set(FIELD1 "${BOLD}${FIELD1}${NC}")
            elseif (current_tag STREQUAL "FIELD2")
                if("${${current_tag}}" MATCHES "^([ \t]*)([^ \t]+)([ \t]+)([^ \t]+)([ \t]*)$")
                    set(leading_ws   "${CMAKE_MATCH_1}")
                    set(word1        "${CMAKE_MATCH_2}")
                    set(inter_ws     "${CMAKE_MATCH_3}")
                    set(word2        "${CMAKE_MATCH_4}")
                    set(trailing_ws  "${CMAKE_MATCH_5}")
                endif ()
                if (word2 MATCHES "package")
                    set(word2 "${CYAN}${word2}${NC}")
                elseif (word2 MATCHES "feature")
                    set(word2 "${BLUE}${word2}${NC}")
                endif ()
                set(${current_tag} "${leading_ws}${MAGENTA}${word1}${NC}${inter_ws}${word2}${trailing_ws}")
            elseif (current_tag STREQUAL "FIELD3")
                set(FIELD3 "${BOLD}${YELLOW}${FIELD3}${NC}")
            elseif (current_tag STREQUAL "FIELD4")
            elseif (current_tag STREQUAL "FIELD5")
                set(FIELD5 "${BLUE}${FIELD5}${NC}")
            endif ()
        endif ()
    endforeach ()
    # @formatter:off
    string(REGEX REPLACE "\\[FIELD0:[^]]*\\]" "${FIELD0} " outstr "${outstr}")
    string(REGEX REPLACE "\\[FIELD1:[^]]*\\]" "${FIELD1} " outstr "${outstr}")
    string(REGEX REPLACE "\\[FIELD2:[^]]*\\]" "${FIELD2} " outstr "${outstr}")
    string(REGEX REPLACE "\\[FIELD3:[^]]*\\]" "${FIELD3} " outstr "${outstr}")
    string(REGEX REPLACE "\\[FIELD4:[^]]*\\]" "${FIELD4} " outstr "${outstr}")
    string(REGEX REPLACE "\\[FIELD5:[^]]*\\]" "${FIELD5} " outstr "${outstr}")
    # @formatter:on

    if (NOT DRY_RUN)
        msg("${outstr}")
    endif ()

endfunction()
