include_guard(GLOBAL)

# --------------------------------------------------------------------------------------------------
# Internal Infrastructure & Variable Resolution
# --------------------------------------------------------------------------------------------------
set_property(GLOBAL PROPERTY HS_NEXT_HNDL 1000)

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
    set(_i 1) #2)
    while (_i LESS ARGC)
        if ("${ARGV${_i}}" STREQUAL "LABEL")
            math(EXPR _i "${_i} + 1")
            set(_label "${ARGV${_i}}")
        elseif ("${ARGV${_i}}" STREQUAL "COLUMNS")
            math(EXPR _i "${_i} + 1")
            set(_cols "${ARGV${_i}}")
        elseif ("${ARGV${_i}}" STREQUAL "FROM")
            # For VIEW: CREATE(VIEW hView FROM hTable1 hTable2 ...)
            math(EXPR _i "${_i} + 1")
            while (_i LESS ARGC AND NOT "${ARGV${_i}}" MATCHES "^(LABEL|COLUMNS|INTO)$")
                # Resolve the member variable names into actual handles
                _hs_sql_resolve_handle("${ARGV${_i}}" _mHndl)
                list(APPEND _members "${_mHndl}")
                math(EXPR _i "${_i} + 1")
            endwhile ()
            math(EXPR _i "${_i} - 1") # Backtrack for outer loop
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "${type}")
    set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_label}")

    if (type STREQUAL "TABLE")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_cols}")
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
    elseif (type STREQUAL "VIEW")
        # Views store the list of handles they represent
        set_property(GLOBAL PROPERTY "${_resolvedHndl}_MEMBERS" "${_members}")
    endif ()
endfunction()
#function(CREATE type outHandleVarName)
#    _hs_sql_generate_handle(${outHandleVarName})
#
#    set(_label "<unnamed>")
#    set(_cols "")
#    set(_i 2)
#    while(_i LESS ARGC)
#        if("${ARGV${_i}}" STREQUAL "LABEL")
#            math(EXPR _i "${_i} + 1")
#            set(_label "${ARGV${_i}}")
#        elseif("${ARGV${_i}}" STREQUAL "COLUMNS")
#            math(EXPR _i "${_i} + 1")
#            set(_cols "${ARGV${_i}}")
#        endif()
#        math(EXPR _i "${_i} + 1")
#    endwhile()
#
#    set_property(GLOBAL PROPERTY "${_resolvedHndl}_TYPE" "${type}")
#    set_property(GLOBAL PROPERTY "${_resolvedHndl}_LABEL" "${_label}")
#
#    if(type STREQUAL "TABLE")
#        set_property(GLOBAL PROPERTY "${_resolvedHndl}_COLUMNS" "${_cols}")
#        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROW_COUNT" 0)
#        set_property(GLOBAL PROPERTY "${_resolvedHndl}_NEXT_ROWID" 1)
#        set_property(GLOBAL PROPERTY "${_resolvedHndl}_ROWIDS" "")
#    endif()
#endfunction()

# --------------------------------------------------------------------------------------------------
# DML: INSERT, UPDATE, DELETE
# --------------------------------------------------------------------------------------------------
function(INSERT kw tableVarName)
    _hs_sql_resolve_handle(${tableVarName} _h)
    _hs_sql_check_readonly(${_h})

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # --- DICTIONARY INSERT LOGIC ---
    if (_type STREQUAL "DICTIONARY")
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
        set_property(GLOBAL PROPERTY "${_h}_R${_nextID}_${_col}" "${ARGV${_valIdx}}")
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
    if (_type STREQUAL "DICTIONARY")
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
    # 1. Capture the destination variable name (the string "h")
    math(EXPR _lastIdx "${ARGC} - 1")
    set(_destVarName "${ARGV${_lastIdx}}")

    # 2. Resolve the source handle from the variable name provided
    _hs_sql_resolve_handle("${ARGV2}" _srcHndl)
    get_property(_type GLOBAL PROPERTY "${_srcHndl}_TYPE")

    # This will hold our final result before we pass it back
    set(_final_result "")

    # --- DICTIONARY PATH ---
    if(_type STREQUAL "DICTIONARY")
        set(_targetKey "")
        set(_i 3)
        while(_i LESS ARGC)
            if("${ARGV${_i}}" STREQUAL "KEY")
                math(EXPR _i "${_i} + 1")
                if("${ARGV${_i}}" STREQUAL "=")
                    math(EXPR _i "${_i} + 1")
                endif()
                set(_targetKey "${ARGV${_i}}")
            endif()
            math(EXPR _i "${_i} + 1")
        endwhile()

        # Retrieve the value/handle from the dictionary key-store
        get_property(_final_result GLOBAL PROPERTY "${_srcHndl}_K_${_targetKey}")

        # Ensure we return "" if the key doesn't exist
        if(NOT DEFINED _final_result)
            set(_final_result "")
        endif()

        # PASS BACK: set(h "HS_HNDL_..." PARENT_SCOPE)
        set(${_destVarName} "${_final_result}" PARENT_SCOPE)
        return()
    endif()

    # --- VIEW PATH (Recursive) ---
    if(_type STREQUAL "VIEW")
        get_property(_members GLOBAL PROPERTY "${_srcHndl}_MEMBERS")
        set(_viewList "")
        foreach(_m IN LISTS _members)
            set(_mVar "_v_${_m}")
            set(${_mVar} "${_m}")
            set(_subArgs ${ARGV})
            list(REMOVE_AT _subArgs 0 1 2)
            list(REMOVE_AT _subArgs -1)
            SELECT(${mode} FROM ${_mVar} ${_subArgs} INTO _subRes)
            if(_subRes)
                list(APPEND _viewList "${_subRes}")
            endif()
        endforeach()
        set(${_destVarName} "${_viewList}" PARENT_SCOPE)
        return()
    endif()

    # --- TABLE PATH ---
    set(_whereCols "")
    set(_whereVals "")
    set(_whereOps "")
    set(_targetRow "")
    set(_targetCol "")

    set(_i 3)

    while(_i LESS ARGC)
        set(_cur "${ARGV${_i}}")
        if(_cur MATCHES "^(ROWID|INDEX)$")
            math(EXPR _i "${_i} + 1")
            if("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
            endif()
            set(_targetRow "${ARGV${_i}}")
        elseif(_cur STREQUAL "COLUMN")
            math(EXPR _i "${_i} + 1")
            if("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
                set(_targetCol "${ARGV${_i}}")
            else()
                set(_cName "${ARGV${_i}}")
                math(EXPR _i "${_i} + 1")
                if("${ARGV${_i}}" STREQUAL "=" OR "${ARGV${_i}}" STREQUAL "LIKE")
                    list(APPEND _whereCols "${_cName}")
                    list(APPEND _whereOps "${ARGV${_i}}")
                    math(EXPR _i "${_i} + 1")
                    list(APPEND _whereVals "${ARGV${_i}}")
                else()
                    set(_targetCol "${_cName}")
                    math(EXPR _i "${_i} - 1")
                endif()
            endif()
        endif()
        math(EXPR _i "${_i} + 1")
    endwhile()

    # Single Value/Handle Result
    if(mode MATCHES "^(VALUE|HANDLE)$" AND _targetRow)
        if(NOT _targetCol AND _targetRow MATCHES "^[0-9]+$")
            get_property(_allCols GLOBAL PROPERTY "${_srcHndl}_COLUMNS")
            math(EXPR _colIdx "${_targetRow} - 1")
            list(GET _allCols ${_colIdx} _targetCol)
        endif()

        get_property(_final_result GLOBAL PROPERTY "${_srcHndl}_R${_targetRow}_${_targetCol}")
        set(${_destVarName} "${_final_result}" PARENT_SCOPE)
        return()
    endif()

    # Multi-row Result Set logic would go here...
endfunction()






















function(SELECT_o mode_o)
    math(EXPR _lastIdx "${ARGC} - 1")
    set(_intoVarName "${ARGV${_lastIdx}}")
    _hs_sql_resolve_handle("${ARGV2}" _h)

    get_property(_type GLOBAL PROPERTY "${_h}_TYPE")

    # 1. Dictionary Path (KEY based)
    if (_type STREQUAL "DICTIONARY")
        set(_targetKey "")
        set(_i 3)
        while (_i LESS ARGC)
            if ("${ARGV${_i}}" STREQUAL "KEY")
                math(EXPR _i "${_i} + 1")
                if ("${ARGV${_i}}" STREQUAL "=") # Skip = if present
                    math(EXPR _i "${_i} + 1")
                endif ()
                set(_targetKey "${ARGV${_i}}")
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()

        if (mode STREQUAL "VALUE" OR mode STREQUAL "HANDLE")
            get_property(_val GLOBAL PROPERTY "${_h}_K_${_targetKey}")
            get_property(_val GLOBAL PROPERTY "${_h}_K_${_targetKey}")
            if (NOT DEFINED _val)
                set(${_intoVarName} "" PARENT_SCOPE)
            else ()
                set(${_intoVarName} "${_val}" PARENT_SCOPE)
            endif ()
            return()
        endif ()
    endif ()

    # 2. Table Path (ROWID / COLUMN based)
    set(_whereCols "")
    set(_whereVals "")
    set(_whereOps "")
    set(_targetRow "")
    set(_targetCol "")

    set(_i 3)
    while (_i LESS ARGC)
        set(_cur "${ARGV${_i}}")
        # --- Handle ROWID/INDEX ---
        if (_cur MATCHES "^(ROWID|INDEX)$")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=")
                math(EXPR _i "${_i} + 1")
            endif ()
            set(_targetRow "${ARGV${_i}}")
            # --- Handle COLUMN ---
        elseif (_cur STREQUAL "COLUMN")
            math(EXPR _i "${_i} + 1")
            if ("${ARGV${_i}}" STREQUAL "=") # Case: COLUMN = "name"
                math(EXPR _i "${_i} + 1")
                set(_targetCol "${ARGV${_i}}")
            else () # Case: COLUMN "name" = ...
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

    # --- Reconciled Fast-path for single value/index lookup ---
    if (mode STREQUAL "VALUE" AND _targetRow)
        # 1. Handle INDEX -> Column Name mapping
        if (NOT _targetCol AND _targetRow MATCHES "^[0-9]+$")
            # If the user used INDEX = N instead of COLUMN = "name"
            get_property(_allCols GLOBAL PROPERTY "${_h}_COLUMNS")
            # ARGV contains the index (e.g., 2). CMake lists are 0-based.
            # If INDEX 1 is Col 1, then we subtract 1.
            math(EXPR _colIdx "${_targetRow} - 1")
            list(GET _allCols ${_colIdx} _targetCol)
        endif ()

        # 2. Fetch the data
        get_property(_val GLOBAL PROPERTY "${_h}_R${_targetRow}_${_targetCol}")

        # 3. Return logic: Return "" if not found (per user instruction)
        if (NOT DEFINED _val OR _val STREQUAL "")
            set(${_intoVarName} "" PARENT_SCOPE)
        else ()
            set(${_intoVarName} "${_val}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # Redirect logic: If source is a VIEW, we run SELECT against its members
    if (_type STREQUAL "VIEW")
        get_property(_members GLOBAL PROPERTY "${_srcHndl}_MEMBERS")
        set(_viewResults "")

        # We recursively call SELECT on each member
        foreach (_mHndl IN LISTS _members)
            set(_tmpVar "_view_sub_${_mHndl}")
            set(${_tmpVar} "${_mHndl}")
            # Reconstruct the arguments for the sub-call
            set(_subArgs ${ARGV})
            list(REMOVE_AT _subArgs 0 1 2) # Remove mode and src
            list(REMOVE_AT _subArgs -1)    # Remove intoVar

            SELECT(${mode} FROM ${_tmpVar} ${_subArgs} INTO _subRes)

            if (_subRes AND NOT _subRes STREQUAL "NOTFOUND")
                list(APPEND _viewResults "${_subRes}")
            endif ()
        endforeach ()

        # Return logic for VIEW results
        if (NOT _viewResults)
            set(${_intoVarName} "NOTFOUND" PARENT_SCOPE)
        else ()
            # If multiple members returned handles, we could return a list or a merged TABLE.
            # Per standard VIEW logic, we return the result set.
            set(${_intoVarName} "${_viewResults}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    if (mode STREQUAL "COUNT")
        get_property(_res GLOBAL PROPERTY "${_h}_ROW_COUNT")
        set(${_intoVarName} "${_res}" PARENT_SCOPE)
        return()
    endif ()

    get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
    get_property(_allCols GLOBAL PROPERTY "${_h}_COLUMNS")
    set(_matches "")
    foreach (_rid IN LISTS _ids)
        set(_rowPass 1)
        list(LENGTH _whereCols _fLen)
        if (_fLen GREATER 0)
            math(EXPR _maxF "${_fLen} - 1")
            foreach (_fi RANGE ${_maxF})
                list(GET _whereCols ${_fi} _fCol)
                list(GET _whereOps ${_fi} _fOp)
                list(GET _whereVals ${_fi} _fVal)
                get_property(_cv GLOBAL PROPERTY "${_h}_R${_rid}_${_fCol}")
                if (_fOp STREQUAL "=" AND NOT "${_cv}" STREQUAL "${_fVal}")
                    set(_rowPass 0)
                elseif (_fOp STREQUAL "LIKE")
                    string(REPLACE "*" ".*" _regex "${_fVal}")
                    if (NOT _cv MATCHES "${_regex}")
                        set(_rowPass 0)
                    endif ()
                endif ()
            endforeach ()
        endif ()
        if (_rowPass)
            list(APPEND _matches "${_rid}")
        endif ()
    endforeach ()

    list(LENGTH _matches _mCount)
    if (_mCount EQUAL 0)
        set(${_intoVarName} "" PARENT_SCOPE)
    elseif (_mCount EQUAL 1 AND mode STREQUAL "VALUE")
        if (NOT _targetCol)
            list(GET _allCols 0 _targetCol)
        endif ()
        get_property(_res GLOBAL PROPERTY "${_h}_R${_matches}_${_targetCol}")
        set(${_intoVarName} "${_res}" PARENT_SCOPE)
    else ()
        CREATE(TABLE _tmpRes LABEL "result_set" COLUMNS "${_allCols}")
        foreach (_rid IN LISTS _matches)
            set(_v "")
            foreach (_c IN LISTS _allCols)
                get_property(_cv GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
                list(APPEND _v "${_cv}")
            endforeach ()
            INSERT(INTO _tmpRes VALUES ${_v})
        endforeach ()
        set(${_intoVarName} "${${_tmpRes}}" PARENT_SCOPE)
    endif ()
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

    # Parse Flags
    set(_verbose FALSE)
    set(_deep FALSE)
    set(_intoVar "")
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
    get_property(_cols GLOBAL PROPERTY "${_h}_COLUMNS")
    get_property(_rows GLOBAL PROPERTY "${_h}_ROW_COUNT")

    set(_out "--- SQL OBJECT DUMP ---\nLABEL: ${_label}\nTYPE:  ${_type}\n")
    if (_type STREQUAL "TABLE")
        string(APPEND _out "ROWS:  ${_rows}\nCOLS:  ${_cols}\n")
    endif ()

    if (_verbose)
        string(APPEND _out "-----------------------\n")
        get_property(_ids GLOBAL PROPERTY "${_h}_ROWIDS")
        foreach (_rid IN LISTS _ids)
            string(APPEND _out "[Row ${_rid}]: ")
            foreach (_c IN LISTS _cols)
                get_property(_v GLOBAL PROPERTY "${_h}_R${_rid}_${_c}")
                string(APPEND _out "${_c}=${_v} | ")
                if (_deep)
                    # Simple recursive check: if the value looks like a handle, dump it
                    if (_v MATCHES "^HS_HNDL_")
                        set(_innerVar "_deep_dump_${_v}")
                        set(${_innerVar} "${_v}")
                        DUMP(FROM ${_innerVar} VERBOSE INTO _innerRes)
                        string(APPEND _out "\n  +-- DEEP: ${_innerRes}")
                    endif ()
                endif ()
            endforeach ()
            string(APPEND _out "\n")
        endforeach ()
    endif ()

    if (_intoVar)
        set(${_intoVar} "${_out}" PARENT_SCOPE)
    else ()
        message("${_out}")
    endif ()
endfunction()
