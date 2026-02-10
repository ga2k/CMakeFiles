include_guard(GLOBAL)

# object_sql.cmake
# SQL-style wrapper API for object.cmake
#
# Provides familiar SQL syntax (CREATE TABLE, SELECT, INSERT, UPDATE, DELETE)
# as a higher-level interface to the object(...) layer.

if (NOT COMMAND object)
    include(${CMAKE_SOURCE_DIR}/cmake/object.cmake)
endif ()

# =================================================================================================
# Schema Definition Language (DDL)
# =================================================================================================

# CREATE TABLE <handleVar> [AS <name>] [COLUMNS (<col1>, <col2>, ...)] [FIXED]
function(CREATE)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 2)
        message(FATAL_ERROR "CREATE: expected at least TABLE|COLLECTION|DICTIONARY <handleVar>")
    endif()
    
    list(GET _args 0 _objectType)
    list(GET _args 1 _handleVar)
    list(REMOVE_AT _args 0 1)
    
    # Parse remaining arguments
    set(_state "INITIAL")
    set(_name "")
    set(_columns "")
    set(_fixed OFF)
    set(_size "")
    set(_collectionType "")
    
    foreach(_arg IN LISTS _args)
        if (_state STREQUAL "INITIAL")
            if ("${_arg}" STREQUAL "AS")
                set(_state "NAME")
            elseif ("${_arg}" STREQUAL "COLUMNS")
                set(_state "COLUMNS")
            elseif ("${_arg}" STREQUAL "FIXED")
                set(_fixed ON)
            elseif ("${_arg}" STREQUAL "OF")
                set(_state "COLLECTION_TYPE")
            else()
                message(FATAL_ERROR "CREATE ${_objectType}: unexpected argument '${_arg}'")
            endif()
        elseif (_state STREQUAL "NAME")
            set(_name "${_arg}")
            set(_state "INITIAL")
        elseif (_state STREQUAL "COLUMNS")
            # Expect parenthesized list - we'll parse as single arg containing commas
            set(_columns "${_arg}")
            set(_state "INITIAL")
        elseif (_state STREQUAL "COLLECTION_TYPE")
            set(_collectionType "${_arg}")
            set(_state "INITIAL")
        endif()
    endforeach()
    
    # ===== CREATE TABLE =====
    if (_objectType STREQUAL "TABLE")
        set(_createArgs "")
        if (NOT "${_name}" STREQUAL "")
            list(APPEND _createArgs LABEL "${_name}")
        endif()
        
        if (NOT "${_columns}" STREQUAL "")
            # Parse columns: remove parens and split by comma
            string(REGEX REPLACE "^\\((.*)\\)$" "\\1" _colsClean "${_columns}")
            string(REPLACE "," ";" _colsList "${_colsClean}")
            
            # Trim whitespace from each column
            set(_colsCleanList "")
            foreach(_col IN LISTS _colsList)
                string(STRIP "${_col}" _colTrim)
                list(APPEND _colsCleanList "${_colTrim}")
            endforeach()
            
            # Convert to semicolon-separated for FIELDS
            list(JOIN _colsCleanList ";" _fieldsStr)
            list(APPEND _createArgs FIELDS "${_fieldsStr}")
        endif()
        
        if (_fixed)
            list(APPEND _createArgs FIXED)
        endif()
        
        object(CREATE ${_handleVar} KIND RECORD ${_createArgs})
        set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== CREATE COLLECTION =====
    if (_objectType STREQUAL "COLLECTION")
        if ("${_collectionType}" STREQUAL "")
            message(FATAL_ERROR "CREATE COLLECTION: missing OF RECORDS|ARRAYS")
        endif()
        
        set(_createArgs "")
        if (NOT "${_name}" STREQUAL "")
            list(APPEND _createArgs LABEL "${_name}")
        endif()
        
        if (_collectionType STREQUAL "RECORDS")
            list(APPEND _createArgs TYPE RECORDS)
        elseif (_collectionType STREQUAL "ARRAYS")
            list(APPEND _createArgs TYPE ARRAYS)
        else()
            message(FATAL_ERROR "CREATE COLLECTION: OF must be RECORDS or ARRAYS, got '${_collectionType}'")
        endif()
        
        object(CREATE ${_handleVar} KIND ARRAY ${_createArgs})
        set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== CREATE DICTIONARY =====
    if (_objectType STREQUAL "DICTIONARY")
        set(_createArgs "")
        if (NOT "${_name}" STREQUAL "")
            list(APPEND _createArgs LABEL "${_name}")
        endif()
        
        object(CREATE ${_handleVar} KIND DICT ${_createArgs})
        set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    message(FATAL_ERROR "CREATE: unknown object type '${_objectType}'. Expected TABLE, COLLECTION, or DICTIONARY")
endfunction()

# ALTER TABLE <handleVar> RENAME TO <newName>
# ALTER TABLE <handleVar> ADD COLUMNS (<col1>, <col2>, ...)
function(ALTER)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 2)
        message(FATAL_ERROR "ALTER: expected TABLE <handleVar> RENAME TO|ADD COLUMNS ...")
    endif()
    
    list(GET _args 0 _objectType)
    list(GET _args 1 _handleVar)
    list(REMOVE_AT _args 0 1)
    
    if (NOT _objectType STREQUAL "TABLE")
        message(FATAL_ERROR "ALTER: only TABLE is supported, got '${_objectType}'")
    endif()
    
    list(LENGTH _args _remainingArgc)
    if (_remainingArgc LESS 1)
        message(FATAL_ERROR "ALTER TABLE: expected RENAME or ADD")
    endif()
    
    list(GET _args 0 _operation)
    list(REMOVE_AT _args 0)
    
    # ===== RENAME TO =====
    if (_operation STREQUAL "RENAME")
        list(LENGTH _args _argc2)
        if (_argc2 LESS 2)
            message(FATAL_ERROR "ALTER TABLE RENAME: expected TO <newName>")
        endif()
        
        list(GET _args 0 _to)
        list(GET _args 1 _newName)
        
        if (NOT _to STREQUAL "TO")
            message(FATAL_ERROR "ALTER TABLE RENAME: expected TO, got '${_to}'")
        endif()
        
        object(RENAME ${_handleVar} "${_newName}")
        set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== ADD COLUMNS =====
    if (_operation STREQUAL "ADD")
        list(LENGTH _args _argc2)
        if (_argc2 LESS 2)
            message(FATAL_ERROR "ALTER TABLE ADD: expected COLUMNS (<col1>, ...)")
        endif()
        
        list(GET _args 0 _columns_kw)
        list(GET _args 1 _columns)
        
        if (NOT _columns_kw STREQUAL "COLUMNS")
            message(FATAL_ERROR "ALTER TABLE ADD: expected COLUMNS, got '${_columns_kw}'")
        endif()
        
        # Parse columns: remove parens and split by comma
        string(REGEX REPLACE "^\\((.*)\\)$" "\\1" _colsClean "${_columns}")
        string(REPLACE "," ";" _colsList "${_colsClean}")
        
        # Trim whitespace from each column
        set(_colsCleanList "")
        foreach(_col IN LISTS _colsList)
            string(STRIP "${_col}" _colTrim)
            list(APPEND _colsCleanList "${_colTrim}")
        endforeach()
        
        # Convert to semicolon-separated for NAMES
        list(JOIN _colsCleanList ";" _fieldsStr)
        
        object(FIELD_NAMES ${_handleVar} NAMES "${_fieldsStr}")
        set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    message(FATAL_ERROR "ALTER TABLE: unknown operation '${_operation}'. Expected RENAME or ADD")
endfunction()

# =================================================================================================
# Data Query Language (DQL) - SELECT
# =================================================================================================

# SELECT * FROM <handleVar> WHERE KEY = <key> INTO <outHandleVar>
# SELECT * FROM <handleVar> WHERE INDEX = <n> INTO <outHandleVar>
# SELECT * FROM <handleVar> WHERE PATH = "<path>" INTO <outHandleVar>
# SELECT * FROM <handleVar> WHERE PATH LIKE "<glob>" INTO <outHandleVar>
# SELECT VALUE FROM <handleVar> WHERE KEY = <key> INTO <outStrVar>
# SELECT <column> FROM <handleVar> WHERE NAME = <value> INTO <outStrVar>
# SELECT COLUMN <n> FROM <handleVar> INTO <outStrVar>
# SELECT VALUE FROM <handleVar> WHERE PATH = "<path>" INTO <outStrVar>
# SELECT MATCHES FROM <handleVar> WHERE PATH LIKE "<glob>" INTO <outHandleVar>
# SELECT HANDLES FROM <handleVar> INTO <outListVar>
function(SELECT)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 1)
        message(FATAL_ERROR "SELECT: expected column or *")
    endif()
    
    list(GET _args 0 _selectWhat)
    list(REMOVE_AT _args 0)
    
    # ===== SELECT HANDLES FROM <handle> INTO <out> =====
    if (_selectWhat STREQUAL "HANDLES")
        list(LENGTH _args _argc2)
        if (_argc2 LESS 4)
            message(FATAL_ERROR "SELECT HANDLES: expected FROM <handleVar> INTO <outVar>")
        endif()
        
        list(GET _args 0 _from_kw)
        list(GET _args 1 _handleVar)
        list(GET _args 2 _into_kw)
        list(GET _args 3 _outVar)
        
        if (NOT _from_kw STREQUAL "FROM")
            message(FATAL_ERROR "SELECT HANDLES: expected FROM, got '${_from_kw}'")
        endif()
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT HANDLES: expected INTO, got '${_into_kw}'")
        endif()
        
        object(ITER_HANDLES ${_outVar} FROM ${_handleVar} CHILDREN)
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== SELECT MATCHES FROM <handle> WHERE PATH LIKE <glob> INTO <out> =====
    if (_selectWhat STREQUAL "MATCHES")
        list(LENGTH _args _argc2)
        if (_argc2 LESS 6)
            message(FATAL_ERROR "SELECT MATCHES: expected FROM <handle> WHERE PATH LIKE <glob> INTO <out>")
        endif()
        
        list(GET _args 0 _from_kw)
        list(GET _args 1 _handleVar)
        list(GET _args 2 _where_kw)
        list(GET _args 3 _path_kw)
        list(GET _args 4 _like_kw)
        list(GET _args 5 _glob)
        list(GET _args 6 _into_kw)
        list(GET _args 7 _outVar)
        
        if (NOT _from_kw STREQUAL "FROM")
            message(FATAL_ERROR "SELECT MATCHES: expected FROM, got '${_from_kw}'")
        endif()
        if (NOT _where_kw STREQUAL "WHERE")
            message(FATAL_ERROR "SELECT MATCHES: expected WHERE, got '${_where_kw}'")
        endif()
        if (NOT _path_kw STREQUAL "PATH")
            message(FATAL_ERROR "SELECT MATCHES: expected PATH, got '${_path_kw}'")
        endif()
        if (NOT _like_kw STREQUAL "LIKE")
            message(FATAL_ERROR "SELECT MATCHES: expected LIKE, got '${_like_kw}'")
        endif()
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT MATCHES: expected INTO, got '${_into_kw}'")
        endif()
        
        object(MATCHES ${_outVar} FROM ${_handleVar} PATH MATCHING "${_glob}")
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # Parse FROM clause (required for most SELECT variants)
    list(LENGTH _args _argc2)
    if (_argc2 LESS 2)
        message(FATAL_ERROR "SELECT: expected FROM <handleVar> ...")
    endif()
    
    list(GET _args 0 _from_kw)
    if (NOT _from_kw STREQUAL "FROM")
        message(FATAL_ERROR "SELECT: expected FROM, got '${_from_kw}'")
    endif()
    
    list(GET _args 1 _handleVar)
    list(REMOVE_AT _args 0 1)
    
    # ===== SELECT * FROM <handle> INTO <out> (no WHERE clause) =====
    if (_selectWhat STREQUAL "*" AND _argc2 EQUAL 4)
        list(GET _args 0 _into_kw)
        list(GET _args 1 _outVar)
        
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT * FROM: expected INTO, got '${_into_kw}'")
        endif()
        
        # This is a simple pass-through / identity
        set(${_outVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # Parse WHERE clause (for most other SELECT variants)
    list(LENGTH _args _remainingArgc)
    if (_remainingArgc LESS 1)
        message(FATAL_ERROR "SELECT: expected WHERE clause or INTO")
    endif()
    
    list(GET _args 0 _next)
    
    # ===== SELECT COLUMN <n> FROM <handle> INTO <out> (no WHERE) =====
    if (_selectWhat STREQUAL "COLUMN")
        # _handleVar is actually the column index
        set(_colIndex "${_handleVar}")
        
        # Next should be FROM
        if (NOT _next STREQUAL "FROM")
            message(FATAL_ERROR "SELECT COLUMN: expected FROM after column index, got '${_next}'")
        endif()
        
        list(REMOVE_AT _args 0)
        list(GET _args 0 _actualHandleVar)
        list(GET _args 1 _into_kw)
        list(GET _args 2 _outVar)
        
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT COLUMN: expected INTO, got '${_into_kw}'")
        endif()
        
        object(STRING ${_outVar} FROM ${_actualHandleVar} INDEX ${_colIndex})
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    if (NOT _next STREQUAL "WHERE")
        message(FATAL_ERROR "SELECT: expected WHERE, got '${_next}'")
    endif()
    
    list(REMOVE_AT _args 0)
    
    # Parse condition
    list(LENGTH _args _condArgc)
    if (_condArgc LESS 1)
        message(FATAL_ERROR "SELECT: WHERE clause requires condition")
    endif()
    
    list(GET _args 0 _conditionType)
    list(REMOVE_AT _args 0)
    
    # ===== WHERE KEY = <key> =====
    if (_conditionType STREQUAL "KEY")
        list(LENGTH _args _argc3)
        if (_argc3 LESS 4)
            message(FATAL_ERROR "SELECT: WHERE KEY = <key> INTO <out>")
        endif()
        
        list(GET _args 0 _eq)
        list(GET _args 1 _key)
        list(GET _args 2 _into_kw)
        list(GET _args 3 _outVar)
        
        if (NOT _eq STREQUAL "=")
            message(FATAL_ERROR "SELECT WHERE KEY: expected =, got '${_eq}'")
        endif()
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT WHERE KEY: expected INTO, got '${_into_kw}'")
        endif()
        
        if (_selectWhat STREQUAL "*")
            object(GET ${_outVar} FROM ${_handleVar} NAME EQUAL "${_key}")
        elseif (_selectWhat STREQUAL "VALUE")
            object(STRING ${_outVar} FROM ${_handleVar} NAME EQUAL "${_key}")
        else()
            message(FATAL_ERROR "SELECT <column> WHERE KEY: expected * or VALUE, got '${_selectWhat}'")
        endif()
        
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== WHERE INDEX = <n> =====
    if (_conditionType STREQUAL "INDEX")
        list(LENGTH _args _argc3)
        if (_argc3 LESS 4)
            message(FATAL_ERROR "SELECT: WHERE INDEX = <n> INTO <out>")
        endif()
        
        list(GET _args 0 _eq)
        list(GET _args 1 _index)
        list(GET _args 2 _into_kw)
        list(GET _args 3 _outVar)
        
        if (NOT _eq STREQUAL "=")
            message(FATAL_ERROR "SELECT WHERE INDEX: expected =, got '${_eq}'")
        endif()
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT WHERE INDEX: expected INTO, got '${_into_kw}'")
        endif()
        
        if (_selectWhat STREQUAL "*")
            object(GET ${_outVar} FROM ${_handleVar} INDEX ${_index})
        elseif (_selectWhat STREQUAL "VALUE")
            object(STRING ${_outVar} FROM ${_handleVar} INDEX ${_index})
        else()
            message(FATAL_ERROR "SELECT <column> WHERE INDEX: expected * or VALUE, got '${_selectWhat}'")
        endif()
        
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== WHERE NAME = <fieldName> =====
    if (_conditionType STREQUAL "NAME")
        list(LENGTH _args _argc3)
        if (_argc3 LESS 4)
            message(FATAL_ERROR "SELECT: WHERE NAME = <name> INTO <out>")
        endif()
        
        list(GET _args 0 _eq)
        list(GET _args 1 _fieldName)
        list(GET _args 2 _into_kw)
        list(GET _args 3 _outVar)
        
        if (NOT _eq STREQUAL "=")
            message(FATAL_ERROR "SELECT WHERE NAME: expected =, got '${_eq}'")
        endif()
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT WHERE NAME: expected INTO, got '${_into_kw}'")
        endif()
        
        # _selectWhat is the column name
        if (_selectWhat STREQUAL "VALUE")
            message(FATAL_ERROR "SELECT VALUE WHERE NAME: ambiguous. Use SELECT <column> FROM ... WHERE NAME = <name>")
        endif()
        
        object(STRING ${_outVar} FROM ${_handleVar} NAME EQUAL "${_fieldName}")
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== WHERE PATH = <path> or WHERE PATH LIKE <glob> =====
    if (_conditionType STREQUAL "PATH")
        list(LENGTH _args _argc3)
        if (_argc3 LESS 4)
            message(FATAL_ERROR "SELECT: WHERE PATH = <path> INTO <out>")
        endif()
        
        list(GET _args 0 _op)
        list(GET _args 1 _pathOrGlob)
        list(GET _args 2 _into_kw)
        list(GET _args 3 _outVar)
        
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "SELECT WHERE PATH: expected INTO, got '${_into_kw}'")
        endif()
        
        if (_op STREQUAL "=")
            # Exact path
            if (_selectWhat STREQUAL "*")
                object(GET ${_outVar} FROM ${_handleVar} PATH EQUAL "${_pathOrGlob}")
            elseif (_selectWhat STREQUAL "VALUE")
                object(STRING ${_outVar} FROM ${_handleVar} PATH EQUAL "${_pathOrGlob}")
            else()
                message(FATAL_ERROR "SELECT <column> WHERE PATH: expected * or VALUE, got '${_selectWhat}'")
            endif()
        elseif (_op STREQUAL "LIKE")
            # Glob path
            if (_selectWhat STREQUAL "*")
                object(GET ${_outVar} FROM ${_handleVar} PATH MATCHING "${_pathOrGlob}")
            elseif (_selectWhat STREQUAL "VALUE")
                object(STRING ${_outVar} FROM ${_handleVar} PATH MATCHING "${_pathOrGlob}")
            else()
                message(FATAL_ERROR "SELECT <column> WHERE PATH LIKE: expected * or VALUE, got '${_selectWhat}'")
            endif()
        else()
            message(FATAL_ERROR "SELECT WHERE PATH: expected = or LIKE, got '${_op}'")
        endif()
        
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    message(FATAL_ERROR "SELECT: unknown WHERE condition type '${_conditionType}'")
endfunction()

# =================================================================================================
# Data Manipulation Language (DML) - INSERT
# =================================================================================================

# INSERT INTO <handleVar> VALUES (<v1>, <v2>, ...) [AT INDEX <n>]
# INSERT INTO <handleVar> (<column>) VALUES (<value>)
# INSERT INTO <handleVar> (KEY <key>) VALUES OBJECT <childHandleVar> [REPLACE]
# INSERT INTO <handleVar> (KEY <key>) VALUES STRING <value> [REPLACE]
# INSERT INTO <handleVar> VALUES RECORD <recordHandleVar>
# INSERT INTO <handleVar> VALUES ARRAY <arrayHandleVar>
function(INSERT)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 4)
        message(FATAL_ERROR "INSERT: expected INTO <handleVar> ...")
    endif()
    
    list(GET _args 0 _into_kw)
    list(GET _args 1 _handleVar)
    
    if (NOT _into_kw STREQUAL "INTO")
        message(FATAL_ERROR "INSERT: expected INTO, got '${_into_kw}'")
    endif()
    
    list(REMOVE_AT _args 0 1)
    
    list(GET _args 0 _next)
    
    # ===== INSERT INTO <handle> VALUES (<v1>, <v2>, ...) [AT INDEX <n>] =====
    # ===== INSERT INTO <handle> VALUES RECORD <rec> =====
    # ===== INSERT INTO <handle> VALUES ARRAY <arr> =====
    if (_next STREQUAL "VALUES")
        list(REMOVE_AT _args 0)
        list(LENGTH _args _valArgc)
        
        if (_valArgc LESS 1)
            message(FATAL_ERROR "INSERT INTO VALUES: expected values")
        endif()
        
        list(GET _args 0 _firstVal)
        
        # Check if it's VALUES RECORD or VALUES ARRAY
        if (_firstVal STREQUAL "RECORD")
            list(GET _args 1 _recHandleVar)
            object(APPEND ${_handleVar} RECORD ${_recHandleVar})
            set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
            return()
        endif()
        
        if (_firstVal STREQUAL "ARRAY")
            list(GET _args 1 _arrHandleVar)
            object(APPEND ${_handleVar} ARRAY ${_arrHandleVar})
            set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
            return()
        endif()
        
        # Otherwise it's bulk values: VALUES (<v1>, <v2>, ...)
        # Parse parenthesized list
        string(REGEX REPLACE "^\\((.*)\\)$" "\\1" _valsClean "${_firstVal}")
        string(REPLACE "," ";" _valsList "${_valsClean}")
        
        # Trim whitespace
        set(_valsCleanList "")
        foreach(_val IN LISTS _valsList)
            string(STRIP "${_val}" _valTrim)
            list(APPEND _valsCleanList "${_valTrim}")
        endforeach()
        
        # Check for AT INDEX
        list(LENGTH _args _remainingArgc)
        set(_index 0)
        if (_remainingArgc GREATER 1)
            list(GET _args 1 _at_kw)
            if (_at_kw STREQUAL "AT")
                list(GET _args 2 _index_kw)
                list(GET _args 3 _indexVal)
                
                if (NOT _index_kw STREQUAL "INDEX")
                    message(FATAL_ERROR "INSERT INTO VALUES AT: expected INDEX, got '${_index_kw}'")
                endif()
                
                set(_index "${_indexVal}")
            endif()
        endif()
        
        object(SET ${_handleVar} INDEX ${_index} ${_valsCleanList})
        set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
        return()
    endif()
    
    # ===== INSERT INTO <handle> (<column>) VALUES (<value>) =====
    # ===== INSERT INTO <handle> (KEY <key>) VALUES OBJECT <child> [REPLACE] =====
    # ===== INSERT INTO <handle> (KEY <key>) VALUES STRING <value> [REPLACE] =====
    if (_next MATCHES "^\\(.*\\)$")
        # Parse the column/key specification
        string(REGEX REPLACE "^\\((.*)\\)$" "\\1" _keySpec "${_next}")
        string(STRIP "${_keySpec}" _keySpec)
        
        list(REMOVE_AT _args 0)
        list(LENGTH _args _argc2)
        
        if (_argc2 LESS 2)
            message(FATAL_ERROR "INSERT INTO (...): expected VALUES ...")
        endif()
        
        list(GET _args 0 _values_kw)
        if (NOT _values_kw STREQUAL "VALUES")
            message(FATAL_ERROR "INSERT INTO (...): expected VALUES, got '${_values_kw}'")
        endif()
        
        list(REMOVE_AT _args 0)
        
        # Check if it's (KEY <key>) or (<column>)
        if (_keySpec MATCHES "^KEY ")
            # Dictionary insertion: (KEY <key>) VALUES OBJECT|STRING <value> [REPLACE]
            string(REGEX REPLACE "^KEY +(.*)$" "\\1" _key "${_keySpec}")
            
            list(LENGTH _args _argc3)
            if (_argc3 LESS 2)
                message(FATAL_ERROR "INSERT INTO (KEY ...): expected OBJECT|STRING <value>")
            endif()
            
            list(GET _args 0 _valueType)
            list(GET _args 1 _value)
            
            set(_replace OFF)
            if (_argc3 GREATER 2)
                list(GET _args 2 _replace_kw)
                if (_replace_kw STREQUAL "REPLACE")
                    set(_replace ON)
                endif()
            endif()
            
            if (_valueType STREQUAL "OBJECT")
                if (_replace)
                    object(SET ${_handleVar} NAME EQUAL "${_key}" HANDLE ${_value} REPLACE)
                else()
                    object(SET ${_handleVar} NAME EQUAL "${_key}" HANDLE ${_value})
                endif()
            elseif (_valueType STREQUAL "STRING")
                if (_replace)
                    object(SET ${_handleVar} NAME EQUAL "${_key}" STRING "${_value}" REPLACE)
                else()
                    object(SET ${_handleVar} NAME EQUAL "${_key}" STRING "${_value}")
                endif()
            else()
                message(FATAL_ERROR "INSERT INTO (KEY ...): expected OBJECT or STRING, got '${_valueType}'")
            endif()
            
            set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
            return()
        else()
            # Record field insertion: (<column>) VALUES (<value>)
            set(_column "${_keySpec}")
            
            list(GET _args 0 _valueParens)
            string(REGEX REPLACE "^\\((.*)\\)$" "\\1" _value "${_valueParens}")
            string(STRIP "${_value}" _value)
            
            object(SET ${_handleVar} NAME EQUAL "${_column}" VALUE "${_value}")
            set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
            return()
        endif()
    endif()
    
    message(FATAL_ERROR "INSERT INTO: unexpected argument '${_next}'")
endfunction()

# =================================================================================================
# Data Manipulation Language (DML) - UPDATE
# =================================================================================================

# UPDATE <handleVar> SET <column> = <value> WHERE NAME = <fieldName>
function(UPDATE)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 7)
        message(FATAL_ERROR "UPDATE: expected <handleVar> SET <column> = <value> WHERE NAME = <fieldName>")
    endif()
    
    list(GET _args 0 _handleVar)
    list(GET _args 1 _set_kw)
    list(GET _args 2 _column)
    list(GET _args 3 _eq)
    list(GET _args 4 _value)
    list(GET _args 5 _where_kw)
    list(GET _args 6 _name_kw)
    list(GET _args 7 _eq2)
    list(GET _args 8 _fieldName)
    
    if (NOT _set_kw STREQUAL "SET")
        message(FATAL_ERROR "UPDATE: expected SET, got '${_set_kw}'")
    endif()
    if (NOT _eq STREQUAL "=")
        message(FATAL_ERROR "UPDATE SET: expected =, got '${_eq}'")
    endif()
    if (NOT _where_kw STREQUAL "WHERE")
        message(FATAL_ERROR "UPDATE: expected WHERE, got '${_where_kw}'")
    endif()
    if (NOT _name_kw STREQUAL "NAME")
        message(FATAL_ERROR "UPDATE WHERE: expected NAME, got '${_name_kw}'")
    endif()
    if (NOT _eq2 STREQUAL "=")
        message(FATAL_ERROR "UPDATE WHERE NAME: expected =, got '${_eq2}'")
    endif()
    
    object(SET ${_handleVar} NAME EQUAL "${_fieldName}" VALUE "${_value}")
    set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
endfunction()

# =================================================================================================
# Data Manipulation Language (DML) - DELETE
# =================================================================================================

# DELETE FROM <handleVar> WHERE NAME = <childName> [REPLACE WITH <newHandleVar>] [STATUS <resultVar>]
function(DELETE)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 6)
        message(FATAL_ERROR "DELETE: expected FROM <handleVar> WHERE NAME = <name> ...")
    endif()
    
    list(GET _args 0 _from_kw)
    list(GET _args 1 _handleVar)
    list(GET _args 2 _where_kw)
    list(GET _args 3 _name_kw)
    list(GET _args 4 _eq)
    list(GET _args 5 _childName)
    
    if (NOT _from_kw STREQUAL "FROM")
        message(FATAL_ERROR "DELETE: expected FROM, got '${_from_kw}'")
    endif()
    if (NOT _where_kw STREQUAL "WHERE")
        message(FATAL_ERROR "DELETE FROM: expected WHERE, got '${_where_kw}'")
    endif()
    if (NOT _name_kw STREQUAL "NAME")
        message(FATAL_ERROR "DELETE WHERE: expected NAME, got '${_name_kw}'")
    endif()
    if (NOT _eq STREQUAL "=")
        message(FATAL_ERROR "DELETE WHERE NAME: expected =, got '${_eq}'")
    endif()
    
    list(REMOVE_AT _args 0 1 2 3 4 5)
    
    # Parse optional REPLACE WITH and STATUS
    set(_replaceWith "")
    set(_statusVar "")
    
    set(_state "INITIAL")
    foreach(_arg IN LISTS _args)
        if (_state STREQUAL "INITIAL")
            if (_arg STREQUAL "REPLACE")
                set(_state "WITH")
            elseif (_arg STREQUAL "STATUS")
                set(_state "STATUS_VAR")
            else()
                message(FATAL_ERROR "DELETE: unexpected argument '${_arg}'")
            endif()
        elseif (_state STREQUAL "WITH")
            if (NOT _arg STREQUAL "WITH")
                message(FATAL_ERROR "DELETE REPLACE: expected WITH, got '${_arg}'")
            endif()
            set(_state "REPLACE_VALUE")
        elseif (_state STREQUAL "REPLACE_VALUE")
            set(_replaceWith "${_arg}")
            set(_state "INITIAL")
        elseif (_state STREQUAL "STATUS_VAR")
            set(_statusVar "${_arg}")
            set(_state "INITIAL")
        endif()
    endforeach()
    
    # Build object(REMOVE ...) call
    set(_removeArgs "ARRAY" "FROM" ${_handleVar} "NAME" "EQUAL" "${_childName}")
    
    if (NOT "${_replaceWith}" STREQUAL "")
        list(APPEND _removeArgs "REPLACE" "WITH" ${_replaceWith})
    endif()
    
    if (NOT "${_statusVar}" STREQUAL "")
        list(APPEND _removeArgs "STATUS" _internalStatus)
    endif()
    
    object(REMOVE ${_removeArgs})
    
    # Propagate results
    set(${_handleVar} "${${_handleVar}}" PARENT_SCOPE)
    if (NOT "${_statusVar}" STREQUAL "")
        set(${_statusVar} "${_internalStatus}" PARENT_SCOPE)
    endif()
endfunction()

# =================================================================================================
# Metadata & Inspection
# =================================================================================================

# DESCRIBE <handleVar> [INTO <outKindVar>]
function(DESCRIBE)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 1)
        message(FATAL_ERROR "DESCRIBE: expected <handleVar> [INTO <outVar>]")
    endif()
    
    list(GET _args 0 _handleVar)
    
    if (_argc EQUAL 1)
        # Print to console
        object(KIND ${_handleVar} _kind)
        message(STATUS "Object kind: ${_kind}")
        return()
    endif()
    
    if (_argc EQUAL 3)
        list(GET _args 1 _into_kw)
        list(GET _args 2 _outVar)
        
        if (NOT _into_kw STREQUAL "INTO")
            message(FATAL_ERROR "DESCRIBE: expected INTO, got '${_into_kw}'")
        endif()
        
        object(KIND ${_handleVar} ${_outVar})
        set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
        return()
    endif()
    
    message(FATAL_ERROR "DESCRIBE: invalid syntax")
endfunction()

# SHOW COLUMNS FROM <handleVar> INTO <outListVar>
# SHOW KEYS FROM <handleVar> INTO <outListVar>
# SHOW NAME FROM <handleVar> INTO <outStrVar>
function(SHOW)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 4)
        message(FATAL_ERROR "SHOW: expected COLUMNS|KEYS|NAME FROM <handleVar> INTO <outVar>")
    endif()
    
    list(GET _args 0 _what)
    list(GET _args 1 _from_kw)
    list(GET _args 2 _handleVar)
    list(GET _args 3 _into_kw)
    list(GET _args 4 _outVar)
    
    if (NOT _from_kw STREQUAL "FROM")
        message(FATAL_ERROR "SHOW: expected FROM, got '${_from_kw}'")
    endif()
    if (NOT _into_kw STREQUAL "INTO")
        message(FATAL_ERROR "SHOW: expected INTO, got '${_into_kw}'")
    endif()
    
    if (_what STREQUAL "KEYS")
        object(KEYS ${_outVar} FROM ${_handleVar})
    elseif (_what STREQUAL "NAME")
        object(NAME ${_outVar} FROM ${_handleVar})
    elseif (_what STREQUAL "COLUMNS")
        # This would require introspecting record fields - not directly supported
        # For now, delegate to KEYS (for named records stored as dict-like)
        message(FATAL_ERROR "SHOW COLUMNS: not yet implemented. Use object(DUMP ...) to inspect record structure.")
    else()
        message(FATAL_ERROR "SHOW: unknown type '${_what}'. Expected COLUMNS, KEYS, or NAME")
    endif()
    
    set(${_outVar} "${${_outVar}}" PARENT_SCOPE)
endfunction()

# =================================================================================================
# Iteration
# =================================================================================================

# FOREACH ROW IN <handleVar> CALL <function>
function(FOREACH)
    set(_args "${ARGN}")
    list(LENGTH _args _argc)
    
    if (_argc LESS 5)
        message(FATAL_ERROR "FOREACH: expected ROW IN <handleVar> CALL <function>")
    endif()
    
    list(GET _args 0 _row_kw)
    list(GET _args 1 _in_kw)
    list(GET _args 2 _handleVar)
    list(GET _args 3 _call_kw)
    list(GET _args 4 _function)
    
    if (NOT _row_kw STREQUAL "ROW")
        message(FATAL_ERROR "FOREACH: expected ROW, got '${_row_kw}'")
    endif()
    if (NOT _in_kw STREQUAL "IN")
        message(FATAL_ERROR "FOREACH ROW: expected IN, got '${_in_kw}'")
    endif()
    if (NOT _call_kw STREQUAL "CALL")
        message(FATAL_ERROR "FOREACH ROW IN: expected CALL, got '${_call_kw}'")
    endif()
    
    foreachobject(FROM ${_handleVar} CHILDREN CALL ${_function})
endfunction()
