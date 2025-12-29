cmake_minimum_required(VERSION 3.28)

set(SsngfnHHNJLKN) # Stop the text above appearing in the next docstring

# A helper that aggressively synchronizes a variable's value across
# - local scope
# - parent scope
# - process environment
# - CMake cache (with FORCE)
# Usage:
#   forceSet(<VAR_NAME> <ENV_NAME_OR_EMPTY> <VALUE> <TYPE>)
# Notes:
# - If ENV_NAME_OR_EMPTY is empty (""), the environment variable name defaults to VAR_NAME.
# - TYPE must be a valid cache type (e.g., BOOL, STRING, FILEPATH, PATH, INTERNAL).
# - This mirrors the behavior described in project docs/comments.
function(forceSet VAR_NAME ENV_NAME VALUE TYPE)
    if(NOT VAR_NAME)
        message(FATAL_ERROR "forceSet: VAR_NAME is required")
    endif()
    if(NOT DEFINED TYPE OR TYPE STREQUAL "")
        set(TYPE STRING)
    endif()

    # Derive environment variable name if not provided
    if(DEFINED ENV_NAME AND NOT ENV_NAME STREQUAL "")
        set(_ENV_NAME "${ENV_NAME}")
    else()
        set(_ENV_NAME "${VAR_NAME}")
    endif()

    # Set in local scope
    set(${VAR_NAME} "${VALUE}")

    # Set in parent scope
    if(CMAKE_CURRENT_FUNCTION)
        set(${VAR_NAME} "${VALUE}" PARENT_SCOPE)
    endif()

    # Set in process environment
    set(ENV{${_ENV_NAME}} "${VALUE}")

    # Set in cache (force to override any prior value)
    # Provide an empty docstring per convention.
    set(${VAR_NAME} "${VALUE}" CACHE ${TYPE} "" FORCE)

    # Optional verbose trace for debugging
    if(DEFINED CMAKE_MESSAGE_LOG_LEVEL AND (CMAKE_MESSAGE_LOG_LEVEL STREQUAL "VERBOSE" OR CMAKE_MESSAGE_LOG_LEVEL STREQUAL "DEBUG"))
        message(VERBOSE "forceSet: ${VAR_NAME}='${VALUE}' (TYPE=${TYPE}) ENV{${_ENV_NAME}} updated and cache forced")
    endif()
endfunction()

# Function to copy specified file patterns from source directories to target directory
function(copy_files_to_target_dir)
    set(options)
    set(oneValueArgs TARGET_DIR)
    set(multiValueArgs SOURCE_DIRS FILE_PATTERNS)

    cmake_parse_arguments(MV "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if (NOT MV_TARGET_DIR)
        message(FATAL_ERROR "TARGET_DIR is required!")
    endif ()

    if (NOT MV_SOURCE_DIRS)
        message(FATAL_ERROR "At least one SOURCE_DIR is required!")
    endif ()

    if (NOT MV_FILE_PATTERNS)
        message(FATAL_ERROR "At least one FILE_PATTERN is required!")
    endif ()

    foreach (SOURCE_DIR IN LISTS MV_SOURCE_DIRS)
        foreach (PATTERN IN LISTS MV_FILE_PATTERNS)
            file(GLOB FILES "${SOURCE_DIR}/${PATTERN}")

            foreach (FILE IN LISTS FILES)
                get_filename_component(FILE_NAME ${FILE} NAME)
                message(STATUS "Copying ${FILE_NAME} from ${SOURCE_DIR} to ${MV_TARGET_DIR}")

                file(MAKE_DIRECTORY ${MV_TARGET_DIR})
                file(COPY ${FILE} DESTINATION ${MV_TARGET_DIR} FOLLOW_SYMLINK_CHAIN)
            endforeach ()
        endforeach ()
    endforeach ()
endfunction()

##
######################################################################################
##
function(ReplaceInFile f old new)

    if (NOT EXISTS ${f})
        set(out_text "Missing file, not patching")
        set(truncStr "${f}")
    else ()

        string(LENGTH "${CMAKE_CURRENT_SOURCE_DIR}" sourceLength)
        math(EXPR sourceLength "${sourceLength} + 1")
        string(SUBSTRING "${f}" ${sourceLength} -1 truncStr)

        file(READ ${f} contents)
        set(count 0)
        set(posn 0)
        set(progressive ${contents})
        string(LENGTH "${old}" old_length)
        string(LENGTH "${contents}" contents_length)

        while (NOT posn EQUAL -1 AND NOT posn GREATER_EQUAL ${contents_length})
            string(FIND "${progressive}" "${old}" posn)
            if (NOT posn EQUAL -1)
                math(EXPR count "${count} + 1")
                math(EXPR posn "${posn} + ${old_length}")
                string(SUBSTRING "${progressive}" ${posn} -1 progressive)
                continue()
            endif ()
        endwhile ()

        set(already_done "")
        set(es "es")
        if (count EQUAL 0)
            set(count "No")
            set(already_done "Already done? ")
        elseif (count EQUAL 1)
            set(count "One")
            set(es "")
        endif ()
        set(out_text "${already_done}${count} patch${es} applied")
        if (NOT ${count} EQUAL 0)
            string(REPLACE "${old}" "${new}" updated_contents "${contents}")
            file(WRITE ${f} "${updated_contents}")

            if (EXISTS ${f})
                file(READ ${f} contents NEWLINE_CONSUME)
                string(FIND "${contents}" "${old}" posn)
                if (NOT posn EQUAL -1)
                    string(JOIN " " out_text "${out_text}" "but lost in")
                else ()
                    string(JOIN " " out_text "${out_text}" "to")
                endif ()
            else ()
                set(out_text "FILE MISSING AFTER PATCHING (BUG?)")
            endif ()
        endif ()
    endif ()

    string(LENGTH "${out_text}" posn_len)
    math(EXPR num_dots "42 - ${posn_len}")
    string(REPEAT "." ${num_dots} dotty)

    message("${out_text} ${dotty}... ${truncStr}")
endfunction()

##
######################################################################################
##
function(FindReplaceInFile l f old new)
    foreach (d IN LISTS l)
        set (p "${d}/${f}")
        if (EXISTS "${p}")
            ReplaceInFile ("${p}" "${old}" "${new}")
            break()
        endif ()
    endforeach ()
endfunction()
##
######################################################################################
##
function(ReplaceFile fileToBeOverwritten sampleContents replacementFile)
    string(LENGTH "${CMAKE_CURRENT_SOURCE_DIR}" srcLength)
    math(EXPR srcLength "${srcLength} + 1")
    string(SUBSTRING "${fileToBeOverwritten}" ${srcLength} -1 truncStr)
    set(repositoryFolder "${CMAKE_CURRENT_SOURCE_DIR}/HoffSoft/cmake/replacements")

    cmake_path(GET fileToBeOverwritten PARENT_PATH destPath)
    cmake_path(GET replacementFile FILENAME destFile)

    if (EXISTS "${repositoryFolder}/${replacementFile}")
        if (EXISTS ${fileToBeOverwritten})
            file(READ ${fileToBeOverwritten} contents)
            string(FIND "${contents}" "${sampleContents}" posn)
            if (NOT posn EQUAL -1)
                file(COPY_FILE "${fileToBeOverwritten}" "${fileToBeOverwritten}.bak")
                file(COPY_FILE "${repositoryFolder}/${replacementFile}" "${destPath}/${destFile}")
                set(out_text "${replacementFile} replaced")
            else ()
                set(out_text "Already done? Replacement skipped for")
            endif ()
        else ()
            file(COPY_FILE "${repositoryFolder}/${replacementFile}" "${destPath}/${destFile}")
            set(out_text "${replacementFile} created")
        endif ()
    else ()
        set(out_text "'${replacementFile}' doesn't exist")
    endif ()

    string(LENGTH "${out_text}" posn_len)
    math(EXPR num_dots "42 - ${posn_len}")
    string(REPEAT "." ${num_dots} dotty)

    message("${out_text} ${dotty}... ${truncStr}")
endfunction()
##
######################################################################################
##
function(ReplaceInList listname index newvalue)
    list(REMOVE_AT ${${listname}} ${index})
    list(INSERT ${${listname}} ${index} "${newvalue}")
endfunction()
##
######################################################################################
##
function(listFrom str out)
    string(REGEX REPLACE "[ \|\,;]" ";" temp ${str})
    set(${out} "${temp}" PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(SplitAt str chr left right)
    string(FIND "${str}" "${chr}" chrIndex)
    if (${chrIndex} EQUAL -1)
        set(${left} "${str}" PARENT_SCOPE)
        unset(${right} PARENT_SCOPE)
    else ()
        set(lvar "")
        set(rvar "")
        string(SUBSTRING "${str}" 0 ${chrIndex} lvar)
        math(EXPR chrIndex "${chrIndex} + 1")
        string(SUBSTRING "${str}" ${chrIndex} -1 rvar)
        set(${left} "${lvar}" PARENT_SCOPE)
        set(${right} "${rvar}" PARENT_SCOPE)
    endif ()
endfunction()
##
######################################################################################
##
###
### Find an entry in a list and return both the entry (as a list) and it's index
### @param list_name the name of the list to search
### @param key the first word of the entry
### @param split_char what separates the key from the rest of the entry
### @param result_var the name of a variable to receive the entry minus the key and split_char
### @param index_var the name of a variable to receive the index. May be omitted if unwanted
### If key is not found, entry_var and index_var are unset
function(findInList list_name key split_char result_var)
    set(index_var ${ARGN})
    set(local ${list_name})
    list(LENGTH local length)

    #    if (${length} LESS_EQUAL 1)
    #        string(REGEX REPLACE "[ |\||\,]" ";" local ${local})
    #        list(LENGTH local length)
    #    endif ()

    if (${length} GREATER 0)
        set(index -1)
        foreach (entry IN LISTS local)
            math(EXPR index "${index} + 1")
            SplitAt("${entry}" "${split_char}" L R)
            if ("${L}" STREQUAL "${key}")
                listFrom("${R}" R)
                set(${result_var} "${R}" PARENT_SCOPE)
                if (index_var)
                    set(${index_var} ${index} PARENT_SCOPE)
                endif ()
                return()
            endif ()
        endforeach ()
    endif ()
    unset(${result_var} PARENT_SCOPE)
    if (index_var)
        unset(${index_var} PARENT_SCOPE)
    endif ()
endfunction()
########################################################################
# Looks through a list, and does a find and replace on each entry in the list
#
# Required parameters :-
#
# VAR         The NAME of the list to work on
# FINDSTR     The text to find in each entry
# REPLACESTR  The test to replace FINDSTR with
#
# Optional parameters :- None
# ##################################################################################
function(replace_substring VAR FINDSTR REPLACESTR)
    # Create an empty list to srcDir the modified elements
    set(modifiedList "")

    # Iterate over the elements of the main list
    foreach (item IN LISTS ${VAR})
        # Check if the element contains the string to remove
        string(FIND "${item}" "${FINDSTR}" removeIndex)

        # If the string to remove is found, remove it
        if (removeIndex GREATER -1)
            # Replace the substring with an empty string
            string(REPLACE "${FINDSTR}" "${REPLACESTR}" newItem "${item}")
            list(APPEND modifiedList "${newItem}")
        else ()
            # If the substring is not found, keep the original element
            list(APPEND modifiedList "${item}")
        endif ()
    endforeach ()

    set(${VAR} ${modifiedList} PARENT_SCOPE)
endfunction()

function(resolve IN OUT_NAME OUT_VALUE)

    set(${OUT_NAME} "" CACHE STRING "" FORCE)
    set(${OUT_VALUE} "" CACHE STRING "" FORCE)

    set(THIS_NAME ${IN})
    set(THIS_VALUE ${${THIS_NAME}})
    set(NEXT_NAME ${${THIS_VALUE}})

    if (NOT "${NEXT_NAME}" STREQUAL "")
        resolve(${THIS_VALUE} ${OUT_NAME} ${OUT_VALUE})
        return()
    endif ()

    set(${OUT_NAME} ${THIS_NAME} CACHE STRING "" FORCE)
    set(${OUT_VALUE} ${THIS_VALUE} CACHE STRING "" FORCE)

endfunction()

function(m)

    foreach (m_ITEM ${ARGN})
        string(TOUPPER ${m_ITEM} m_ITEM)
        list(APPEND m_ARGN ${m_ITEM})
    endforeach ()

    list(APPEND m_SWITCHES VERBATIM)
    cmake_parse_arguments(M m_SWITCHES "" "" ${m_ARGN})

    list(REMOVE_ITEM ARGN "VERBATIM")

    set(M_TEXT ${ARGN})
    if (NOT M_VERBATIM)
        resolve(${M_TEXT} M_DC M_TEXT)
    endif ()
    message(STATUS "${M_TEXT}")
endfunction()

function(brif doIt)
    if (${doIt})
        m(${ARGV})
    endif ()
endfunction()

function(br)
    m(${ARGV})
endfunction()

function(doDump doDump_ITEMS doDump_TITLE)

    if (NOT DEFINED ${doDump_ITEMS})
        m("${doDump_TITLE} (not defined)" VERBATIM)
        return()
    endif ()
    if ("${${doDump_ITEMS}}" STREQUAL "")
        m("${doDump_TITLE} (empty)" VERBATIM)
        return()
    endif ()

    resolve(doDump_ITEMS VR VL)

    list(LENGTH ${doDump_ITEMS} length)
    if (${length} EQUAL 1)
        m("${doDump_TITLE} ${VL}" VERBATIM)
        return()
    endif ()

    m("${doDump_TITLE}" VERBATIM)
    list(APPEND CMAKE_MESSAGE_INDENT "    ")

    foreach (l ${VL})
        m(${l} VERBATIM)
    endforeach ()

    list(POP_BACK CMAKE_MESSAGE_INDENT)
endfunction()

# #############################################################
# Dumps a list's contents formatted nicely
#
# Required args:-
#
# LIST_NAME     The text literal to print
#
# Optional args
#
# ALWAYS        Always present the list. If set, the
# message list will ALWAYS be printed,
# as STATUS.
#
# If not present, the list may or may not
# print, accoring to CMAKE_MESSAGE_LOG_LEVEL
#
# NOTICE        Print if CMAKE_MESSAGE_LOG_LEVEL <= NOTICE
# STATUS        Print if CMAKE_MESSAGE_LOG_LEVEL <= STATUS
#         Print if CMAKE_MESSAGE_LOG_LEVEL <= DEBUG
#
# LEVEL <level> One of NOTICE, STATUS etc.
#
# LF            Print a blank line before outputting
#
# LIST          TEXT is the name of a list variable
# LISTS lists   A number of lists to dump
#
# TITLE <str>   Print this instead of "Contents of <list>"
#
# #############################################################
function(log LIST_NAME)
    set(options LF LF_ _LF INDENT OUTDENT)
    set(oneValueArgs TITLE LIST)
    set(multiValueArgs LISTS)

    set(index 0)
    foreach (item IN LISTS ARGN)
        if ("${item}" STREQUAL "VAR")
            list(REMOVE_AT ARGN ${index})
            list(INSERT ARGN ${index} "LIST")
        elseif ("${item}" STREQUAL "VARS")
            list(REMOVE_AT ARGN ${index})
            list(INSERT ARGN ${index} "LISTS")
        endif ()
        math(EXPR index "${index} + 1")
    endforeach ()

    cmake_parse_arguments(AA_DUMP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (${LIST_NAME} IN_LIST options)
        string(TOUPPER "${LIST_NAME}" LIST_NAME)
        set(AA_DUMP_${LIST_NAME} TRUE)
        unset(LIST_NAME)
    elseif (${LIST_NAME} IN_LIST oneValueArgs)
        string(TOUPPER "${LIST_NAME}" LIST_NAME)
        list(GET AA_DUMP_UNPARSED_ARGUMENTS 0 AA_DUMP_${LIST_NAME})
        list(REMOVE_AT AA_DUMP_UNPARSED_ARGUMENTS 0)
        unset(LIST_NAME)
    elseif (${LIST_NAME} IN_LIST multiValueArgs)
        string(TOUPPER "${LIST_NAME}" LIST_NAME)
        set(AA_DUMP_${LIST_NAME} ${AA_DUMP_UNPARSED_ARGUMENTS})
        unset(AA_DUMP_UNPARSED_ARGUMENTS)
        unset(LIST_NAME)
    endif ()

    if (AA_DUMP_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments : ${AA_DUMP_UNPARSED_ARGUMENTS}")
        return() # Won't, really
    endif ()

    unset(LF_)
    unset(_LF)

    if (AA_DUMP_LF OR AA_DUMP_LF_)
        set(LF_ ON)
        unset(AA_DUMP_LF_)
    endif ()

    if (AA_DUMP_LF OR AA_DUMP__LF)
        set(_LF ON)
        unset(AA_DUMP__LF)
    endif ()

    if (AA_DUMP_OUTDENT)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
    endif ()

    brif(LF_)

    if (AA_DUMP_LIST)
        list(FIND ARGN "LIST" listIndex)
        list(FIND ARGN "LISTS" listsIndex)

        if (listIndex EQUAL -1 AND listsIndex GREATER_EQUAL 0)
            # LIST is first item in command arguments
            list(PREPEND AA_DUMP_LISTS ${AA_DUMP_LIST})
            unset(AA_DUMP_LIST)
        elseif (listsIndex EQUAL -1 AND listIndex GREATER_EQUAL 0)
            # LISTS is first item in command arguments
            list(APPEND AA_DUMP_LISTS ${AA_DUMP_LIST})
            unset(AA_DUMP_LIST)
        elseif (listIndex LESS listsIndex)
            # LIST is before LISTS
            list(PREPEND AA_DUMP_LISTS ${AA_DUMP_LIST})
            unset(AA_DUMP_LIST)
        elseif (listIndex GREATER listsIndex)
            # LIST is after LISTS
            list(APPEND AA_DUMP_LISTS ${AA_DUMP_LIST})
            unset(AA_DUMP_LIST)
        else ()
            set(AA_DUMP_LISTS ${AA_DUMP_LIST})
        endif ()
    endif ()

    unset(AA_DUMP_TEMP_TITLE)

    if (AA_DUMP_TITLE)
        set(AA_DUMP_TEMP_TITLE "${AA_DUMP_TITLE}")
        set(AA_DUMP_TITLE_USED "${AA_DUMP_TEMP_TITLE}")
        list(LENGTH AA_DUMP_LISTS numberOfLists)
        #        if (${numberOfLists} GREATER 1)
        set(AA_DUMP_TITLE_USED "${AA_DUMP_TEMP_TITLE} - Begin")
        #        endif ()
        m(${AA_DUMP_TITLE_USED})
        list(APPEND CMAKE_MESSAGE_INDENT "    ")
    endif ()

    foreach (AA_ ${AA_DUMP_LISTS})
        resolve(${AA_} VVAR VVAL)
        set(AA_DUMP_TITLE "Contents of $CACHE{VVAR}: ")
        doDump(${VVAR} "${AA_DUMP_TITLE}")
    endforeach ()

    if (AA_DUMP_TEMP_TITLE)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        set(AA_DUMP_TITLE_USED "${AA_DUMP_TEMP_TITLE}")
        #        if (${numberOfLists} GREATER 1)
        set(AA_DUMP_TITLE_USED "${AA_DUMP_TEMP_TITLE} - End")
        #        endif ()
        m(${AA_DUMP_TITLE_USED})
    endif ()

    if (AA_DUMP_INDENT)
        list(APPEND CMAKE_MESSAGE_INDENT "    ")
    endif ()
endfunction()

# #############################################################
# Dumps a list's contents formatted nicely
#
# Required args:-
#
# TEXT          The text literal to print
#
# Optional args
#
# ALWAYS        Always present the list. If set, the
# message list will ALWAYS be printed,
# as STATUS.
#
# If not present, the list may or may not
# print, accoring to CMAKE_MESSAGE_LOG_LEVEL
#
# NOTICE        Print if CMAKE_MESSAGE_LOG_LEVEL <= NOTICE
# STATUS        Print if CMAKE_MESSAGE_LOG_LEVEL <= STATUS
#         Print if CMAKE_MESSAGE_LOG_LEVEL <= DEBUG
# WARNING       Printed at WARNING
# FATAL_ERROR   Printed as FATAL_ERROR
#
# LEVEL <level> One of NOTICE, STATUS etc.
#
# LF            Print a blank line before outputting
#
# VAR           TEXT is the name of a string variable
# LIST          TEXT is the name of a list variable
# LISTS lists   A number of lists to log
# TITLE <str>   Print this instead of "Contents of <list>"
#
# #############################################################
function(lorg)
    dump(${ARGV})
    return()

    set(options LF LF_ _LF CHECK_START CHECK_PASS CHECK_FAIL INDENT OUTDENT)
    set(oneValueArgs TITLE LIST VAR)
    set(multiValueArgs LISTS VARS)

    cmake_parse_arguments(AA_LOG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(AA_LOG_TEXT)
    string(JOIN " " AA_LOG_TEXT ${TEXT} ${AA_LOG_UNPARSED_ARGUMENTS})

    if (AA_LOG_LIST OR AA_LOG_LISTS) # Let dump handle it
        dump(${ARGV})
        return()
    endif ()

    unset(LF_)
    unset(_LF)
    unset(LL)

    if (AA_LOG_LF OR AA_LOG_LF_)
        set(LF_ TRUE)
        unset(AA_LOG_LF)
        unset(AA_LOG_LF_)
    endif ()

    if (AA_LOG__LF)
        set(_LF TRUE)
        unset(AA_LOG__LF)
    endif ()

    if (AA_LOG_OUTDENT)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
    endif ()

    set(AA_LOG_PREPAD)
    set(AA_LOG_BODY)
    set(AA_LOG_POSTPAD)

    if (AA_LOG_VAR)
        set(AA_LOG_TEXT "${${AA_LOG_VAR}}") # Convert VAR into TEXT

        if (NOT AA_LOG_TITLE) # Add our own TITLE if none
            set(AA_LOG_TITLE "Contents of ${AA_LOG_VAR}: ")
        endif ()

    else ()
        set(AA_LOG_TEXT "${AA_LOG_TEXT}") # Special sauce
    endif ()

    set(AA_LOG_OUTPUT "${AA_LOG_PREPAD}${AA_LOG_TITLE}${AA_LOG_TEXT}${AA_LOG_POSTPAD}")

    m(${AA_LOG_OUTPUT})

    if (AA_LOG_INDENT)
        list(APPEND CMAKE_MESSAGE_INDENT "    ")
    endif ()

    if (AA_LOG_SAVED)
        set(CMAKE_MESSAGE_LOG_LEVEL ${AA_LOG_SAVED})
    endif ()
endfunction()

#
# Find a library locally or installed
#
# Required args
#
# LIBNAME   Library name
#
# Optional args
#
# One of (LOCALFIRST;LOCAL;INSTALLED)
# Defaults to LOCALFIRST if omitted
#
function(find_lib LIBNAME)
    set(options LOCALFIRST LOCAL INSTALLED)
    set(oneValueArgs "")
    set(multiValueArgs "")

    cmake_parse_arguments("FIND_LIB" "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (FIND_LIB_UNPARSED_ARGUMENTS)
        log(VAR FIND_LIB_UNPARSED_ARGUMENTS TITLE "Unrecognised arguments passed to find_lib()" LF)
        return()
    endif ()

    if (FIND_LIB_LOCALFIRST)
        log("${LIBNAME}: LOCALFIRST was defined")
    elseif (FIND_LIB_LOCAL)
        log("${LIBNAME}: LOCAL was defined")
    elseif (FIND_LIB_INSTALLED)
        log("${LIBNAME}: INSTALLED was defined")
    else ()
        log("${LIBNAME}: None of LOCALFIRST, LOCAL, INSTALLED were defined, defaulting to LOCALFIRST")
        set(FIND_LIB_LOCALFIRST TRUE)
    endif ()

    unset(${LIBNAME}_FOUND)

    if (FIND_LIB_LOCAL)
        log("Looking for ${LIBNAME} locally only...")
        find_package(${LIBNAME} PATHS "${STAGED_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake" NO_DEFAULT_PATH REQUIRED)
        return()
    elseif (FIND_LIB_LOCALFIRST)
        log("Looking for ${LIBNAME} locally first...")
        find_package(${LIBNAME} PATHS "${STAGED_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake" NO_DEFAULT_PATH)

        if (${LIBNAME}_FOUND)
            log(TITLE "Found OK")
            return()
        else ()
            log("Looking for ${LIBNAME} installed...")
            find_package(${LIBNAME} REQUIRED)
        endif ()
    else ()
        log("Looking for ${LIBNAME} installed...")
        find_package(${LIBNAME} REQUIRED)
    endif ()
endfunction()

# ##########################################################
# getVariant()      find library extended name for the
# current combination of
# CMAKE_BUILD_TYPE and BUILD_SHARED_LIBS
#
# Required parameters - (none)
# Optional parameters -
#
# [OUT] <var> receives the value (empty, -s, -d or -sd)
# The OUT keyword may be omitted if you want.
#
# SHARE <var> receives the share value (s or empty)
# <var> receives the debug value (d or empty)
#
# QUIET       Don't halt on parameter parsing error,
# just return with getVariant_value_ERROR
# true
#
# ##########################################################
function(getVariant)
    set(options QUIET)
    set(oneValueArgs "OUT;SHARE;DEBUG")
    set(multiValueArgs "")

    cmake_parse_arguments("GV" "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (GV_UNPARSED_ARGUMENTS)
        if (NOT DEFINED GV_OUT)
            set(GV_OUT ${GV_UNPARSED_ARGUMENTS})
        else ()
            if (GV_QUIET EQUAL FALSE)
                dump(GV_UNPARSED_ARGUMENTS TITLE "Unrecognised arguments passed to GV_value()" LF ALWAYS FATAL_ERROR)
            endif ()

            set(getVariant_ERROR TRUE PARENT_SCOPE)
            return()
        endif ()
    endif ()

    if (NOT DEFINED GV_OUT)
        if (GV_QUIET EQUAL FALSE)
            dump(GV_UNPARSED_ARGUMENTS TITLE "Missing OUT variable in call to GV_value()" LF ALWAYS FATAL_ERROR)
        endif ()

        set(getVariant_ERROR TRUE PARENT_SCOPE)
        return()
    endif ()

    unset(getVariant_ERROR PARENT_SCOPE)

    unset(_buildTail)
    unset(_shareTail)
    unset(_debugTail)

    if (BUILD_SHARED_LIBS)
        set(_shareTail "s")
    else ()
        set(_shareTail "")
    endif ()

    if (GV_SHARE)
        set(${GV_SHARE} ${_shareTail} PARENT_SCOPE)
    endif ()

    if (${CMAKE_BUILD_TYPE} STREQUAL Debug)
        set(_debugTail "d")
    else ()
        set(_debugTail "")
    endif ()

    if (GV_DEBUG)
        set(${GV_DEBUG} ${_debugTail} PARENT_SCOPE)
    endif ()

    string(APPEND _buildTail ${_shareTail} ${_debugTail})

    if (NOT ${_buildTail} STREQUAL "")
        string(PREPEND _buildTail "-")
    endif ()

    if (GV_OUT)
        set(${GV_OUT} ${_buildTail} PARENT_SCOPE)
    endif ()
endfunction()

# Get the on-disk name for a given library
#
# Works on Mac/Linux/Windows
#
# Required args
#
# NAME                      The name of a library
# RECEIVING_VARIABLE_NAME   The name of a variable
# to hold the output.
# Optional args
#
# NOEXT                     Do not add the extension
# to the output. Good for
# rm ${VAR}*
function(library_name NAME RECEIVING_VARIABLE_NAME)
    set(options NOEXT)
    set(oneValueArgs TITLE)
    set(multiValueArgs LISTS)

    cmake_parse_arguments(LN "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (LN_UNPARSED_ARGUMENTS)
        dump(LN_UNPARSED_ARGUMENTS TITLE "Unrecognised arguments passed to library_name()" LF ALWAYS FATAL_ERROR)
        return()
    endif ()

    getVariant(OUT variantType)

    # Determine library extension based on platform and library type
    if (LN_NOEXT)
        set(library_extension "")
    else ()
        if (WIN32)
            if (${LINK_TYPE_UC} STREQUAL "SHARED")
                set(library_extension ".dll")
            else ()
                set(library_extension ".lib")
            endif ()
        elseif (APPLE)
            if (${LINK_TYPE_UC} STREQUAL "SHARED")
                set(library_extension ".dynlib")
            else ()
                set(library_extension ".a")
            endif ()
        elseif (UNIX)
            if (${LINK_TYPE_UC} STREQUAL "SHARED")
                set(library_extension ".so")
            else ()
                set(library_extension ".a")
            endif ()
        else ()
            message(FATAL_ERROR "Unsupported platform")
        endif ()
    endif ()

    # Construct library name
    set(${RECEIVING_VARIABLE_NAME} "${CMAKE_${LINK_TYPE_UC}_LIBRARY_PREFIX}${NAME}${variantType}${library_extension}" PARENT_SCOPE)
endfunction()

# ##################################################################
# stringify_list(IN OUT SEP)
#
# Generate a list of quoted strings, separated by the SEP character
#
# Required args
#
# IN        The NAME of the list to work on
# OUT       The NAME of the list to receive the output
# SEP       The value to terminate each string with, like a comma
#           or a semi-colon.
# CR        TRUE if each element separated by CR
#           FALSE if not
# Q         TRUE if each element is surrounded by quotes
#           FALSE if not
# ##################################################################
function(stringify_list IN OUT SEP CR Q)
    if (Q)
        set(Q "\"")
    else ()
        set(Q "")
    endif ()

    resolve(${IN} vName vVal)

    if (CR)
        string(REPLACE ";" "${Q}${SEP}\n${Q}" TEMP "${vVal}")
    else ()
        string(REPLACE ";" "${Q}${SEP}${Q} " TEMP "${vVal}")
    endif ()

    set(${OUT} "${Q}${TEMP}${Q}" PARENT_SCOPE)
endfunction()

# ##################################################################
# configure_stringify(IN OUT [LIST [LIST [... [LIST]]]])
#
# Generate a vscode c_cpp_properties.json file
#
# Required args
#
# IN        The name of the template file with @placeholders@
# OUT       The name of the destination file to hold the output.
#
# Optional args
#
# LIST      Zero or more lists that need to be stringified before
#           the output can be generated. The list will be
#           stringified to a text string called <LIST>_VALUES,
#           so make sure you use THAT name in the template.
# ##################################################################
function(configure_stringify)
    set(FLAGS "CR;NOCR;QUOTES;NOQUOTES")
    set(SINGLE_ARGS "IN;SOURCE;OUT;DESTINATION;SEP;LIST")
    set(MULTI_ARGS "LISTS")

    cmake_parse_arguments(A_CS "${FLAGS}" "${SINGLE_ARGS}" "${MULTI_ARGS}" ${ARGN})

    if (A_CS_UNPARSED_ARGUMENTS AND NOT A_CS_IN AND NOT A_CS_SOURCE)
        list(POP_FRONT A_CS_UNPARSED_ARGUMENTS A_CS_IN)
    endif ()

    if (A_CS_UNPARSED_ARGUMENTS AND NOT A_CS_OUT AND NOT A_CS_DESTINATION)
        list(POP_FRONT A_CS_UNPARSED_ARGUMENTS A_CS_OUT)
    endif ()

    if (A_CS_LIST)
        list(PREPEND A_CS_LISTS ${A_CS_LIST})
        unset(A_CS_LIST)
    endif ()

    if (A_CS_UNPARSED_ARGUMENTS)
        list(APPEND A_CS_LISTS ${A_CS_UNPARSED_ARGUMENTS})
        unset(A_CS_UNPARSED_ARGUMENTS)
    endif ()

    if (A_CS_SEP)
        set(A_CS_SEP "${A_CS_SEP}")
    else ()
        set(A_CS_SEP ",")
    endif ()

    if (A_CS_CR)
        set(A_CS_CR true)
        set(A_CS_NOCR false)
    elseif (A_CS_NOCR)
        set(A_CS_CR false)
        set(A_CS_NOCR true)
    else ()
        set(A_CS_CR true)
        set(A_CS_NOCR false)
    endif ()

    if (A_CS_QUOTES)
        set(A_CS_QUOTES true)
        set(A_CS_NOQUOTES false)
    elseif (A_CS_NOQUOTES)
        set(A_CS_QUOTES false)
        set(A_CS_NOQUOTES true)
    else ()
        set(A_CS_QUOTES true)
        set(A_CS_NOQUOTES false)
    endif ()

    if (NOT A_CS_IN)
        if (A_CS_SOURCE)
            set(A_CS_IN ${A_CS_SOURCE})
            unset(A_CS_SOURCE)
        else ()
            log(FATAL_ERROR TITLE "Missing parameter" "IN or SOURCE missing")
        endif ()
    endif ()

    if (NOT A_CS_OUT)
        if (A_CS_DESTINATION)
            set(A_CS_OUT ${A_CS_DESTINATION})
            unset(A_CS_DESTINATION)
        else ()
            log(FATAL_ERROR TITLE "Missing parameter" "OUT or DESTINATION missing")
        endif ()
    endif ()

    foreach (aList ${A_CS_LISTS})
        list(LENGTH ${${aList}} PriorLen)
        list(REMOVE_DUPLICATES ${${aList}})
        list(LENGTH ${${aList}} AfterLen)
        log(LISTS PriorLen AfterLen TITLE "${aList} size before and after duplicates removed")
        set(REPLACEMENT ${aList}_VALUES)
        stringify_list(${${aList}} REPLACEMENT "${A_CS_SEP}" ${A_CS_CR} ${A_CS_QUOTES})
        set(${aList}_VALUES ${REPLACEMENT})
    endforeach ()

    string(REPLACE "%%" "\n" COPYRIGHT_NOTICE_RAW "$CACHE{COPYRIGHT}")
    string(REPLACE "@TPL_COPYRIGHT_YEAR@" "${COPYRIGHT_YEAR}" COPYRIGHT_NOTICE ${COPYRIGHT_NOTICE_RAW})

    string(TIMESTAMP TPL_CURRENT_YEAR "%Y")

    if (${TPL_CURRENT_YEAR} STREQUAL "${COPYRIGHT_YEAR}")
        set(TPL_CURRENT_YEAR "")
    else ()
        set(TPL_CURRENT_YEAR "-${TPL_CURRENT_YEAR}")
    endif ()

    string(REPLACE "@TPL_CURRENT_YEAR@" "${TPL_CURRENT_YEAR}" COPYRIGHT_NOTICE ${COPYRIGHT_NOTICE})

    string(TIMESTAMP TPL_CURRENT_DATE "%Y-%m-%d")
    string(REPLACE "@TPL_CURRENT_DATE@" ${TPL_CURRENT_DATE} COPYRIGHT_NOTICE ${COPYRIGHT_NOTICE})

    configure_file(${A_CS_IN} ${A_CS_OUT} @ONLY)
endfunction()

## @brief
##
##  Clear all local and parent variables named in PARAM_TARGET and force the
##  CACHE variable of the same name to exist and contain the value of the
##  variable named in PARAM_VAR. If the variable named in PARAM_VAR doesn't
##  exist, or we were passed the empty value "", the value of the CACHE
##  variable named in PARAM_TARGET is set to the value PARAM_VALUE.
##
##   The CACHE variable will have the type supplied in TYPE
##
## @param PARAM_TARGET holds the NAME of the variable to action
## @param PARAM_VAR holds the NAME of the variable which might hold our value.
##           It may be the empty string "" to tell us to just set the default.
## @param PARAM_VALUE holds the value to use if VAR doesn't exist or is ""
## @param PARAM_TYPE is the type of CACHE variable to create (STRING, BOOL, FILEPATH, etc)
macro(forceUnset PARAM_TARGET)
    unset(${PARAM_TARGET})
    if(CMAKE_CURRENT_FUNCTION)
        unset(${PARAM_TARGET} PARENT_SCOPE)
    endif ()
    unset(${PARAM_TARGET} CACHE)
endmacro()
macro(forceSet PARAM_TARGET PARAM_VAR PARAM_VALUE PARAM_TYPE)

    forceUnset(${PARAM_TARGET})

    if (NOT "${PARAM_VAR}" STREQUAL "" AND DEFINED ${PARAM_VAR})
        set(${PARAM_TARGET} "${${PARAM_VAR}}" CACHE ${PARAM_TYPE} "Please don't change" FORCE)
        set(${PARAM_TARGET} "${${PARAM_VAR}}")
        if(CMAKE_CURRENT_FUNCTION)
            set(${PARAM_TARGET} "${${PARAM_VAR}}" PARENT_SCOPE)
        endif ()
    else ()
        set(${PARAM_TARGET} "${PARAM_VALUE}" CACHE ${PARAM_TYPE} "Please don't change" FORCE)
        set(${PARAM_TARGET} "${PARAM_VALUE}")
        if(CMAKE_CURRENT_FUNCTION)
            set(${PARAM_TARGET} "${PARAM_VALUE}" PARENT_SCOPE)
        endif ()
    endif ()

    unset(PARAM_TARGET)
    unset(PARAM_VAR)
    unset(PARAM_VALUE)
    unset(PARAM_TYPE)
endmacro()

macro(generateExportHeader _target)
    include(GenerateExportHeader)
    string(TOLOWER "${_target}" _targetlc)
    if ("${CMAKE_SOURCE_DIR}" STREQUAL "${PROJECT_SOURCE_DIR}")
        set(_generated_export_header "${CMAKE_SOURCE_DIR}/include/${_target}/${_targetlc}_export.h")
    else ()
        set(_generated_export_header "${CMAKE_SOURCE_DIR}/${_target}/include/${_target}/${_targetlc}_export.h")
    endif ()
    generate_export_header(${_target} EXPORT_FILE_NAME ${_generated_export_header})
    target_sources(${_target} PUBLIC FILE_SET HEADERS BASE_DIRS ${HEADER_BASE_DIRS} FILES ${_generated_export_header})

endmacro()

function(newestFile IN_LIST OUT_LIST)
    set(working_list "")
    set(sorted_list "")

    log(TITLE "Provided list" LISTS IN_LIST)

    # 1. Filter only existing files
    foreach(file IN LISTS IN_LIST)
        if(EXISTS "${file}")
            list(APPEND working_list "${file}")
        endif()
    endforeach()

    log(TITLE "Working list" LISTS working_list)

    # 2. Selection sort by timestamp
    while(working_list)
        list(GET working_list 0 newest)

        foreach(current_file IN LISTS working_list)
            # If current_file is newer than our current 'newest', update 'newest'
            if("${current_file}" IS_NEWER_THAN "${newest}")
                set(newest "${current_file}")
            endif()
        endforeach()

        list(APPEND sorted_list "${newest}")
        list(REMOVE_ITEM working_list "${newest}")
    endwhile()

    log(TITLE "Sorted by date order" LISTS sorted_list)
    set(${OUT_LIST} "${sorted_list}" PARENT_SCOPE)
endfunction()

set(CPYRGHT "# ##############################################################################
# Copyright (c) @TPL_COPYRIGHT_YEAR@@TPL_CURRENT_YEAR@ Hoffmann Systems. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# ##############################################################################
#
# Author: Geoffrey Hoffmann
# Date: @TPL_CURRENT_DATE@
#
# ##############################################################################
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice,
# this list of conditions and the following disclaimer.
#
# 2. Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the distribution.
#
# 3. Neither the name of the copyright holder nor the names of its
# contributors may be used to endorse or promote products derived from
# this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS 'AS IS'
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
# ##############################################################################")
string(REPLACE "\n" "%%" CPYRGHT ${CPYRGHT})
set(COPYRIGHT "${CPYRGHT}" CACHE STRING "Copyright notice" FORCE)
