include_guard(GLOBAL)

# --------------------------------------------------------------------------------------------------
# Data Hygiene & Encoding Logic
# --------------------------------------------------------------------------------------------------

# Encodes a string field: replaces empty strings with a sentinel to avoid property deletion.
function(_hs_sql_field_to_storage inVal outVar)
    # message(STATUS "DEBUG: _hs_sql_field_to_storage inVal='${inVal}' outVar='${outVar}'")

    if ("${inVal}" STREQUAL "")
        set(${outVar} "[[EMPTY_SENTINEL]]" PARENT_SCOPE)
    else ()
        set(${outVar} "${inVal}" PARENT_SCOPE)
    endif ()
endfunction()

# Decodes a string field: replaces the sentinel back with an actual empty string.
function(_hs_sql_field_to_user inVal outVar)
    set(_v "${inVal}")
    if (ARGC GREATER 1)
        list(GET ARGV -1 outVar)
        if (ARGC GREATER 2)
            set(_v "${ARGV}")
            list(REMOVE_AT _v -1)
        endif ()
    endif ()

    if ("${_v}" STREQUAL "[[EMPTY_SENTINEL]]" OR NOT DEFINED _v)
        set(${outVar} "" PARENT_SCOPE)
    else ()
        set(${outVar} "${_v}" PARENT_SCOPE)
    endif ()
endfunction()

# Decodes a string field: replaces the sentinel back with an actual empty string.
function(_hs_sql_fields_to_user inVal outVar)
    set(options "")
    set(args "")
    set(lists "")
    cmake_parse_arguments(_hs_sql_fields_to_user "${options}" "${args}" "${lists}" ${ARGV})
    set(inVal ${_hs_sql_fields_to_user_UNPARSED_ARGUMENTS_0})
    set(outVar ${_hs_sql_fields_to_user_UNPARSED_ARGUMENTS_1})

    string(REPLACE "[[EMPTY_SENTINEL]]" "" _done "${inVal}")
    set("${outVar}" "${_done}" PARENT_SCOPE)
endfunction()

# Encodes a CMake list for storage: replaces list separators (;) with a safe alternative.
function(_hs_sql_list_to_record inList outVar)
    string(REPLACE ";" "[[LIST_SEP]]" _encoded "${${inList}}")
#    _hs_sql_field_to_storage("${_encoded}" _final)
    set(${outVar} "${_encoded}" PARENT_SCOPE)
endfunction()

# Decodes a record from storage back into a CMake list.
function(_hs_sql_record_to_list inRec outVar)
    set(_v "${inRec}")
    if (ARGC GREATER 1)
        list(GET ARGV -1 outVar)
        if (ARGC GREATER 2)
            set(_v "${ARGV}")
            list(REMOVE_AT _v -1)
        endif ()
    endif ()

    _hs_sql_field_to_user("${_v}" _decoded)
    string(REPLACE "[[LIST_SEP]]" ";" _final "${_decoded}")
    set(${outVar} "${_final}" PARENT_SCOPE)
endfunction()

# Internal Helper: Right-padded string
function(_hs_pad_string text width outVar)
    set(options "")
    set(args "")
    set(lists "")
    cmake_parse_arguments(_hs_pad_string "${options}" "${args}" "${lists}" ${ARGV})
    set(text ${_hs_pad_string_UNPARSED_ARGUMENTS_0})
    set(width ${_hs_pad_string_UNPARSED_ARGUMENTS_1})
    set(outVar ${_hs_pad_string_UNPARSED_ARGUMENTS_2})

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
    _hs_sql_record_to_list("${_encCols}" _cols)
    get_property(_nextID GLOBAL PROPERTY "${hndl}_NEXT_ROWID")

    # If values is passed as a quoted list, it might be the first item in a larger list
    # but here we expect the list itself.
    set(_vList ${values})
    # message(STATUS "DEBUG: _hs_sql_internal_insert hndl=${hndl} _vList='${_vList}'")
    set(_vIdx 0)
    list(LENGTH _vList _vLen)
    foreach (_c IN LISTS _cols)
        if (_vIdx LESS _vLen)
            list(GET _vList ${_vIdx} _curVal)
        else ()
            set(_curVal "")
        endif ()
        _hs_sql_field_to_storage("${_curVal}" _v)
        # message(STATUS "DEBUG: Setting PROPERTY ${hndl}_R${_nextID}_${_c} TO ${_v}")
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

macro(_hs_sql_resolve_handle varName outHndl)
    if (NOT "${varName}" STREQUAL "")
        set(_input "${${varName}}")
        if (NOT DEFINED "${varName}")
            # If the variable is not defined, maybe the input itself is a label
            set(_input "${varName}")
        endif ()

        # 1. Check if it's already a handle
        get_property(_exists GLOBAL PROPERTY "${_input}_TYPE" SET)
        if (_exists)
            set(${outHndl} "${_input}")
        else ()
            # 2. Check if it's a label
            get_property(_hndl GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_input}")
            if (_hndl)
                set(${outHndl} "${_hndl}")
            else ()
                message(FATAL_ERROR "SQL Error: '${varName}' (value: '${_input}') is neither a valid SQL handle nor a registered table name.")
            endif ()
        endif ()
    else ()
        set(${outHndl} "")
    endif ()
endmacro()

macro(_hs_sql_check_readonly hndl)
    get_property(_t GLOBAL PROPERTY "${hndl}_TYPE")
    if (_t MATCHES "VIEW$")
        message(FATAL_ERROR "SQL Error: Cannot mutate VIEW '${hndl}'. Views are read-only.")
    endif ()
endmacro()

# --------------------------------------------------------------------------------------------------
# Nope # Replace "( this is a list )" with "this;is;a;list"
# Nope # Correctly handles joined args like "(this is a list)"
# Nope # If no "(" and no ")", returns entire inList as outList and remainder ""
# Nope # If "(" but not ")" and vice versa, throw FATAL_ERROR

#function(_repair_arg_list inList outList)
#    foreach (_thing IN LISTS ${inList})
#
#        # Find first and last characters of the current token
#        if (_thing STREQUAL "(" OR _thing STREQUAL ")")
#            list(APPEND _fixed ${_thing})
#            continue()
#        endif ()
#
#        string(SUBSTRING ${_thing} 0 1 _first)
#        string(LENGTH ${_thing} _len)
#        math(EXPR _last "${_len} - 1")
#        string(SUBSTRING ${_thing} ${_last} 1 _final)
#        string(REPLACE "(" "" _thing "${_thing}")
#        string(REPLACE ")" "" _thing "${_thing}")
#
#        if (_first STREQUAL "(")
#            list(APPEND _fixed "(")
#        endif ()
#
#        list(APPEND _fixed "${_thing}")
#
#        if (_final STREQUAL ")")
#            list(APPEND _fixed ")")
#        endif ()
#
#    endforeach ()
#
#    set(${outList} "${_fixed}" PARENT_SCOPE)
#
#endfunction()
function(_parse_expression expr output)

    if(NOT expr)
        return()
    endif()

    # Track whether THIS call is the top-level entry point
    if(ARGC GREATER_EQUAL 3)
        set(_depth ${ARGV2})
        set(_top_level OFF)
    else()
        set(_depth 0)
        set(_top_level ON)
        # Initialize the cache accumulator fresh
        set(_PARSE_PAREN_ACCUMULATOR "" CACHE INTERNAL "")
    endif()

    set(_balance 0)
    unset(_expr)
    unset(_subexpr)

    separate_arguments(_fixed NATIVE_COMMAND "${expr}")

    unset(_z)
    foreach(_x IN LISTS _fixed)
        foreach(_y IN LISTS _x)
            list(APPEND _z ${_y})
        endforeach()
    endforeach()
    set(expr ${_z})

    set(_writing_into_subexpr)
    foreach(_token IN LISTS expr)
        if(_token STREQUAL "(")
            if(_balance EQUAL 0)
                list(APPEND _expr "[[SUBEXPR_${_depth}]]")
                set(_writing_into_subexpr ON)
                math(EXPR _balance "${_balance} + 1")
                continue()
            endif()
            math(EXPR _balance "${_balance} + 1")
        elseif(_token STREQUAL ")")
            math(EXPR _balance "${_balance} - 1")
            if(_balance EQUAL 0)
                set(_writing_into_subexpr OFF)
                continue()
            endif()
        endif()
        if(_writing_into_subexpr)
            list(APPEND _subexpr ${_token})
        else()
            list(APPEND _expr ${_token})
        endif()
    endforeach()

    if(_balance)
        message(FATAL_ERROR "Unbalanced parenthesis in statement \"${expr}\"")
    endif()

    # Serialize outer expression and append to accumulator
    _hs_sql_list_to_record(_expr _Xexpr)

    # Read fresh from cache, never from local scope
    set(_current "$CACHE{_PARSE_PAREN_ACCUMULATOR}")
    list(APPEND _current "${_Xexpr}")
    set(_PARSE_PAREN_ACCUMULATOR "${_current}" CACHE INTERNAL "")

    # Recurse into subexpression
    if(_subexpr)
        math(EXPR _depth "${_depth} + 1")
        _parse_expression("${_subexpr}" ${output} ${_depth})
    endif()

    # Only the original top-level call writes result back to caller
    if(_top_level)
        set("${output}" "$CACHE{_PARSE_PAREN_ACCUMULATOR}" PARENT_SCOPE)
        unset(_PARSE_PAREN_ACCUMULATOR CACHE)
    endif()

endfunction()

macro(_fix_ooo)
    foreach(_singleton IN LISTS ooo)
        if(DEFINED ${CMAKE_CURRENT_FUNCTION}_${singleton})
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
    _parse_expression("${ARGN}" result)
    # log(LISTS result)

    set(options TABLE VIEW MATERIALIZED_VIEW MAP SHEET)
    set(args INTO)
    set(lists COLUMNS ROWS)
    cmake_parse_arguments(CREATE "${options}" "${args}" "${lists}" ${ARGN})

    foreach(_singleton IN LISTS options)
        if(CREATE_${_singleton})
            set(CREATE_TYPE ${_singleton})
            break()
        endif ()
    endforeach ()

    if(NOT CREATE_TYPE)
         message(FATAL_ERROR "CREATE: No type (TABLE, SHEET, MAP, etc.) specified. ARGN: ${ARGN}")
    endif()

    # The new syntax: CREATE(TABLE name ...)
    # name should be in CREATE_UNPARSED_ARGUMENTS[0]
    list(GET CREATE_UNPARSED_ARGUMENTS 0 _label)

    if(NOT _label)
        message(FATAL_ERROR "CREATE: No table name specified. ARGN: ${ARGN}")
    endif()

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
            message(AUTHOR_WARNING "SQL Warning: Label '${_label}' is already in use by handle '${_prev}'. Overwriting with '${_resolvedHndl}'.")
        endif ()
        set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_label}" "${_resolvedHndl}")
    endif ()

    set(_cols "${CREATE_COLUMNS}")
    set(_rows "${CREATE_ROWS}")
    set(_members "${CREATE_FROM}")

    if (CREATE_TABLE OR CREATE_SHEET)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "TABLE")
        _hs_sql_field_to_storage("${_label}" _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")
        _hs_sql_list_to_record(_cols _encCols)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_encCols}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_NAMES" "")

        if (_rows)
            foreach (_rname IN LISTS _rows)
                get_property(_nextID GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID")
                # Initialize empty row
                set(_rowVals "")
                foreach (_c IN LISTS _cols)
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
        _hs_sql_field_to_storage("${_label}" _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")
        _hs_sql_list_to_record("${_members}" _encMems)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_MEMBERS" "${_encMems}")

    elseif (CREATE_MATERIALIZED_VIEW)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "MATERIALIZED_VIEW")
        _hs_sql_field_to_storage("${_label}" _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")

        # 1. Schema Merging: Combine columns from all sources
        set(_allCols "")
        foreach (_m IN LISTS _members)
            get_property(_mc GLOBAL PROPERTY "${_m}_COLUMNS")
            list(APPEND _allCols ${_mc})
        endforeach ()
        list(REMOVE_DUPLICATES _allCols)
        _hs_sql_list_to_record("${_allCols}" _encCols)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_encCols}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)

        # 2. Snapshot: Physically copy data
        foreach (_m IN LISTS _members)
            get_property(_mEncIDs GLOBAL PROPERTY "${_m}_ROWIDS")
            _hs_sql_record_to_list("${_mEncIDs}" _mIDs)
            get_property(_mEncCols GLOBAL PROPERTY "${_m}_COLUMNS")
            _hs_sql_record_to_list("${_mEncCols}" _mCols)

            foreach (_rid IN LISTS _mIDs)
                set(_rowVals "")
                foreach (_c IN LISTS _allCols)
                    if (_c IN_LIST _mCols)
                        get_property(_vEnc GLOBAL PROPERTY "${_m}_R${_rid}_${_c}")
                        _hs_sql_field_to_user("${_vEnc}" _v)
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
        _hs_sql_field_to_storage("${_label}" _encLabel)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_encLabel}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_KEYS" "")
    else ()
        message(ALWAYS FATAL_ERROR "CREATE :- Don't know how to create object, use TABLE, VIEW, MATERIALIZED_VIEW or MAP options")
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# DML: INSERT & UPDATE
# --------------------------------------------------------------------------------------------------
function(INSERT)
    set(options "INTO")
    set(args "AS;KEY;VALUE;HANDLE;TABLE;ROW")
    set(lists "VALUES")
    cmake_parse_arguments(INSERT "${options}" "${args}" "${lists}" ${ARGV})
    set(tableVarName ${INSERT_TABLE})

    if (NOT tableVarName)
        list(GET INSERT_UNPARSED_ARGUMENTS 0 tableVarName)
    endif ()

    _hs_sql_resolve_handle("${tableVarName}" _h)
    _hs_sql_check_readonly(${_h})
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    if (_type STREQUAL "MAP")
        set(_key "${INSERT_KEY}")
        set(_val "${INSERT_VALUE}")
        set(_isH FALSE)
        if (INSERT_HANDLE)
            _hs_sql_resolve_handle("${INSERT_HANDLE}" _val)
            set(_isH TRUE)
        endif ()

        get_property(_exists GLOBAL PROPERTY "${_h}_K_${_key}" SET)
        if (_exists)
            message(FATAL_ERROR "SQL Error: Key '${_key}' exists. Use UPDATE.")
        endif ()
        _hs_sql_field_to_storage("${_val}" _encVal)
        set_property(GLOBAL PROPERTY "${_h}_K_${_key}" "${_encVal}")
        set_property(GLOBAL PROPERTY "${_h}_K_${_key}_ISHANDLE" ${_isH})
        set_property(GLOBAL APPEND PROPERTY "${_h}_KEYS" "${_key}")

    else () # TABLE logic
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list("${_encCols}" _cols)
        get_property(_nextID GLOBAL PROPERTY "${_h}_NEXT_ROWID")

        set(_values ${INSERT_VALUES})
        if (NOT _values)
            set(_values ${INSERT_UNPARSED_ARGUMENTS})
            if (NOT INSERT_TABLE)
                list(REMOVE_AT _values 0) # remove tableVarName
            endif ()
        endif ()

        _hs_sql_internal_insert("${_h}" "${_values}")
        
        if (INSERT_ROW)
            set_property(GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${INSERT_ROW}" "${_nextID}")
            set_property(GLOBAL PROPERTY "${_h}_ROWID_TO_NAME_${_nextID}" "${INSERT_ROW}")
            set_property(GLOBAL APPEND PROPERTY "${_h}_ROW_NAMES" "${INSERT_ROW}")
        endif ()
    endif ()
endfunction()

function(UPDATE)
    set(options "")
    set(args "KEY;VALUE;HANDLE;COLUMN;SET;ROWID;TABLE;ROW;LABEL;AS")
    set(lists "ROWID_NAMES;ROWNAME_LIST;ROWNAMES")
    cmake_parse_arguments(UPDATE "${options}" "${args}" "${lists}" ${ARGV})
    set(tableVarName ${UPDATE_TABLE})

    if (NOT tableVarName)
        list(GET UPDATE_UNPARSED_ARGUMENTS 0 tableVarName)
    endif ()

    _hs_sql_resolve_handle("${tableVarName}" _h)
    _hs_sql_check_readonly(${_h})
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    if (_type STREQUAL "MAP")
        # Logic same as INSERT but without existence check
        set(_key "${UPDATE_KEY}")
        if (UPDATE_VALUE)
            _hs_sql_field_to_storage("${UPDATE_VALUE}" _encVal)
            set_property(GLOBAL PROPERTY "${_h}_K_${_key}" "${_encVal}")
            set_property(GLOBAL PROPERTY "${_h}_K_${_key}_ISHANDLE" FALSE)
        elseif (UPDATE_HANDLE)
            _hs_sql_resolve_handle("${UPDATE_HANDLE}" _hndl)
            set_property(GLOBAL PROPERTY "${_h}_K_${_key}" "${_hndl}")
            set_property(GLOBAL PROPERTY "${_h}_K_${_key}_ISHANDLE" TRUE)
        endif ()
    else () # TABLE logic
        if (UPDATE_ROWID_NAMES OR UPDATE_ROWNAME_LIST OR UPDATE_ROWNAMES)
            set(_names ${UPDATE_ROWID_NAMES} ${UPDATE_ROWNAME_LIST} ${UPDATE_ROWNAMES})
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

        if (UPDATE_LABEL OR UPDATE_AS)
            set(_newLabel "${UPDATE_LABEL}${UPDATE_AS}")
            # Get old label
            get_property(_oldEncLabel GLOBAL PROPERTY "${_h}_LABEL")
            _hs_sql_field_to_user("${_oldEncLabel}" _oldLabel)
            
            # Remove old mapping if it points to this handle
            get_property(_oldHndl GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_oldLabel}")
            if ("${_oldHndl}" STREQUAL "${_h}")
                set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_oldLabel}" "")
            endif ()
            
            # Add new mapping
            _hs_sql_field_to_storage("${_newLabel}" _newEncLabel)
            set_property(GLOBAL PROPERTY "${_h}_LABEL" "${_newEncLabel}")
            
            get_property(_prev GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_newLabel}")
            if (_prev AND NOT "${_prev}" STREQUAL "${_h}")
                message(AUTHOR_WARNING "SQL Warning: Label '${_newLabel}' is already in use by handle '${_prev}'. Overwriting with '${_h}'.")
            endif ()
            
            set_property(GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_newLabel}" "${_h}")
            return()
        endif ()

        set(_col "${UPDATE_COLUMN}")
        set(_val "${UPDATE_SET}")
        set(_rid "${UPDATE_ROWID}")

        if (NOT _rid AND UPDATE_ROW)
            get_property(_rid GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${UPDATE_ROW}")
        endif ()

        if (_h AND _rid AND _col)
            _hs_sql_field_to_storage("${_val}" _enc)
            set_property(GLOBAL PROPERTY "${_h}_R${_rid}_${_col}" "${_enc}")
        else ()
            message(FATAL_ERROR "SQL UPDATE: Missing required parameters (Target: ${_h}, Row: ${_rid}, Col: ${_col})")
        endif ()

    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# DQL: SELECT
# --------------------------------------------------------------------------------------------------
function(SELECT)
    set(options "VALUE;HANDLE;COUNT;ROW")
    set(args "FROM;INTO;ROWID;INDEX;COLUMN;NAME;KEY;LIKE;VALUES")
    set(lists "")
    # Check for * in arguments and replace with a placeholder to avoid expansion
    set(_processed_argv "")
    foreach(_arg IN LISTS ARGV)
        if ("${_arg}" STREQUAL "*")
            list(APPEND _processed_argv "[[STAR]]")
            set(SELECT_STAR TRUE)
        else()
            list(APPEND _processed_argv "${_arg}")
        endif()
    endforeach()
    cmake_parse_arguments(SELECT "${options}" "${args}" "${lists}" ${_processed_argv})

    if (SELECT_INTO)
        set(_intoVar "${SELECT_INTO}")
    else ()
        list(GET ARGV -1 _intoVar)
    endif ()

    if (SELECT_FROM)
        _hs_sql_resolve_handle("${SELECT_FROM}" _h)
    else ()
        # Try to find 'FROM <handle>' in ARGV
        list(FIND ARGV "FROM" _fromIdx)
        if (NOT _fromIdx EQUAL -1)
            math(EXPR _hIdx "${_fromIdx} + 1")
            list(GET ARGV ${_hIdx} _fromHandleVar)
            _hs_sql_resolve_handle("${_fromHandleVar}" _h)
        else()
             # Fallback for when FROM keyword is missing but handle is provided positionally
             # We need to find something that LOOKS like a handle or a label
             foreach(_arg IN LISTS ARGV)
                 if (NOT _arg MATCHES "^(SELECT|VALUE|HANDLE|COUNT|ROW|COLUMN|INTO|ROWID|INDEX|NAME|KEY|LIKE|VALUES)$")
                     if (DEFINED "${_arg}")
                         set(_h_try "${${_arg}}")
                     else ()
                         set(_h_try "${_arg}")
                     endif ()
                     get_property(_exists GLOBAL PROPERTY "${_h_try}_TYPE" SET)
                     if (_exists)
                         set(_h "${_h_try}")
                         break()
                     endif ()
                     get_property(_h_label GLOBAL PROPERTY "HS_LABEL_TO_HNDL_${_h_try}")
                     if (_h_label)
                         set(_h "${_h_label}")
                         break()
                     endif ()
                 endif ()
             endforeach ()
        endif()
    endif ()

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    if (SELECT_HANDLE)
        if (_h)
            set(${_intoVar} "${_h}" PARENT_SCOPE)
            return()
        endif()
    endif()

    if (_type STREQUAL "MAP")
        if (SELECT_NAME)
            set(_targetKey "${SELECT_NAME}")
        elseif (SELECT_KEY)
            set(_targetKey "${SELECT_KEY}")
        else ()
            set(_targetKey "")
            # Try to find key in unparsed arguments
            foreach(_arg IN LISTS SELECT_UNPARSED_ARGUMENTS)
                if (NOT _arg STREQUAL "${_intoVar}" AND NOT _arg STREQUAL "${SELECT_FROM}" AND NOT _arg STREQUAL "${_h}")
                    set(_targetKey "${_arg}")
                    break()
                endif()
            endforeach()

            if (NOT _targetKey)
                set(_i 1)
                while (_i LESS ARGC)
                    if ("${ARGV${_i}}" MATCHES "^(NAME|KEY)$")
                        math(EXPR _i "${_i} + 1")
                        if ("${ARGV${_i}}" STREQUAL "=")
                            math(EXPR _i "${_i} + 1")
                        endif ()
                        set(_targetKey "${ARGV${_i}}")
                    endif ()
                    math(EXPR _i "${_i} + 1")
                endwhile ()
            endif()
        endif ()
        get_property(_raw GLOBAL PROPERTY "${_h}_K_${_targetKey}")
        _hs_sql_field_to_user("${_raw}" _final)
        set(${_intoVar} "${_final}" PARENT_SCOPE)
        return()
    endif ()

    if (_type STREQUAL "VIEW")
        get_property(_encMems GLOBAL PROPERTY "${_h}_MEMBERS")
        _hs_sql_record_to_list("${_encMems}" _members)
        set(_res "")
        set(_last "")

        set(_args ${ARGV})
        # Attempt to remove INTO and its value if they were at the end
        list(GET _args -2 _penultimate)
        if (_penultimate STREQUAL "INTO")
            list(REMOVE_AT _args -1 -2)
        else ()
            list(REMOVE_AT _args -1)
        endif ()
        # Remove the handle if it was positional (usually ARGV1)
        if (NOT SELECT_FROM)
            list(REMOVE_AT _args 1)
        endif ()

        foreach (_m IN LISTS _members)
            set(_mVar "_v_${_m}")
            set(${_mVar} "${_m}")
            SELECT(${_args} FROM _m INTO _sub)
            if (_sub)
                list(APPEND _res "${_sub}")
                set(_last "${_sub}")
            endif ()
        endforeach ()
        list(LENGTH _res _matches)
        if (_matches EQUAL 1)
            set(${_intoVar} "${_last}" PARENT_SCOPE)
        else ()
            set(${_intoVar} "${_res}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # TABLE Logic
    set(_whereCols "")
    set(_whereOps "")
    set(_whereVals "")
    set(_tRow "")
    set(_tCol "")

    get_property(_encIDs GLOBAL PROPERTY "${_h}_ROWIDS")
    _hs_sql_record_to_list("${_encIDs}" _ids)

    if (SELECT_ROWID)
        set(_tRow "${SELECT_ROWID}")
    elseif (SELECT_INDEX)
        set(_tRow "${SELECT_INDEX}")
    endif ()

    if (SELECT_COLUMN)
        set(_tCol "${SELECT_COLUMN}")
    endif ()

    # Fallback to manual parsing for WHERE clauses if not covered by basic keywords
    set(_i 1)
    while (_i LESS ARGC)
        set(_curr "${ARGV${_i}}")
        if ("${_curr}" MATCHES "^(ROWID|INDEX)$")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
            endif ()
            set(_tRow "${ARGV${_i}}")
        elseif ("${_curr}" STREQUAL "ROW")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
            endif ()
            set(_rowName "${ARGV${_i}}")
            get_property(_rid GLOBAL PROPERTY "${_h}_ROWNAME_TO_ID_${_rowName}")
            if (_rid)
                set(_tRow "${_rid}")
            else ()
                set(_tRow "${_rowName}")
            endif ()
        elseif ("${_curr}" STREQUAL "COLUMN")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
                set(_tCol "${ARGV${_i}}")
            else ()
                set(_cName "${ARGV${_i}}")
                math(EXPR _i "${_i} + 1")
                if ("${ARGV${_i}}" MATCHES "^(=|LIKE)$")
                    list(APPEND _whereCols "${_cName}")
                    list(APPEND _whereOps "${ARGV${_i}}")
                    math(EXPR _i "${_i} + 1")
                    list(APPEND _whereVals "${ARGV${_i}}")
                else ()
                    set(_tCol "${_cName}")
                    math(EXPR _i "${_i} - 1")
                endif ()
            endif ()
        elseif ("${_curr}" STREQUAL "WHERE")
             # Skip WHERE, the next part should be ROW = or COL =
             # If it's COLUMN =, the loop will handle it.
             # If it's something else like Name = Alice, we need to handle it.
             math(EXPR _nextIdx "${_i} + 1")
             list(GET ARGV ${_nextIdx} _next)
             if (NOT "${_next}" MATCHES "^(ROW|COLUMN)$")
                 # This is likely a column filter like Name = Alice
                 list(APPEND _whereCols "${_next}")
                 math(EXPR _i "${_i} + 1") # Point to Name
                 math(EXPR _i "${_i} + 1") # Point to =
                 list(GET ARGV ${_i} _op)
                 list(APPEND _whereOps "${_op}")
                 math(EXPR _i "${_i} + 1") # Point to Alice
                 list(GET ARGV ${_i} _val)
                 list(APPEND _whereVals "${_val}")
             endif ()
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    if (SELECT_VALUES)
        # Handle multiple values (columns) for a single row
        # ARGV parsing for multiple columns after VALUES is tricky with manual loop.
        # But if we have SELECT_VALUES, it might just be the first one if we used set(args ... VALUES)
        # Actually cmake_parse_arguments only takes one value for an argument in 'args'.
        # Let's use 'lists' for VALUES.
    endif ()

    if (SELECT_STAR AND _tRow)
        CREATE(MAP "Row MAP" INTO _hMap)
        # Handle created in current scope, resolve it for use
        _hs_sql_resolve_handle(_hMap _hMapRes)
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list("${_encCols}" _allCols)
        foreach (_c IN LISTS _allCols)
            get_property(_raw GLOBAL PROPERTY "${_h}_R${_tRow}_${_c}")
            _hs_sql_field_to_user("${_raw}" _val)
            # Use MAP-specific insert logic
            _hs_sql_field_to_storage("${_val}" _encVal)
            set_property(GLOBAL PROPERTY "${_hMapRes}_K_${_c}" "${_encVal}")
            set_property(GLOBAL PROPERTY "${_hMapRes}_K_${_c}_ISHANDLE" FALSE)
            set_property(GLOBAL APPEND PROPERTY "${_hMapRes}_KEYS" "${_c}")
        endforeach ()
        set(${_intoVar} "${_hMapRes}" PARENT_SCOPE)
        return()
    endif ()

    if (SELECT_ROW AND NOT SELECT_VALUE AND NOT SELECT_HANDLE AND NOT SELECT_STAR)
        get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list("${_encCols}" _allCols)
        set(_rowList "")
        foreach (_c IN LISTS _allCols)
            get_property(_raw GLOBAL PROPERTY "${_h}_R${_tRow}_${_c}")
            _hs_sql_field_to_user("${_raw}" _val)
            list(APPEND _rowList "${_val}")
        endforeach ()
        set(${_intoVar} "${_rowList}" PARENT_SCOPE)
        return()
    endif ()

    if ((SELECT_VALUE OR SELECT_HANDLE OR SELECT_ROW) AND _tRow)
        # Try to find column name from unparsed args if _tCol is empty
        if (NOT _tCol AND NOT SELECT_ROW)
             # Get all column names to check against unparsed args
             get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
             _hs_sql_record_to_list("${_encCols}" _allCols)
             
             foreach(_arg IN LISTS SELECT_UNPARSED_ARGUMENTS)
                 if (NOT _arg STREQUAL "${_intoVar}" AND NOT _arg STREQUAL "${SELECT_FROM}" AND NOT _arg STREQUAL "${_h}" AND NOT _arg STREQUAL "[[STAR]]" AND NOT _arg STREQUAL "WHERE" AND NOT _arg STREQUAL "=")
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
            _hs_sql_field_to_user("${_raw}" _final)
            set(${_intoVar} "${_final}" PARENT_SCOPE)
            return()
        endif ()
    endif ()


    # B. Restored Multi-row Filtering Logic (SELECT * / SELECT COUNT)
    get_property(_encIDs GLOBAL PROPERTY "${_h}_ROWIDS")
    _hs_sql_record_to_list("${_encIDs}" _ids)
    get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
    _hs_sql_record_to_list("${_encCols}" _allCols)

    set(_matches "")
    set(_matched_column_name "")

    foreach (_rid IN LISTS _ids)
        set(_rowPass TRUE)
        list(LENGTH _whereCols _filterCount)
        if (_filterCount GREATER 0)
            math(EXPR _maxF "${_filterCount} - 1")
            foreach (_fIdx RANGE ${_maxF})
                list(GET _whereCols ${_fIdx} _fCol)
                list(GET _whereOps ${_fIdx} _fOp)
                list(GET _whereVals ${_fIdx} _fVal)
                get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_fCol}")
                _hs_sql_field_to_user("${_val}" _actualVal)

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
            list(APPEND _matches "${_rid}")
            if (_fCol)
                list(APPEND _matched_column_name "${_fCol}")
            elseif (_tCol)
                list(APPEND _matched_column_name "${_tCol}")
            endif ()
        endif ()
    endforeach ()
    # --- C. Shape the Output ---
    if (SELECT_COUNT)
        list(LENGTH _matches _count)
        set(${_intoVar} "${_count}" PARENT_SCOPE)
        return()
    endif ()

    # If the user specifically asked for a VALUE (scalar string)
    if (SELECT_VALUE OR SELECT_HANDLE)
        list(LENGTH _matches _matchCount)
        if (_matchCount GREATER 0)
            # Return the value from the first matching row
            list(GET _matches 0 _firstID)

            if (NOT _tCol)
                 # Try to find column name from unparsed args
                 get_property(_encCols GLOBAL PROPERTY "${_h}_COLUMNS")
                 _hs_sql_record_to_list("${_encCols}" _allCols)
                 # message(STATUS "DEBUG: SELECT matching column from unparsed. _allCols='${_allCols}' unparsed='${SELECT_UNPARSED_ARGUMENTS}'")
                 
                 foreach(_arg IN LISTS SELECT_UNPARSED_ARGUMENTS)
                     if (NOT _arg STREQUAL "${_intoVar}" AND NOT _arg STREQUAL "${SELECT_FROM}" AND NOT _arg STREQUAL "${_h}" AND NOT _arg STREQUAL "[[STAR]]" AND NOT _arg STREQUAL "WHERE" AND NOT _arg STREQUAL "=")
                         # Check if it's a valid column name
                         list(FIND _allCols "${_arg}" _isCol)
                         if (NOT _isCol EQUAL -1)
                             set(_tCol "${_arg}")
                             break()
                         endif ()
                     endif ()
                 endforeach ()
            endif ()

            if (_tCol)
                get_property(_val GLOBAL PROPERTY "${_h}_R${_firstID}_${_tCol}")
                _hs_sql_field_to_user("${_val}" _final_result)
                set(${_intoVar} "${_final_result}" PARENT_SCOPE)
            else ()
                # If no column specified, maybe return first column? 
                # Or just empty.
                set(${_intoVar} "" PARENT_SCOPE)
            endif ()
        else ()
            # No rows matched: return empty string
            set(${_intoVar} "" PARENT_SCOPE)
        endif ()
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
        _hs_sql_record_to_list("${_encCols}" _allCols)

        foreach (_col IN LISTS _allCols)
            get_property(_v GLOBAL PROPERTY "${_h}_R${_targetRow}_${_col}")
            #            _hs_sql_field_to_user("${_v}" _v)
            list(APPEND _rowList "${_v}")
        endforeach ()

        set(${_intoVar} "${_rowList}" PARENT_SCOPE)
        return()
    endif ()

    # --- D. Default: Return a result set (New Table Handle) ---
    CREATE(TABLE "result_set" COLUMNS "${_allCols}" INTO _tmpRes)
    foreach (_mID IN LISTS _matches)
        set(_rowValues "")
        foreach (_col IN LISTS _allCols)
            get_property(_val GLOBAL PROPERTY "${_h}_R${_mID}_${_col}")
            list(APPEND _rowValues "${_val}")
        endforeach ()
        INSERT(INTO _tmpRes VALUES ${_rowValues})
    endforeach ()

    set(${_intoVar} "${_tmpRes}" PARENT_SCOPE)
endfunction()

# --------------------------------------------------------------------------------------------------
# DML: DELETE
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

    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_raw GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user("${_raw}" _final)
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

    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_raw GLOBAL PROPERTY "${_h}_COLUMNS")
    _hs_sql_record_to_list("${_raw}" _final)
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

    _hs_sql_resolve_handle(${handleVarName} _h)
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

    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    get_property(_rawLabel GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user("${_rawLabel}" _label)

    message("Object: ${_label}")
    message("Type:   ${_type}")

    if (_type STREQUAL "TABLE" OR _type STREQUAL "MATERIALIZED_VIEW")
        get_property(_rawCols GLOBAL PROPERTY "${_h}_COLUMNS")
        _hs_sql_record_to_list("${_rawCols}" _cols)
        get_property(_count GLOBAL PROPERTY "${_h}_ROW_COUNT")
        message("Rows:   ${_count}")
        message("Cols:   ${_cols}")
    elseif (_type STREQUAL "VIEW")
        get_property(_rawMems GLOBAL PROPERTY "${_h}_MEMBERS")
        _hs_sql_record_to_list("${_rawMems}" _mems)
        message("Source Members: ${_mems}")
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

    _hs_sql_resolve_handle(${handleVarName} _h)
    set(_expectedType "${ASSERT_TYPE}")
    set(_expectedCount "${ASSERT_COUNT}")

    if (_expectedType)
        get_property(_actualType GLOBAL PROPERTY "${_h}_TYPE")
        if (NOT "${_actualType}" STREQUAL "${_expectedType}")
            message(FATAL_ERROR "ASSERT FAILED: Type is '${_actualType}', expected '${_expectedType}'")
        endif ()
    endif ()

    if (NOT "${_expectedCount}" STREQUAL "")
        get_property(_actualCount GLOBAL PROPERTY "${_h}_ROW_COUNT")
        if (NOT "${_actualCount}" EQUAL "${_expectedCount}")
            message(FATAL_ERROR "ASSERT FAILED: Count is ${_actualCount}, expected ${_expectedCount}")
        endif ()
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# Introspection: DUMP
# --------------------------------------------------------------------------------------------------
function(DUMP)
    set(options "VERBOSE;DEEP;FROM")
    set(args "INTO;DEPTH;HANDLE")
    set(lists "")
    cmake_parse_arguments(DUMP "${options}" "${args}" "${lists}" ${ARGV})
    set(handleVarName ${DUMP_HANDLE})

    if (NOT handleVarName)
        set(handleVarName ${DUMP_UNPARSED_ARGUMENTS_0})
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

    _hs_sql_resolve_handle(${handleVarName} _h)

    string(REPEAT "${_padding_str}" ${_depth} _offset_padding)
    if (_depth GREATER 1)
        set(_depth_note "\n\n${_offset_padding}Depth: ${_depth} ")
    endif ()

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    get_property(_encLabel GLOBAL PROPERTY "${_h}_LABEL")
    _hs_sql_field_to_user("${_encLabel}" _label)

    string(APPEND _out "${_depth_note}--- SQL DUMP: ${_label} (${_type}) [HANDLE: ${_h}] ---\n")

    # --- VIEW Logic (Show member pointers) ---
    if (_type STREQUAL "VIEW")
        get_property(_encMembers GLOBAL PROPERTY "${_h}_MEMBERS")
        _hs_sql_record_to_list("${_encMembers}" _members)
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
                _hs_sql_field_to_user("${_raw}" _v)
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
        _hs_sql_record_to_list("${_encCols}" _cols)
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
                    _hs_sql_field_to_user("${_encVal}" _val)
                    _hs_sql_record_to_list("${_val}" _valList)

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
                    _hs_sql_field_to_user("${_encVal}" _val)
                    _hs_sql_record_to_list("${_val}" _valList)
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
                        _hs_sql_field_to_user("${_encVal}" _val)
                        _hs_sql_record_to_list("${_val}" _valList)

                        # Apply GitHub domain omission for display
                        if (_val MATCHES "^https://github.com/(.*)")
                            set(_val "${CMAKE_MATCH_1}")
                        endif ()
                        _hs_sql_field_to_user("${_val}" _maybe_blank)
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
        message("${_out}")
    endif ()
endfunction()
