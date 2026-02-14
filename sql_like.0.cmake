include_guard(GLOBAL)

# --------------------------------------------------------------------------------------------------
# Internal Infrastructure & Variable Resolution
# --------------------------------------------------------------------------------------------------
set_property(GLOBAL PROPERTY HS_NEXT_HNDL 1000)

set(lst_sep ";")
set(sql_sep "&&")
set(sql_efs "»«")

function(_hs_sql_field_to_storage _in _outVar)
    if ("${_in}" STREQUAL "")
        set(${_outVar} "${sql_efs}" PARENT_SCOPE)
    else ()
        string(REPLACE "${lst_sep}" "${sql_sep}" _escaped "${_in}")
        set(${_outVar} "${_escaped}" PARENT_SCOPE)
    endif ()
endfunction()

function(_hs_sql_field_to_user _in _outVar)
    if ("${_in}" STREQUAL "${sql_efs}")
        set(${_outVar} "" PARENT_SCOPE)
    else ()
        # Undo escaping applied in _hs__field_to_storage
        string(REPLACE "${sql_sep}" "${lst_sep}" _unescaped "${_in}")
        set(${_outVar} "${_unescaped}" PARENT_SCOPE)
    endif ()
endfunction()

function(_hs_sql_record_to_list _rec _outVar)
    string(REPLACE "${sql_sep}" "${lst_sep}" _tmp "${_rec}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs_sql_list_to_record _lst _outVar)
    string(REPLACE "${lst_sep}" "${sql_sep}" _tmp "${_lst}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

macro(_hs_sql_generate_handle outVarName)
    get_property(_next GLOBAL PROPERTY HS_NEXT_HNDL)
    set(_newHndl "HS_HNDL_${_next}")
    math(EXPR _next "${_next} + 1")
    set_property(GLOBAL PROPERTY HS_NEXT_HNDL ${_next})
    set(${outVarName} "${_newHndl}" PARENT_SCOPE)
    set(_resolvedHndl "${_newHndl}")
endmacro()

macro(_hs_sql_resolve_handle varName outHndl)
    if (NOT DEFINED ${varName})
        message(FATAL_ERROR "SQL Error: Variable '${varName}' is not defined.")
    endif ()
    set(${outHndl} "${${varName}}")
    get_property(_exists GLOBAL PROPERTY "${${outHndl}}_TYPE" SET)
    if (NOT _exists)
        message(FATAL_ERROR "SQL Error: Variable '${varName}' contains '${${outHndl}}', which is not a valid SQL object.")
    endif ()
endmacro()

macro(_hs_sql_check_readonly hndl)
    get_property(_t GLOBAL PROPERTY "${hndl}_TYPE")
    if (_t STREQUAL "VIEW")
        message(FATAL_ERROR "SQL Error: Cannot mutate VIEW '${hndl}'. Views are read-only.")
    endif ()
endmacro()


# Internal Helper: Right-padded string
function(_hs_pad_string text width outVar)
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
# DDL: CREATE
# --------------------------------------------------------------------------------------------------
# --------------------------------------------------------------------------------------------------
# DDL: CREATE (Updated for VIEW)
# --------------------------------------------------------------------------------------------------
function(CREATE type outHandleVarName)
    _hs_sql_generate_handle(${outHandleVarName})

    set(_label "<unnamed>")
    set(_cols "")
    set(_members "")
    set(_i 2)
    while (_i LESS ARGC)
        if ("${ARGV${_i}}" STREQUAL "LABEL")
            math(EXPR _i "${_i} + 1")
            set(_label "${ARGV${_i}}")
        elseif ("${ARGV${_i}}" STREQUAL "COLUMNS")
            math(EXPR _i "${_i} + 1")
            set(_cols "${ARGV${_i}}")
        elseif ("${ARGV${_i}}" STREQUAL "FROM")
            math(EXPR _i "${_i} + 1")
            while (_i LESS ARGC AND NOT "${ARGV${_i}}" MATCHES "^(LABEL|COLUMNS)$")
                _hs_sql_resolve_handle("${ARGV${_i}}" _mHndl)
                list(APPEND _members "${_mHndl}")
                math(EXPR _i "${_i} + 1")
            endwhile ()
            math(EXPR _i "${_i} - 1")
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_label}")

    if (type STREQUAL "TABLE")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "TABLE")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_cols}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")

    elseif (type STREQUAL "VIEW")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "VIEW")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_MEMBERS" "${_members}")

    elseif (type STREQUAL "MATERIALIZED_VIEW")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "MATERIALIZED_VIEW")

        # 1. Schema Merging: Combine columns from all sources
        set(_allCols "")
        foreach (_m IN LISTS _members)
            get_property(_mc GLOBAL PROPERTY "${_m}_COLUMNS")
            list(APPEND _allCols ${_mc})
        endforeach ()
        list(REMOVE_DUPLICATES _allCols)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_allCols}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)

        # 2. Snapshot: Physically copy data
        foreach (_m IN LISTS _members)
            get_property(_mIDs GLOBAL PROPERTY "${_m}_ROWIDS")
            get_property(_mCols GLOBAL PROPERTY "${_m}_COLUMNS")
            foreach (_rid IN LISTS _mIDs)
                set(_rowVals "")
                foreach (_c IN LISTS _allCols)
                    if (_c IN_LIST _mCols)
                        get_property(_v GLOBAL PROPERTY "${_m}_R${_rid}_${_c}")
                        list(APPEND _rowVals "${_v}")
                    else ()
                        list(APPEND _rowVals "")
                    endif ()
                endforeach ()
                # Use internal insert to bypass read-only check
                _hs_sql_internal_insert("${_resolvedHndl}" "${_rowVals}")
            endforeach ()
        endforeach ()

    elseif (type STREQUAL "DICT")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "DICT")
    endif ()

endfunction()

# --------------------------------------------------------------------------------------------------
# DML: INSERT, UPDATE, DELETE
# --------------------------------------------------------------------------------------------------
function(INSERT kw tableVarName)
    _hs_sql_resolve_handle(${tableVarName} _h)
    _hs_sql_check_readonly(${_h})
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # --- DICT INSERT LOGIC ---
    if (_type STREQUAL "DICT")
        set(_key "")
        set(_val "")
        set(_isHandle FALSE)

        # Parse Dictionary arguments
        set(_i 2)
        while (_i LESS ARGC)
            set(_cur "${ARGV${_i}}")
            if (_cur STREQUAL "KEY")
                math(EXPR _i "${_i} + 1")
                set(_key "${ARGV${_i}}")
            elseif (_cur STREQUAL "VALUE")
                math(EXPR _i "${_i} + 1")
                set(_val "${ARGV${_i}}")
                set(_isHandle FALSE)
            elseif (_cur STREQUAL "HANDLE")
                math(EXPR _i "${_i} + 1")
                set(_val "${${ARGV${_i}}}")
                set(_isHandle TRUE)
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()

        # Collision Check
        get_property(_exists GLOBAL PROPERTY "${_h}_K_${_key}" SET)
        if (_exists)
            message(FATAL_ERROR "SQL Error: Key '${_key}' already exists in DICTIONARY. Use UPDATE to overwrite.")
        endif ()

        # Storage
        set_property(GLOBAL PROPERTY "${_h}_K_${_key}" "${_val}")
        set_property(GLOBAL PROPERTY "${_h}_K_${_key}_ISHANDLE" ${_isHandle})

        # Maintain a list of keys for SELECT KEYS queries
        if (NOT _exists)
            set_property(GLOBAL APPEND PROPERTY "${_h}_KEYS" "${_key}")
        endif ()
        return()
    endif ()

    # --- TABLE INSERT LOGIC ---
    get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
    get_property(_nextID GLOBAL PROPERTY "${_h}_NEXT_ROWID")
    set(_valIdx 2)
    if ("${ARGV${_valIdx}}" STREQUAL "VALUES")
        math(EXPR _valIdx "${_valIdx} + 1")
    endif ()
    foreach (_col IN LISTS _cols)
        _hs_sql_field_to_storage("${ARGV${_valIdx}}" _safeVal)
        set_property(GLOBAL PROPERTY "${_h}_R${_nextID}_${_col}" "${_safeVal}")
        math(EXPR _valIdx "${_valIdx} + 1")
    endforeach ()
    set_property(GLOBAL APPEND PROPERTY "${_h}_ROWIDS" "${_nextID}")
    get_property(_count GLOBAL PROPERTY "${_h}_ROW_COUNT")
    math(EXPR _newCount "${_count} + 1")
    set_property(GLOBAL PROPERTY "${_h}_ROW_COUNT" "${_newCount}")
    math(EXPR _newID "${_nextID} + 1")
    set_property(GLOBAL PROPERTY "${_h}_NEXT_ROWID" "${_newID}")
endfunction()

function(UPDATE tableVarName)
    _hs_sql_resolve_handle(${tableVarName} _h)
    _hs_sql_check_readonly(${_h})
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # --- DICTIONARY INSERT LOGIC ---
    if (_type STREQUAL "DICT")
        set(_key "")
        set(_val "")
        set(_isHandle FALSE)

        # Parse Dictionary arguments
        set(_i 2)
        while (_i LESS ARGC)
            set(_cur "${ARGV${_i}}")
            if (_cur STREQUAL "KEY")
                math(EXPR _i "${_i} + 1")
                set(_key "${ARGV${_i}}")
            elseif (_cur STREQUAL "VALUE")
                math(EXPR _i "${_i} + 1")
                set(_val "${ARGV${_i}}")
                set(_isHandle FALSE)
            elseif (_cur STREQUAL "HANDLE")
                math(EXPR _i "${_i} + 1")
                set(_val "${ARGV${_i}}")
                set(_isHandle TRUE)
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()

        # Storage
        set_property(GLOBAL PROPERTY "${_h}_K_${_key}" "${_val}")
        set_property(GLOBAL PROPERTY "${_h}_K_${_key}_ISHANDLE" ${_isHandle})

        # Maintain a list of keys for SELECT KEYS queries
        if (NOT _exists)
            set_property(GLOBAL APPEND PROPERTY "${_h}_KEYS" "${_key}")
        endif ()
        return()
    endif ()

    set(_col "")
    set(_val "")
    set(_rid "")

    # Dynamic Parser
    set(_i 1)
    while (_i LESS ARGC)
        set(_cur "${ARGV${_i}}")
        if (_cur STREQUAL "COLUMN")
            math(EXPR _i "${_i} + 1")
            set(_col "${ARGV${_i}}")
        elseif (_cur STREQUAL "SET")
            math(EXPR _i "${_i} + 1")
            set(_val "${ARGV${_i}}")
        elseif (_cur STREQUAL "ROWID")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
            endif ()
            set(_rid "${ARGV${_i}}")
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    if (_h AND _rid AND _col)
        set_property(GLOBAL PROPERTY "${_h}_R${_rid}_${_col}" "${_val}")
    else ()
        message(FATAL_ERROR "SQL UPDATE: Missing required parameters (Target: ${_h}, Row: ${_rid}, Col: ${_col})")
    endif ()
endfunction()

function(DELETE kwFrom tableVarName)
    _hs_sql_resolve_handle(${tableVarName} _h)
    _hs_sql_check_readonly(${_h})

    set(_rid "")
    set(_i 2)
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

    if (NOT _rid)
        message(FATAL_ERROR "SQL DELETE: WHERE ROWID = <id> is required.")
    endif ()

    get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
    foreach (_c IN LISTS _cols)
        set_property(GLOBAL PROPERTY "${_h}_R${_rid}_${_c}" "")
    endforeach ()

    get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
    list(REMOVE_ITEM _ids "${_rid}")
    set_property(GLOBAL PROPERTY "${_h}_ROWIDS" "${_ids}")

    get_property(_count GLOBAL PROPERTY "${_h}_ROW_COUNT")
    math(EXPR _newCount "${_count} - 1")
    set_property(GLOBAL PROPERTY "${_h}_ROW_COUNT" "${_newCount}")
endfunction()


# --------------------------------------------------------------------------------------------------
# DQL: SELECT
# --------------------------------------------------------------------------------------------------
function(SELECT mode)
    math(EXPR _lastIdx "${ARGC} - 1")
    set(_destVarName "${ARGV${_lastIdx}}")
    _hs_sql_resolve_handle("${ARGV2}" _srcHndl)
    get_property(_type GLOBAL PROPERTY "${_srcHndl}_TYPE")

    set(_final_result "")

    # --- 1. DICTIONARY PATH ---
    if (_type STREQUAL "DICT")
        set(_targetKey "")
        set(_i 3)
        while (_i LESS ARGC)
            if ("${ARGV${_i}}" STREQUAL "KEY")
                math(EXPR _i "${_i} + 1")
                if ("${ARGV${_i}}" STREQUAL "=")
                    math(EXPR _i "${_i} + 1")
                endif ()
                set(_targetKey "${ARGV${_i}}")
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()
        get_property(_final_result GLOBAL PROPERTY "${_srcHndl}_K_${_targetKey}")
        set(${_destVarName} "${_final_result}" PARENT_SCOPE)
        return()
    endif ()

    # --- 2. VIEW PATH (Recursive) ---
    if (_type STREQUAL "VIEW")
        get_property(_members GLOBAL PROPERTY "${_srcHndl}_MEMBERS")
        set(_viewList "")
        foreach (_m IN LISTS _members)
            set(_mVar "_v_${_m}")
            set(${_mVar} "${_m}")
            set(_subArgs ${ARGV})
            list(REMOVE_AT _subArgs 0 1 2)
            list(REMOVE_AT _subArgs -1)
            SELECT(${mode} FROM ${_mVar} ${_subArgs} INTO _subRes)
            if (_subRes)
                list(APPEND _viewList "${_subRes}")
            endif ()
        endforeach ()
        set(${_destVarName} "${_viewList}" PARENT_SCOPE)
        return()
    endif ()

    # --- 3. TABLE/MATERIALIZED_VIEW PATH ---
    set(_whereCols "")
    set(_whereVals "")
    set(_whereOps "")

    set(_targetRow "")
    set(_targetCol "")

    set(_i 3)
    while (_i LESS ARGC)
        set(_cur "${ARGV${_i}}")
        if (_cur MATCHES "^(ROWID|INDEX)$")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
            endif ()
            set(_targetRow "${ARGV${_i}}")
        elseif (_cur STREQUAL "COLUMN")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=") # SELECT VALUE ... COLUMN = "X"
                math(EXPR _i "${_i} + 1")
                set(_targetCol "${ARGV${_i}}")
            else () # SELECT * ... WHERE COLUMN "X" = "Y"
                set(_cName "${ARGV${_i}}")
                math(EXPR _i "${_i} + 1")
                if ("${ARGV${_i}}" STREQUAL "=" OR "${ARGV${_i}}" STREQUAL "LIKE")
                    list(APPEND _whereCols "${_cName}")
                    list(APPEND _whereOps "${ARGV${_i}}")
                    math(EXPR _i "${_i} + 1")
                    list(APPEND _whereVals "${ARGV${_i}}")
                else ()
                    set(_targetCol "${_cName}")
                    math(EXPR _i "${_i} - 1")
                endif ()
            endif ()
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    # A. Fast-path: Single Value/Handle
    if (mode MATCHES "^(VALUE|HANDLE)$" AND _targetRow)
        if (NOT _targetCol AND _targetRow MATCHES "^[0-9]+$")
            get_property(_allCols GLOBAL PROPERTY "${_srcHndl}_COLUMNS")
            math(EXPR _colIdx "${_targetRow} - 1")
            list(GET _allCols ${_colIdx} _targetCol)
        endif ()
        get_property(_final_result GLOBAL PROPERTY "${_srcHndl}_R${_targetRow}_${_targetCol}")
        set(${_destVarName} "${_final_result}" PARENT_SCOPE)
        return()
    endif ()

    # B. Restored Multi-row Filtering Logic (SELECT * / SELECT COUNT)
    get_property(_ids GLOBAL PROPERTY "${_srcHndl}_ROWIDS")
    get_property(_allCols GLOBAL PROPERTY "${_srcHndl}_COLUMNS")
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
                get_property(_actualVal GLOBAL PROPERTY "${_srcHndl}_R${_rid}_${_fCol}")

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
            list(APPEND _matched_column_name "${_fCol}")
        endif ()
    endforeach ()
    # --- C. Shape the Output ---
    if (mode STREQUAL "COUNT")
        list(LENGTH _matches _count)
        set(${_destVarName} "${_count}" PARENT_SCOPE)
        return()
    endif ()

    # If the user specifically asked for a VALUE (scalar string)
    if (mode STREQUAL "VALUE")
        list(LENGTH _matches _matchCount)
        if (_matchCount GREATER 0)
            # Return the value from the first matching row
            list(GET _matches 0 _firstID)
            if (_targetCol)
                set(_use_this_column_name "${_targetCol}")
            else ()
                list(GET _matched_column_name 0 _use_this_column_name)
            endif ()

            get_property(_final_result GLOBAL PROPERTY "${_srcHndl}_R${_firstID}_${_use_this_column_name}")
            set(${_destVarName} "${_final_result}" PARENT_SCOPE)
        else ()
            # No rows matched: return empty string
            set(${_destVarName} "" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # --- Inside SELECT function ---
    if(mode STREQUAL "ROW")
        if(NOT _targetRow)
            # If no ROWID specified, default to the first match
            list(GET _matches 0 _targetRow)
        endif()

        set(_rowList "")
        get_property(_allCols GLOBAL PROPERTY "${_srcHndl}_COLUMNS")
        foreach(_col IN LISTS _allCols)
            get_property(_val GLOBAL PROPERTY "${_srcHndl}_R${_targetRow}_${_col}")
            # Protect semicolons within data to avoid list corruption
            string(REPLACE "${lst_sep}" "${sql_sep}" _safeVal "${_val}")
            list(APPEND _rowList "${_safeVal}")
        endforeach()

        set(${_destVarName} "${_rowList}" PARENT_SCOPE)
        return()
    endif()

    # --- D. Default: Return a result set (New Table Handle) ---
    CREATE(TABLE _tmpRes LABEL "result_set" COLUMNS "${_allCols}")
    foreach (_mID IN LISTS _matches)
        set(_rowValues "")
        foreach (_col IN LISTS _allCols)
            get_property(_v GLOBAL PROPERTY "${_srcHndl}_R${_mID}_${_col}")
            list(APPEND _rowValues "${_v}")
        endforeach ()
        INSERT(INTO _tmpRes VALUES ${_rowValues})
    endforeach ()

    set(${_destVarName} "${_tmpRes}" PARENT_SCOPE)
endfunction()

# --------------------------------------------------------------------------------------------------
# Introspection: ASSERT, LABEL, DESCRIBE, GET_COLUMNS, GET_ROWIDS, TYPEOF
# --------------------------------------------------------------------------------------------------
function(ASSERT cond handleVarName)
    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    if (NOT _type STREQUAL cond)
        message(FATAL_ERROR "SQL ASSERT: Expected type '${cond}', but found '${_type}' for ${handleVarName}")
    endif ()
endfunction()

function(LABEL kwOf handleVarName kwInto outVarName)
    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_label GLOBAL PROPERTY "${_h}_LABEL")
    set(${outVarName} "${_label}" PARENT_SCOPE)
endfunction()

function(DESCRIBE handleVarName kwInto outVarName)
    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
    get_property(_rows GLOBAL PROPERTY "${_h}_ROW_COUNT")
    set(${outVarName} "COLUMNS: ${_cols} | ROWS: ${_rows}" PARENT_SCOPE)
endfunction()

function(GET_COLUMNS handleVarName outVarName)
    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
    set(${outVarName} "${_cols}" PARENT_SCOPE)
endfunction()

function(GET_ROWIDS handleVarName outVarName)
    _hs_sql_resolve_handle(${handleVarName} _h)
    get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
    set(${outVarName} "${_ids}" PARENT_SCOPE)
endfunction()

function(TYPEOF handleVarName outVarName)
    if (NOT DEFINED ${handleVarName})
        set(${outVarName} "STRING" PARENT_SCOPE)
    else ()
        get_property(_type GLOBAL PROPERTY "${${handleVarName}}_TYPE")
        set(${outVarName} "${_type}" PARENT_SCOPE)
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# DUMP: Visualizing Data
# --------------------------------------------------------------------------------------------------
function(DUMP kwFrom handleVarName)
    _hs_sql_resolve_handle(${handleVarName} _h)

    set(_verbose FALSE)
    set(_deep FALSE)
    set(_intoVar "")

    # Corrected multi-line statement parsing
    foreach (_arg IN LISTS ARGN)
        if (_arg STREQUAL "VERBOSE")
            set(_verbose TRUE)
        elseif (_arg STREQUAL "DEEP")
            set(_deep TRUE)
        elseif (_arg STREQUAL "INTO")
            set(_catchNext TRUE)
        elseif (_catchNext)
            set(_intoVar "${_arg}")
            set(_catchNext FALSE)
        endif ()
    endforeach ()

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")
    get_property(_label GLOBAL PROPERTY "${_h}_LABEL")
    set(_out "--- SQL DUMP: ${_label} (${_type}) ---\n")

    # --- VIEW Logic (Show member pointers) ---
    if (_type STREQUAL "VIEW")
        get_property(_members GLOBAL PROPERTY "${_h}_MEMBERS")
        string(APPEND _out " MEMBERS: ${_members}\n")
        if (_deep)
            foreach (_m IN LISTS _members)
                set(_mVar "_v_${_m}")
                set(${_mVar} "${_m}")
                DUMP(FROM ${_mVar} VERBOSE INTO _inner)
                string(APPEND _out "  |--- MEMBER ${_m}: ${_inner}\n")
            endforeach ()
        endif ()

    elseif (_type MATCHES "TABLE|MATERIALIZED_VIEW")
        get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
        get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")

        if (NOT _verbose)
            string(APPEND _out "    COLS: ${_cols}\n")
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
                    get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")

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
            string(APPEND _out "${_header}\n")

            # Build Rows
            foreach (_rid IN LISTS _ids)
                set(_rowLines 1)
                # Determine how many sub-lines this row needs
                foreach (_c IN LISTS _cols)
                    get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
                    string(REPLACE ";" "\n" _lines "${_val}")
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
                        get_property(_val GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")

                        # Apply GitHub domain omission for display
                        if (_val MATCHES "^https://github.com/(.*)")
                            set(_val "${CMAKE_MATCH_1}")
                        endif ()

                        string(REPLACE ";" "\n" _lines "${_val}")
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
                    string(APPEND _out "${_lineStr}\n")
                endforeach ()
            endforeach ()
        endif ()

        #        # --- TABLE / MATERIALIZED_VIEW Logic (Show rows) ---
        #    elseif(_type MATCHES "TABLE|MATERIALIZED_VIEW")
        #        get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
        #        get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
        #        string(APPEND _out " COLS: ${_cols}\n")
        #        if(_verbose)
        #            foreach(_rid IN LISTS _ids)
        #                string(APPEND _out " [Row ${_rid}]: ")
        #                foreach(_c IN LISTS _cols)
        #                    get_property(_v GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
        #                    string(APPEND _out "${_c}=${_v} | ")
        #                endforeach()
        #                string(APPEND _out "\n")
        #            endforeach()
        #        endif()

        # --- DICTIONARY Logic ---
    elseif (_type STREQUAL "DICT")
        get_property(_keys GLOBAL PROPERTY "${_h}_KEYS")
        foreach (_k IN LISTS _keys)
            get_property(_v GLOBAL PROPERTY "${_h}_K_${_k}")
            get_property(_isH GLOBAL PROPERTY "${_h}_K_${_k}_ISHANDLE")
            if (_isH)
                string(APPEND _out " [KEY] ${_k} => [HANDLE] ${_v}\n")
                set(_mVar "_v_${_v}")
                set(${_mVar} "${_v}")
                DUMP(FROM ${_mVar} VERBOSE DEEP INTO _inner)
                string(APPEND _out "  |--- MEMBER ${_m}: ${_inner}\n")
            else ()
                string(APPEND _out " [KEY] ${_k} => [VALUE] \"${_v}\"\n")
            endif ()
        endforeach ()
    endif ()

    if (_intoVar)
        set(${_intoVar} "${_out}" PARENT_SCOPE)
    else ()
        message("${_out}")
    endif ()
endfunction()

