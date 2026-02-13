include_guard(GLOBAL)

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
    if (NOT VAR_NAME)
        message(FATAL_ERROR "forceSet: VAR_NAME is required")
    endif ()
    if (NOT DEFINED TYPE OR TYPE STREQUAL "")
        set(TYPE STRING)
    endif ()

    # Derive environment variable name if not provided
    if (DEFINED ENV_NAME AND NOT ENV_NAME STREQUAL "")
        set(_ENV_NAME "${ENV_NAME}")
    else ()
        set(_ENV_NAME "${VAR_NAME}")
    endif ()

    # Set in local scope
    set(${VAR_NAME} "${VALUE}")

    # Set in parent scope
    if (CMAKE_CURRENT_FUNCTION)
        set(${VAR_NAME} "${VALUE}" PARENT_SCOPE)
    endif ()

    # Set in process environment
    set(ENV{${_ENV_NAME}} "${VALUE}")

    # Set in cache (force to override any prior value)
    # Provide an empty docstring per convention.
    set(${VAR_NAME} "${VALUE}" CACHE ${TYPE} "" FORCE)

    # Optional verbose trace for debugging
    if (DEFINED CMAKE_MESSAGE_LOG_LEVEL AND (CMAKE_MESSAGE_LOG_LEVEL STREQUAL "VERBOSE" OR CMAKE_MESSAGE_LOG_LEVEL STREQUAL "DEBUG"))
        message(VERBOSE "forceSet: ${VAR_NAME}='${VALUE}' (TYPE=${TYPE}) ENV{${_ENV_NAME}} updated and cache forced")
    endif ()
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

    foreach (SRCDIR IN LISTS MV_SOURCE_DIRS)
        foreach (PATTERN IN LISTS MV_FILE_PATTERNS)
            file(GLOB FILES "${SRCDIR}/${PATTERN}")

            foreach (FILE IN LISTS FILES)
                get_filename_component(FILE_NAME ${FILE} NAME)
                message(STATUS "Copying ${FILE_NAME} from ${SRCDIR} to ${MV_TARGET_DIR}")

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
        set(p "${d}/${f}")
        if (EXISTS "${p}")
            ReplaceInFile("${p}" "${old}" "${new}")
            break()
        endif ()
    endforeach ()
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
# REPLACESTR  The text to replace FINDSTR with
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

    set(modes
            FATAL_ERROR
            SEND_ERROR
            WARNING
            AUTHOR_WARNING
            DEPRECATION
            NOTICE
            STATUS
            VERBOSE
            DEBUG
            TRACE
    )

    set(switches
            ALWAYS
            VERBATIM
    )
    set(options
            ${modes}
            ${switches}
    )

    cmake_parse_arguments(AA "${options}" "" "" ${ARGN})

    set(alreadyHaveOne OFF)
    foreach (mode IN LISTS modes)
        if (AA_${mode})
            if (alreadyHaveOne)
                unset(AA_${mode})
            else ()
                set(alreadyHaveOne ON)
            endif ()
        endif ()
    endforeach ()

    set(text "${AA_UNPARSED_ARGUMENTS}")
    if (NOT AA_VERBATIM)
        resolve(${text} dc text)
    endif ()

    if (APP_DEBUG OR AA_ALWAYS)
        if (AA_FATAL_ERROR)
            message(FATAL_ERROR "${text}")
        elseif (AA_SEND_ERROR)
            message(SEND_ERROR "${text}")
        elseif (AA_WARNING)
            message(WARNING "${text}")
        elseif (AA_AUTHOR_WARNING)
            message(AUTHOR_WARNING "${text}")
        elseif (AA_DEPRECATION)
            message(DEPRECATION "${text}")
        elseif (AA_STATUS)
            message(STATUS "${text}")
        elseif (AA_VERBOSE)
            message(VERBOSE "${text}")
        elseif (AA_DEBUG)
            message(DEBUG "${text}")
        elseif (AA_TRACE)
            message(TRACE "${text}")
        else ()
            message(NOTICE "${text}")
        endif ()
    endif ()

endfunction()

function(brif doIt)
    if (${doIt})
        m(${ARGV})
    endif ()
endfunction()

function(doDump)

    set(modes
            FATAL_ERROR
            SEND_ERROR
            WARNING
            AUTHOR_WARNING
            DEPRECATION
            NOTICE
            STATUS
            VERBOSE
            DEBUG
            TRACE
    )

    set(switches
            ALWAYS
            VERBATIM
    )
    set(options
            ${modes}
            ${switches}
    )

    cmake_parse_arguments(AA "${options}" "" "" ${ARGN})

    set(alreadyHaveOne OFF)
    foreach (mode IN LISTS modes)
        if (AA_${mode})
            if (alreadyHaveOne)
                unset(AA_${mode})
            else ()
                set(alreadyHaveOne ON)
            endif ()
        endif ()
    endforeach ()

    list(POP_FRONT AA_UNPARSED_ARGUMENTS doDump_ITEMS doDump_TITLE)

    set(dunno)
    if (NOT DEFINED ${doDump_ITEMS})
        set(dunno "${doDump_TITLE} (not defined)")
    elseif ("${${doDump_ITEMS}}" STREQUAL "")
        set(dunno "${doDump_TITLE} (empty)")
    endif ()

    macro(mmmChocolate words)
        if (AA_FATAL_ERROR)
            m(FATAL_ERROR "${words}" VERBATIM)
        elseif (AA_SEND_ERROR)
            m(SEND_ERROR "${words}" VERBATIM)
        elseif (AA_WARNING)
            m(WARNING "${words}" VERBATIM)
        elseif (AA_AUTHOR_WARNING)
            m(AUTHOR_WARNING "${words}" VERBATIM)
        elseif (AA_DEPRECATION)
            m(DEPRECATION "${words}" VERBATIM)
        elseif (AA_STATUS)
            m(STATUS "${words}" VERBATIM)
        elseif (AA_VERBOSE)
            m(VERBOSE "${words}" VERBATIM)
        elseif (AA_DEBUG)
            m(DEBUG "${words}" VERBATIM)
        elseif (AA_TRACE)
            m(TRACE "${words}" VERBATIM)
        else ()
            m(NOTICE "${words}" VERBATIM)
        endif ()
    endmacro()

    if (${dunno})
        mmmChocolate("${dunno}")
        return()
    endif ()

    resolve(doDump_ITEMS VR VL)

    list(LENGTH ${doDump_ITEMS} length)
    if (${length} EQUAL 1)
        mmmChocolate("${doDump_TITLE} ${VL}")
        return()
    endif ()

    mmmChocolate("${doDump_TITLE}")
    list(APPEND CMAKE_MESSAGE_INDENT "  ")

    foreach (l ${VL})
        mmmChocolate("${l}")
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
function(log)

    set(modes
            FATAL_ERROR
            SEND_ERROR
            WARNING
            AUTHOR_WARNING
            DEPRECATION
            NOTICE
            STATUS
            VERBOSE
            DEBUG
            TRACE
    )

    set(switches
            ALWAYS
            LF
            LF_
            _LF
            INDENT
            OUTDENT
    )
    set(options
            ${modes}
            ${switches}
    )
    set(oneValueArgs TITLE LIST)
    set(multiValueArgs LISTS)

    set(index 0)
    list(TRANSFORM ARGN REPLACE "VARS" "LISTS")
    list(TRANSFORM ARGN REPLACE "VAR" "LIST")
    #
    #    foreach (item IN LISTS ARGN)
    #        if ("${item}" STREQUAL "VAR")
    #            list(REMOVE_AT ARGN ${index})
    #            list(INSERT ARGN ${index} "LIST")
    #        elseif ("${item}" STREQUAL "VARS")
    #            list(REMOVE_AT ARGN ${index})
    #            list(INSERT ARGN ${index} "LISTS")
    #        endif ()
    #        math(EXPR index "${index} + 1")
    #    endforeach ()

    cmake_parse_arguments("AA" "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if (AA_UNPARSED_ARGUMENTS AND NOT "${AA_UNPARSED_ARGUMENTS}" STREQUAL "")
        list(APPEND AA_LISTS ${AA_UNPARSED_ARGUMENTS})
    endif ()

    if (AA_LIST AND NOT "${AA_LIST}" STREQUAL "")
        list(APPEND AA_LISTS ${AA_LIST})
        unset(AA_LIST)
    endif ()

    set(alreadyHaveOne OFF)
    foreach (mode IN LISTS modes)
        if (AA_${mode})
            if (alreadyHaveOne)
                unset(AA_${mode})
            else ()
                set(alreadyHaveOne ON)
            endif ()
        endif ()
    endforeach ()

    #    if (${LIST_NAME} IN_LIST options)
    #        string(TOUPPER "${LIST_NAME}" LIST_NAME)
    #        set(AA_${LIST_NAME} TRUE)
    #        unset(LIST_NAME)
    #    elseif (${LIST_NAME} IN_LIST oneValueArgs)
    #        string(TOUPPER "${LIST_NAME}" LIST_NAME)
    #        list(GET AA_UNPARSED_ARGUMENTS 0 AA_${LIST_NAME})
    #        list(REMOVE_AT AA_UNPARSED_ARGUMENTS 0)
    #        unset(LIST_NAME)
    #    elseif (${LIST_NAME} IN_LIST multiValueArgs)
    #        string(TOUPPER "${LIST_NAME}" LIST_NAME)
    #        set(AA_${LIST_NAME} ${AA_UNPARSED_ARGUMENTS})
    #        unset(AA_UNPARSED_ARGUMENTS)
    #        unset(LIST_NAME)
    #    endif ()

    #    if (AA_UNPARSED_ARGUMENTS)
    #        message(FATAL_ERROR "Unrecognised arguments : ${AA_UNPARSED_ARGUMENTS}")
    #        return() # Won't, really
    #    endif ()

    unset(LF_)
    unset(_LF)

    if (AA_LF OR AA_LF_)
        set(LF_ ON)
        unset(AA_LF_)
    endif ()

    if (AA_LF OR AA__LF)
        set(_LF ON)
        unset(AA__LF)
    endif ()

    if (AA_OUTDENT)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
    endif ()

    brif(LF_)

    #    if (AA_LIST)
    #        list(FIND ARGN "LIST" listIndex)
    #        list(FIND ARGN "LISTS" listsIndex)
    #
    #        if (listIndex EQUAL -1 AND listsIndex GREATER_EQUAL 0)
    #            # LIST is first item in command arguments
    #            list(PREPEND AA_LISTS ${AA_LIST})
    #            unset(AA_LIST)
    #        elseif (listsIndex EQUAL -1 AND listIndex GREATER_EQUAL 0)
    #            # LISTS is first item in command arguments
    #            list(APPEND AA_LISTS ${AA_LIST})
    #            unset(AA_LIST)
    #        elseif (listIndex LESS listsIndex)
    #            # LIST is before LISTS
    #            list(PREPEND AA_LISTS ${AA_LIST})
    #            unset(AA_LIST)
    #        elseif (listIndex GREATER listsIndex)
    #            # LIST is after LISTS
    #            list(APPEND AA_LISTS ${AA_LIST})
    #            unset(AA_LIST)
    #        else ()
    #            set(AA_LISTS ${AA_LIST})
    #        endif ()
    #    endif ()

    unset(AA_TEMP_TITLE)

    if (AA_TITLE)
        set(AA_TEMP_TITLE "${AA_TITLE}")
        set(AA_TITLE_USED "${AA_TEMP_TITLE}")
        set(AA_TITLE_USED "${AA_TEMP_TITLE} - Begin")

        if (AA_FATAL_ERROR)
            m(FATAL_ERROR "${AA_TITLE_USED}")
        elseif (AA_SEND_ERROR)
            m(SEND_ERROR "${AA_TITLE_USED}")
        elseif (AA_WARNING)
            m(WARNING "${AA_TITLE_USED}")
        elseif (AA_AUTHOR_WARNING)
            m(AUTHOR_WARNING "${AA_TITLE_USED}")
        elseif (AA_DEPRECATION)
            m(DEPRECATION "${AA_TITLE_USED}")
        elseif (AA_STATUS)
            m(STATUS "${AA_TITLE_USED}")
        elseif (AA_VERBOSE)
            m(VERBOSE "${AA_TITLE_USED}")
        elseif (AA_DEBUG)
            m(DEBUG "${AA_TITLE_USED}")
        elseif (AA_TRACE)
            m(TRACE "${AA_TITLE_USED}")
        else ()
            m(NOTICE "${AA_TITLE_USED}")
        endif ()

        list(APPEND CMAKE_MESSAGE_INDENT "  ")
    endif ()

    foreach (AA_ ${AA_LISTS})
        resolve(${AA_} VVAR VVAL)
        set(AA_TITLE "Contents of $CACHE{VVAR}: ")

        if (AA_FATAL_ERROR)
            doDump(FATAL_ERROR ${VVAR} "${AA_TITLE}")
        elseif (AA_SEND_ERROR)
            doDump(SEND_ERROR ${VVAR} "${AA_TITLE}")
        elseif (AA_WARNING)
            doDump(WARNING ${VVAR} "${AA_TITLE}")
        elseif (AA_AUTHOR_WARNING)
            doDump(AUTHOR_WARNING ${VVAR} "${AA_TITLE}")
        elseif (AA_DEPRECATION)
            doDump(DEPRECATION ${VVAR} "${AA_TITLE}")
        elseif (AA_STATUS)
            doDump(STATUS ${VVAR} "${AA_TITLE}")
        elseif (AA_VERBOSE)
            doDump(VERBOSE ${VVAR} "${AA_TITLE}")
        elseif (AA_DEBUG)
            doDump(DEBUG ${VVAR} "${AA_TITLE}")
        elseif (AA_TRACE)
            doDump(TRACE ${VVAR} "${AA_TITLE}")
        else ()
            doDump(NOTICE ${VVAR} "${AA_TITLE}")
        endif ()
    endforeach ()

    if (AA_TEMP_TITLE)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        set(AA_TITLE_USED "${AA_TEMP_TITLE}")
        set(AA_TITLE_USED "${AA_TEMP_TITLE} - End")

        if (AA_FATAL_ERROR)
            m(FATAL_ERROR "${AA_TITLE_USED}")
        elseif (AA_SEND_ERROR)
            m(SEND_ERROR "${AA_TITLE_USED}")
        elseif (AA_WARNING)
            m(WARNING "${AA_TITLE_USED}")
        elseif (AA_AUTHOR_WARNING)
            m(AUTHOR_WARNING "${AA_TITLE_USED}")
        elseif (AA_DEPRECATION)
            m(DEPRECATION "${AA_TITLE_USED}")
        elseif (AA_STATUS)
            m(STATUS "${AA_TITLE_USED}")
        elseif (AA_VERBOSE)
            m(VERBOSE "${AA_TITLE_USED}")
        elseif (AA_DEBUG)
            m(DEBUG "${AA_TITLE_USED}")
        elseif (AA_TRACE)
            m(TRACE "${AA_TITLE_USED}")
        else ()
            m(NOTICE "${AA_TITLE_USED}")
        endif ()
    endif ()

    if (AA_INDENT)
        list(APPEND CMAKE_MESSAGE_INDENT "  ")
    endif ()

    brif(_LF)

endfunction()

function(msg)
    set(modes
            FATAL_ERROR
            SEND_ERROR
            WARNING
            AUTHOR_WARNING
            DEPRECATION
            NOTICE
            STATUS
            VERBOSE
            DEBUG
            TRACE
    )

    set(switches
            ALWAYS
    )
    set(options
            ${modes}
            ${switches}
    )

    cmake_parse_arguments(AA "${options}" "" "" ${ARGN})
    set(AA_message_text "${AA_UNPARSED_ARGUMENTS}")

    set(alreadyHaveOne OFF)
    foreach (mode IN LISTS modes)
        if (AA_${mode})
            if (alreadyHaveOne)
                unset(AA_${mode})
            else ()
                set(alreadyHaveOne ON)
            endif ()
        endif ()
    endforeach ()

    if (AA_ALWAYS OR APP_DEBUG)
        if (AA_FATAL_ERROR)
            message(FATAL_ERROR "${AA_message_text}")
        elseif (AA_SEND_ERROR)
            message(SEND_ERROR "${AA_message_text}")
        elseif (AA_WARNING)
            message(WARNING "${AA_message_text}")
        elseif (AA_AUTHOR_WARNING)
            message(AUTHOR_WARNING "${AA_message_text}")
        elseif (AA_DEPRECATION)
            message(DEPRECATION "${AA_message_text}")
        elseif (AA_STATUS)
            message(STATUS "${AA_message_text}")
        elseif (AA_VERBOSE)
            message(VERBOSE "${AA_message_text}")
        elseif (AA_DEBUG)
            message(DEBUG "${AA_message_text}")
        elseif (AA_TRACE)
            message(TRACE "${AA_message_text}")
        else ()
            message(NOTICE "${AA_message_text}")
        endif ()
    endif ()
endfunction()

function(longest)
    set(switches LEFT RIGHT CENTRE GAP QUIET)
    set(args CURRENT MIN_LENGTH PAD_CHAR TEXT LONGEST PADDED JUSTIFY)
    set(lists)

    cmake_parse_arguments("LONG" "${switches}" "${args}" "${lists}" ${ARGN})

    if (LONG_JUSTIFY)
        string(TOUPPER "${LONG_JUSTIFY}" LONG_JUSTIFY)
        if (NOT LONG_JUSTIFY STREQUAL "LEFT" AND NOT LONG_JUSTIFY STREQUAL "RIGHT" AND NOT LONG_JUSTIFY STREQUAL "CENTRE")
            if (NOT LONG_QUIET)
                msg(WARNING "longest(): JUSTIFY must be LEFT, CENTRE, or RIGHT, got '${LONG_JUSTIFY}'. Defaulted to LEFT")
            endif ()
            set(LONG_LEFT ON)
            set(LONG_CENTRE OFF)
            set(LONG_RIGHT OFF)
            set(LONG_JUSTIFY "LEFT")
        else ()
            if (LONG_JUSTIFY STREQUAL "LEFT")
                set(LONG_LEFT ON)
                set(LONG_CENTRE OFF)
                set(LONG_RIGHT OFF)
            elseif (LONG_JUSTIFY STREQUAL "CENTRE")
                set(LONG_LEFT OFF)
                set(LONG_CENTRE ON)
                set(LONG_RIGHT OFF)
            else ()
                set(LONG_LEFT OFF)
                set(LONG_CENTRE OFF)
                set(LONG_RIGHT ON)
            endif ()
        endif ()
    endif ()
    if ((LONG_LEFT AND LONG_CENTRE) OR
    (LONG_LEFT AND LONG_RIGHT) OR
    (LONG_CENTRE AND LONG_RIGHT))
        if (NOT LONG_QUIET)
            msg(WARNING "longest(): Can't have more than one of LEFT, CENTRE, or RIGHT padding. Pick one. Defaulted to LEFT")
        endif ()
        set(LONG_LEFT ON)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "LEFT")
    elseif (LONG_LEFT AND LONG_JUSTIFY AND (LONG_JUSTIFY STREQUAL "CENTRE" OR LONG_JUSTIFY STREQUAL "RIGHT"))
        if (NOT LONG_QUIET)
            msg(WARNING "longest(): Can't have both LEFT and JUSTIFY CENTRE or JUSTIFY RIGHT padding. Pick one. Defaulted to LEFT")
        endif ()
        set(LONG_LEFT ON)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "LEFT")
    elseif (LONG_CENTRE AND LONG_JUSTIFY AND (LONG_JUSTIFY STREQUAL "LEFT" OR LONG_JUSTIFY STREQUAL "RIGHT"))
        if (NOT LONG_QUIET)
            msg(WARNING "longest(): Can't have both CENTRE and JUSTIFY LEFT or JUSTIFY RIGHT padding. Pick one. Defaulted to LEFT")
        endif ()
        set(LONG_LEFT ON)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "LEFT")
    elseif (LONG_RIGHT AND LONG_JUSTIFY AND (LONG_JUSTIFY STREQUAL "LEFT" OR LONG_JUSTIFY STREQUAL "CENTRE"))
        if (NOT LONG_QUIET)
            msg(WARNING "longest(): Can't have both RIGHT and JUSTIFY LEFT or JUSTIFY CENTRE padding. Pick one. Defaulted to LEFT")
        endif ()
        set(LONG_LEFT ON)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "LEFT")
    elseif (LONG_LEFT)
        set(LONG_LEFT ON)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "LEFT")
    elseif (LONG_CENTRE)
        set(LONG_LEFT OFF)
        set(LONG_CENTRE ON)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "CENTRE")
    elseif (LONG_RIGHT)
        set(LONG_LEFT OFF)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT ON)
        set(LONG_JUSTIFY "RIGHT")
    else ()
        set(LONG_LEFT ON)
        set(LONG_CENTRE OFF)
        set(LONG_RIGHT OFF)
        set(LONG_JUSTIFY "LEFT")
    endif ()
    if (NOT DEFINED LONG_CURRENT OR LONG_CURRENT STREQUAL "")
        set(LONG_CURRENT 0)
    else ()
        if (NOT LONG_CURRENT MATCHES "^[0-9]+$")
            if (NOT LONG_QUIET)
                msg(WARNING "longest(): CURRENT must be a non-negative integer, got '${LONG_CURRENT}'")
            endif ()
            set(LONG_CURRENT 0)
        endif ()
    endif ()
    if (NOT LONG_MIN_LENGTH OR LONG_MIN_LENGTH STREQUAL "")
        set(LONG_MIN_LENGTH 0)
    else ()
        if (NOT LONG_MIN_LENGTH MATCHES "^[0-9]+$")
            if (NOT LONG_QUIET)
                msg(WARNING "longest(): MIN_LENGTH must be a non-negative integer, got '${LONG_MIN_LENGTH}'")
            endif ()
            set(LONG_MIN_LENGTH 0)
        endif ()
    endif ()
    if (NOT LONG_PAD_CHAR OR LONG_PAD_CHAR STREQUAL "")
        set(LONG_PAD_CHAR " ")
    endif ()
    if (LONG_GAP)
        if (NOT LONG_TEXT)
            set(gap ${LONG_PAD_CHAR})
        else ()
            set(gap " ")
        endif ()
    else()
        set(gap "")
    endif ()

    string(REPEAT "${LONG_PAD_CHAR}" ${LONG_MIN_LENGTH} fixed_padding)
    if (LONG_LEFT)
        set(fixed_l_padding "")
        set(fixed_r_padding "${gap}${fixed_padding}")
    elseif (LONG_RIGHT)
        set(fixed_l_padding "${fixed_padding}${gap}")
        set(fixed_r_padding "")
    else ()
        set(fixed_l_padding "${fixed_padding}${gap}")
        set(fixed_r_padding "${gap}${fixed_padding}")
    endif ()

    if (NOT LONG_TEXT)
        set(LONG_TEXT "")
    endif ()

    string(LENGTH "${LONG_TEXT}" this_length)

    if (${this_length} GREATER ${LONG_CURRENT})
        set(new_longest ${this_length})
    else ()
        set(new_longest ${LONG_CURRENT})
    endif ()
    set(${LONG_LONGEST} ${new_longest} PARENT_SCOPE)

    math(EXPR DIFFERENCE "${new_longest} - ${this_length}")
    if (DIFFERENCE GREATER_EQUAL 0)
        if(LONG_CENTRE)
            math(EXPR lDIFF "${DIFFERENCE} / 2")
            math(EXPR rDIFF "${DIFFERENCE} - ${lDIFF}")
            string(REPEAT "${LONG_PAD_CHAR}" ${lDIFF} needed_l_padding)
            string(REPEAT "${LONG_PAD_CHAR}" ${rDIFF} needed_r_padding)
        elseif (LONG_LEFT)
            set(needed_l_padding)
            string(REPEAT "${LONG_PAD_CHAR}" ${DIFFERENCE} needed_r_padding)
        else ()
            string(REPEAT "${LONG_PAD_CHAR}" ${DIFFERENCE} needed_l_padding)
            set(needed_r_padding)
        endif ()
    else ()
        set(needed_l_padding)
        set(needed_r_padding)
    endif ()

    if (LONG_PADDED)
#        set(needed_l_padding " NL ")
#        set(fixed_l_padding  " FL ")
#        set(fixed_r_padding  " FR ")
#        set(needed_r_padding " NR ")
        set("${LONG_PADDED}" "${needed_l_padding}${fixed_l_padding}${LONG_TEXT}${fixed_r_padding}${needed_r_padding}" PARENT_SCOPE)
#
#        if (LONG_LEFT)
#            set("${LONG_PADDED}" "${LONG_TEXT}${fixed_padding}${needed_padding}" PARENT_SCOPE)
#        else ()
#            set("${LONG_PADDED}" "${needed_padding}${fixed_padding}${LONG_TEXT}" PARENT_SCOPE)
#        endif ()
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
    set(FLAGS CR NOCR QUOTES NOQUOTES)
    set(SINGLE_ARGS IN SOURCE OUT DESTINATION SEP LIST)
    set(MULTI_ARGS LISTS)

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
    if (CMAKE_CURRENT_FUNCTION)
        unset(${PARAM_TARGET} PARENT_SCOPE)
    endif ()
    unset(${PARAM_TARGET} CACHE)
endmacro()
macro(forceSet PARAM_TARGET PARAM_VAR PARAM_VALUE PARAM_TYPE)

    forceUnset(${PARAM_TARGET})

    if (NOT "${PARAM_VAR}" STREQUAL "" AND DEFINED ${PARAM_VAR})
        set(${PARAM_TARGET} "${${PARAM_VAR}}" CACHE ${PARAM_TYPE} "Please don't change" FORCE)
        set(${PARAM_TARGET} "${${PARAM_VAR}}")
        if (CMAKE_CURRENT_FUNCTION)
            set(${PARAM_TARGET} "${${PARAM_VAR}}" PARENT_SCOPE)
        endif ()
    else ()
        set(${PARAM_TARGET} "${PARAM_VALUE}" CACHE ${PARAM_TYPE} "Please don't change" FORCE)
        set(${PARAM_TARGET} "${PARAM_VALUE}")
        if (CMAKE_CURRENT_FUNCTION)
            set(${PARAM_TARGET} "${PARAM_VALUE}" PARENT_SCOPE)
        endif ()
    endif ()

    unset(PARAM_TARGET)
    unset(PARAM_VAR)
    unset(PARAM_VALUE)
    unset(PARAM_TYPE)
endmacro()

macro(generateExportHeader)
    set(FLAGS "")
    set(SINGLE_ARGS "TARGET;FILE_SET;DESTDIR;BASE_DIR")
    set(MULTI_ARGS "")

    cmake_parse_arguments(A_GEH "${FLAGS}" "${SINGLE_ARGS}" "${MULTI_ARGS}" ${ARGN})

    if (NOT A_GEH_TARGET)
        message(FATAL_ERROR "TARGET missing for generateExportHeader")
    else ()
        set(_target ${A_GEH_TARGET})
        string(TOLOWER "${_target}" _targetlc)
    endif ()

    if (NOT A_GEH_FILE_SET)
        set(A_GEH_FILE_SET HEADERS)
    endif ()

    if (NOT A_GEH_DESTDIR)
        if (MONOREPO)
            set(A_GEH_DESTDIR "${CMAKE_SOURCE_DIR}/include/${_target}")
            message(AUTHOR_WARNING "MONOREPO: Setting A_GEH_DESTDIR to '${A_GEH_DESTDIR}'")
        else ()
            set(A_GEH_DESTDIR "${CMAKE_SOURCE_DIR}/${_target}/include/${_target}")
            message(AUTHOR_WARNING "Setting A_GEH_DESTDIR to '${A_GEH_DESTDIR}'")
        endif ()
    endif ()

    get_filename_component(A_GEH_DESTDIR "${A_GEH_DESTDIR}" ABSOLUTE)

    set(_generated_export_header "${A_GEH_DESTDIR}/${_targetlc}_export.h")

    include(GenerateExportHeader)

    # Before generate_export_header
    set(_saved_scan_for_modules ${CMAKE_CXX_SCAN_FOR_MODULES})
    set(CMAKE_CXX_SCAN_FOR_MODULES OFF)
    generate_export_header(${_target} EXPORT_FILE_NAME ${_generated_export_header})
    set(CMAKE_CXX_SCAN_FOR_MODULES ${_saved_scan_for_modules})

    target_sources(${_target}
            PUBLIC
            FILE_SET ${A_GEH_FILE_SET}
            TYPE HEADERS
            #            BASE_DIRS ${A_GEH_DESTDIR}
            FILES ${_generated_export_header})

endmacro()

function(newestFile IN_LIST IGNORE_EXISTENCE OUT_LIST)
    set(working_list "")
    set(sorted_list "")

    log(TITLE "Provided list" LISTS IN_LIST)

    # 1. Filter only existing files
    foreach (file IN LISTS IN_LIST)
        if (EXISTS "${file}" OR IGNORE_EXISTENCE)
            list(APPEND working_list "${file}")
        endif ()
    endforeach ()
    log(TITLE "Working list" LISTS working_list)

    # 2. Selection sort by timestamp
    while (working_list)
        list(GET working_list 0 newest)

        foreach (current_file IN LISTS working_list)

            # If current_file is newer than our current 'newest', update 'newest'
            if ("${current_file}" IS_NEWER_THAN "${newest}" AND
                    "${newest}" IS_NEWER_THAN "${current_file}")
                set(newest "${newest}")
            elseif ("${newest}" IS_NEWER_THAN "${current_file}")
                set(newest "${newest}")
            elseif ("${current_file}" IS_NEWER_THAN "${newest}")
                set(newest "${current_file}")
            endif ()
        endforeach ()

        list(APPEND sorted_list "${newest}")
        list(REMOVE_ITEM working_list "${newest}")
    endwhile ()

    log(TITLE "Sorted by date order" LISTS sorted_list)
    set(${OUT_LIST} "${sorted_list}" PARENT_SCOPE)
endfunction()
##
########
##
function(replaceFile target patchList)

    string(ASCII 27 ESC)
    set(BOLD "${ESC}[1m")
    set(RED "${ESC}[31m${BOLD}")
    set(GREEN "${ESC}[32m${BOLD}")
    set(ORANGE "${ESC}[33m")
    set(YELLOW "${ESC}[33m${BOLD}")
    set(OFF "${ESC}[0m")
    unset(visited)

    message(" ")
    message(CHECK_START "Replacing files for target ${YELLOW}${target}${OFF}")
    list(APPEND CMAKE_MESSAGE_INDENT "\t")
    set(any_failed OFF)

    if (${target}_ALREADY_FOUND)
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "Not required for ${BOLD}imported libraries${OFF}")
        return()
    endif ()

    foreach (patch IN LISTS patchList)

        SplitAt("${patch}" "|" patchBranch externalTrunk)

        message(CHECK_START "Replacement pattern is ${YELLOW}${patchBranch}${OFF}")
        list(APPEND CMAKE_MESSAGE_INDENT "\t")

        string(LENGTH "${externalTrunk}" etLength)
        math(EXPR etLastCharOffset "${etLength} - 1")
        string(SUBSTRING "${externalTrunk}" ${etLastCharOffset} -1 etLastChar)
        set(etIsAbsolute OFF)
        if ("${etLastChar}" STREQUAL "/")
            set(etIsAbsolute ON)
        endif ()

        set(from_path "${CMAKE_SOURCE_DIR}/cmake/patches/${patchBranch}")
        if (EXISTS "${from_path}" AND NOT IS_DIRECTORY "${from_path}")
            get_filename_component(actual_from_path "${from_path}" DIRECTORY)
            get_filename_component(file_pattern "${from_path}" NAME)

            set(final_part "${file_pattern}")
            set(from_path "${actual_from_path}")

            string(LENGTH "${file_pattern}" fn_len)
            string(LENGTH "${patchBranch}" path_len)
            math(EXPR path_len "${path_len} - ${fn_len} - 1")

            string(SUBSTRING "${patchBranch}" 0 ${path_len} patchBranch)
        elseif (EXISTS "${from_path}")
            get_filename_component(final_part "${from_path}" NAME)
            set(file_pattern "*")
        endif ()

        set(failed OFF)

        if (EXISTS ${from_path})
            file(GLOB_RECURSE override_files RELATIVE "${from_path}" "${from_path}/${file_pattern}")
            if (etIsAbsolute)
                get_filename_component(to_path "${externalTrunk}" ABSOLUTE)
            else ()
                get_filename_component(to_path "${externalTrunk}/../${patchBranch}" ABSOLUTE)
            endif ()
            foreach (file_rel_path IN LISTS override_files)

                # Skip this file if it is a check file
                get_filename_component(extn "${file_rel_path}" LAST_EXT)
                if ("${extn}" STREQUAL ".check")
                    # We obviously won't patch this ?? ...
                    continue()
                endif ()

                if (etIsAbsolute)
                    get_filename_component(true_file_rel_path "${file_rel_path}" NAME)
                else ()
                    set(true_file_rel_path "${file_rel_path}")
                endif ()
                message(CHECK_START "${BOLD}Replacing${OFF} ${file_rel_path}")
                list(APPEND CMAKE_MESSAGE_INDENT "\t")

                set(override_file_path "${from_path}/${file_rel_path}")
                set(system_file_path "${to_path}/${true_file_rel_path}")

                message("destination file = ${override_file_path}")
                message("     source file = ${system_file_path}")

                set(errored OFF)
                unset(error_message)

                if (EXISTS "${system_file_path}")

                    # See if we are attempting to patch again.
                    # visited[Override_1,System_1,Override_2,System_2,...,Override_n,System_n]

                    list(FIND visited "${override_file_path}" patchIndex)
                    list(FIND visited "${system_file_path}" sourceIndex)

                    if (visited)
                        if (${patchIndex} GREATER_EQUAL 0)
                            math(EXPR six "${patchIndex} + 1")
                            list(GET visited ${six} destination)
                        endif ()

                        if (${sourceIndex} GREATER 0)
                            math(EXPR pix "${sourceIndex} - 1")
                            list(GET visited ${pix} source)
                        endif ()

                        if ("${source}" STREQUAL "${override_file_path}" AND "${destination}" STREQUAL "${system_file_path}")
                            set(error_message "Replaced in previous iteration of loop")
                        elseif ("${source}" STREQUAL "${override_file_path}" AND NOT "${destination}" STREQUAL "${system_file_path}")
                            set(errored ON)
                            set(error_message "source file has been used to replace ${destination}")
                        elseif (NOT "${source}" STREQUAL "${override_file_path}" AND "${destination}" STREQUAL "${system_file_path}")
                            set(errored ON)
                            set(error_message "destination has already been replaced by ${source}")
                        endif ()
                    endif ()

                    if (NOT error_message)

                        # save the details of this visit.

                        list(APPEND visited "${override_file_path}" "${system_file_path}")

                        # is there a check file?
                        set(check_file_path "${override_file_path}.check")
                        if (EXISTS "${check_file_path}")
                            file(READ "${check_file_path}" check_contents)
                            file(READ "${override_file_path}" override_contents)
                            file(READ "${system_file_path}" source_contents)

                            # ensure they are the same
                            if (NOT "${check_contents}" STREQUAL "${source_contents}")

                                #  see if it has already been patched
                                if ("${source_contents}" STREQUAL "${override_contents}")
                                    set(error_message "Replacement has already been made.")
                                    set(errored OFF)
                                elseif (NOT "${check_contents}" STREQUAL "${source_contents}")
                                    set(error_message "Original destination file differs from expected. Replacement aborted.")
                                    set(errored ON)
                                endif ()
                            endif ()
                        endif ()
                    endif ()

                    if (NOT error_message)
                        file(COPY_FILE "${override_file_path}" "${system_file_path}")
                    endif ()

                else ()
                    set(errored ON)
                    set(error_message "destination file doesn't exist.")
                endif ()

                list(POP_BACK CMAKE_MESSAGE_INDENT)

                if (NOT error_message)
                    set(error_message "OK")
                endif ()

                if (errored)
                    message(CHECK_FAIL "${RED}[FAILED]${OFF} ${BOLD}${error_message}${OFF}")
                else ()
                    message(CHECK_PASS "${GREEN}${error_message}${OFF}")
                endif ()
            endforeach ()
        else ()
            message("${RED}[FAILED]${OFF} ${from_path} doesn't exist.")
            set(any_failed ON)
        endif ()

        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "${GREEN}OK.${OFF}")

    endforeach ()

    list(POP_BACK CMAKE_MESSAGE_INDENT)
    if (any_failed)
        message(CHECK_FAIL "${ORANGE}[FAILED] Some patches failed.${OFF}")
    else ()
        message(CHECK_PASS "${GREEN}OK.${OFF}")
    endif ()

endfunction()

function(inc var)
    set(_ ${${var}})
    math(EXPR _ "${_} + 1")
    set(${var} ${_} PARENT_SCOPE)
endfunction()
function(dec var)
    set(_ ${${var}})
    math(EXPR _ "${_} - 1")
    set(${var} ${_} PARENT_SCOPE)
endfunction()
