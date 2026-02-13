include_guard(GLOBAL)

# object_sql_enhanced.cmake
# SQL-like facade over the object(...) API.
#
# TYPE MAPPING
#   TABLE      -> ARRAY TYPE RECORDS  (rows) + a schema RECORD at index 0 (metadata)
#   COLLECTION -> ARRAY TYPE RECORDS|ARRAYS
#   DICTIONARY -> DICT
#   VIEW       -> CATALOG  (read-only; CREATE_VIEW)
#
# HANDLE CONVENTIONS (identical to object.cmake)
#   - All CREATE variants return opaque handle tokens in the caller's variable.
#   - All GET/SELECT variants that return objects:    "" means not found.
#   - All SELECT variants that return scalars: "NOTFOUND" means not found.
#
# UNNAMED GATE
#   Objects created without a LABEL have label "<unnamed>".
#   They must be renamed with ALTER(TABLE ... RENAME TO ...) before any mutation.
#   (CREATE TABLE always requires LABEL and sets the label immediately.)
#
# SCOPE DESIGN
#   Every public macro expands inline in the caller's scope.
#   Every worker function is called directly from the macro, so one PARENT_SCOPE
#   hop inside the worker lands back in the caller — no intermediate dispatch
#   functions that would swallow the scope step.
#
#   Internal helpers that accept object handles take the handle VALUE (the
#   opaque token string), never a variable name, to avoid double-dereference
#   confusion across scope boundaries.
#
# API ENTRY POINTS
#   CREATE(TABLE|COLLECTION|DICTIONARY|VIEW ...)
#   INSERT(INTO ...)
#   SELECT(VALUE|ROW|COLUMN|*|COUNT|HANDLE|KEYS FROM ...)
#   UPDATE(tableHandle SET ...)
#   DELETE(FROM ...)
#   SET(dictHandle KEY ...)
#   ALTER(TABLE ...)
#   DESCRIBE(tableHandle INTO outVar)
#   TYPEOF(handleVar INTO outVar)
#   ASSERT(handleVar IS type [type...])
#   LABEL(OF handleVar INTO outVar)
#   DUMP(handleVar INTO outVar)
#   FOREACH(ROW|HANDLE|KEY IN handleVar CALL functionName)

if (NOT COMMAND object)
    include(${CMAKE_SOURCE_DIR}/cmake/object.cmake)
endif ()

# --------------------------------------------------------------------------------------------------
# Internal constants

set(_HS_SQL_META_LABEL    "__HS_SQL_TABLE_META__")
set(_HS_SQL_META_COLS_IDX  0)   # encoded column list
set(_HS_SQL_META_ROWID_IDX 1)   # next ROWID counter
set(_HS_SQL_META_FIXED_IDX 2)   # "1" if FIXED, else "0"

# ==================================================================================================
# Internal helpers
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# _hs_sql__get_meta
# Reads metadata from a TABLE.  tblHndl is the handle VALUE (not a var name).
# Outputs: outMetaHndl  outColumns (CMake list)  outNextRowid  outFixed ("1"/"0")
#
function(_hs_sql__get_meta tblHndl outMetaHndl outColumns outNextRowid outFixed)
    set(_tv "${tblHndl}")
    object(GET _mh FROM _tv INDEX 0)
    if (NOT _mh)
        msg(ALWAYS FATAL_ERROR "SQL: TABLE '${tblHndl}' has no metadata row")
    endif ()

    object(STRING _colsEncoded FROM _mh INDEX ${_HS_SQL_META_COLS_IDX})
    object(STRING _nextRowid   FROM _mh INDEX ${_HS_SQL_META_ROWID_IDX})
    object(STRING _fixedFlag   FROM _mh INDEX ${_HS_SQL_META_FIXED_IDX})

    if ("${_colsEncoded}" STREQUAL "NOTFOUND")
        msg(ALWAYS FATAL_ERROR "SQL: TABLE metadata slot 0 (columns) is missing")
    endif ()
    if ("${_nextRowid}" STREQUAL "NOTFOUND")
        msg(ALWAYS FATAL_ERROR "SQL: TABLE metadata slot 1 (rowid counter) is missing")
    endif ()
    if ("${_fixedFlag}" STREQUAL "NOTFOUND")
        set(_fixedFlag "0")
    endif ()

    string(REPLACE "${_HS_REC_FIELDS_SEP}" ";" _cols "${_colsEncoded}")

    set(${outMetaHndl}  "${_mh}"        PARENT_SCOPE)
    set(${outColumns}   "${_cols}"      PARENT_SCOPE)
    set(${outNextRowid} "${_nextRowid}" PARENT_SCOPE)
    set(${outFixed}     "${_fixedFlag}" PARENT_SCOPE)
endfunction()

# --------------------------------------------------------------------------------------------------
# _hs_sql__update_rowid  —  tblHndl is a VALUE
#
function(_hs_sql__update_rowid tblHndl newRowid)
    set(_tv "${tblHndl}")
    object(GET _mh FROM _tv INDEX 0)
    object(SET _mh INDEX ${_HS_SQL_META_ROWID_IDX} "${newRowid}")
endfunction()

# --------------------------------------------------------------------------------------------------
# _hs_sql__update_columns  —  tblHndl is a VALUE
#
function(_hs_sql__update_columns tblHndl newColsEncoded)
    set(_tv "${tblHndl}")
    object(GET _mh FROM _tv INDEX 0)
    object(SET _mh INDEX ${_HS_SQL_META_COLS_IDX} "${newColsEncoded}")
endfunction()

# --------------------------------------------------------------------------------------------------
# _hs_sql__iter_rows  —  tblHndl is a VALUE
# Returns list of row handle tokens (skips index 0 = metadata).
#
function(_hs_sql__iter_rows tblHndl outRowHandles)
    set(_tv "${tblHndl}")
    set(_rows "")
    set(_i 1)
    while (ON)
        object(GET _rh FROM _tv INDEX ${_i})
        if (NOT _rh)
            break()
        endif ()
        list(APPEND _rows "${_rh}")
        math(EXPR _i "${_i} + 1")
    endwhile ()
    set(${outRowHandles} "${_rows}" PARENT_SCOPE)
endfunction()

# --------------------------------------------------------------------------------------------------
# _hs_sql__typeof_value  —  hndlValue is a VALUE
# Returns "TABLE"|"COLLECTION"|"DICTIONARY"|"VIEW"|"STRING"
#
function(_hs_sql__typeof_value hndlValue outType)
    if ("${hndlValue}" STREQUAL "" OR NOT "${hndlValue}" MATCHES "^HS_HNDL_")
        set(${outType} "STRING" PARENT_SCOPE)
        return()
    endif ()

    set(_hv "${hndlValue}")
    object(KIND _hv _k)

    if (_k STREQUAL "ARRAY")
        object(GET _maybeMetaHndl FROM _hv INDEX 0)
        if (_maybeMetaHndl)
            object(NAME _lbl0 FROM _maybeMetaHndl)
            if ("${_lbl0}" STREQUAL "${_HS_SQL_META_LABEL}")
                set(${outType} "TABLE" PARENT_SCOPE)
                return()
            endif ()
        endif ()
        set(${outType} "COLLECTION" PARENT_SCOPE)
    elseif (_k STREQUAL "DICT")
        set(${outType} "DICTIONARY" PARENT_SCOPE)
    elseif (_k STREQUAL "CATALOG")
        set(${outType} "VIEW" PARENT_SCOPE)
    elseif (_k STREQUAL "RECORD")
        set(${outType} "RECORD" PARENT_SCOPE)
    else ()
        set(${outType} "STRING" PARENT_SCOPE)
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# _hs_sql__assert_named  —  hndlValue is a VALUE
# FATAL_ERROR if the object is "<unnamed>".
#
function(_hs_sql__assert_named hndlValue context)
    set(_hv "${hndlValue}")
    object(NAME _lbl FROM _hv)
    if ("${_lbl}" STREQUAL "<unnamed>")
        msg(ALWAYS FATAL_ERROR "${context}: object must be named before mutation "
                "(supply LABEL at creation or use ALTER TABLE ... RENAME TO)")
    endif ()
endfunction()

# --------------------------------------------------------------------------------------------------
# _hs_sql__parse_select_args  (MACRO — expands in caller scope)
# Parses "FROM <varName> [WHERE ...] INTO <outVarName>" from ARGN.
# Sets in the caller's scope:
#   _sel_src_val    — the dereferenced handle VALUE from the FROM variable
#   _sel_where_args — list of tokens between WHERE and INTO
#   _sel_out        — name of the output variable
#
macro(_hs_sql__parse_select_args)
    set(_sel_src_val "")
    set(_sel_where_args "")
    set(_sel_out "")
    set(_pstate "EXPECT_FROM")

    set(_pi 0)
    while (_pi LESS ARGC)
        set(_pa "${ARGV${_pi}}")
        if (_pstate STREQUAL "EXPECT_FROM")
            if (_pa STREQUAL "FROM")
                set(_pstate "SRC")
            else ()
                msg(ALWAYS FATAL_ERROR "SELECT: expected FROM, got '${_pa}'")
            endif ()
        elseif (_pstate STREQUAL "SRC")
            set(_sel_src_val "${${_pa}}")   # dereference: variable name -> handle value
            set(_pstate "AFTER_SRC")
        elseif (_pstate STREQUAL "AFTER_SRC")
            if (_pa STREQUAL "WHERE")
                set(_pstate "WHERE_ARGS")
            elseif (_pa STREQUAL "INTO")
                set(_pstate "OUT")
            else ()
                msg(ALWAYS FATAL_ERROR "SELECT: expected WHERE or INTO after source, got '${_pa}'")
            endif ()
        elseif (_pstate STREQUAL "WHERE_ARGS")
            if (_pa STREQUAL "INTO")
                set(_pstate "OUT")
            else ()
                list(APPEND _sel_where_args "${_pa}")
            endif ()
        elseif (_pstate STREQUAL "OUT")
            set(_sel_out "${_pa}")
            set(_pstate "DONE")
        endif ()
        math(EXPR _pi "${_pi} + 1")
    endwhile ()

    if ("${_sel_out}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "SELECT: missing output variable (INTO <var>)")
    endif ()
endmacro()

# ==================================================================================================
# CREATE
# ==================================================================================================
# CREATE(TABLE  outHandleVar LABEL "name" COLUMNS "col1;col2;..." [FIXED])
# CREATE(COLLECTION outHandleVar LABEL "name" TYPE TABLES|COLLECTIONS)
# CREATE(DICTIONARY outHandleVar LABEL "name")
# CREATE(VIEW outHandleVar LABEL "name" FROM handle1 [handle2 ...])
#
# The macro dispatches directly to the worker function, which writes to
# ${outHandleVar} with PARENT_SCOPE — one hop back to the real caller.
#
macro(CREATE _createType _outHandleVar)
    if ("${_createType}" STREQUAL "TABLE")
        _hs_sql__create_table("${_outHandleVar}" ${ARGN})
    elseif ("${_createType}" STREQUAL "COLLECTION")
        _hs_sql__create_collection("${_outHandleVar}" ${ARGN})
    elseif ("${_createType}" STREQUAL "DICTIONARY")
        _hs_sql__create_dictionary("${_outHandleVar}" ${ARGN})
    elseif ("${_createType}" STREQUAL "VIEW")
        _hs_sql__create_view("${_outHandleVar}" ${ARGN})
    else ()
        msg(ALWAYS FATAL_ERROR "CREATE: unknown type '${_createType}'. "
                "Expected TABLE, COLLECTION, DICTIONARY, or VIEW.")
    endif ()
endmacro()

# -- CREATE TABLE ----------------------------------------------------------------------------------
function(_hs_sql__create_table outHandleVar)
    set(_label "")
    set(_columns "")
    set(_fixed "0")

    set(_i 0)
    while (_i LESS ARGC)
        set(_arg "${ARGV${_i}}")
        if (_arg STREQUAL "LABEL")
            math(EXPR _i "${_i} + 1")
            set(_label "${ARGV${_i}}")
        elseif (_arg STREQUAL "COLUMNS")
            math(EXPR _i "${_i} + 1")
            # Accept semicolon-delimited string — CMake splits on ; automatically
            set(_columns ${ARGV${_i}})
        elseif (_arg STREQUAL "FIXED")
            set(_fixed "1")
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    if ("${_label}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "CREATE TABLE: LABEL is required")
    endif ()
    if ("${_columns}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "CREATE TABLE: COLUMNS is required")
    endif ()

    object(CREATE _arrHndl KIND ARRAY LABEL "${_label}" TYPE RECORDS)

    string(JOIN "${_HS_REC_FIELDS_SEP}" _colsEncoded ${_columns})

    object(CREATE _metaHndl KIND RECORD LABEL "${_HS_SQL_META_LABEL}" LENGTH 3 FIXED)
    object(SET _metaHndl INDEX ${_HS_SQL_META_COLS_IDX}  "${_colsEncoded}")
    object(SET _metaHndl INDEX ${_HS_SQL_META_ROWID_IDX} "1")
    object(SET _metaHndl INDEX ${_HS_SQL_META_FIXED_IDX} "${_fixed}")

    object(APPEND _arrHndl RECORD _metaHndl)

    set(${outHandleVar} "${_arrHndl}" PARENT_SCOPE)
endfunction()

# -- CREATE COLLECTION -----------------------------------------------------------------------------
function(_hs_sql__create_collection outHandleVar)
    set(_label "<unnamed>")
    set(_arrType "RECORDS")

    set(_i 0)
    while (_i LESS ARGC)
        set(_arg "${ARGV${_i}}")
        if (_arg STREQUAL "LABEL")
            math(EXPR _i "${_i} + 1")
            set(_label "${ARGV${_i}}")
        elseif (_arg STREQUAL "TYPE")
            math(EXPR _i "${_i} + 1")
            set(_t "${ARGV${_i}}")
            if (_t STREQUAL "TABLES")
                set(_arrType "RECORDS")
            elseif (_t STREQUAL "COLLECTIONS")
                set(_arrType "ARRAYS")
            else ()
                msg(ALWAYS FATAL_ERROR
                        "CREATE COLLECTION: TYPE must be TABLES or COLLECTIONS, got '${_t}'")
            endif ()
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    object(CREATE _h KIND ARRAY LABEL "${_label}" TYPE ${_arrType})
    set(${outHandleVar} "${_h}" PARENT_SCOPE)
endfunction()

# -- CREATE DICTIONARY -----------------------------------------------------------------------------
function(_hs_sql__create_dictionary outHandleVar)
    set(_label "<unnamed>")

    set(_i 0)
    while (_i LESS ARGC)
        set(_arg "${ARGV${_i}}")
        if (_arg STREQUAL "LABEL")
            math(EXPR _i "${_i} + 1")
            set(_label "${ARGV${_i}}")
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    object(CREATE _h KIND DICT LABEL "${_label}")
    set(${outHandleVar} "${_h}" PARENT_SCOPE)
endfunction()

# -- CREATE VIEW -----------------------------------------------------------------------------------
function(_hs_sql__create_view outHandleVar)
    set(_label "")
    set(_srcHandles "")
    set(_state "START")

    set(_i 0)
    while (_i LESS ARGC)
        set(_arg "${ARGV${_i}}")
        if (_arg STREQUAL "LABEL")
            math(EXPR _i "${_i} + 1")
            set(_label "${ARGV${_i}}")
        elseif (_arg STREQUAL "FROM")
            set(_state "SOURCES")
        elseif (_state STREQUAL "SOURCES")
            list(APPEND _srcHandles "${_arg}")
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    if ("${_label}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "CREATE VIEW: LABEL is required")
    endif ()
    if ("${_srcHandles}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "CREATE VIEW: at least one source handle required after FROM")
    endif ()

    object(CREATE_VIEW _h ${_srcHandles} LABEL "${_label}")
    set(${outHandleVar} "${_h}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# INSERT
# ==================================================================================================
# INSERT(INTO tableHandle VALUES "v1" "v2" ...)
# INSERT(INTO tableHandle ROW recordHandle)
# INSERT(INTO collHandle  TABLE tableHandle)
# INSERT(INTO collHandle  COLLECTION nestedCollHandle)
#
# _targetHandleVar is the variable NAME.  The macro peeks at ARGV0 (first arg
# after the variable name) to pick the worker.  Workers receive both the
# variable name (to propagate the updated handle back) and the current handle
# VALUE.
#
macro(INSERT _kw _targetHandleVar)
    if (NOT "${_kw}" STREQUAL "INTO")
        msg(ALWAYS FATAL_ERROR "INSERT: expected INTO, got '${_kw}'")
    endif ()

    set(_ins_sub "${ARGV0}")

    if ("${_ins_sub}" STREQUAL "VALUES")
        _hs_sql__insert_values("${_targetHandleVar}" "${${_targetHandleVar}}" ${ARGN})
    elseif ("${_ins_sub}" STREQUAL "ROW")
        _hs_sql__insert_row("${_targetHandleVar}" "${${_targetHandleVar}}" ${ARGN})
    elseif ("${_ins_sub}" STREQUAL "TABLE" OR "${_ins_sub}" STREQUAL "COLLECTION")
        _hs_sql__insert_into_collection("${_targetHandleVar}" "${${_targetHandleVar}}" ${ARGN})
    else ()
        msg(ALWAYS FATAL_ERROR
                "INSERT INTO: expected VALUES, ROW, TABLE, or COLLECTION, got '${_ins_sub}'")
    endif ()
    unset(_ins_sub)
endmacro()

# -- INSERT INTO table VALUES ... ------------------------------------------------------------------
# ARGV0 = tableHndlVar name (string)
# ARGV1 = tblHndl value
# ARGV2 = "VALUES"
# ARGV3..N = cell values
#
function(_hs_sql__insert_values tableHndlVar tblHndl)
    _hs_sql__assert_named("${tblHndl}" "INSERT INTO")
    _hs_sql__get_meta("${tblHndl}" _metaHndl _columns _nextRowid _fixed)

    # Collect values — ARGV0=varName ARGV1=tblHndl ARGV2="VALUES" ARGV3+...
    set(_values "")
    set(_i 3)
    while (_i LESS ARGC)
        list(APPEND _values "${ARGV${_i}}")
        math(EXPR _i "${_i} + 1")
    endwhile ()

    list(LENGTH _columns _colCount)
    list(LENGTH _values  _valCount)
    if (NOT _valCount EQUAL _colCount)
        msg(ALWAYS FATAL_ERROR
                "INSERT INTO: expected ${_colCount} values (columns: ${_columns}), got ${_valCount}")
    endif ()

    set(_rowLabel "ROW_${_nextRowid}")
    object(CREATE _rowHndl KIND RECORD LABEL "${_rowLabel}" FIELDS ${_columns})

    set(_ci 0)
    foreach (_col IN LISTS _columns)
        list(GET _values ${_ci} _val)
        object(SET _rowHndl NAME EQUAL "${_col}" VALUE "${_val}")
        math(EXPR _ci "${_ci} + 1")
    endforeach ()

    set(_tv "${tblHndl}")
    object(APPEND _tv RECORD _rowHndl)

    math(EXPR _newNext "${_nextRowid} + 1")
    _hs_sql__update_rowid("${tblHndl}" "${_newNext}")

    set(${tableHndlVar} "${_tv}" PARENT_SCOPE)
endfunction()

# -- INSERT INTO table ROW recordHandle ------------------------------------------------------------
# ARGV0 = tableHndlVar name, ARGV1 = tblHndl value, ARGV2 = "ROW", ARGV3 = recHndlVar name
#
function(_hs_sql__insert_row tableHndlVar tblHndl)
    set(_recHndlVar "${ARGV3}")
    set(_recHndl    "${${_recHndlVar}}")

    _hs_sql__assert_named("${tblHndl}" "INSERT INTO ROW")
    _hs_sql__get_meta("${tblHndl}" _metaHndl _columns _nextRowid _fixed)

    set(_rowLabel "ROW_${_nextRowid}")
    set(_rv "${_recHndl}")
    object(RENAME _rv "${_rowLabel}")

    set(_tv "${tblHndl}")
    object(APPEND _tv RECORD _rv)

    math(EXPR _newNext "${_nextRowid} + 1")
    _hs_sql__update_rowid("${tblHndl}" "${_newNext}")

    set(${tableHndlVar} "${_tv}" PARENT_SCOPE)
    set(${_recHndlVar}  "${_rv}" PARENT_SCOPE)
endfunction()

# -- INSERT INTO collection TABLE|COLLECTION handle ------------------------------------------------
# ARGV0 = collHndlVar name, ARGV1 = collHndl value, ARGV2 = "TABLE"|"COLLECTION", ARGV3 = objHndlVar name
#
function(_hs_sql__insert_into_collection collHndlVar collHndl)
    set(_objType    "${ARGV2}")
    set(_objHndlVar "${ARGV3}")
    set(_objHndl    "${${_objHndlVar}}")

    _hs_sql__assert_named("${collHndl}" "INSERT INTO COLLECTION")
    _hs_sql__assert_named("${_objHndl}" "INSERT INTO COLLECTION (inserted object)")

    set(_cv "${collHndl}")
    set(_ov "${_objHndl}")

    if (_objType STREQUAL "TABLE")
        object(APPEND _cv RECORD _ov)
    else ()
        object(APPEND _cv ARRAY _ov)
    endif ()

    set(${collHndlVar} "${_cv}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# SELECT
# ==================================================================================================
# SELECT(VALUE  FROM handleVar [WHERE ...] INTO outVar)
# SELECT(ROW    FROM tableVar  WHERE ROWID = <n> INTO outVar)
# SELECT(COLUMN FROM tableVar  WHERE COLUMN = "col" INTO outVar)
# SELECT(*      FROM tableVar  WHERE COLUMN "col" = "val" [AND ...] INTO outVar)
# SELECT(COUNT  FROM handleVar INTO outVar)
# SELECT(HANDLE FROM dictOrCollVar WHERE KEY|NAME|INDEX ... INTO outVar)
# SELECT(KEYS   FROM dictVar [WHERE KEY LIKE "pat"] INTO outVar)
#
# _hs_sql__parse_select_args (a macro) sets _sel_src_val / _sel_where_args / _sel_out
# in the caller's scope.  The worker function then writes directly to _sel_out via
# PARENT_SCOPE — one hop back to the real caller.
#
macro(SELECT _selectWhat)
    _hs_sql__parse_select_args(${ARGN})

    if ("${_selectWhat}" STREQUAL "VALUE")
        _hs_sql__select_value("${_sel_src_val}" "${_sel_out}" ${_sel_where_args})
    elseif ("${_selectWhat}" STREQUAL "ROW")
        _hs_sql__select_row("${_sel_src_val}" "${_sel_out}" ${_sel_where_args})
    elseif ("${_selectWhat}" STREQUAL "COLUMN")
        _hs_sql__select_column("${_sel_src_val}" "${_sel_out}" ${_sel_where_args})
    elseif ("${_selectWhat}" STREQUAL "*")
        _hs_sql__select_star("${_sel_src_val}" "${_sel_out}" ${_sel_where_args})
    elseif ("${_selectWhat}" STREQUAL "COUNT")
        _hs_sql__select_count("${_sel_src_val}" "${_sel_out}")
    elseif ("${_selectWhat}" STREQUAL "HANDLE")
        _hs_sql__select_handle("${_sel_src_val}" "${_sel_out}" ${_sel_where_args})
    elseif ("${_selectWhat}" STREQUAL "KEYS")
        _hs_sql__select_keys("${_sel_src_val}" "${_sel_out}" ${_sel_where_args})
    else ()
        msg(ALWAYS FATAL_ERROR "SELECT: unknown selector '${_selectWhat}'. "
                "Expected VALUE, ROW, COLUMN, *, COUNT, HANDLE, or KEYS.")
    endif ()

    unset(_sel_src_val)
    unset(_sel_where_args)
    unset(_sel_out)
endmacro()

# Worker function signature convention:
#   ARGV0 = source handle VALUE
#   ARGV1 = name of the caller's output variable
#   ARGV2..N = WHERE arguments

# -- SELECT VALUE ----------------------------------------------------------------------------------
function(_hs_sql__select_value srcHndl outVar)
    set(_wargs "")
    set(_wi 2)
    while (_wi LESS ARGC)
        list(APPEND _wargs "${ARGV${_wi}}")
        math(EXPR _wi "${_wi} + 1")
    endwhile ()

    _hs_sql__typeof_value("${srcHndl}" _srcType)

    if (_srcType STREQUAL "DICTIONARY")
        list(GET _wargs 2 _keyName)   # WHERE KEY = "k"  -> index 2 = key name
        set(_sv "${srcHndl}")
        object(STRING _v FROM _sv NAME EQUAL "${_keyName}")
        set(${outVar} "${_v}" PARENT_SCOPE)
        return()
    endif ()

    list(GET _wargs 0 _w0)

    if (_w0 STREQUAL "VALUE")
        # WHERE VALUE LIKE "regex"
        list(GET _wargs 2 _regex)

        _hs_sql__get_meta("${srcHndl}" _metaHndl _columns _nextRowid _fixed)
        _hs_sql__iter_rows("${srcHndl}" _rowHandles)

        set(_matchKeys   "")
        set(_matchValues "")

        foreach (_rh IN LISTS _rowHandles)
            set(_rhv "${_rh}")
            object(NAME _rowLabel FROM _rhv)
            string(REGEX REPLACE "^ROW_" "" _rowid "${_rowLabel}")

            foreach (_col IN LISTS _columns)
                object(STRING _cellVal FROM _rhv NAME EQUAL "${_col}")
                if ("${_cellVal}" STREQUAL "NOTFOUND")
                    continue()
                endif ()
                if ("${_cellVal}" MATCHES "${_regex}")
                    list(APPEND _matchKeys   "ROWID:${_rowid}:COLUMN:${_col}")
                    list(APPEND _matchValues "${_cellVal}")
                endif ()
            endforeach ()
        endforeach ()

        list(LENGTH _matchKeys _hitCount)
        if (_hitCount EQUAL 0)
            set(${outVar} "NOTFOUND" PARENT_SCOPE)
        elseif (_hitCount EQUAL 1)
            list(GET _matchValues 0 _v)
            set(${outVar} "${_v}" PARENT_SCOPE)
        else ()
            object(CREATE _dictHndl KIND DICT LABEL "VALUE_MATCHES")
            set(_ki 0)
            list(LENGTH _matchKeys _kLen)
            while (_ki LESS _kLen)
                list(GET _matchKeys   ${_ki} _k)
                list(GET _matchValues ${_ki} _v)
                object(SET _dictHndl NAME EQUAL "${_k}" STRING "${_v}")
                math(EXPR _ki "${_ki} + 1")
            endwhile ()
            set(${outVar} "${_dictHndl}" PARENT_SCOPE)
        endif ()

    elseif (_w0 STREQUAL "ROWID")
        # WHERE ROWID = <n> AND COLUMN|INDEX = <accessor>
        # _wargs: [0]=ROWID [1]== [2]=<n> [3]=AND [4]=COLUMN|INDEX [5]== [6]=<accessor>
        list(GET _wargs 2 _targetRowid)
        list(GET _wargs 4 _accessType)
        list(GET _wargs 6 _accessor)

        _hs_sql__iter_rows("${srcHndl}" _rowHandles)
        set(_found "NOTFOUND")
        foreach (_rh IN LISTS _rowHandles)
            set(_rhv "${_rh}")
            object(NAME _lbl FROM _rhv)
            if ("${_lbl}" STREQUAL "ROW_${_targetRowid}")
                if (_accessType STREQUAL "COLUMN")
                    object(STRING _cellVal FROM _rhv NAME EQUAL "${_accessor}")
                elseif (_accessType STREQUAL "INDEX")
                    object(STRING _cellVal FROM _rhv INDEX ${_accessor})
                else ()
                    msg(ALWAYS FATAL_ERROR
                            "SELECT VALUE: expected COLUMN or INDEX after AND, got '${_accessType}'")
                endif ()
                set(_found "${_cellVal}")
                break()
            endif ()
        endforeach ()
        set(${outVar} "${_found}" PARENT_SCOPE)
    else ()
        msg(ALWAYS FATAL_ERROR
                "SELECT VALUE: unsupported WHERE form starting with '${_w0}'. "
                "Use WHERE VALUE LIKE <regex>  or  WHERE ROWID = <n> AND COLUMN|INDEX = <accessor>")
    endif ()
endfunction()

# -- SELECT ROW ------------------------------------------------------------------------------------
# WHERE ROWID = <n>
# _wargs[2] = <n>
#
function(_hs_sql__select_row srcHndl outVar)
    # Named params: ARGV0=srcHndl ARGV1=outVar
    # ARGN (where args): [0]=ROWID [1]== [2]=<n>
    list(GET ARGN 2 _targetRowid)

    _hs_sql__iter_rows("${srcHndl}" _rowHandles)
    foreach (_rh IN LISTS _rowHandles)
        set(_rhv "${_rh}")
        object(NAME _lbl FROM _rhv)
        if ("${_lbl}" STREQUAL "ROW_${_targetRowid}")
            set(${outVar} "${_rh}" PARENT_SCOPE)
            return()
        endif ()
    endforeach ()
    set(${outVar} "" PARENT_SCOPE)
endfunction()

# -- SELECT COLUMN ---------------------------------------------------------------------------------
# WHERE COLUMN = "colName"  OR  WHERE INDEX = <i>
# _wargs: [0]=COLUMN|INDEX  [1]==  [2]=<accessor>
#
function(_hs_sql__select_column srcHndl outVar)
    # ARGV0=srcHndl ARGV1=outVar ARGV2=COLUMN|INDEX ARGV3== ARGV4=<accessor>
    set(_accessType "${ARGV2}")
    set(_accessor   "${ARGV4}")

    _hs_sql__get_meta("${srcHndl}" _metaHndl _columns _nextRowid _fixed)

    if (_accessType STREQUAL "INDEX")
        list(GET _columns ${_accessor} _colName)
        if ("${_colName}" STREQUAL "")
            set(${outVar} "" PARENT_SCOPE)
            return()
        endif ()
    elseif (_accessType STREQUAL "COLUMN")
        set(_colName "${_accessor}")
        list(FIND _columns "${_colName}" _colIdx)
        if (_colIdx EQUAL -1)
            set(${outVar} "" PARENT_SCOPE)
            return()
        endif ()
    else ()
        msg(ALWAYS FATAL_ERROR "SELECT COLUMN: expected COLUMN or INDEX in WHERE clause")
    endif ()

    set(_sv "${srcHndl}")
    object(NAME _srcLabelName FROM _sv)
    _hs_sql__create_table(_colTblHndl LABEL "${_srcLabelName}__col_${_colName}" COLUMNS "${_colName}")

    _hs_sql__iter_rows("${srcHndl}" _rowHandles)
    foreach (_rh IN LISTS _rowHandles)
        set(_rhv "${_rh}")
        object(STRING _cellVal FROM _rhv NAME EQUAL "${_colName}")
        if ("${_cellVal}" STREQUAL "NOTFOUND")
            set(_cellVal "")
        endif ()
        _hs_sql__insert_values(_colTblHndl "${_colTblHndl}" VALUES "${_cellVal}")
    endforeach ()

    set(${outVar} "${_colTblHndl}" PARENT_SCOPE)
endfunction()

# -- SELECT * --------------------------------------------------------------------------------------
# WHERE COLUMN "col" = "val" [AND COLUMN "col2" LIKE "pat"] ...
# ARGV0=srcHndl ARGV1=outVar ARGV2+...=where tokens
#
function(_hs_sql__select_star srcHndl outVar)
    set(_condCols "")
    set(_condOps  "")
    set(_condVals "")

    set(_wi 2)
    while (_wi LESS ARGC)
        set(_wa "${ARGV${_wi}}")
        if (_wa STREQUAL "AND")
            math(EXPR _wi "${_wi} + 1")
            continue()
        endif ()
        if (_wa STREQUAL "COLUMN")
            math(EXPR _wi "${_wi} + 1")
            set(_col "${ARGV${_wi}}")
            math(EXPR _wi "${_wi} + 1")
            set(_op "${ARGV${_wi}}")
            math(EXPR _wi "${_wi} + 1")
            set(_val "${ARGV${_wi}}")
            list(APPEND _condCols "${_col}")
            list(APPEND _condOps  "${_op}")
            list(APPEND _condVals "${_val}")
        endif ()
        math(EXPR _wi "${_wi} + 1")
    endwhile ()

    list(LENGTH _condCols _condCount)
    if (_condCount EQUAL 0)
        msg(ALWAYS FATAL_ERROR "SELECT *: no COLUMN conditions supplied after WHERE")
    endif ()

    _hs_sql__get_meta("${srcHndl}" _metaHndl _columns _nextRowid _fixed)
    _hs_sql__iter_rows("${srcHndl}" _rowHandles)

    set(_sv "${srcHndl}")
    object(NAME _srcName FROM _sv)
    _hs_sql__create_table(_resultHndl LABEL "${_srcName}__result" COLUMNS "${_columns}")

    foreach (_rh IN LISTS _rowHandles)
        set(_rhv "${_rh}")
        set(_rowMatches ON)
        set(_ci 0)
        while (_ci LESS _condCount)
            list(GET _condCols ${_ci} _col)
            list(GET _condOps  ${_ci} _op)
            list(GET _condVals ${_ci} _val)

            object(STRING _cellVal FROM _rhv NAME EQUAL "${_col}")
            if ("${_cellVal}" STREQUAL "NOTFOUND")
                set(_rowMatches OFF)
                break()
            endif ()
            if (_op STREQUAL "=")
                if (NOT "${_cellVal}" STREQUAL "${_val}")
                    set(_rowMatches OFF)
                    break()
                endif ()
            elseif (_op STREQUAL "LIKE")
                if (NOT "${_cellVal}" MATCHES "${_val}")
                    set(_rowMatches OFF)
                    break()
                endif ()
            else ()
                msg(ALWAYS FATAL_ERROR "SELECT *: unknown operator '${_op}'. Use = or LIKE.")
            endif ()
            math(EXPR _ci "${_ci} + 1")
        endwhile ()

        if (_rowMatches)
            set(_vals "")
            foreach (_col IN LISTS _columns)
                object(STRING _cv FROM _rhv NAME EQUAL "${_col}")
                if ("${_cv}" STREQUAL "NOTFOUND")
                    set(_cv "")
                endif ()
                list(APPEND _vals "${_cv}")
            endforeach ()
            _hs_sql__insert_values(_resultHndl "${_resultHndl}" VALUES ${_vals})
        endif ()
    endforeach ()

    _hs_sql__get_meta("${_resultHndl}" _rm _rc _rn _rf)
    math(EXPR _rowCount "${_rn} - 1")
    if (_rowCount EQUAL 0)
        set(${outVar} "" PARENT_SCOPE)
    else ()
        set(${outVar} "${_resultHndl}" PARENT_SCOPE)
    endif ()
endfunction()

# -- SELECT COUNT ----------------------------------------------------------------------------------
function(_hs_sql__select_count srcHndl outVar)
    _hs_sql__typeof_value("${srcHndl}" _srcType)
    set(_sv "${srcHndl}")

    if (_srcType STREQUAL "TABLE")
        set(_i 1)
        set(_count 0)
        while (ON)
            object(GET _rh FROM _sv INDEX ${_i})
            if (NOT _rh)
                break()
            endif ()
            math(EXPR _count "${_count} + 1")
            math(EXPR _i "${_i} + 1")
        endwhile ()
        set(${outVar} "${_count}" PARENT_SCOPE)

    elseif (_srcType STREQUAL "COLLECTION")
        set(_i 0)
        set(_count 0)
        while (ON)
            object(GET _rh FROM _sv INDEX ${_i})
            if (NOT _rh)
                break()
            endif ()
            math(EXPR _count "${_count} + 1")
            math(EXPR _i "${_i} + 1")
        endwhile ()
        set(${outVar} "${_count}" PARENT_SCOPE)

    elseif (_srcType STREQUAL "DICTIONARY")
        object(KEYS _keys FROM _sv)
        list(LENGTH _keys _count)
        list(FIND _keys "__HS_OBJ__NAME" _nameIdx)
        if (NOT _nameIdx EQUAL -1)
            math(EXPR _count "${_count} - 1")
        endif ()
        set(${outVar} "${_count}" PARENT_SCOPE)

    else ()
        set(${outVar} "1" PARENT_SCOPE)
    endif ()
endfunction()

# -- SELECT HANDLE ---------------------------------------------------------------------------------
# WHERE KEY   = "key"   (DICTIONARY)
# WHERE NAME  = "name"  (COLLECTION)
# WHERE INDEX = <n>     (COLLECTION)
# ARGV0=srcHndl ARGV1=outVar ARGV2=KEY|NAME|INDEX ARGV3== ARGV4=<value>
#
function(_hs_sql__select_handle srcHndl outVar)
    set(_wType "${ARGV2}")
    set(_wVal  "${ARGV4}")

    _hs_sql__typeof_value("${srcHndl}" _srcType)
    set(_sv "${srcHndl}")

    if (_srcType STREQUAL "DICTIONARY")
        if (NOT _wType STREQUAL "KEY")
            msg(ALWAYS FATAL_ERROR "SELECT HANDLE FROM DICTIONARY: expected WHERE KEY = <key>")
        endif ()
        object(GET _h FROM _sv NAME EQUAL "${_wVal}")
        set(${outVar} "${_h}" PARENT_SCOPE)
        return()
    endif ()

    if (_wType STREQUAL "NAME")
        set(_i 0)
        while (ON)
            object(GET _rh FROM _sv INDEX ${_i})
            if (NOT _rh)
                break()
            endif ()
            set(_rhv "${_rh}")
            object(NAME _lbl FROM _rhv)
            if ("${_lbl}" STREQUAL "${_wVal}")
                set(${outVar} "${_rh}" PARENT_SCOPE)
                return()
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()
        set(${outVar} "" PARENT_SCOPE)

    elseif (_wType STREQUAL "INDEX")
        object(GET _rh FROM _sv INDEX ${_wVal})
        set(${outVar} "${_rh}" PARENT_SCOPE)

    else ()
        msg(ALWAYS FATAL_ERROR
                "SELECT HANDLE: unsupported WHERE key '${_wType}'. Use KEY, NAME, or INDEX.")
    endif ()
endfunction()

# -- SELECT KEYS -----------------------------------------------------------------------------------
# [WHERE KEY LIKE "pattern"]  — omit WHERE clause to return all keys
# ARGV0=srcHndl ARGV1=outVar [ARGV2=KEY ARGV3=LIKE ARGV4=pattern]
#
function(_hs_sql__select_keys srcHndl outVar)
    set(_sv "${srcHndl}")
    object(KEYS _allKeys FROM _sv)
    list(REMOVE_ITEM _allKeys "__HS_OBJ__NAME")

    # Named params: ARGV0=srcHndl ARGV1=outVar; ARGN = where args (may be empty)
    if (ARGC LESS_EQUAL 2)
        set(${outVar} "${_allKeys}" PARENT_SCOPE)
        return()
    endif ()

    # WHERE KEY LIKE "pattern"
    # ARGV2=KEY ARGV3=LIKE ARGV4=pattern
    set(_w0 "${ARGV2}")
    set(_w1 "${ARGV3}")
    set(_pattern "${ARGV4}")
    if (NOT _w0 STREQUAL "KEY" OR NOT _w1 STREQUAL "LIKE")
        msg(ALWAYS FATAL_ERROR "SELECT KEYS: expected WHERE KEY LIKE <pattern>")
    endif ()

    set(_matched "")
    foreach (_k IN LISTS _allKeys)
        if ("${_k}" MATCHES "${_pattern}")
            list(APPEND _matched "${_k}")
        endif ()
    endforeach ()
    set(${outVar} "${_matched}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# UPDATE
# ==================================================================================================
# UPDATE(tableHandle SET COLUMN "col" = "val" WHERE ROWID = <n>)
# UPDATE(tableHandle SET INDEX  <i>   = "val" WHERE ROWID = <n>)
# UPDATE(tableHandle SET COLUMN "col" = "val" WHERE COLUMN "searchCol" = "val")
# UPDATE(tableHandle SET COLUMN "col" = "val" WHERE COLUMN "searchCol" LIKE "pat")
#
macro(UPDATE _tableHandleVar)
    _hs_sql__update("${_tableHandleVar}" "${${_tableHandleVar}}" ${ARGN})
endmacro()

function(_hs_sql__update tableHndlVar tblHndl)
    if (NOT "${ARGV0}" STREQUAL "SET")
        msg(ALWAYS FATAL_ERROR "UPDATE: expected SET, got '${ARGV0}'")
    endif ()

    set(_setArgs   "")
    set(_whereArgs "")
    set(_phase "SET")

    set(_i 1)
    while (_i LESS ARGC)
        set(_arg "${ARGV${_i}}")
        if (_arg STREQUAL "WHERE")
            set(_phase "WHERE")
        elseif (_phase STREQUAL "SET")
            list(APPEND _setArgs "${_arg}")
        else ()
            list(APPEND _whereArgs "${_arg}")
        endif ()
        math(EXPR _i "${_i} + 1")
    endwhile ()

    # SET clause: COLUMN "col" = "val"  OR  INDEX <i> = "val"
    list(GET _setArgs 0 _setType)
    list(GET _setArgs 1 _setAccessor)
    # _setArgs[2] = "="
    list(GET _setArgs 3 _newVal)

    # WHERE clause
    list(GET _whereArgs 0 _whereType)

    _hs_sql__iter_rows("${tblHndl}" _rowHandles)

    foreach (_rh IN LISTS _rowHandles)
        set(_rhv "${_rh}")
        set(_matches OFF)

        if (_whereType STREQUAL "ROWID")
            list(GET _whereArgs 2 _targetRowid)
            object(NAME _lbl FROM _rhv)
            if ("${_lbl}" STREQUAL "ROW_${_targetRowid}")
                set(_matches ON)
            endif ()

        elseif (_whereType STREQUAL "COLUMN")
            list(GET _whereArgs 1 _searchCol)
            list(GET _whereArgs 2 _searchOp)
            list(GET _whereArgs 3 _searchVal)
            object(STRING _cellVal FROM _rhv NAME EQUAL "${_searchCol}")
            if (NOT "${_cellVal}" STREQUAL "NOTFOUND")
                if (_searchOp STREQUAL "=" AND "${_cellVal}" STREQUAL "${_searchVal}")
                    set(_matches ON)
                elseif (_searchOp STREQUAL "LIKE" AND "${_cellVal}" MATCHES "${_searchVal}")
                    set(_matches ON)
                endif ()
            endif ()
        else ()
            msg(ALWAYS FATAL_ERROR "UPDATE WHERE: expected ROWID or COLUMN, got '${_whereType}'")
        endif ()

        if (_matches)
            if (_setType STREQUAL "COLUMN")
                object(SET _rhv NAME EQUAL "${_setAccessor}" VALUE "${_newVal}")
            elseif (_setType STREQUAL "INDEX")
                object(SET _rhv INDEX ${_setAccessor} "${_newVal}")
            else ()
                msg(ALWAYS FATAL_ERROR "UPDATE SET: expected COLUMN or INDEX, got '${_setType}'")
            endif ()
        endif ()
    endforeach ()

    set(${tableHndlVar} "${tblHndl}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# DELETE
# ==================================================================================================
# DELETE(FROM tableHandle WHERE ROWID = <n>)
# DELETE(FROM tableHandle WHERE COLUMN "col" = "val")
# DELETE(FROM tableHandle WHERE COLUMN "col" LIKE "pat")
# DELETE(FROM collHandle  WHERE NAME = "name" [STATUS outVar])
# DELETE(FROM collHandle  WHERE NAME = "name" REPLACE WITH newHandle [STATUS outVar])
#
macro(DELETE _kw _targetHandleVar)
    if (NOT "${_kw}" STREQUAL "FROM")
        msg(ALWAYS FATAL_ERROR "DELETE: expected FROM, got '${_kw}'")
    endif ()

    # ARGV0="WHERE" ARGV1=ROWID|COLUMN|NAME
    set(_del_w1 "${ARGV1}")

    if ("${_del_w1}" STREQUAL "ROWID" OR "${_del_w1}" STREQUAL "COLUMN")
        _hs_sql__delete_from_table("${_targetHandleVar}" "${${_targetHandleVar}}" ${ARGN})
    elseif ("${_del_w1}" STREQUAL "NAME")
        _hs_sql__delete_from_collection("${_targetHandleVar}" "${${_targetHandleVar}}" ${ARGN})
    else ()
        msg(ALWAYS FATAL_ERROR "DELETE WHERE: expected ROWID, COLUMN, or NAME — got '${_del_w1}'")
    endif ()
    unset(_del_w1)
endmacro()

# -- DELETE FROM table -----------------------------------------------------------------------------
# ARGV0=tableHndlVar ARGV1=tblHndl ARGV2=WHERE ARGV3=ROWID|COLUMN ...
#
function(_hs_sql__delete_from_table tableHndlVar tblHndl)
    # ARGV2=WHERE ARGV3=ROWID|COLUMN
    set(_whereType "${ARGV3}")
    _hs_sql__iter_rows("${tblHndl}" _rowHandles)

    foreach (_rh IN LISTS _rowHandles)
        set(_rhv "${_rh}")
        set(_matches OFF)

        if (_whereType STREQUAL "ROWID")
            # ARGV4== ARGV5=<n>
            set(_targetRowid "${ARGV5}")
            object(NAME _lbl FROM _rhv)
            if ("${_lbl}" STREQUAL "ROW_${_targetRowid}")
                set(_matches ON)
            endif ()
        elseif (_whereType STREQUAL "COLUMN")
            # ARGV4="col" ARGV5=op ARGV6="val"
            set(_searchCol "${ARGV4}")
            set(_searchOp  "${ARGV5}")
            set(_searchVal "${ARGV6}")
            object(STRING _cellVal FROM _rhv NAME EQUAL "${_searchCol}")
            if (NOT "${_cellVal}" STREQUAL "NOTFOUND")
                if (_searchOp STREQUAL "=" AND "${_cellVal}" STREQUAL "${_searchVal}")
                    set(_matches ON)
                elseif (_searchOp STREQUAL "LIKE" AND "${_cellVal}" MATCHES "${_searchVal}")
                    set(_matches ON)
                endif ()
            endif ()
        endif ()

        if (_matches)
            object(NAME _rowLabel FROM _rhv)
            set(_tv "${tblHndl}")
            object(REMOVE ARRAY FROM _tv NAME EQUAL "${_rowLabel}")
        endif ()
    endforeach ()

    set(${tableHndlVar} "${tblHndl}" PARENT_SCOPE)
endfunction()

# -- DELETE FROM collection ------------------------------------------------------------------------
# ARGV0=collHndlVar ARGV1=collHndl ARGV2=WHERE ARGV3=NAME ARGV4== ARGV5="name"
# [ARGV6=REPLACE ARGV7=WITH ARGV8=newHandleVar] [ARGVn=STATUS ARGVn+1=outVar]
#
function(_hs_sql__delete_from_collection collHndlVar collHndl)
    set(_targetName "${ARGV5}")

    set(_replaceHndlVar "")
    set(_statusVar "")

    set(_ai 6)
    while (_ai LESS ARGC)
        set(_a "${ARGV${_ai}}")
        if (_a STREQUAL "REPLACE")
            math(EXPR _ai "${_ai} + 2")   # skip "REPLACE WITH"
            set(_replaceHndlVar "${ARGV${_ai}}")
        elseif (_a STREQUAL "STATUS")
            math(EXPR _ai "${_ai} + 1")
            set(_statusVar "${ARGV${_ai}}")
        endif ()
        math(EXPR _ai "${_ai} + 1")
    endwhile ()

    set(_cv "${collHndl}")

    if (_replaceHndlVar)
        set(_rv "${${_replaceHndlVar}}")
        if (_statusVar)
            object(REMOVE ARRAY FROM _cv NAME EQUAL "${_targetName}" REPLACE WITH _rv STATUS _st)
            set(${_statusVar} "${_st}" PARENT_SCOPE)
        else ()
            object(REMOVE ARRAY FROM _cv NAME EQUAL "${_targetName}" REPLACE WITH _rv)
        endif ()
    else ()
        if (_statusVar)
            object(REMOVE ARRAY FROM _cv NAME EQUAL "${_targetName}" STATUS _st)
            set(${_statusVar} "${_st}" PARENT_SCOPE)
        else ()
            object(REMOVE ARRAY FROM _cv NAME EQUAL "${_targetName}")
        endif ()
    endif ()

    set(${collHndlVar} "${_cv}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# SET (Dictionary)
# ==================================================================================================
# SET(dictHandle KEY "key" VALUE "val"         [REPLACE])
# SET(dictHandle KEY "key" HANDLE objectHandle [REPLACE])
#
macro(SET _dictHandleVar)
    _hs_sql__dict_set("${_dictHandleVar}" "${${_dictHandleVar}}" ${ARGN})
endmacro()

function(_hs_sql__dict_set dictHndlVar dictHndl)
    # ARGV0=dictHndlVar ARGV1=dictHndl ARGV2="KEY" ARGV3=keyName ARGV4="VALUE"|"HANDLE" ARGV5=value [ARGV6="REPLACE"]
    if (NOT "${ARGV2}" STREQUAL "KEY")
        msg(ALWAYS FATAL_ERROR "SET: expected KEY, got '${ARGV2}'")
    endif ()
    set(_keyName "${ARGV3}")
    set(_valType "${ARGV4}")
    set(_value   "${ARGV5}")

    set(_replace OFF)
    if (ARGC GREATER_EQUAL 7 AND "${ARGV6}" STREQUAL "REPLACE")
        set(_replace ON)
    endif ()

    _hs_sql__assert_named("${dictHndl}" "SET dictionary key")

    set(_dv "${dictHndl}")
    if (_valType STREQUAL "VALUE")
        if (_replace)
            object(SET _dv NAME EQUAL "${_keyName}" STRING "${_value}" REPLACE)
        else ()
            object(SET _dv NAME EQUAL "${_keyName}" STRING "${_value}")
        endif ()
    elseif (_valType STREQUAL "HANDLE")
        set(_hv "${${_value}}")   # _value is a variable name; dereference it
        if (_replace)
            object(SET _dv NAME EQUAL "${_keyName}" HANDLE _hv REPLACE)
        else ()
            object(SET _dv NAME EQUAL "${_keyName}" HANDLE _hv)
        endif ()
    else ()
        msg(ALWAYS FATAL_ERROR "SET: expected VALUE or HANDLE, got '${_valType}'")
    endif ()

    set(${dictHndlVar} "${_dv}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# ALTER TABLE
# ==================================================================================================
# ALTER(TABLE tableHandle RENAME TO "newName")
# ALTER(TABLE tableHandle ADD COLUMN "colName")
#
macro(ALTER _kw _tableHandleVar)
    if (NOT "${_kw}" STREQUAL "TABLE")
        msg(ALWAYS FATAL_ERROR "ALTER: expected TABLE, got '${_kw}'")
    endif ()
    _hs_sql__alter("${_tableHandleVar}" "${${_tableHandleVar}}" ${ARGN})
endmacro()

function(_hs_sql__alter tableHndlVar tblHndl)
    # ARGV0=tableHndlVar ARGV1=tblHndl ARGV2=RENAME|ADD ...
    set(_op "${ARGV2}")

    if (_op STREQUAL "RENAME")
        # ARGV3=TO ARGV4=newName
        if (NOT "${ARGV3}" STREQUAL "TO")
            msg(ALWAYS FATAL_ERROR "ALTER TABLE RENAME: expected TO, got '${ARGV3}'")
        endif ()
        set(_newName "${ARGV4}")
        set(_tv "${tblHndl}")
        object(RENAME _tv "${_newName}")
        set(${tableHndlVar} "${_tv}" PARENT_SCOPE)

    elseif (_op STREQUAL "ADD")
        # ARGV3=COLUMN ARGV4=colName
        if (NOT "${ARGV3}" STREQUAL "COLUMN")
            msg(ALWAYS FATAL_ERROR "ALTER TABLE ADD: expected COLUMN, got '${ARGV3}'")
        endif ()
        set(_newCol "${ARGV4}")

        _hs_sql__get_meta("${tblHndl}" _metaHndl _columns _nextRowid _fixed)
        if (_fixed STREQUAL "1")
            msg(ALWAYS FATAL_ERROR
                    "ALTER TABLE ADD COLUMN: table is FIXED and cannot have columns added")
        endif ()

        list(APPEND _columns "${_newCol}")
        string(JOIN "${_HS_REC_FIELDS_SEP}" _colsEncoded ${_columns})
        _hs_sql__update_columns("${tblHndl}" "${_colsEncoded}")
        set(${tableHndlVar} "${tblHndl}" PARENT_SCOPE)

    else ()
        msg(ALWAYS FATAL_ERROR "ALTER TABLE: expected RENAME or ADD, got '${_op}'")
    endif ()
endfunction()

# ==================================================================================================
# DESCRIBE
# ==================================================================================================
# DESCRIBE(tableHandle INTO outStringVar)
# Returns: "COLUMNS: col1;col2;col3 | ROWS: <count> | FIXED: YES/NO"
#
macro(DESCRIBE _tableHandleVar _intoKw _outVar)
    if (NOT "${_intoKw}" STREQUAL "INTO")
        msg(ALWAYS FATAL_ERROR "DESCRIBE: expected INTO, got '${_intoKw}'")
    endif ()
    _hs_sql__describe("${${_tableHandleVar}}" "${_outVar}")
endmacro()

function(_hs_sql__describe tblHndl outVar)
    _hs_sql__get_meta("${tblHndl}" _metaHndl _columns _nextRowid _fixed)

    set(_sv "${tblHndl}")
    set(_rowCount 0)
    set(_i 1)
    while (ON)
        object(GET _rh FROM _sv INDEX ${_i})
        if (NOT _rh)
            break()
        endif ()
        math(EXPR _rowCount "${_rowCount} + 1")
        math(EXPR _i "${_i} + 1")
    endwhile ()

    string(JOIN ";" _colStr ${_columns})
    if (_fixed STREQUAL "1")
        set(_fixedStr "YES")
    else ()
        set(_fixedStr "NO")
    endif ()

    set(${outVar} "COLUMNS: ${_colStr} | ROWS: ${_rowCount} | FIXED: ${_fixedStr}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# TYPEOF
# ==================================================================================================
# TYPEOF(handleVar INTO outTypeVar)
# Returns: "TABLE" | "COLLECTION" | "DICTIONARY" | "VIEW" | "STRING"
#
macro(TYPEOF _handleVar _intoKw _outVar)
    if (NOT "${_intoKw}" STREQUAL "INTO")
        msg(ALWAYS FATAL_ERROR "TYPEOF: expected INTO, got '${_intoKw}'")
    endif ()
    _hs_sql__typeof_value("${${_handleVar}}" "${_outVar}")
endmacro()

# ==================================================================================================
# ASSERT
# ==================================================================================================
# ASSERT(handleVar IS expectedType [expectedType2 ...])
#
macro(ASSERT _handleVar _isKw)
    if (NOT "${_isKw}" STREQUAL "IS")
        msg(ALWAYS FATAL_ERROR "ASSERT: expected IS, got '${_isKw}'")
    endif ()
    _hs_sql__assert_type("${${_handleVar}}" ${ARGN})
endmacro()

function(_hs_sql__assert_type hndlValue)
    _hs_sql__typeof_value("${hndlValue}" _actualType)
    set(_allowed ${ARGN})

    list(FIND _allowed "${_actualType}" _idx)
    if (_idx EQUAL -1)
        string(JOIN " | " _allowedStr ${_allowed})
        msg(ALWAYS FATAL_ERROR
                "ASSERT: expected type ${_allowedStr}, but handle is ${_actualType}")
    endif ()
endfunction()

# ==================================================================================================
# LABEL
# ==================================================================================================
# LABEL(OF handleVar INTO outLabelVar)
#
macro(LABEL _ofKw _handleVar _intoKw _outVar)
    if (NOT "${_ofKw}" STREQUAL "OF")
        msg(ALWAYS FATAL_ERROR "LABEL: expected OF, got '${_ofKw}'")
    endif ()
    if (NOT "${_intoKw}" STREQUAL "INTO")
        msg(ALWAYS FATAL_ERROR "LABEL: expected INTO, got '${_intoKw}'")
    endif ()
    _hs_sql__get_label("${${_handleVar}}" "${_outVar}")
endmacro()

function(_hs_sql__get_label hndlValue outVar)
    set(_hv "${hndlValue}")
    object(NAME _lbl FROM _hv)
    if ("${_lbl}" STREQUAL "")
        set(_lbl "<unnamed>")
    endif ()
    set(${outVar} "${_lbl}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# DUMP
# ==================================================================================================
# DUMP(handleVar INTO outStringVar)
#
macro(DUMP _handleVar _intoKw _outVar)
    if (NOT "${_intoKw}" STREQUAL "INTO")
        msg(ALWAYS FATAL_ERROR "DUMP: expected INTO, got '${_intoKw}'")
    endif ()
    _hs_sql__dump("${${_handleVar}}" "${_outVar}")
endmacro()

function(_hs_sql__dump hndlValue outVar)
    set(_hv "${hndlValue}")
    object(DUMP _hv _dump)
    set(${outVar} "${_dump}" PARENT_SCOPE)
endfunction()

# ==================================================================================================
# FOREACH
# ==================================================================================================
# FOREACH(ROW    IN tableHandle CALL functionName)
# FOREACH(HANDLE IN collHandle  CALL functionName)
# FOREACH(KEY    IN dictHandle  CALL functionName)
#
macro(FOREACH _iterType _inKw _handleVar _callKw _functionName)
    if (NOT "${_inKw}" STREQUAL "IN")
        msg(ALWAYS FATAL_ERROR "FOREACH: expected IN, got '${_inKw}'")
    endif ()
    if (NOT "${_callKw}" STREQUAL "CALL")
        msg(ALWAYS FATAL_ERROR "FOREACH: expected CALL, got '${_callKw}'")
    endif ()
    _hs_sql__foreach("${_iterType}" "${${_handleVar}}" "${_functionName}")
endmacro()

function(_hs_sql__foreach iterType hndlValue functionName)
    set(_sv "${hndlValue}")

    if (iterType STREQUAL "ROW")
        _hs_sql__iter_rows("${hndlValue}" _rowHandles)
        foreach (_rh IN LISTS _rowHandles)
            cmake_language(CALL "${functionName}" "${_rh}")
        endforeach ()

    elseif (iterType STREQUAL "HANDLE")
        set(_i 0)
        while (ON)
            object(GET _rh FROM _sv INDEX ${_i})
            if (NOT _rh)
                break()
            endif ()
            cmake_language(CALL "${functionName}" "${_rh}")
            math(EXPR _i "${_i} + 1")
        endwhile ()

    elseif (iterType STREQUAL "KEY")
        object(KEYS _keys FROM _sv)
        list(REMOVE_ITEM _keys "__HS_OBJ__NAME")
        foreach (_k IN LISTS _keys)
            object(STRING _kval FROM _sv NAME EQUAL "${_k}")
            if ("${_kval}" STREQUAL "NOTFOUND")
                object(GET _hv FROM _sv NAME EQUAL "${_k}")
                cmake_language(CALL "${functionName}" "${_k}" "${_hv}")
            else ()
                cmake_language(CALL "${functionName}" "${_k}" "${_kval}")
            endif ()
        endforeach ()

    else ()
        msg(ALWAYS FATAL_ERROR "FOREACH: expected ROW, HANDLE, or KEY, got '${iterType}'")
    endif ()
endfunction()