include_guard(GLOBAL)

set(_TOK_STAR "✸")   # [[STAR]]
set(_TOK_EMPTY_FIELD "⍰")   # [EMPTY_SENTINEL]]
set(_TOK_EMPTY_LIST "∅")   # No use currently
set(_TOK_LIST_SEP "␞")   # [[LIST_SEP]]
set(_TOK_NOUN_ROW "α")   # Replaces "ROW"    in WHERE
set(_TOK_NOUN_COLUMN "β")   # Replaces "COLUMN" in WHERE
set(_TOK_NOUN_ROWID "δ")   # Replaces "ROWID"  in WHERE
set(_TOK_NOUN_INDEX "ε")   # Replaces "INDEX"  in WHERE
set(_TOK_NOUN_NAME "θ")   # Replaces "NAME"   in WHERE
set(_TOK_NOUN_KEY "μ")   # Replaces "KEY"    in WHERE
set(_TOK_FS "␟")
set(_TOK_RS "␞")
set(_TOK_GS "␝")

set(_hs_sql_allowed_ops "=|!=|<=|>=|<|>|LIKE")

# --------------------------------------------------------------------------------------------------
# Data Hygiene & Encoding Logic
# --------------------------------------------------------------------------------------------------

# Encodes a single string field: replaces empty strings with a sentinel to avoid property deletion.
function(_hs_sql_field_to_storage inVal outVar)
    # msg(STATUS "DEBUG: _hs_sql_field_to_storage inVal='${inVal}' outVar='${outVar}'")

    if ("${${inVal}}" STREQUAL "")
        set(${outVar} "${_TOK_EMPTY_FIELD}" PARENT_SCOPE)
    else ()
        set(${outVar} "${${inVal}}" PARENT_SCOPE)
    endif ()
endfunction()

# Encodes a cmake list : replaces empty fields with a sentinel to avoid property deletion.
# Replaces an empty list with a unique sentinal (differentiate between "Never Set" and "Now Empty")
function(_hs_sql_fields_to_storage inList outVar)

    if (NOT inList)
        set(${outVar} ${_TOK_EMPTY_LIST} PARENT_SCOPE)
        return()
    endif ()

    _hs_sql_list_to_record(${inList} _0)

    # REGEX REPLACE <match-regex> <replace-expr> <out-var> <input> ...

    string(REGEX REPLACE "^;" "${_TOK_EMPTY_FIELD};" _1 "${${inList}}")
    string(REGEX REPLACE ";$" ";${_TOK_EMPTY_FIELD}" _2 "${_1}")
    string(REGEX REPLACE ";;" ";${_TOK_EMPTY_FIELD};" _3 "${_2}")
    string(REGEX REPLACE ";;" ";${_TOK_EMPTY_FIELD};" _4 "${_3}")

    set(${outVar} "${_4}" PARENT_SCOPE)
endfunction()

# Decodes a single string field: replaces the sentinel back with an actual empty string.
function(_hs_sql_field_to_user inVal outVar)
    set(_v "${${inVal}}")
    if (ARGC GREATER 2)
        set(_v "${ARGV}")
        list(REMOVE_AT _v -1)
    endif ()

    if ("${_v}" STREQUAL "${_TOK_EMPTY_FIELD}" OR NOT DEFINED _v OR "${_v}" STREQUAL "")
        set(${outVar} "" PARENT_SCOPE)
    else ()
        set(${outVar} "${_v}" PARENT_SCOPE)
    endif ()
endfunction()

# Decodes a string field: replaces the sentinel back with an actual empty string.
function(_hs_sql_fields_to_user inList outVar)

    if ("${${inList}}" STREQUAL ${_TOK_EMPTY_LIST})
        set(${outVar} "" PARENT_SCOPE)
        return()
    endif ()

    string(REGEX REPLACE ${_TOK_EMPTY_FIELD} "" _encoded "${inList}")
    set(${outVar} "${_encoded}" PARENT_SCOPE)

endfunction()

# Encodes a CMake list for storage: replaces list separators (;) with a safe alternative.
function(_hs_sql_list_to_record inList outVar)
    string(REPLACE ";" "${_TOK_LIST_SEP}" _encoded "${${inList}}")
    set(${outVar} "${_encoded}" PARENT_SCOPE)
endfunction()

# Decodes a record from storage back into a CMake list.
function(_hs_sql_record_to_list inRec outVar)
    string(REPLACE "${_TOK_LIST_SEP}" ";" _decoded "${${inRec}}")
    set(${outVar} "${_decoded}" PARENT_SCOPE)
endfunction()

# Internal Helper: Right-padded string
function(_hs_pad_string text width outVar)
    # msg(STATUS "DEBUG: _hs_pad_string text='${text}' width='${width}' outVar='${outVar}' ARGV='${ARGV}'")
    string(LENGTH "${text}" _len)
    set(_res "${text}")
    if (_len LESS width)
        math(EXPR _diff "${width} - ${_len}")
        foreach (_i RANGE 1 ${_diff})
            string(APPEND _res " ")
        endforeach ()
    elseif (_len GREATER width)
        # Truncation logic
        math(EXPR _cut "${width} - 3")
        if (_cut GREATER 0)
            string(SUBSTRING "${text}" 0 ${_cut} _sub)
            set(_res "${_sub}...")
        endif ()
    endif ()
    set(${outVar} "${_res}" PARENT_SCOPE)
endfunction()

# --------------------------------------------------------------------------------------------------
# Internal Infrastructure
# --------------------------------------------------------------------------------------------------
set_property(GLOBAL PROPERTY HS_NEXT_HNDL 1000)

function(_hs_sql_internal_insert hndl values)
    get_property(_encCols GLOBAL PROPERTY "${hndl}_COLUMNS")
    _hs_sql_record_to_list(_encCols _cols)
    get_property(_nextID GLOBAL PROPERTY "${hndl}_NEXT_ROWID")

    # If values is passed as a quoted list, it might be the first item in a larger list
    # but here we expect the list itself.
    _hs_sql_record_to_list(values _vList)
    #    set(_vList ${values})

    # msg(STATUS "DEBUG: _hs_sql_internal_insert hndl=${hndl} _vList='${_vList}'")
    set(_vIdx 0)
    list(LENGTH _vList _vLen)
    foreach (_c IN LISTS _cols)
        if (_vIdx LESS _vLen)
            list(GET _vList ${_vIdx} _curVal)
        else ()
            set(_curVal "")
        endif ()
        _hs_sql_field_to_storage(_curVal _v)
        # msg(STATUS "DEBUG: Setting PROPERTY ${hndl}_R${_nextID}_${_c} TO ${_v}")
        set_property(GLOBAL PROPERTY "${hndl}_R${_nextID}_${_c}" "${_v}")
        math(EXPR _vIdx "${_vIdx} + 1")
    endforeach ()

    set_property(GLOBAL APPEND PROPERTY "${hndl}_ROWIDS" "${_nextID}")
    get_property(_count GLOBAL PROPERTY "${hndl}_ROW_COUNT")
    math(EXPR _newCount "${_count} + 1")
    set_property(GLOBAL PROPERTY "${hndl}_ROW_COUNT" "${_newCount}" PARENT_SCOPE)
    set_property(GLOBAL PROPERTY "${hndl}_ROW_COUNT" "${_newCount}")
    math(EXPR _nextID "${_nextID} + 1")
    set_property(GLOBAL PROPERTY "${hndl}_NEXT_ROWID" "${_nextID}" PARENT_SCOPE)
    set_property(GLOBAL PROPERTY "${hndl}_NEXT_ROWID" "${_nextID}")
endfunction()

macro(_hs_sql_generate_handle outVarName)
    get_property(_next GLOBAL PROPERTY HS_NEXT_HNDL)
    set(_newHndl "HS_HNDL_${_next}")
    math(EXPR _next "${_next} + 1")
    set_property(GLOBAL PROPERTY HS_NEXT_HNDL ${_next})
    set(${outVarName} "${_newHndl}" PARENT_SCOPE)
    set(${outVarName} "${_newHndl}") # Also set in current scope for immediate use
    set(_resolvedHndl "${_newHndl}")
endmacro()

# ============================================================
# _sql_rejoin_args
# Rejoins CMake's tokenised ARGN into a normalised string,
# and swaps bare * for the sentinel token.
# Usage: _sql_rejoin_args(_out_var ${ARGN})
# ============================================================
function(_sql_rejoin_args out_var)
    if ("${ARGN}" STREQUAL "")
        set(_joined ${_TOK_EMPTY_LIST})
    else ()
        set(_args "${ARGN}")
        _hs_sql_fields_to_storage(_args _0)
        string(REGEX REPLACE "^;" "${_TOK_EMPTY_FIELD};" _1 "${_0}")
        string(REGEX REPLACE ";$" ";${_TOK_EMPTY_FIELD}" _2 "${_1}")
        string(REGEX REPLACE ";;" ";${_TOK_EMPTY_FIELD};" _3 "${_2}")

        string(JOIN " " _joined ${_3})
        string(REGEX REPLACE "[ \t\r\n]+" " " _joined "${_joined}")
        string(STRIP "${_joined}" _joined)
        # Swap bare * for sentinel
        string(REPLACE "*" "${_TOK_STAR}" _joined "${_joined}")
    endif ()
    set(${out_var} "${_joined}" PARENT_SCOPE)
endfunction()

# ============================================================
# _sql_peel_into
# Removes trailing  INTO <var>  from a string if present.
# out_str  : string with INTO clause removed (or unchanged)
# out_into : the var name, or "" if absent
# ============================================================
function(_sql_peel_into in_str out_str out_into)
    if (in_str MATCHES "^(.*) INTO ([^ ]+)$")
        string(STRIP "${CMAKE_MATCH_1}" _head)
        set(${out_str} "${_head}" PARENT_SCOPE)
        set(${out_into} "${CMAKE_MATCH_2}" PARENT_SCOPE)
    else ()
        set(${out_str} "${in_str}" PARENT_SCOPE)
        set(${out_into} "" PARENT_SCOPE)
    endif ()
endfunction()

# ============================================================
# _sql_peel_as
# Removes any <var>  from a string if present.
# out_str  : string with AS clause removed (or unchanged)
# out_into : the var name, or "" if absent
# ============================================================
#function(_sql_peel_as in_str out_str out_into)
#    if (in_str MATCHES "^(.*) AS ([^ ]+)(.*)$")
#        string(STRIP "${CMAKE_MATCH_1}" _head)
#        string(STRIP "${CMAKE_MATCH_3}" _tail)
#        set(${out_str} "${_head} ${_tail}" PARENT_SCOPE)
#        set(${out_into} "${CMAKE_MATCH_2}" PARENT_SCOPE)
#    else ()
#        set(${out_str} "${in_str}" PARENT_SCOPE)
#        set(${out_into} "" PARENT_SCOPE)
#    endif ()
#endfunction()
function(_sql_peel_as in_str out_str out_into out_fields)
    string(REGEX MATCHALL "[^ ]+" _tokens "${in_str}")
    list(LENGTH _tokens _len)
    math(EXPR _last "${_len} - 1")

    set(_aliases "")
    set(_fields "")
    set(_remaining "")
    set(_i 0)
    set(_hit_from FALSE)

    while (_i LESS_EQUAL _last)
        list(GET _tokens ${_i} _tok)

        if (_hit_from)
            list(APPEND _remaining "${_tok}")
            math(EXPR _i "${_i} + 1")
            continue()
        endif ()

        if (_tok STREQUAL "FROM")
            set(_hit_from TRUE)
            list(APPEND _remaining "FROM")
            math(EXPR _i "${_i} + 1")
            continue()
        endif ()

        # Peek ahead
        math(EXPR _next_i "${_i} + 1")
        if (_next_i LESS_EQUAL _last)
            list(GET _tokens ${_next_i} _next_tok)
        else ()
            set(_next_tok "")
        endif ()

        if (_next_tok STREQUAL "AS")
            # COLUMN AS ALIAS — consume 3 tokens
            math(EXPR _alias_i "${_i} + 2")
            if (_alias_i LESS_EQUAL _last)
                list(GET _tokens ${_alias_i} _alias)
                list(APPEND _aliases "${_alias}")
            else ()
                list(APPEND _aliases "${_tok}")
            endif ()
            list(APPEND _fields "${_tok}")
            math(EXPR _i "${_i} + 3")
        else ()
            # Bare column
            list(APPEND _aliases "${_tok}")
            list(APPEND _fields "${_tok}")
            math(EXPR _i "${_i} + 1")
        endif ()
    endwhile ()

    # Reconstruct the string for the next stage: raw fields + FROM tail
    list(JOIN _fields " " _fields_str)
    list(JOIN _remaining " " _tail_str)
    #    set(_reconstructed "${_fields_str} ${_tail_str}")
    set(_reconstructed "${_tail_str}")
    string(STRIP "${_reconstructed}" _reconstructed)

    list(JOIN _aliases ";" _alias_str)
    list(JOIN _fields ";" _fields_out)

    set(${out_str} "${_reconstructed}" PARENT_SCOPE)
    set(${out_into} "${_alias_str}" PARENT_SCOPE)
    set(${out_fields} "${_fields_out}" PARENT_SCOPE)
endfunction()

# ============================================================
# _sql_peel_where
# Removes trailing  WHERE <clause>  from a string if present.
# out_str   : string with WHERE clause removed (or unchanged)
# out_where : the where clause, or "" if absent
# ============================================================
function(_sql_peel_where in_str out_str out_where)
    if (in_str MATCHES "^(.*) WHERE (.+)$")
        string(STRIP "${CMAKE_MATCH_1}" _head)
        set(${out_str} "${_head}" PARENT_SCOPE)
        set(${out_where} "${CMAKE_MATCH_2}" PARENT_SCOPE)
    else ()
        set(${out_str} "${in_str}" PARENT_SCOPE)
        set(${out_where} "" PARENT_SCOPE)
    endif ()
endfunction()


# ============================================================
# _sql_peel_fields
# Removes field names and ensures
#   (A) the fields exist, and
#   (B) the fields are single quoted if they are reserved words
#
# field_list    : CMake list of field names
# where_list    : CMake list if WHERE column names
# in_handle     : resolved handle needed to construct GLOBAL
#               : variable names
# in_keywords   : keyword list, ";" or "|" separated
# out_list      : list of parsed and stripped valid fields, or
#               : error message(s) if failed. Error message
#               : can be identified by the list being >=2 items
#               : long, with element 0 being the single character
#               : "!" and subsequent element(s) being the error(s)
# ============================================================
function(_sql_peel_fields in_handle field_list where_list in_keywords out_list)

    string(REPLACE ";" "|" _regex_keywords "${in_keywords}")
    get_property(_allCols GLOBAL PROPERTY "${in_handle}_COLUMNS")
    _hs_sql_record_to_list(_allCols _allCols)
    string(REPLACE ";" "|" _regex_fields "${_allCols}")

    set(_error "!")

    string(REPLACE " " ";" _field_list "${field_list}")
    list(LENGTH field_list _sizeof)

    if (_sizeof EQUAL 1)
        if (_field_list MATCHES "^(${_regex_keywords})$")
            list(APPEND _good_tokens "${_field_list}")
        else ()
            list(APPEND _resolved_fields ${_field_list})
        endif ()
    endif ()

    set(_ix 0)
    foreach(pass RANGE 1 2)
        if(pass EQUAL 1)
            if (NOT field_list)
                continue()
            endif ()
            set(_list "${field_list}")
        else ()
            if (NOT where_list)
                continue()
            endif ()
            set(_list "${where_list}")
        endif ()

        foreach (_token IN LISTS _list)
            if (_token MATCHES "^(${_regex_keywords})$")
                if(pass EQUAL 1)
                    if (_ix GREATER 0)
                        list(APPEND _bad_select_tokens ${_token})
                    else ()
                        list(APPEND _good_tokens)
                    endif ()
                else ()
                    list(APPEND _bad_where_tokens ${_token})
                endif ()
            else ()
                string(REPLACE "'" "" _token ${_token})
                if (NOT _token MATCHES "^(${_regex_fields})$")
                    if(pass EQUAL 1)
                        list(APPEND _bad_select_fields ${_token})
                    else ()
                        list(APPEND _bad_where_fields ${_token})
                    endif ()
                else ()
                    list(APPEND _resolved_fields ${_token})
                endif ()
            endif ()
            inc(_ix)
        endforeach ()
    endforeach ()

    #    list(LENGTH field_list _sizeof)
    #    foreach (_broken IN LISTS _field_list)
    #        if (_broken MATCHES "^(${_regex_keywords})$")
    #            if (_sizeof GREATER 1)
    #                list(APPEND _bad_tokens ${_broken})
    #            endif ()
    #        else ()
    #            string(REPLACE "'" "" _token ${_broken})
    #            if (NOT _token MATCHES "^(${_regex_fields})$")
    #                list(APPEND _bad_fields ${_token})
    #            else ()
    #                list(APPEND _resolved_fields ${_token})
    #            endif ()
    #        endif ()
    #    endforeach ()

    foreach (WHAT IN ITEMS SELECT WHERE)
        string(TOLOWER "${WHAT}" what)
        if (DEFINED _bad_${what}_tokens AND NOT _bad_${what}_tokens STREQUAL "")
            foreach (bad IN LISTS _bad_${what}_tokens)
                list(APPEND _fixed "'${bad}'")
            endforeach ()
            string(REPLACE ";" " " _bad_examples "${_bad_${what}_tokens}")
            string(REPLACE ";" " " _good_examples "${_fixed}")
            list(LENGTH _bad_examples flen)
            if(flen EQUAL 1)
                set(s        s)
                set(was_were was)
                set(it_them  it)
            else ()
                set(s        )
                set(was_were were)
                set(it_them  them)
            endif ()
            list(APPEND _error "keyword${s} (${_bad_examples}) ${was_were} found in your ${WHAT} field list. Replace ${it_them} with (${_good_examples})")
        endif ()

        if (DEFINED _bad_${what}_fields AND NOT _bad_${what}_fields STREQUAL "")
            string(REPLACE ";" " " _fields "${_bad_${what}_fields}")
            string(REPLACE "|" " " _columns "${_regex_fields}")

            list(LENGTH _fields flen)
            if(flen EQUAL 1)
                set(s        s)
                set(was_were was)
                set(it_them  it)
            else ()
                set(s        )
                set(was_were were)
                set(it_them  them)
            endif ()
            list(APPEND _error "${WHAT} field${s} (${_fields}) ${was_were} not found in (${_columns})")
        endif ()
    endforeach ()

    list(REMOVE_DUPLICATES _resolved_fields)

    if (_error STREQUAL "!")
        set("${out_list}" "${_resolved_fields}" PARENT_SCOPE)
    else ()
        set("${out_list}" "${_error}" PARENT_SCOPE)
    endif ()

endfunction()

# ============================================================
# _sql_extract_nouns
# Walks the WHERE lists and promotes recognised noun tokens
# (ROWID, INDEX, ROW, COLUMN, NAME, KEY) to named variables
# in the caller's scope:  _where_<NOUN>  e.g. _where_ROWID
#
# Modifies _whereCols, _whereOps, _whereVals in place —
# noun entries are removed, leaving only plain filter conditions.
#
# Usage:
#   _sql_extract_nouns(_whereCols _whereOps _whereVals)
#   # then use ${_where_ROWID}, ${_where_ROW}, ${_where_COLUMN} etc.
# ============================================================
function(_sql_extract_nouns cols_var ops_var vals_var)
    set(_nouns "ROWID;INDEX;ROW;COLUMN;NAME;KEY")

    set(_cols "${${cols_var}}")
    set(_ops "${${ops_var}}")
    set(_vals "${${vals_var}}")

    set(_ix 0)
    list(LENGTH _cols _len)

    while (_ix LESS _len)
        list(GET _cols ${_ix} _noun_candidate)

        list(FIND _nouns "${_noun_candidate}" _found)
        if (NOT _found EQUAL -1)
            list(GET _vals ${_ix} _noun_val)
            # Promote to named variable in caller's scope
            set(_where_${_noun_candidate} "${_noun_val}" PARENT_SCOPE)

            list(REMOVE_AT _cols ${_ix})
            list(REMOVE_AT _ops ${_ix})
            list(REMOVE_AT _vals ${_ix})

            list(LENGTH _cols _len)
            # Don't increment — recheck same index after removal
        else ()
            math(EXPR _ix "${_ix} + 1")
        endif ()
    endwhile ()

    # Write modified lists back to caller
    set(${cols_var} "${_cols}" PARENT_SCOPE)
    set(${ops_var} "${_ops}" PARENT_SCOPE)
    set(${vals_var} "${_vals}" PARENT_SCOPE)
endfunction()

macro(_hs_sql_resolve_handle varName outHndl)
    if (NOT "${varName}" STREQUAL "")
        # Check if the variable exists and contains a handle
        if (DEFINED "${varName}")
            set(_input "${${varName}}")
        else ()
            # If the variable is not defined, treat the string as a literal handle or label
            set(_input "${varName}")
        endif ()

        # 1. Check if _input is already a handle
        get_property(_exists GLOBAL PROPERTY "${_input}_TYPE" SET)
        if (_exists)
            set(${outHndl} "${_input}")
        else ()
            # 2. Check if _input is a label
            get_property(_hndl GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_input}")
            if (_hndl)
                set(${outHndl} "${_hndl}")
            else ()
                set(${outHndl} "")
            endif ()
        endif ()
    else ()
        set(${outHndl} "")
    endif ()
endmacro()

macro(_hs_sql_check_readonly hndl)
    get_property(_t GLOBAL PROPERTY "${hndl}_TYPE")
    if (_t MATCHES "VIEW$")
        msg(ALWAYS FATAL_ERROR "SQL Error: Cannot mutate VIEW '${hndl}'. Views are read-only.")
    endif ()
endmacro()

function(_parse_expression expr output)

    if (NOT expr)
        return()
    endif ()

    # Track whether THIS call is the top-level entry point
    if (ARGC GREATER_EQUAL 3)
        set(_depth ${ARGV2})
        set(_top_level OFF)
    else ()
        set(_depth 0)
        set(_top_level ON)
        # Initialize the cache accumulator fresh
        set(_PARSE_PAREN_ACCUMULATOR "" CACHE INTERNAL "")
    endif ()

    set(_subexpr_marker "[[SUBEXPR_${_depth}]]")
    set(_balance 0)
    unset(_expr)
    unset(_subexpr)

    separate_arguments(_fixed NATIVE_COMMAND "${expr}")

    unset(_z)
    foreach (_x IN LISTS _fixed)
        foreach (_y IN LISTS _x)
            list(APPEND _z ${_y})
        endforeach ()
    endforeach ()
    set(expr ${_z})

    set(_writing_into_subexpr)
    foreach (_token IN LISTS expr)
        if (_token STREQUAL "(")
            if (_balance EQUAL 0)
                list(APPEND _expr "${_subexpr_marker}")
                set(_writing_into_subexpr ON)
                math(EXPR _balance "${_balance} + 1")
                continue()
            endif ()
            math(EXPR _balance "${_balance} + 1")
        elseif (_token STREQUAL ")")
            math(EXPR _balance "${_balance} - 1")
            if (_balance EQUAL 0)
                set(_writing_into_subexpr OFF)
                continue()
            endif ()
        endif ()
        if (_writing_into_subexpr)
            list(APPEND _subexpr ${_token})
        else ()
            list(APPEND _expr ${_token})
        endif ()
    endforeach ()

    if (_balance)
        msg(ALWAYS FATAL_ERROR "Unbalanced parenthesis in statement \"${expr}\"")
    endif ()

    if (NOT _expr OR _expr STREQUAL "${_subexpr_marker}")     # Just a list or a bracketed list. Return the list
        set(_expr "${_subexpr}")
        set(_subexpr)
    endif ()

    # Serialize outer expression and append to accumulator
    _hs_sql_list_to_record(_expr _Xexpr)

    # Read fresh from cache, never from local scope
    set(_current "$CACHE{_PARSE_PAREN_ACCUMULATOR}")
    list(APPEND _current "${_Xexpr}")
    set(_PARSE_PAREN_ACCUMULATOR "${_current}" CACHE INTERNAL "")

    # Recurse into subexpression
    if (_subexpr)
        math(EXPR _depth "${_depth} + 1")
        _parse_expression("${_subexpr}" ${output} ${_depth})
    endif ()

    # Only the original top-level call writes result back to caller
    if (_top_level)
        set("${output}" "$CACHE{_PARSE_PAREN_ACCUMULATOR}" PARENT_SCOPE)
        unset(_PARSE_PAREN_ACCUMULATOR CACHE)
    endif ()

endfunction()

macro(_fix_ooo)
    foreach (_singleton IN LISTS ooo)
        if (DEFINED ${CMAKE_CURRENT_FUNCTION}_${singleton})
            set(${CMAKE_CURRENT_FUNCTION}_HANDLE ${${CMAKE_CURRENT_FUNCTION}_${singleton}})
            break()
        endif ()
    endforeach ()
    unset(_singleton)
endmacro()


# --------------------------------------------------------------------------------------------------
# DDL: CREATE
# --------------------------------------------------------------------------------------------------

function(CREATE)

    set(_args "${ARGN}")
    _hs_sql_fields_to_storage(_args _argn)

    set(options TABLE VIEW MATERIALIZED_VIEW MAP SHEET)
    set(args INTO)
    set(lists COLUMNS ROWS)
    cmake_parse_arguments(CREATE "${options}" "${args}" "${lists}" ${_argn})

    foreach (_singleton IN LISTS options)
        if (CREATE_${_singleton})
            set(CREATE_TYPE ${_singleton})
            break()
        endif ()
    endforeach ()

    if (NOT CREATE_TYPE)
        msg(ALWAYS FATAL_ERROR "CREATE: No type (TABLE, SHEET, MAP, etc.) specified. ARGN: ${ARGN}")
    endif ()

    # The new syntax: CREATE(TABLE name ...)
    # name should be in CREATE_UNPARSED_ARGUMENTS[0]
    list(GET CREATE_UNPARSED_ARGUMENTS 0 _label)

    if (NOT _label)
        msg(ALWAYS FATAL_ERROR "CREATE: No table name specified. ARGN: ${ARGN}")
    endif ()

    set(outHandleVarName ${CREATE_INTO})
    if (outHandleVarName)
        _hs_sql_generate_handle("${outHandleVarName}")
    else ()
        # Generate internal handle but don't pass back to user
        _hs_sql_generate_handle(_internalHndl)
        set(_resolvedHndl ${_internalHndl})
    endif ()

    if (NOT _label STREQUAL "<unnamed>")
        get_property(_prev GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_label}")
        if (_prev)
            msg(AUTHOR_WARNING "SQL Warning: Label '${_label}' is already in use by handle '${_prev}'. Overwriting with '${_resolvedHndl}'.")
        endif ()
        set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_label}" "${_resolvedHndl}")
    endif ()

    set(_cols "${CREATE_COLUMNS}")
    set(_rows "${CREATE_ROWS}")
    set(_members "${CREATE_FROM}")

    if (CREATE_TABLE OR CREATE_SHEET)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "TABLE")
        _hs_sql_fields_to_storage(_label _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")

        _parse_expression("${CREATE_COLUMNS}" result)
        list(POP_BACK result _1)
        #        separate_arguments(_2 NATIVE_COMMAND "${_1}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_1}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_NAMES" "")

        if (CREATE_ROWS)
            foreach (_rname IN LISTS CREATE_ROWS)
                get_property(_nextID GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID")
                # Initialize empty row
                set(_rowVals "")
                foreach (_c IN LISTS CREATE_COLUMNS)
                    list(APPEND _rowVals "")
                endforeach ()
                _hs_sql_internal_insert("${_resolvedHndl}" "${_rowVals}")

                # Map name to ID
                set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWNAME_TO_ID_${_rname}" "${_nextID}")
                set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWID_TO_NAME_${_nextID}" "${_rname}")
                set_property(GLOBAL APPEND PROPERTY "${_resolvedHndl}_ROW_NAMES" "${_rname}")
            endforeach ()
        endif ()

    elseif (CREATE_VIEW)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "VIEW")
        _hs_sql_field_to_storage(_label _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")
        _hs_sql_list_to_record(_members _encMems)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_MEMBERS" "${_encMems}")

    elseif (CREATE_MATERIALIZED_VIEW)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "MATERIALIZED_VIEW")
        _hs_sql_field_to_storage(_label _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")

        # 1. Schema Merging: Combine columns from all sources
        set(_allCols "")
        foreach (_m IN LISTS _members)
            get_property(_mc GLOBAL PROPERTY "${_m}_COLUMNS")
            list(APPEND _allCols ${_mc})
        endforeach ()
        list(REMOVE_DUPLICATES _allCols)
        _hs_sql_list_to_record(_allCols _encCols)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_encCols}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)

        # 2. Snapshot: Physically copy data
        foreach (_m IN LISTS _members)
            get_property(_mEncIDs GLOBAL PROPERTY "${_m}_ROWIDS")
            _hs_sql_record_to_list(_mEncIDs _mIDs)
            get_property(_mEncCols GLOBAL PROPERTY "${_m}_COLUMNS")
            _hs_sql_record_to_list(_mEncCols _mCols)

            foreach (_rid IN LISTS _mIDs)
                set(_rowVals "")
                foreach (_c IN LISTS _allCols)
                    if (_c IN_LIST _mCols)
                        get_property(_vEnc GLOBAL PROPERTY "${_m}_R${_rid}_${_c}")
                        _hs_sql_field_to_user(_vEnc _v)
                        list(APPEND _rowVals "${_v}")
                    else ()
                        _hs_sql_field_to_user("" _v)
                        list(APPEND _rowVals "${_v}")
                    endif ()
                endforeach ()
                # Use internal insert to bypass read-only check
                _hs_sql_internal_insert("${_resolvedHndl}" "${_rowVals}")
            endforeach ()
        endforeach ()

    elseif (CREATE_MAP)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "MAP")
        _hs_sql_field_to_storage(_label _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_KEYS" "")
    else ()
        msg(ALWAYS FATAL_ERROR "CREATE :- Don't know how to create object, use TABLE, VIEW, MATERIALIZED_VIEW or MAP options")
    endif ()
endfunction()

# ============================================================
# UPDATE <table> SET <col1> = <val1> <col2> = <val2> ... [WHERE ...]
# UPDATE <table> ROWNAMES <name1> <name2> ...
# UPDATE <table> LABEL <new_name>
# ============================================================
function(UPDATE)
    set(_keywords "COUNT|HANDLE|ROW|ROWID|COLUMN|NAME|KEY|${_TOK_STAR}")

    # ── Normalise args ───────────────────────────────────────────────────
    _sql_rejoin_args(_upd_args ${ARGN})

    # ── Check for LABEL renaming ─────────────────────────────────────────
    if (_upd_args MATCHES "^([^ ]+) LABEL (.+)$")
        set(_target "${CMAKE_MATCH_1}")
        set(_new_label "${CMAKE_MATCH_2}")

        _hs_sql_resolve_handle("${_target}" _h)
        if (NOT _h)
            msg(ALWAYS FATAL_ERROR "UPDATE: Could not resolve handle for '${_target}'")
        endif ()
        _hs_sql_check_readonly(${_h})

        # Get old label
        get_property(_oldEncLabel GLOBAL PROPERTY "${_h}_LABEL")
        _hs_sql_field_to_user(_oldEncLabel _oldLabel)

        # Remove old mapping if it points to this handle
        get_property(_oldHndl GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_oldLabel}")
        if ("${_oldHndl}" STREQUAL "${_h}")
            set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_oldLabel}" "")
        endif ()

        # Add new mapping
        _hs_sql_field_to_storage(_new_label _newEncLabel)
        set_property(GLOBAL PROPERTY "${_h}_LABEL" "${_newEncLabel}")

        get_property(_prev GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_new_label}")
        if (_prev AND NOT "${_prev}" STREQUAL "${_h}")
            msg(AUTHOR_WARNING "UPDATE: Label '${_new_label}' is already in use by handle '${_prev}'. Overwriting with '${_h}'.")
        endif ()

        set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_new_label}" "${_h}")
        return()
    endif ()

    # ── Check for ROWNAMES ───────────────────────────────────────────────
    if (_upd_args MATCHES "^([^ ]+) ROWNAMES (.+)$")
        set(_target "${CMAKE_MATCH_1}")
        string(STRIP "${CMAKE_MATCH_2}" _names_str)

        _hs_sql_resolve_handle("${_target}" _h)
        if (NOT _h)
            msg(ALWAYS FATAL_ERROR "UPDATE: Could not resolve handle for '${_target}'")
        endif ()
        _hs_sql_check_readonly(${_h})

        get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
        if (NOT _type STREQUAL "TABLE")
            msg(ALWAYS FATAL_ERROR "UPDATE: ROWNAMES only works on tables, not ${_type}")
        endif ()

        string(REPLACE " " ";" _names "${_names_str}")
        get_property(_rowids GLOBAL PROPERTY "${_h}_ROWIDS")
        set(_idx 0)
        list(LENGTH _rowids _len)

        foreach (_rname IN LISTS _names)
            if (_idx LESS _len)
                list(GET _rowids ${_idx} _rid)
                set_property(GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${_rname}" "${_rid}")
                set_property(GLOBAL PROPERTY "${_h}_ROWID_TO_NAME_${_rid}" "${_rname}")
                set_property(GLOBAL APPEND PROPERTY "${_h}_ROW_NAMES" "${_rname}")
            endif ()
            math(EXPR _idx "${_idx} + 1")
        endforeach ()
        return()
    endif ()

    # ── Parse SET clause ─────────────────────────────────────────────────
    # UPDATE <table> SET <col> = <val> ... [WHERE ...]
    if (NOT _upd_args MATCHES "^([^ ]+) SET (.+)$")
        msg(ALWAYS FATAL_ERROR "UPDATE: Expected 'UPDATE <table> SET <assignments> [WHERE ...]' but got '${_upd_args}'")
    endif ()

    set(_target "${CMAKE_MATCH_1}")
    string(STRIP "${CMAKE_MATCH_2}" _set_and_where)

    _hs_sql_resolve_handle("${_target}" _h)
    if (NOT _h)
        msg(ALWAYS FATAL_ERROR "UPDATE: Could not resolve handle for '${_target}'")
    endif ()
    _hs_sql_check_readonly(${_h})

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # ── Peel WHERE ───────────────────────────────────────────────────────
    _sql_peel_where("${_set_and_where}" _set_clause _upd_where)

    # ── Parse WHERE and extract nouns ────────────────────────────────────
    set(_whereCols "")
    set(_whereOps "")
    set(_whereVals "")
    if (NOT "${_upd_where}" STREQUAL "")
        parse_where("${_upd_where}")
    endif ()
    _sql_extract_nouns(_whereCols _whereOps _whereVals)

    # ── Handle MAP type ──────────────────────────────────────────────────
    if (_type STREQUAL "MAP")
        # Parse SET as key = value pairs
        string(REPLACE " " ";" _set_tokens "${_set_clause}")

        set(_expect_key TRUE)
        set(_current_key "")
        foreach (_tok IN LISTS _set_tokens)
            if (_expect_key)
                set(_current_key "${_tok}")
                set(_expect_key FALSE)
            elseif (_tok STREQUAL "=")
                # Skip equals sign
                continue()
            else ()
                # This is the value
                _hs_sql_field_to_storage(_tok _encVal)
                set_property(GLOBAL PROPERTY "${_h}_K_${_current_key}" "${_encVal}")
                set_property(GLOBAL PROPERTY "${_h}_K_${_current_key}_ISHANDLE" FALSE)
                set(_expect_key TRUE)
            endif ()
        endforeach ()
        return()
    endif ()

    # ── Handle TABLE type ────────────────────────────────────────────────
    # Parse SET clause into col/val pairs
    string(REPLACE " " ";" _set_tokens "${_set_clause}")

    set(_cols_to_update "")
    set(_vals_to_update "")
    set(_expect_col TRUE)
    set(_current_col "")

    foreach (_tok IN LISTS _set_tokens)
        if (_expect_col)
            set(_current_col "${_tok}")
            set(_expect_col FALSE)
        elseif (_tok STREQUAL "=")
            continue()
        else ()
            list(APPEND _cols_to_update "${_current_col}")
            list(APPEND _vals_to_update "${_tok}")
            set(_expect_col TRUE)
        endif ()
    endforeach ()

    # Validate columns
    _sql_peel_fields(${_h} "${_cols_to_update}" "${_whereCols}" "${_keywords}" _validated_cols)
    list(GET _validated_cols 0 _first)
    if (_first STREQUAL "!")
        list(REMOVE_AT _validated_cols 0)
        string(JOIN "\n" _errs ${_validated_cols})
        msg(ALWAYS FATAL_ERROR "UPDATE: ${_errs}")
    endif ()

    # Determine target row(s)
    set(_target_rows "")

    if (DEFINED _where_ROWID)
        list(APPEND _target_rows "${_where_ROWID}")
    elseif (DEFINED _where_INDEX)
        list(APPEND _target_rows "${_where_INDEX}")
    elseif (DEFINED _where_ROW)
        get_property(_rid GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${_where_ROW}")
        if (_rid)
            list(APPEND _target_rows "${_rid}")
        endif ()
    else ()
        # No specific row — need to filter all rows
        get_property(_encIDs GLOBAL PROPERTY "${_h}_ROWIDS")
        _hs_sql_record_to_list(_encIDs _all_ids)

        foreach (_rid IN LISTS _all_ids)
            set(_rowPass TRUE)
            list(LENGTH _whereCols _filterCount)
            if (_filterCount GREATER 0)
                math(EXPR _maxF "${_filterCount} - 1")
                foreach (_fIdx RANGE ${_maxF})
                    list(GET _whereCols ${_fIdx} _fCol)
                    list(GET _whereOps ${_fIdx} _fOp)
                    list(GET _whereVals ${_fIdx} _fVal)
                    get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_fCol}")
                    _hs_sql_field_to_user(_val _actualVal)

                    if (_fOp STREQUAL "=")
                        if (NOT "${_actualVal}" STREQUAL "${_fVal}")
                            set(_rowPass FALSE)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "LIKE")
                        string(REPLACE "*" ".*" _regex "${_fVal}")
                        if (NOT "${_actualVal}" MATCHES "^${_regex}$")
                            set(_rowPass FALSE)
                            break()
                        endif ()
                    endif ()
                endforeach ()
            endif ()

            if (_rowPass)
                list(APPEND _target_rows "${_rid}")
            endif ()
        endforeach ()
    endif ()

    # Apply updates
    list(LENGTH _validated_cols _num_updates)
    math(EXPR _max_idx "${_num_updates} - 1")

    foreach (_rid IN LISTS _target_rows)
        foreach (_idx RANGE ${_max_idx})
            list(GET _validated_cols ${_idx} _col)
            list(GET _vals_to_update ${_idx} _val)
            _hs_sql_field_to_storage(_val _enc)
            set_property(GLOBAL PROPERTY "${_h}_R${_rid}_${_col}" "${_enc}")
        endforeach ()
    endforeach ()

endfunction()


# ============================================================
# INSERT INTO <table> VALUES (val1 val2 ...)
# INSERT INTO <table> (col1 col2 ...) VALUES (val1 val2 ...)
# ============================================================
function(INSERT)
    set(_keywords "COUNT|HANDLE|ROW|ROWID|COLUMN|NAME|KEY|${_TOK_STAR}")

    if ("${ARGN}" STREQUAL "")
        set(_argn ${_TOK_EMPTY_LIST})
    else ()

        string(REGEX REPLACE "^;" "${_TOK_EMPTY_FIELD};" _1 "${ARGN}")
        string(REGEX REPLACE ";$" ";${_TOK_EMPTY_FIELD}" _2 "${_1}")
        string(REGEX REPLACE ";;" ";${_TOK_EMPTY_FIELD};" _3 "${_2}")
        string(REGEX REPLACE ";;" ";${_TOK_EMPTY_FIELD};" _4 "${_3}")

    endif ()


    #    set(_args ${ARGV})
    #    _hs_sql_fields_to_storage(_0 _1)
    # ── Normalise args ───────────────────────────────────────────────────
    _sql_rejoin_args(_ins_args ${_4})

    # ── Parse INTO <table> ... ───────────────────────────────────────────
    if (NOT _ins_args MATCHES "^INTO ([^ ]+) (.+)$")
        msg(ALWAYS FATAL_ERROR "INSERT: Expected 'INSERT INTO <table> ...' but got '${_ins_args}'")
    endif ()

    set(_target "${CMAKE_MATCH_1}")
    string(STRIP "${CMAKE_MATCH_2}" _rest)

    _hs_sql_resolve_handle("${_target}" _h)
    if (NOT _h)
        msg(ALWAYS FATAL_ERROR "INSERT: Could not resolve handle for '${_target}'")
    endif ()
    _hs_sql_check_readonly(${_h})

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # ── Check for explicit column list: (col1 col2) VALUES (...) ────────
    set(_explicit_cols "")
    if (_rest MATCHES "^\\(([^)]+)\\) VALUES \\((.+)\\)$")
        # Mode B: explicit columns
        string(STRIP "${CMAKE_MATCH_1}" _cols_str)
        string(STRIP "${CMAKE_MATCH_2}" _vals_str)

        # Parse column list
        string(REPLACE " " ";" _explicit_cols "${_cols_str}")
        # Strip quotes from column names
        string(REPLACE "\"" "" _explicit_cols "${_explicit_cols}")

    elseif (_rest MATCHES "^VALUES \\((.+)\\)$")
        # Mode A: positional
        string(STRIP "${CMAKE_MATCH_1}" _vals_str)

    else ()
        msg(ALWAYS FATAL_ERROR "INSERT: Expected 'VALUES (...)' or '(cols...) VALUES (...)' but got '${_rest}'")
    endif ()

    # Parse values
    string(REPLACE " " ";" _vals "${_vals_str}")
    # Strip quotes from values
    string(REPLACE "\"" "" _vals "${_vals}")

    # ── Handle MAP type ──────────────────────────────────────────────────
    if (_type STREQUAL "MAP")
        if (NOT _explicit_cols)
            msg(ALWAYS FATAL_ERROR "INSERT: MAP type requires explicit column names: INSERT INTO ${_target} (key1 key2) VALUES (val1 val2)")
        endif ()

        list(LENGTH _explicit_cols _num_cols)
        list(LENGTH _vals _num_vals)
        if (NOT _num_cols EQUAL _num_vals)
            msg(ALWAYS FATAL_ERROR "INSERT: Column count (${_num_cols}) doesn't match value count (${_num_vals})")
        endif ()

        math(EXPR _max_idx "${_num_cols} - 1")
        foreach (_idx RANGE ${_max_idx})
            list(GET _explicit_cols ${_idx} _key)
            list(GET _vals ${_idx} _val)
            _hs_sql_field_to_storage(_val _encVal)
            set_property(GLOBAL PROPERTY "${_h}_K_${_key}" "${_encVal}")
            set_property(GLOBAL PROPERTY "${_h}_K_${_key}_ISHANDLE" FALSE)
            set_property(GLOBAL APPEND PROPERTY "${_h}_KEYS" "${_key}")
        endforeach ()
        return()
    endif ()

    # ── Handle TABLE type ────────────────────────────────────────────────
    # Get table columns
    get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
    _hs_sql_record_to_list(_encCols _table_cols)

    # Determine column order
    if (_explicit_cols)
        # Validate explicit columns
        _sql_peel_fields(${_h} "${_explicit_cols}" "" "${_keywords}" _validated_cols)
        list(GET _validated_cols 0 _first)
        if (_first STREQUAL "!")
            list(REMOVE_AT _validated_cols 0)
            string(JOIN "\n" _errs ${_validated_cols})
            msg(ALWAYS FATAL_ERROR "INSERT: ${_errs}")
        endif ()
        set(_insert_cols "${_validated_cols}")
    else ()
        # Use table column order
        set(_insert_cols "${_table_cols}")
    endif ()

    # Check value count matches column count
    list(LENGTH _insert_cols _num_cols)
    list(LENGTH _vals _num_vals)
    if (NOT _num_cols EQUAL _num_vals)
        msg(ALWAYS FATAL_ERROR "INSERT: Column count (${_num_cols}) doesn't match value count (${_num_vals})")
    endif ()

    # Generate new row ID
    get_property(_rowids GLOBAL PROPERTY "${_h}_ROWIDS")
    if (_rowids)
        list(LENGTH _rowids _count)
    else ()
        set(_count 0)
    endif ()
    math(EXPR _new_id "${_count} + 1")

    # Add row ID to list
    set_property(GLOBAL APPEND PROPERTY "${_h}_ROWIDS" "${_new_id}")

    # Set values for specified columns
    math(EXPR _max_idx "${_num_cols} - 1")
    foreach (_idx RANGE ${_max_idx})
        list(GET _insert_cols ${_idx} _col)
        list(GET _vals ${_idx} _val)
        _hs_sql_field_to_storage(_val _enc)
        set(_var_name "${_h}_R${_new_id}_${_col}")
        set_property(GLOBAL PROPERTY "${_var_name}" "${_enc}")
    endforeach ()

    # If using explicit columns, initialize remaining columns to empty
    if (_explicit_cols)
        foreach (_col IN LISTS _table_cols)
            list(FIND _insert_cols "${_col}" _found)
            if (_found EQUAL -1)
                set_property(GLOBAL PROPERTY "${_h}_R${_new_id}_${_col}" "${_TOK_EMPTY_FIELD}")
            endif ()
        endforeach ()
    endif ()

endfunction()

# ============================================================
# Translate sentinel back to * for error messages
# ============================================================
function(rw_display token out_var)
    if ("${token}" STREQUAL "${_TOK_STAR}")
        set(${out_var} "*" PARENT_SCOPE)
    else ()
        set(${out_var} "${token}" PARENT_SCOPE)
    endif ()
endfunction()


# ============================================================
# parse_where
# Input : where_str  — everything after WHERE (before INTO/end)
# Output: WHERE_LHS, WHERE_OP, WHERE_RHS  (lists, same length)
# ============================================================
function(parse_where where_str)

    set(lhs_list "")
    set(op_list "")
    set(rhs_list "")
    string(REGEX REPLACE "[ \t\r\n]+" " " tail "${where_str}")
    string(STRIP "${tail}" tail)

    # Split on AND into individual condition strings
    string(REPLACE " AND " ";" conditions "${tail}")

    foreach (condition IN LISTS conditions)
        string(STRIP "${condition}" condition)

        if (condition MATCHES "^([^ ]+) (${_hs_sql_allowed_ops}) ([^ ]+)$")
            list(APPEND lhs_list "${CMAKE_MATCH_1}")
            list(APPEND op_list "${CMAKE_MATCH_2}")
            list(APPEND rhs_list "${CMAKE_MATCH_3}")
        else ()
            msg(WARNING "parse_where: unrecognised condition: '${condition}'")
        endif ()
    endforeach ()

    set(_whereCols "${lhs_list}" PARENT_SCOPE)
    set(_whereOps "${op_list}" PARENT_SCOPE)
    set(_whereVals "${rhs_list}" PARENT_SCOPE)

endfunction()


# ======================================================================================================================
# SELECT(<mode> [AS <var>] FROM <name_or_handle> [WHERE <filters>])
# SELECT(<mode> FROM <name_or_handle> [WHERE <filters>] [INTO <var>]) ** DEPRECATED **
# ======================================================================================================================
# Modes:
#
# Tokens before     Mode    Description
# the "FROM" kw     Name
# ----------------  ------  --------------------------------------------------------------------------------------------
# <col> [...]       VALUE   Returns value/values from a specific row
# ROW               ROW     Returns the entire row as a CMake list.
# COLUMN            COLUMN  Returns the entire column as a CMake list.
# ROWID             ROWID   Returns the ROWID attribute
# *                 STAR    If a specific row is targeted: Returns the row as a MAP handle.
#                           If no specific row: Returns a new TABLE handle containing the Result Set {RS}.
# COUNT             COUNT   Returns the number of matching rows.
# HANDLE            HANDLE  Returns the internal handle of the object.
#
# ======================================================================================================================
# Result Set (RS)   The result will be returned to the caller as follows
#
#                   If no AS variable supplied:
#
#                       the result will be placed into a variable named SELECT_RESULT_{col} if mode is VALUE, otherwise
#                       the result will be placed into a variable named SELECT_RESULT_{mode} ie SELECT_RESULT_ROWID
#
#                   If AS variable is supplied:
#
#                       the result will be placed into <as> variable if only one <col> was requested, otherwise
#                       the result will be placed into <as>_<col> ... variables if more than one <col> was requested.
#
# ======================================================================================================================
# RS Format:        For SCALAR, ROW, COLUMN
#
#                       If {RS} empty,              <var> is ""
#                       If {RS} is a single value,  <var> is the actual value
#                       If {RS} is multi values,    <var> is a CMake list
#
#                   For COUNT, HANDLE, ROWID
#
#                       If {RS} empty,              <var> is "NOTFOUND"
#                       If {RS} is a single value,  <var> is the actual value
#
#                   For *
#
#                       If {RS} empty,              <var> is "NOTFOUND"
#                       If {RS} is a single value,  <var> is a MAP,     with the Column_Name or KEY as the KEY,
#                                                                       with the value as the VALUE
#                       If {RS} is multi values,    <var> is a TABLE,   with the Column_Name or KEY as the Column_Name
#                                                                      with the value as the row+column VALUE
#
# ======================================================================================================================
# Filtering / Targeting:
#
# ROWID|INDEX <id>              Targets a row by its numeric ID.
# ROW <name>                    Targets a row by its name.
# COLUMN <col>                  Targets a specific column.
# WHERE <col> = <val> [AND ...] Filters rows where column matches value.
# WHERE <col> LIKE <pattern>    Filters using * as wildcard.
# KEY|NAME <key>:               (Maps) Targets a specific key.

# ======================================================================================================================
# Examples:
#
# SELECT(Age AS ageVar FROM "Users" ROW Alice)                  Age returned in variable "ageVar"
# SELECT(ROWID FROM "Users" WHER Name = Alice)                  ROWID returned in variable "ROWID"
# SELECT(* AS hResults FROM "Users" WHERE City = "Milan")       Results returned in hResults
# SELECT(* FROM "Users" WHERE City = "Milan")                   Results returned in special var "SELECT_RESULT_SET"

# ======================================================================================================================
# Special vars set on return:   SELECT_RESULT_SET       (if no AS) Whatever the result of the SELECT was
#                               SELECT_RESULT_KIND      The type (SCALAR/LIST/MAP/TABLE) of SELECT_RESULT_SET
#                               SELECT_OK               TRUE if sizeof(resultset) > 0, otherwise FALSE
# ======================================================================================================================
function(SELECT)

    function(_parent_scope __col __val)
        string(REGEX REPLACE "'" "" _var "${__col}")

        if (__col STREQUAL "${_var}")
            list(FIND SELECT_VALUES "${__col}"   index)
            list(GET  SELECT_AS      ${index}    _var)
        endif ()

        set(${_var} "${__val}"  CACHE INTERNAL "")
    endfunction()

    set(_sel_modes "COUNT|HANDLE|ROW|COLUMN|ROWID|NAME|KEY|${_TOK_STAR}")
    set(_sel_nouns "${_sel_modes}|INDEX")
    set(_sel_keywords "FROM|INTO|WHERE|${_sel_nouns}")

    if (ARGV0 STREQUAL "*")
        set(_mode "SELECT_STAR")
    elseif (ARGV0 MATCHES "^(${_sel_modes})$")
        set(SELECT_${ARGV0} ON)
        set(_mode ${ARGV0})
    else ()
        set(SELECT_VALUE ON)
        set(_mode VALUES)
    endif ()

    # ── Normalise args ────────────────────────────────────────────────────────────────────────────────────────────────
    _sql_rejoin_args(_sel_args ${ARGN})

    # ── Peel INTO and WHERE ───────────────────────────────────────────────────────────────────────────────────────────
    _sql_peel_as("${_sel_args}" _sel_args SELECT_AS SELECT_VALUES)
    _sql_peel_into("${_sel_args}" _sel_args _x)
    _sql_peel_where("${_sel_args}" _sel_args _sel_where)

    if (_x AND NOT SELECT_AS)
        msg(ALWAYS DEPRECATED "SELECT(INTO) : INTO is deprecated, use \"AS\"")
        set(SELECT_AS ${_x})
    endif ()

    # ── <mode+cols> FROM <name> ───────────────────────────────────────────────────────────────────────────────────────
    if (_sel_args MATCHES "^(.*) FROM ([^ ]+)$")
        _hs_sql_resolve_handle("${CMAKE_MATCH_2}" _h)
    else ()
        if (_sel_args MATCHES "^FROM ([^ ]+)$")
            _hs_sql_resolve_handle("${CMAKE_MATCH_1}" _h)
        else ()
            msg(ALWAYS FATAL_ERROR "SELECT: syntax error near '${_sel_args}'")
        endif ()
    endif ()

    # ── Resolve handle ────────────────────────────────────────────────────────────────────────────────────────────────
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # ── Mode is HANDLE → return immediately ───────────────────────────────────────────────────────────────────────────
    if (SELECT_HANDLE)

        _parent_scope("'${SELECT_HANDLE}'" "${_h}")
        return()

    endif ()
    #
    #    # ── Peel FIELDS and verify for existence and validity ─────────────────────────────────────────────────────────────
    #    _sql_peel_fields("${_sel_mode_cols}" ${_h} "${_sel_modes}" _fields)
    #    list(LENGTH _fields _sizeof_fields)
    #    if (_sizeof_fields GREATER 0)
    #        list(GET _fields 0 _error_signal)
    #        if (_error_signal STREQUAL "!")
    #            string(REPLACE ";" " " _src "${ARGV}")
    #            string(REPLACE ";" "\n" _text "${_fields}")
    #            msg(ALWAYS FATAL_ERROR "SELECT(${_src}) : ERROR${_text}\n")
    #        endif ()
    #    endif ()
    #    if (NOT _fields STREQUAL "")
    #
    #        set(SELECT_VALUE ON)
    #        set(SELECT_VALUES "${_fields}")
    #
    #    else ()
    #
    #        set(SELECT_${_mode} ON)
    #
    #    endif ()

    # ── Parse WHERE, then extract nouns ───────────────────────────────────────────────────────────────────────────────
    set(_whereCols "")
    set(_whereOps "")
    set(_whereVals "")
    if (NOT "${_sel_where}" STREQUAL "")
        parse_where("${_sel_where}")
    endif ()
    _sql_extract_nouns(_whereCols _whereOps _whereVals)
    string(REPLACE "|" ";" _nouns "${_sel_nouns}")
    foreach (_noun IN LISTS _nouns)
        if (DEFINED _where_${_noun})
            set(SELECT_WHERE_${_noun} "${_where_${_noun}}")
        endif ()
    endforeach ()

    # ── Peel FIELDS and verify for existence and validity ─────────────────────────────────────────────────────────────
    _sql_peel_fields(${_h} "${_sel_mode_cols}" "${_whereCols}" "${_sel_modes}" _fields)
    list(LENGTH _fields _sizeof_fields)
    if (_sizeof_fields GREATER 0)
        list(GET _fields 0 _error_signal)
        if (_error_signal STREQUAL "!")
            string(REPLACE ";" " " _src "${ARGV}")
            string(REPLACE ";" "\n" _text "${_fields}")
            msg(ALWAYS FATAL_ERROR "SELECT(${_src}) : ERROR${_text}\n")
        endif ()
    endif ()
#    if (NOT _fields STREQUAL "")
#
#        set(SELECT_VALUE ON)
#
#    else ()
#
#        set(SELECT_${_mode} ON)
#
#    endif ()

    ####################################################################################################################
    set(SELECT_OK OFF PARENT_SCOPE)

    if (_type STREQUAL "MAP")

        if (SELECT_NAME)
            set(_targetKey "${SELECT_WHERE_NAME}")
        elseif (SELECT_KEY)
            set(_targetKey "${SELECT_WHERE_KEY}")
        else ()
            msg(ALWAYS FATAL_ERROR "SELECT: NAME or KEY mode with maps requires 'NAME' or 'KEY' in WHERE clause \"${_sel_where}\"")
        endif ()

        get_property(_raw GLOBAL PROPERTY "${_h}_K_${_targetKey}")
        _hs_sql_field_to_user(_raw _final)
        if (NOT _final)
            set(_final NOTFOUND)
        endif ()
        set(${SELECT_AS} "${_final}" PARENT_SCOPE)

        set(SELECT_RESULT_SET ${_final} PARENT_SCOPE)
        set(SELECT_RESULT_KIND "MAP" PARENT_SCOPE)
        set(SELECT_OK ON PARENT_SCOPE)
        return()
    endif ()

    if (_type STREQUAL "VIEW")
        get_property(_encMems GLOBAL PROPERTY "${_h}_MEMBERS")
        _hs_sql_record_to_list(_encMems _members)

        foreach (_m IN LISTS _members)
            set(_mVar "_v_${_m}")
            set(${_mVar} "${_m}")
            if (SELECT_VALUE)
                SELECT(${_SELECT_VALUES} FROM _m INTO _sub)
            else ()
                SELECT(${_SELECT_MODE} FROM _m INTO _sub)
            endif ()
            if (_sub)
                list(APPEND _res "${_sub}")
                set(_last "${_sub}")
            endif ()
        endforeach ()

        list(LENGTH _res _matches)

        if (_matches EQUAL 0)
            set(${SELECT_AS} "${_last}" PARENT_SCOPE)
            set(SELECT_RESULT_SET "${_last}" PARENT_SCOPE)
            set(SELECT_RESULT_KIND "VALUE" PARENT_SCOPE)
        elseif (_matches EQUAL 1)
            set(${SELECT_AS} "${_last}" PARENT_SCOPE)
            set(SELECT_RESULT_SET "${_last}" PARENT_SCOPE)
            set(SELECT_RESULT_KIND "SCALAR" PARENT_SCOPE)
            set(SELECT_OK ON PARENT_SCOPE)
        else ()
            set(${SELECT_AS} "${_res}" PARENT_SCOPE)
            set(SELECT_RESULT_SET "${_res}" PARENT_SCOPE)
            set(SELECT_RESULT_KIND "LIST" PARENT_SCOPE)
            set(SELECT_OK ON PARENT_SCOPE)
        endif ()


        return()
    endif ()

    # ==================================================================================================================

    set(_tRow)
    set(_tCol)

    get_property(_encIDs GLOBAL PROPERTY "${_h}_ROWIDS")
    _hs_sql_record_to_list(_encIDs _ids)

    if (SELECT_ROWID OR SELECT_WHERE_ROWID)
        set(_tRow "${SELECT_WHERE_ROWID}")
    elseif (SELECT_INDEX OR SELECT_WHERE_INDEX)
        set(_tRow "${SELECT_WHERE_INDEX}")
    endif ()

    if (SELECT_COLUMN)
        set(_tCol "${SELECT_WHERE_COLUMN}")
    endif ()

    if (SELECT_WHERE_ROW)
        get_property(_rid GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${SELECT_WHERE_ROW}")
        if (_rid)
            set(_tRow "${_rid}")
        else ()
            set(_tRow "${SELECT_WHERE_ROW}")
        endif ()
    endif ()

    if (SELECT_VALUES)
        # Handle multiple values (columns) for a single row
        # ARGV parsing for multiple columns after VALUES is tricky with manual loop.
        # But if we have SELECT_VALUES, it might just be the first one if we used set(args ... VALUES)
        # Actually cmake_parse_arguments only takes one value for an argument in 'args'.
        # Let's use 'lists' for VALUES.
    endif ()

    if (SELECT_STAR AND _tRow)
        CREATE(MAP "Row MAP ${_h}" INTO _hMap)
        # Handle created in current scope, resolve it for use
        _hs_sql_resolve_handle(_hMap _hMapRes)
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list(_encCols _allCols)
        foreach (_c IN LISTS _allCols)
            get_property(_raw GLOBAL PROPERTY "${_h}_R${_tRow}_${_c}")
            _hs_sql_field_to_user(_raw _val)
            # Use MAP-specific insert logic
            _hs_sql_field_to_storage(_val _encVal)
            set_property(GLOBAL PROPERTY "${_hMapRes}_K_${_c}" "${_encVal}")
            set_property(GLOBAL PROPERTY "${_hMapRes}_K_${_c}_ISHANDLE" FALSE)
            set_property(GLOBAL APPEND PROPERTY "${_hMapRes}_KEYS" "${_c}")
        endforeach ()

        if (SELECT_AS)
            set(${SELECT_AS} "${_hMapRes}" PARENT_SCOPE)
        else ()
            set(SELECT_RESULT_SET "${_hMapRes}" PARENT_SCOPE)
        endif ()
        set(SELECT_OK ON PARENT_SCOPE)
        set(SELECT_RESULT_KIND "HANDLE" PARENT_SCOPE)

        return()
    endif ()

    if (SELECT_ROW AND _tRow)
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list(_encCols _allCols)
        set(_rowList "")
        foreach (_c IN LISTS _allCols)
            get_property(_raw GLOBAL PROPERTY "${_h}_R${_tRow}_${_c}")
            _hs_sql_field_to_user(_raw _val)
            list(APPEND _rowList "${_val}")
        endforeach ()

        if (SELECT_AS)
            set(${SELECT_AS} "${_rowList}" PARENT_SCOPE)
        else ()
            set(SELECT_RESULT_SET "${_rowList}" PARENT_SCOPE)
        endif ()
        set(SELECT_RESULT_KIND "LIST" PARENT_SCOPE)
        set(SELECT_OK ON PARENT_SCOPE)

        return()
    endif ()

    if ((SELECT_VALUE OR SELECT_HANDLE OR SELECT_ROW) AND _tRow)
        # Try to find column name from unparsed args if _tCol is empty
        if (NOT _tCol AND NOT SELECT_WHERE_ROW)
            # Get all column names to check against unparsed args
            get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
            _hs_sql_record_to_list(_encCols _allCols)

            foreach (_arg IN LISTS SELECT_VALUES)
                if (NOT _arg STREQUAL "${SELECT_AS}" AND NOT _arg STREQUAL "${SELECT_FROM}" AND NOT _arg STREQUAL "${_h}" AND NOT _arg STREQUAL "${_TOK_STAR}" AND NOT _arg STREQUAL "WHERE" AND NOT _arg STREQUAL "=")
                    # Check if it's a valid column name
                    list(FIND _allCols "${_arg}" _isCol)
                    if (NOT _isCol EQUAL -1)
                        set(_tCol "${_arg}")
                        break()
                    endif ()
                endif ()
            endforeach ()
        endif ()

        if (SELECT_ROW AND NOT SELECT_VALUE AND NOT SELECT_HANDLE)
            # Already handled above, but just in case
        elseif (_tCol)
            get_property(_raw GLOBAL PROPERTY "${_h}_R${_tRow}_${_tCol}")
            _hs_sql_field_to_user(_raw _final)

            if (SELECT_AS)
                set(${SELECT_AS} "${_final}" PARENT_SCOPE)
            else ()
                set(SELECT_RESULT_SET "${_final}" PARENT_SCOPE)
            endif ()

            set(SELECT_RESULT_KIND "${_mode}" PARENT_SCOPE)
            set(SELECT_OK ON PARENT_SCOPE)

            return()
        endif ()
    endif ()

    # B. Restored Multi-row Filtering Logic (SELECT * / SELECT COUNT)
    get_property(_encIDs GLOBAL PROPERTY "${_h}_ROWIDS")
    _hs_sql_record_to_list(_encIDs _ids)
    get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
    _hs_sql_record_to_list(_encCols _allCols)

    set(_matches "")

    list(LENGTH _whereCols _filterCount)
    math(EXPR _maxF "${_filterCount} - 1")

    foreach (_rid IN LISTS _ids)
        set(_rowPass ON)
        if (_filterCount GREATER 0)
            foreach (_fIdx RANGE ${_maxF})
                list(GET _whereCols ${_fIdx} _fCol)
                list(GET _whereOps ${_fIdx} _fOp)
                list(GET _whereVals ${_fIdx} _fVal)
                get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_fCol}")
                _hs_sql_field_to_user(_val _actualVal)

                if (_fVal MATCHES "^\-?[0-9]+$") # Numeric comparisons =================================================
                    if (_fOp STREQUAL "=")
                        if (NOT _actualVal EQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "!=")
                        if (_actualVal EQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "<=")
                        if (NOT _actualVal LESS_EQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "<")
                        if (NOT _actualVal LESS ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL ">=")
                        if (NOT _actualVal GREATER_EQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL ">")
                        if (NOT _actualVal GREATER ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    endif ()

                else () # Text based comparison ========================================================================

                    if (_fOp STREQUAL "=")
                        if (NOT _actualVal STREQUAL "${_fVal}")
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "LIKE")
                        string(REPLACE ${_TOK_STAR} ".*" _regex "${_fVal}")
                        if (NOT _actualVal MATCHES "^${_regex}$")
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "!=")
                        if (_actualVal STREQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "<=")
                        if (NOT _actualVal STRLESS_EQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL "<")
                        if (NOT _actualVal STRLESS ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL ">=")
                        if (NOT _actualVal STRGREATER_EQUAL ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    elseif (_fOp STREQUAL ">")
                        if (NOT _actualVal STRGREATER ${_fVal})
                            set(_rowPass OFF)
                            break()
                        endif ()
                    endif ()
                endif ()
            endforeach ()
        endif ()
        if (_rowPass)
            list(APPEND _matches "${_rid}")
        endif ()
    endforeach ()

    # --- C. Shape the Output ---
    if (SELECT_COUNT)
        list(LENGTH _matches _count)
        set(${SELECT_AS} "${_count}" PARENT_SCOPE)

        if (SELECT_AS)
            set(${SELECT_AS} ${_count} PARENT_SCOPE)
        else ()
            set(SELECT_RESULT_SET ${_count} PARENT_SCOPE)
        endif ()
        set(SELECT_RESULT_KIND "COUNT" PARENT_SCOPE)
        set(SELECT_OK ON PARENT_SCOPE)

        return()
    endif ()

    # If the user specifically asked for a VALUE (scalar string)
    if (SELECT_VALUE)

        if (NOT _matches)
            foreach (_tCol IN LISTS SELECT_VALUES)
                _parent_scope("${_tCol}" "")
            endforeach ()
            set(SELECT_RESULT_KIND "SCALAR" PARENT_SCOPE)
            return()
        endif ()

        list(LENGTH _matches _matchCount)

        foreach (_tCol IN LISTS SELECT_VALUES)
            set(_srs)
            foreach (_rid IN LISTS _matches)
                get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_tCol}")
                _hs_sql_field_to_user(_val _final_result)

                list(APPEND _srs "${_val}")

            endforeach ()
            _parent_scope("${_tCol}" "${_srs}")
        endforeach ()

        if (_matchCount EQUAL 1)
            set(SELECT_RESULT_KIND "SCALAR" PARENT_SCOPE)
        else ()
            set(SELECT_RESULT_KIND "LIST" PARENT_SCOPE)
        endif ()
        set(SELECT_OK ON PARENT_SCOPE)

        return()

    endif ()

    # --- Inside SELECT function ---
    if (SELECT_ROW)
        if (NOT _targetRow)
            # If no ROWID specified, default to the first match
            list(GET _matches 0 _targetRow)
        endif ()

        set(_rowList "")
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list(_encCols _allCols)

        foreach (_col IN LISTS _allCols)
            get_property(_v GLOBAL PROPERTY "${_h}_R${_targetRow}_${_col}")
            _hs_sql_field_to_user(_v _v)
            list(APPEND _rowList "${_v}")
        endforeach ()

        set(${SELECT_AS} "${_rowList}" PARENT_SCOPE)

        set(SELECT_RESULT_SET "_rowList" PARENT_SCOPE)
        set(SELECT_RESULT_KIND "LIST" PARENT_SCOPE)
        set(SELECT_OK ON PARENT_SCOPE)

        return()
    endif ()

    # --- D. Default: Return a result set (New Table Handle) ---
    CREATE(TABLE "result_set" COLUMNS "${_allCols}" INTO _tmpRes)
    if(_matches)
        set(SELECT_OK ON PARENT_SCOPE)

        foreach (_mID IN LISTS _matches)
            set(_rowValues "")
            foreach (_col IN LISTS _allCols)
                get_property(_val GLOBAL PROPERTY "${_h}_R${_mID}_${_col}")
                list(APPEND _rowValues "${_val}")
            endforeach ()
            INSERT(INTO _tmpRes VALUES (${_rowValues}))
        endforeach ()

        _parent_scope("'${SELECT_AS}'" "${_tmpRes}")
    #    set(SELECT_RESULT_SET "${_tmpRes}" PARENT_SCOPE)
        set(SELECT_RESULT_KIND "HANDLE" PARENT_SCOPE)
    #
    #    set(${SELECT_AS} "${_tmpRes}" PARENT_SCOPE)
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# DML: DELETE & DROP
# --------------------------------------------------------------------------------------------------
function(DELETE)
    set(options "FROM")
    set(args "ROWID;TABLE")
    set(lists "")
    cmake_parse_arguments(DELETE "${options}" "${args}" "${lists}" ${ARGV})
    set(tableVarName ${DELETE_TABLE})

    if (NOT tableVarName)
        set(tableVarName ${DELETE_UNPARSED_ARGUMENTS_0})
    endif ()

    _hs_sql_resolve_handle("${tableVarName}" _h)
    _hs_sql_check_readonly(${_h})

    if (DELETE_ROWID)
        set(_rid "${DELETE_ROWID}")
    else ()
        set(_rid "")
        set(_i 1)
        while (_i LESS ARGC)
            if ("${ARGV${_i}}" STREQUAL "ROWID")
                math(EXPR _i "${_i} + 1")
                if ("${ARGV${_i}}" STREQUAL "=")
                    math(EXPR _i "${_i} + 1")
                endif ()
                set(_rid "${ARGV${_i}}")
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()
    endif ()

    if (_rid)
        # Remove from the ROWIDS list
        get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
        list(REMOVE_ITEM _ids "${_rid}")
        set_property(GLOBAL PROPERTY "${_h}_ROWIDS" "${_ids}")

        # Update Count
        list(LENGTH _ids _newCount)
        set_property(GLOBAL PROPERTY "${_h}_ROW_COUNT" "${_newCount}")

        # Note: We leave the actual R${_rid}_COL properties in global memory
        # but they are now unreachable via standard SELECT/DUMP.
    endif ()
endfunction()

function(DROP)
    set(options "CASCADE;TABLE;VIEW;MATERIALIZED_VIEW;MAP;SHEET;HANDLE")
    set(args "")
    set(lists "QUIET")
    cmake_parse_arguments(DROP "${options}" "${args}" "${lists}" ${ARGV})

    if (DEFINED DROP_QUIET AND DROP_QUIET)
        set(_quiet_types UNRESOLVED TYPE)
        cmake_parse_arguments(DROP_QUIET "${_quiet_types}" "" "" ${DROP_QUIET})
    endif ()

    # Determine type and target from unparsed or options
    set(_target "")
    set(_type_constraint "")
    foreach (_opt IN ITEMS TABLE VIEW MATERIALIZED_VIEW MAP SHEET)
        if (DROP_${_opt})
            set(_type_constraint ${_opt})
            break()
        endif ()
    endforeach ()

    if (DROP_HANDLE)
        list(GET DROP_UNPARSED_ARGUMENTS 0 _handleVar)
        if (NOT _handleVar)
            msg(ALWAYS FATAL_ERROR "DROP(HANDLE <var>): Missing handle variable name.")
        endif ()
        set(_target "${${_handleVar}}")
        if (NOT _target)
            # If the variable is empty, it might already be dropped or never set
            return()
        endif ()
        # Nullify the handle in the parent scope
        unset(${_handleVar} PARENT_SCOPE)
    else ()
        list(GET DROP_UNPARSED_ARGUMENTS 0 _target)
    endif ()

    if (NOT _target)
        msg(ALWAYS FATAL_ERROR "DROP: Missing name or handle. ARGN: ${ARGN}")
    endif ()

    _hs_sql_resolve_handle("${_target}" _h)
    if (NOT _h)
        if (DROP_QUIET_UNRESOLVED)
            return()
        else ()
            msg(ALWAYS FATAL_ERROR "SQL DROP Error: Could not resolve handle for '${_target}'.")
        endif ()
    endif ()

    # Type verification if constrained
    get_property(_actualType GLOBAL PROPERTY "${_h}_TYPE")
    if (_type_constraint)
        if (_type_constraint STREQUAL "SHEET")
            set(_type_constraint "TABLE")
        endif ()
        if (NOT _actualType STREQUAL _type_constraint)
            if (DROP_QUIET_TYPE)
                msg(ALWAYS FATAL_ERROR "SQL DROP Warning: Object '${_target}' is type '${_actualType}', but DROP(${_type_constraint} ...) was requested.")
                return()
            else ()
                msg(ALWAYS FATAL_ERROR "SQL DROP Error: Object '${_target}' is type '${_actualType}', but DROP(${_type_constraint} ...) was requested.")
            endif ()
        endif ()
    endif ()

    # Get label for cleanup
    get_property(_encLabel GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user(_encLabel _label)

    # CASCADE logic: find other handles that might reference this one
    if (DROP_CASCADE)
        get_property(_nextH GLOBAL PROPERTY HS_NEXT_HNDL)
        math(EXPR _maxH "${_nextH} - 1")
        foreach (_i RANGE 1000 ${_maxH})
            set(_otherH "HS_HNDL_${_i}")
            if (NOT "${_otherH}" STREQUAL "${_h}")
                get_property(_oType GLOBAL PROPERTY "${_otherH}_TYPE")
                if (_oType STREQUAL "MAP")
                    get_property(_keys GLOBAL PROPERTY "${_otherH}_KEYS")
                    set(_keysToRemoval "")
                    foreach (_k IN LISTS _keys)
                        get_property(_isH GLOBAL PROPERTY "${_otherH}_K_${_k}_ISHANDLE")
                        if (_isH)
                            get_property(_val GLOBAL PROPERTY "${_otherH}_K_${_k}")
                            if ("${_val}" STREQUAL "${_h}")
                                list(APPEND _keysToRemoval "${_k}")
                            endif ()
                        endif ()
                    endforeach ()
                    foreach (_k IN LISTS _keysToRemoval)
                        set_property(GLOBAL PROPERTY "${_otherH}_K_${_k}" "")
                        set_property(GLOBAL PROPERTY "${_otherH}_K_${_k}_ISHANDLE" "")
                        list(REMOVE_ITEM _keys "${_k}")
                    endforeach ()
                    set_property(GLOBAL PROPERTY "${_otherH}_KEYS" "${_keys}")
                endif ()
                if (_oType STREQUAL "VIEW")
                    get_property(_encMems GLOBAL PROPERTY "${_otherH}_MEMBERS")
                    _hs_sql_record_to_list(_encMems _mems)
                    if ("${_h}" IN_LIST _mems)
                        list(REMOVE_ITEM _mems "${_h}")
                        _hs_sql_list_to_record(_mems _encNewMems)
                        set_property(GLOBAL PROPERTY "${_otherH}_MEMBERS" "${_encNewMems}")
                    endif ()
                endif ()
            endif ()
        endforeach ()
    endif ()

    # Delete main properties
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    if (_type MATCHES "TABLE|MATERIALIZED_VIEW")
        get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list(_encCols _cols)
        foreach (_rid IN LISTS _ids)
            foreach (_c IN LISTS _cols)
                set_property(GLOBAL PROPERTY "${_h}_R${_rid}_${_c}" "")
            endforeach ()
        endforeach ()
        set_property(GLOBAL PROPERTY "${_h}_ROWIDS" "")
        set_property(GLOBAL PROPERTY "${_h}_COLUMNS" "")
        set_property(GLOBAL PROPERTY "${_h}_ROW_COUNT" "")
        set_property(GLOBAL PROPERTY "${_h}_NEXT_ROWID" "")

        # Clean row name mappings if any
        get_property(_rnames GLOBAL PROPERTY "${_h}_ROW_NAMES")
        foreach (_rn IN LISTS _rnames)
            set_property(GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${_rn}" "")
            set_property(GLOBAL PROPERTY "${_h}_ROWID_TO_NAME_${_rn}" "") # Just in case
        endforeach ()
        set_property(GLOBAL PROPERTY "${_h}_ROW_NAMES" "")

    elseif (_type STREQUAL "MAP")
        get_property(_keys GLOBAL PROPERTY "${_h}_KEYS")
        foreach (_k IN LISTS _keys)
            set_property(GLOBAL PROPERTY "${_h}_K_${_k}" "")
            set_property(GLOBAL PROPERTY "${_h}_K_${_k}_ISHANDLE" "")
        endforeach ()
        set_property(GLOBAL PROPERTY "${_h}_KEYS" "")
    elseif (_type STREQUAL "VIEW")
        set_property(GLOBAL PROPERTY "${_h}_MEMBERS" "")
    endif ()

    set_property(GLOBAL PROPERTY "${_h}_TYPE" "")
    set_property(GLOBAL PROPERTY "${_h}_LABEL" "")

    # Remove Label Mapping
    if (_label)
        get_property(_registeredHndl GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_label}")
        if ("${_registeredHndl}" STREQUAL "${_h}")
            set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_label}" "")
        endif ()
    endif ()

endfunction()

# --------------------------------------------------------------------------------------------------
# Introspection & Utilities
# --------------------------------------------------------------------------------------------------

function(TYPEOF)
    set(options "")
    set(args "INTO;HANDLE")
    set(lists "")
    cmake_parse_arguments(TYPEOF "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${TYPEOF_HANDLE})
    set(outVar ${TYPEOF_INTO})

    if (NOT handleVarName)
        list(GET TYPEOF_UNPARSED_ARGUMENTS 0 handleVarName)
    endif ()
    if (NOT outVar)
        list(GET TYPEOF_UNPARSED_ARGUMENTS 1 outVar)
    endif ()

    _hs_sql_resolve_handle("${handleVarName}" _h)
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    set(${outVar} "${_type}" PARENT_SCOPE)
endfunction()

function(LABEL)
    set(options "OF")
    set(args "INTO;HANDLE")
    set(lists "")
    cmake_parse_arguments(LABEL "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${LABEL_HANDLE})
    set(outVar ${LABEL_INTO})

    if (NOT handleVarName)
        set(handleVarName ${LABEL_UNPARSED_ARGUMENTS_0})
    endif ()
    if (NOT outVar)
        set(outVar ${LABEL_UNPARSED_ARGUMENTS_1})
    endif ()

    _hs_sql_resolve_handle("${handleVarName}" _h)
    get_property(_raw GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user(_raw _final)
    set(${outVar} "${_final}" PARENT_SCOPE)
endfunction()

function(GET_COLUMNS)
    set(options "")
    set(args "INTO;HANDLE")
    set(lists "")
    cmake_parse_arguments(GET_COLUMNS "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${GET_COLUMNS_HANDLE})
    set(outVar ${GET_COLUMNS_INTO})

    if (NOT handleVarName)
        set(handleVarName ${GET_COLUMNS_UNPARSED_ARGUMENTS_0})
    endif ()
    if (NOT outVar)
        set(outVar ${GET_COLUMNS_UNPARSED_ARGUMENTS_1})
    endif ()

    _hs_sql_resolve_handle("${handleVarName}" _h)
    get_property(_raw GLOBAL PROPERTY "${_h}_COLUMNS")
    _hs_sql_record_to_list(_raw _final)
    set(${outVar} "${_final}" PARENT_SCOPE)
endfunction()

function(GET_ROWIDS)
    set(options "")
    set(args "INTO;HANDLE")
    set(lists "")
    cmake_parse_arguments(GET_ROWIDS "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${GET_ROWIDS_HANDLE})
    set(outVar ${GET_ROWIDS_INTO})

    if (NOT handleVarName)
        set(handleVarName ${GET_ROWIDS_UNPARSED_ARGUMENTS_0})
    endif ()
    if (NOT outVar)
        set(outVar ${GET_ROWIDS_UNPARSED_ARGUMENTS_1})
    endif ()

    _hs_sql_resolve_handle("${handleVarName}" _h)
    get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
    set(${outVar} "${_ids}" PARENT_SCOPE)
endfunction()

function(DESCRIBE)
    set(options "")
    set(args "HANDLE")
    set(lists "")
    cmake_parse_arguments(DESCRIBE "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${DESCRIBE_HANDLE})

    if (NOT handleVarName)
        set(handleVarName ${DESCRIBE_UNPARSED_ARGUMENTS_0})
    endif ()

    _hs_sql_resolve_handle("${handleVarName}" _h)

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    get_property(_rawLabel GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user(_rawLabel _label)

    if (NOT _h)
        msg(AUTHOR_WARNING "DESCRIBE: Could not resolve handle for '${handleVarName}'")
        return()
    endif ()

    msg("Object: ${_label}")
    msg("Type:   ${_type}")

    if (_type STREQUAL "TABLE" OR _type STREQUAL "MATERIALIZED_VIEW")
        get_property(_rawCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list(_rawCols _cols)
        get_property(_count GLOBAL PROPERTY "${_h}_ROW_COUNT")
        msg("Rows:   ${_count}")
        msg("Cols:   ${_cols}")
    elseif (_type STREQUAL "VIEW")
        get_property(_rawMems GLOBAL PROPERTY "${_h}_MEMBERS")
        _hs_sql_record_to_list(_rawMems _mems)
        msg("Source Members: ${_mems}")
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# Validation: ASSERT
# --------------------------------------------------------------------------------------------------
function(ASSERT)
    set(options "")
    set(args "TYPE;COUNT;HANDLE")
    set(lists "")
    cmake_parse_arguments(ASSERT "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${ASSERT_HANDLE})

    if (NOT handleVarName)
        set(handleVarName ${ASSERT_UNPARSED_ARGUMENTS_0})
    endif ()

    _hs_sql_resolve_handle("${handleVarName}" _h)
    set(_expectedType "${ASSERT_TYPE}")
    set(_expectedCount "${ASSERT_COUNT}")

    if (_expectedType)
        get_property(_actualType GLOBAL PROPERTY "${_h}_TYPE")
        if (NOT "${_actualType}" STREQUAL "${_expectedType}")
            msg(ALWAYS FATAL_ERROR "ASSERT FAILED: Type is '${_actualType}', expected '${_expectedType}'")
        endif ()
    endif ()

    if (NOT "${_expectedCount}" STREQUAL "")
        get_property(_actualCount GLOBAL PROPERTY "${_h}_ROW_COUNT")
        if (NOT "${_actualCount}" EQUAL "${_expectedCount}")
            msg(ALWAYS FATAL_ERROR "ASSERT FAILED: Count is ${_actualCount}, expected ${_expectedCount}")
        endif ()
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# Introspection: DUMP
# --------------------------------------------------------------------------------------------------
function(DUMP)
    set(options "VERBOSE;DEEP")
    set(args "FROM;INTO;DEPTH;HANDLE")
    set(lists "")
    cmake_parse_arguments(DUMP "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${DUMP_FROM})

    if (NOT handleVarName)
        if (DUMP_UNPARSED_ARGUMENTS)
            list(GET DUMP_UNPARSED_ARGUMENTS 0 handleVarName)
        endif ()
    endif ()

    set(_verbose ${DUMP_VERBOSE})
    set(_deep ${DUMP_DEEP})
    set(_intoVar "${DUMP_INTO}")
    set(_depth "${DUMP_DEPTH}")
    if (NOT _depth)
        set(_depth 1)
    endif ()
    set(_offset_padding)
    set(_depth_note)
    set(_padding_str "\t")
    set(_out)

    _hs_sql_resolve_handle("${handleVarName}" _h)

    # msg(STATUS "DEBUG: DUMP resolved handle '\${_h}' for input '\${handleVarName}'")

    if (NOT _h)
        set(_out "SQL Error: Could not resolve handle for '${handleVarName}'\n")
        if (_intoVar)
            set(${_intoVar} "${_out}" PARENT_SCOPE)
        else ()
            msg("${_out}")
        endif ()
        return()
    endif ()

    string(REPEAT "${_padding_str}" ${_depth} _offset_padding)
    if (_depth GREATER 1)
        set(_depth_note "\n\n${_offset_padding}Depth: ${_depth} ")
    endif ()

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    get_property(_encLabel GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user(_encLabel _label)

    string(APPEND _out "${_depth_note}--- SQL DUMP: ${_label} (${_type}) [HANDLE: ${_h}] ---\n")

    # --- VIEW Logic (Show member pointers) ---
    if (_type STREQUAL "VIEW")
        get_property(_encMembers GLOBAL PROPERTY "${_h}_MEMBERS")
        _hs_sql_record_to_list(_encMembers _members)
        string(APPEND _out "${_offset_padding} MEMBERS: ${_members}\n")
        if (_deep)
            foreach (_m IN LISTS _members)
                set(_mVar "_v_${_m}")
                set(${_mVar} "${_m}")
                math(EXPR _level "${_depth} + 1")
                DUMP(FROM ${_mVar} VERBOSE ${_verbose} DEEP ${_deep} INTO _inner DEPTH ${_level})
                string(APPEND _out "${_offset_padding}  |--- MEMBER ${_m}: ${_inner}\n")
            endforeach ()
        endif ()

    elseif (_type STREQUAL "MAP")
        get_property(_keys GLOBAL PROPERTY "${_h}_KEYS")
        foreach (_pass RANGE 1 2)
            foreach (_k IN LISTS _keys)
                get_property(_raw GLOBAL PROPERTY "${_h}_K_${_k}")
                _hs_sql_field_to_user(_raw _v)
                get_property(_isH GLOBAL PROPERTY "${_h}_K_${_k}_ISHANDLE")
                if (_pass EQUAL 1)
                    if (_isH)
                        string(APPEND _out "${_offset_padding} [KEY] ${_k} => [HANDLE] ${_v}\n")
                    else ()
                        string(APPEND _out "${_offset_padding} [KEY] ${_k} => [VALUE] \"${_v}\"\n")
                    endif ()
                else ()
                    if (_deep)
                        math(EXPR _level "${_depth} + 1")
                        DUMP(FROM _v VERBOSE ${_verbose} DEEP ${_deep} INTO _ours DEPTH ${_level})
                        set(_out "${_out}\n${_ours}")
                    endif ()
                endif ()
            endforeach ()
        endforeach ()
    elseif (_type MATCHES "TABLE|MATERIALIZED_VIEW")
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list(_encCols _cols)
        get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")

        if (NOT _verbose)
            string(APPEND _out "${_offset_padding}    COLS: ${_cols}\n")
        else ()
            # --- PASS 1: MEASURE ---
            # Initialize widths with header lengths

            foreach (_c IN LISTS _cols)
                string(LENGTH "${_c}" _len)
                set(_w_${_c} ${_len})
            endforeach ()
            set(_w_ROW 3) # Minimum width for "Row" header

            foreach (_rid IN LISTS _ids)
                foreach (_c IN LISTS _cols)
                    get_property(_encVal GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
                    _hs_sql_field_to_user(_encVal _val)
                    _hs_sql_record_to_list(_val _valList)

                    # Apply GitHub domain omission logic for measurement
                    if (_val MATCHES "^https://github.com/(.*)")
                        set(_val "${CMAKE_MATCH_1}")
                    endif ()

                    # Split by semicolon to find the longest individual line in a multi-value field
                    string(REPLACE ";" "\n" _lines "${_val}")
                    string(REPLACE "\n" ";" _lineList "${_lines}")
                    foreach (_line IN LISTS _lineList)
                        string(LENGTH "${_line}" _lLen)
                        if (_lLen GREATER _w_${_c})
                            set(_w_${_c} ${_lLen})
                        endif ()
                    endforeach ()
                endforeach ()
            endforeach ()

            # --- PASS 2: LAYOUT ---
            # Build Header Row
            set(_header "    | Row |")
            foreach (_c IN LISTS _cols)
                _hs_pad_string("${_c}" ${_w_${_c}} _padded)
                string(APPEND _header " ${_padded} |")
            endforeach ()
            string(APPEND _header "\n")
            string(APPEND _out "${_offset_padding}${_header}")

            # Build Rows
            foreach (_rid IN LISTS _ids)
                set(_rowLines 1)
                # Determine how many sub-lines this row needs
                foreach (_c IN LISTS _cols)
                    get_property(_encVal GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
                    _hs_sql_field_to_user(_encVal _val)
                    _hs_sql_record_to_list(_val _valList)
                    string(REPLACE "&" ";" _noAmp "${_val}")
                    string(REPLACE ";" "\n" _lines "${_noAmp}")
                    string(REPLACE "\n" ";" _lineList "${_lines}")
                    list(LENGTH _lineList _lCount)
                    if (_lCount GREATER _rowLines)
                        set(_rowLines ${_lCount})
                    endif ()
                endforeach ()

                # Print each sub-line for the current row
                math(EXPR _maxLineIdx "${_rowLines} - 1")
                foreach (_li RANGE ${_maxLineIdx})
                    if (_li EQUAL 0)
                        _hs_pad_string("${_rid}" 3 _pRid)
                        set(_lineStr "    | ${_pRid} |")
                    else ()
                        set(_lineStr "    |     |")
                    endif ()

                    foreach (_c IN LISTS _cols)
                        get_property(_encVal GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
                        _hs_sql_field_to_user(_encVal _val)
                        _hs_sql_record_to_list(_val _valList)

                        # Apply GitHub domain omission for display
                        if (_val MATCHES "^https://github.com/(.*)")
                            set(_val "${CMAKE_MATCH_1}")
                        endif ()
                        _hs_sql_field_to_user(_val _maybe_blank)
                        string(REPLACE "&&" "&" _single_amp "${_maybe_blank}")
                        string(REPLACE "&" ";" _no_amp "${_single_amp}")
                        string(REPLACE ";" "\n" _lines "${_no_amp}")
                        string(REPLACE "\n" ";" _lineList "${_lines}")

                        list(LENGTH _lineList _currentMax)
                        if (_li LESS _currentMax)
                            list(GET _lineList ${_li} _cellText)
                        else ()
                            set(_cellText "")
                        endif ()

                        _hs_pad_string("${_cellText}" ${_w_${_c}} _paddedCell)
                        string(APPEND _lineStr " ${_paddedCell} |")
                    endforeach ()
                    string(APPEND _out "${_offset_padding}${_lineStr}\n")
                endforeach ()
            endforeach ()
        endif ()
    endif ()

    if (_intoVar)
        set(${_intoVar} "${_out}" PARENT_SCOPE)
    else ()
        msg("${_out}")
    endif ()
endfunction()


# ==================================================================================================
# FOREACH
# ==================================================================================================
# SQL_FOREACH(ROW    IN tableHandle CALL functionName)
# SQL_FOREACH(HANDLE IN collHandle  CALL functionName)
# SQL_FOREACH(KEY    IN dictHandle  CALL functionName)
#
macro(SQL_FOREACH _iterType _inKw _handleVar _callKw _functionName)
    if (NOT "${_inKw}" STREQUAL "IN")
        msg(ALWAYS FATAL_ERROR "SQL_FOREACH: expected IN, got '${_inKw}'")
    endif ()
    if (NOT "${_callKw}" STREQUAL "CALL")
        msg(ALWAYS FATAL_ERROR "SQL_FOREACH: expected CALL, got '${_callKw}'")
    endif ()
    _hs_sql_resolve_handle("${_handleVar}" _hndl)
    _hs_sql__foreach("${_iterType}" "${_hndl}" "${_functionName}")
endmacro()

function(_hs_sql__iter_rows hndl outVar)
    get_property(_ids GLOBAL PROPERTY "${hndl}_ROWIDS")
    set(${outVar} "${_ids}" PARENT_SCOPE)
endfunction()

function(_hs_sql__foreach iterType hndlValue functionName)
    if (iterType STREQUAL "ROW")
        _hs_sql__iter_rows("${hndlValue}" _rowIDs)
        foreach (_rid IN LISTS _rowIDs)
            cmake_language(CALL "${functionName}" "${_rid}")
        endforeach ()

    elseif (iterType STREQUAL "HANDLE")
        get_property(_type GLOBAL PROPERTY "${hndlValue}_TYPE")
        if (_type STREQUAL "MAP")
            get_property(_keys GLOBAL PROPERTY "${hndlValue}_KEYS")
            foreach (_k IN LISTS _keys)
                get_property(_isH GLOBAL PROPERTY "${hndlValue}_K_${_k}_ISHANDLE")
                if (_isH)
                    get_property(_hv GLOBAL PROPERTY "${hndlValue}_K_${_k}")
                    cmake_language(CALL "${functionName}" "${_hv}")
                endif ()
            endforeach ()
        else ()
            msg(AUTHOR_WARNING "FOREACH(HANDLE ...): Not implemented for type '${_type}'")
        endif ()

    elseif (iterType STREQUAL "KEY")
        get_property(_type GLOBAL PROPERTY "${hndlValue}_TYPE")
        if (_type STREQUAL "MAP")
            get_property(_keys GLOBAL PROPERTY "${hndlValue}_KEYS")
            foreach (_k IN LISTS _keys)
                get_property(_raw GLOBAL PROPERTY "${hndlValue}_K_${_k}")
                _hs_sql_field_to_user(_raw _kval)
                cmake_language(CALL "${functionName}" "${_k}" "${_kval}")
            endforeach ()
        else ()
            msg(ALWAYS FATAL_ERROR "FOREACH(KEY ...): Only supported for MAP, got '${_type}'")
        endif ()

    else ()
        msg(ALWAYS FATAL_ERROR "SQL_FOREACH: expected ROW, HANDLE, or KEY, got '${iterType}'")
    endif ()
endfunction()