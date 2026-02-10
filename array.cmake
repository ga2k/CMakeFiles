include_guard(GLOBAL)

# ======================================================================================================================
# Hierarchical "list replacement" primitives with NAMED objects and path-based access:
#
#   - record     : Named FS-separated fields (ASCII 0x1C) stored in a single CMake variable.
#                  Format: {FS}NAME{FS}field1{FS}field2...
#                  First field is always the name.
#
#   - array      : Named sequence of records OR arrays (but never mixed) stored in a single variable.
#                  Format: {RS}NAME{RS}elem1{RS}elem2... OR {GS}NAME{GS}elem1{GS}elem2...
#                  First element after marker is always the name.
#
#   - dict : Named key-value map where values can be records, arrays, or other dicts.
#                  Format: {US}key1{US}value1{US}key2{US}value2...
#                  Uses US (Unit Separator, ASCII 0x1F) as delimiter.
#
# Path-based access:
#   - array(GET myArray EQUAL "DATABASE/SOCI" outVar)
#   - dict(GET myCol "PACKAGES/DATABASE/SOCI" outVar)
#
# Design constraints / invariants:
#   - "Empty field" is stored as the sentinel "-" (literal hyphen).
#   - "Empty record" (zero fields) is forbidden (but can have all "-" fields).
#   - Names are mandatory for all records, arrays, and dict keys.
#   - Control characters (FS/GS/RS/US) must not appear inside user payload values.
#   - Names within same container must be unique, but no global uniqueness required.
#
# ======================================================================================================================

set(list_sep ";")
string(ASCII 28 FS) # File Separator  (record field delimiter)
string(ASCII 29 GS) # Group Separator (array-of-arrays delimiter)
string(ASCII 30 RS) # Record Separator (array-of-records delimiter)
string(ASCII 31 US) # Unit Separator (dict key-value delimiter)

set(RECORD_EMPTY_FIELD_SENTINEL "-")

# Store an object value into:
#   - current scope (so globalObjSync can see it)
#   - parent scope (so caller can see it)
#   - global backing store (one source of truth)
macro(_hs__store _handle _value)
    set(${_handle} "${_value}")
    set(${_handle} "${_value}" PARENT_SCOPE)
    _hs__global_sync("${_handle}")
endmacro()
# ----------------------------------------------------------------------------------------------------------------------
# Global backing-store integration
#   If cmake/global.cmake is included, records/arrays/dicts become GLOBAL-backed automatically.
# ----------------------------------------------------------------------------------------------------------------------
function(_hs__global_load_if_set _varName)
    if (COMMAND globalObjLoadIfSet)
        globalObjLoadIfSet("${_varName}")
    endif ()
endfunction()

function(_hs__global_sync _varName)
    if (COMMAND globalObjSync)
        globalObjSync("${_varName}")
    endif ()
endfunction()

# ----------------------------------------------------------------------------------------------------------------------
# Internal helpers (intentionally underscore-prefixed, not stable API)

function(_hs__assert_no_ctrl_chars _where _value)
    foreach (_c IN ITEMS "${FS}" "${GS}" "${RS}" "${US}")
        string(FIND "${_value}" "${_c}" _pos)
        if (NOT _pos EQUAL -1)
            msg(ALWAYS FATAL_ERROR "${_where}: value contains a forbidden control separator character (ASCII ${_c})")
        endif ()
    endforeach ()
endfunction()

#function(_hs__field_to_storage _in _outVar)
#    # Map "" -> "-" for storage
#    if ("${_in}" STREQUAL "")
#        set(${_outVar} "${RECORD_EMPTY_FIELD_SENTINEL}" PARENT_SCOPE)
#    else ()
#        set(${_outVar} "${_in}" PARENT_SCOPE)
#    endif ()
#endfunction()
#
#function(_hs__field_to_user _in _outVar)
#    # Map "-" -> "" for presentation
#    if ("${_in}" STREQUAL "${RECORD_EMPTY_FIELD_SENTINEL}")
#        set(${_outVar} "" PARENT_SCOPE)
#    else ()
#        set(${_outVar} "${_in}" PARENT_SCOPE)
#    endif ()
#endfunction()

function(_hs__field_to_storage _in _outVar)
    # Map "" -> "-" for storage
    if ("${_in}" STREQUAL "")
        set(${_outVar} "${RECORD_EMPTY_FIELD_SENTINEL}" PARENT_SCOPE)
    else ()
        # IMPORTANT:
        # Records are converted to CMake lists by replacing FS with ';'.
        # Therefore any literal ';' inside a field value MUST be escaped,
        # or it will split into multiple list elements and corrupt KV pairing.
        string(REPLACE ";" "»«" _escaped "${_in}")
        set(${_outVar} "${_escaped}" PARENT_SCOPE)
    endif ()
endfunction()

function(_hs__field_to_user _in _outVar)
    # Map "-" -> "" for presentation
    if ("${_in}" STREQUAL "${RECORD_EMPTY_FIELD_SENTINEL}")
        set(${_outVar} "" PARENT_SCOPE)
    else ()
        # Undo escaping applied in _hs__field_to_storage
        string(REPLACE "»«" ";" _unescaped "${_in}")
        set(${_outVar} "${_unescaped}" PARENT_SCOPE)
    endif ()
endfunction()

function(_hs__record_to_list _rec _outVar)
    string(REPLACE "${FS}" "${list_sep}" _tmp "${_rec}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs__record_to_list _rec _outVar)
    string(REPLACE "${FS}" "${list_sep}" _tmp "${_rec}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs__list_to_record _lst _outVar)
    string(REPLACE "${list_sep}" "${FS}" _tmp "${_lst}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs__get_object_type _value _typeOut)
    # Returns: RECORD | ARRAY_RECORDS | ARRAY_ARRAYS | DICT | UNSET | UNKNOWN
    if ("${_value}" STREQUAL "")
        set(${_typeOut} "UNSET" PARENT_SCOPE)
        return()
    endif ()

    string(SUBSTRING "${_value}" 0 1 _m)
    if (_m STREQUAL "${FS}")
        set(${_typeOut} "RECORD" PARENT_SCOPE)
    elseif (_m STREQUAL "${RS}")
        set(${_typeOut} "ARRAY_RECORDS" PARENT_SCOPE)
    elseif (_m STREQUAL "${GS}")
        set(${_typeOut} "ARRAY_ARRAYS" PARENT_SCOPE)
    elseif (_m STREQUAL "${US}")
        set(${_typeOut} "DICT" PARENT_SCOPE)
    else ()
        set(${_typeOut} "UNKNOWN" PARENT_SCOPE)
    endif ()
endfunction()

# Expose private function through this interface macro that takes the name of the object var instead of the object
macro(getObjectType _isdiah__ObjectVarName _oktojtojn__ReceivingVarName)
    _hs__get_object_type("${${_isdiah__ObjectVarName}}" "${_oktojtojn__ReceivingVarName}")
endmacro()

function(_hs__array_get_kind _arrayValue _kindOut _sepOut)
    # Returns:
    #   kind = RECORDS | ARRAYS | UNSET
    #   sep  = RS | GS | ""
    if ("${_arrayValue}" STREQUAL "")
        set(${_kindOut} "UNSET" PARENT_SCOPE)
        set(${_sepOut} "" PARENT_SCOPE)
        return()
    endif ()

    string(SUBSTRING "${_arrayValue}" 0 1 _m)
    if (_m STREQUAL "${RS}")
        set(${_kindOut} "RECORDS" PARENT_SCOPE)
        set(${_sepOut} "${RS}" PARENT_SCOPE)
    elseif (_m STREQUAL "${GS}")
        set(${_kindOut} "ARRAYS" PARENT_SCOPE)
        set(${_sepOut} "${GS}" PARENT_SCOPE)
    else ()
        set(${_kindOut} "UNKNOWN" PARENT_SCOPE)
        set(${_sepOut} "" PARENT_SCOPE)
        msg(ALWAYS WARNING "array: missing type marker (must start with RS or GS)")
    endif ()
endfunction()
# Expose private function through this interface macro that takes the name of the object var instead of the object
macro(getArrayKind _ldskfglk__ObjectVarName _ksfdjggkk__ReceivingVarName)
    _hs__array_get_kind("${${_ldskfglk__ObjectVarName}}" "${_ksfdjggkk__ReceivingVarName}")
endmacro()

function(_hs__array_to_list _arrayValue _sep _outVar)
    # Converts array to CMake list, stripping leading marker
    string(LENGTH "${_arrayValue}" _L)
    if (_L LESS 1)
        set(${_outVar} "" PARENT_SCOPE)
        return()
    endif ()

    string(SUBSTRING "${_arrayValue}" 1 -1 _payload)
    if ("${_payload}" STREQUAL "")
        set(${_outVar} "" PARENT_SCOPE)
        return()
    endif ()

    string(REPLACE "${_sep}" "${list_sep}" _lst "${_payload}")
    set(${_outVar} "${_lst}" PARENT_SCOPE)
endfunction()

function(_hs__list_to_array _lst _kind _outVar)
    if ("${_kind}" STREQUAL "RECORDS")
        set(_sep "${RS}")
    elseif ("${_kind}" STREQUAL "ARRAYS")
        set(_sep "${GS}")
    else ()
        msg(ALWAYS FATAL_ERROR "_hs__list_to_array: invalid kind '${_kind}'")
    endif ()

    if ("${_lst}" STREQUAL "")
        # Empty array with just marker
        set(${_outVar} "${_sep}" PARENT_SCOPE)
        return()
    endif ()

    string(REPLACE "${list_sep}" "${_sep}" _payload "${_lst}")
    set(${_outVar} "${_sep}${_payload}" PARENT_SCOPE)
endfunction()

function(_hs__get_object_name _value _nameOut)
    # Extract name from a named object (record or array)
    # Format: {SEP}NAME{SEP}...
    _hs__get_object_type("${_value}" _type)

    if (_type STREQUAL "RECORD")
        set(_sep "${FS}")
    elseif (_type STREQUAL "ARRAY_RECORDS")
        set(_sep "${RS}")
    elseif (_type STREQUAL "ARRAY_ARRAYS")
        set(_sep "${GS}")
    else ()
        set(${_nameOut} "" PARENT_SCOPE)
        return()
    endif ()

    # Strip leading separator
    string(SUBSTRING "${_value}" 1 -1 _rest)
    string(FIND "${_rest}" "${_sep}" _pos)

    if (_pos LESS 0)
        # No second separator - entire thing is the name
        set(${_nameOut} "${_rest}" PARENT_SCOPE)
    else ()
        string(SUBSTRING "${_rest}" 0 ${_pos} _name)
        set(${_nameOut} "${_name}" PARENT_SCOPE)
    endif ()
endfunction()
# Expose private function through this interface macro that takes the name of the object var instead of the object
macro(getObjectName _ejdgjned__ObjectVarName _bcihujewiewyrg__ReceivingVarName)
    _hs__get_object_name("${${_ejdgjned__ObjectVarName}}" "${_bcihujewiewyrg__ReceivingVarName}")
endmacro()

function(_hs__set_object_name _value _name _outVar)
    # replace name in a named object
    # Format: {SEP}NAME{SEP}...

    _hs__get_object_type("${_value}" _type _sep)
    if (_type STREQUAL "RECORD")
        _hs__record_to_list("${_value}" _lst)
        list(APPEND _lst "iqjerhiuhdsfnUEFHIUYHGF")
        list(REMOVE_AT _lst 1)
        list(INSERT _lst 1 "${_name}")
        list(REMOVE_ITEM _lst "iqjerhiuhdsfnUEFHIUYHGF")
        _hs__list_to_record("${_lst}" _value)
    elseif (_type STREQUAL "ARRAY_RECORDS" OR _type STREQUAL "ARRAY_ARRAYS")
        _hs__array_get_kind("${_value}" _aKind _aSep)
        _hs__array_to_list("${_value}" ${_aSep} _lst)
        list(APPEND _lst "iqjerhiuhdsfnUEFHIUYHGF")
        list(REMOVE_AT _lst 0)
        list(INSERT _lst 0 "${_name}")
        list(REMOVE_ITEM _lst "iqjerhiuhdsfnUEFHIUYHGF")
        _hs__list_to_array("${_lst}" ${_aKind} _value)
    elseif (_type STREQUAL "DICT")
    else ()
        return()
    endif ()
    set("${_outVar}" "${_value}" PARENT_SCOPE)
endfunction()
# Expose private function through this interface macro that takes the name of the object var instead of the object
macro(setObjectName _ejdgjned__ObjectVarName _bcihujewiewyrg__NewName _hegfvuia__ReceivingVarName)
    _hs__set_object_name("${${_ejdgjned__ObjectVarName}}" "${_bcihujewiewyrg__NewName}" "${_hegfvuia__ReceivingVarName}")
endmacro()

function(_hs__resolve_path _containerValue _path _resultOut)
    # Resolve a path like "DATABASE/SOCI" within a container
    # Returns the matching object or empty string if not found

    if ("${_path}" STREQUAL "")
        set(${_resultOut} "" PARENT_SCOPE)
        return()
    endif ()

    # Split path by '/'
    string(REPLACE "/" ";" _pathParts "${_path}")
    list(LENGTH _pathParts _numParts)

    if (_numParts EQUAL 0)
        set(${_resultOut} "" PARENT_SCOPE)
        return()
    endif ()

    list(GET _pathParts 0 _currentName)

    _hs__get_object_type("${_containerValue}" _containerType)

    # Search within container for matching name
    if (_containerType STREQUAL "ARRAY_RECORDS" OR _containerType STREQUAL "ARRAY_ARRAYS")
        _hs__array_get_kind("${_containerValue}" _kind _sep)
        _hs__array_to_list("${_containerValue}" "${_sep}" _elements)

        # Skip first element (array name itself)
        list(LENGTH _elements _len)
        if (_len LESS 2)
            set(${_resultOut} "" PARENT_SCOPE)
            return()
        endif ()

        # Start from element 1 (element 0 is the array's own name)
        set(_i 1)
        while (_i LESS _len)
            list(GET _elements ${_i} _elem)
            _hs__get_object_name("${_elem}" _elemName)

            if ("${_elemName}" STREQUAL "${_currentName}")
                # Found matching element
                if (_numParts EQUAL 1)
                    # End of path - return this element
                    set(${_resultOut} "${_elem}" PARENT_SCOPE)
                    return()
                else ()
                    # Continue down the path
                    list(REMOVE_AT _pathParts 0)
                    string(REPLACE ";" "/" _remainingPath "${_pathParts}")
                    _hs__resolve_path("${_elem}" "${_remainingPath}" _subResult)
                    set(${_resultOut} "${_subResult}" PARENT_SCOPE)
                    return()
                endif ()
            endif ()

            math(EXPR _i "${_i} + 1")
        endwhile ()

        # Not found
        set(${_resultOut} "" PARENT_SCOPE)
        return()

    elseif (_containerType STREQUAL "DICT")
        # Search dict by key
        string(SUBSTRING "${_containerValue}" 1 -1 _payload)
        string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")

        list(LENGTH _kvList _kvLen)
        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _key)
            math(EXPR _i "${_i} + 1")
            if (_i GREATER_EQUAL _kvLen)
                break()
            endif ()
            list(GET _kvList ${_i} _value)

            if ("${_key}" STREQUAL "${_currentName}")
                if (_numParts EQUAL 1)
                    set(${_resultOut} "${_value}" PARENT_SCOPE)
                    return()
                else ()
                    list(REMOVE_AT _pathParts 0)
                    string(REPLACE ";" "/" _remainingPath "${_pathParts}")
                    _hs__resolve_path("${_value}" "${_remainingPath}" _subResult)
                    set(${_resultOut} "${_subResult}" PARENT_SCOPE)
                    return()
                endif ()
            endif ()

            math(EXPR _i "${_i} + 1")
        endwhile ()

        set(${_resultOut} "" PARENT_SCOPE)
        return()
    else ()
        # Can't traverse further
        set(${_resultOut} "" PARENT_SCOPE)
        return()
    endif ()
endfunction()

# ======================================================================================================================
# record() - Named record operations
#
# Extended signature:
#   record(CREATE <recVar> <name> <numFields>)
#   record(APPEND|PREPEND <recVar> <newValue>...)
#   record(CONVERT <recVar> [LIST|RECORD])
#   record(DUMP <recVar> [<outVarName>] [VERBOSE])
#   record(FIND <recVar> EQUAL <value> <outVarName>)
#   record(FIND <recVar> MATCHING <regex> <outVarName>)
#   record(GET <recVar> <fieldIndex> <outVarName>... [TOUPPER|TOLOWER])
#   record(GET <recVar> NAME <outVar>)
#   record(NAME <recVar> <outVarName>)
#   record(RELABEL <recVar> <name>)
#   record(POP_FRONT|POP_BACK <recVar> <outVarName>... [TOUPPER|TOLOWER])
#   record(SET <recVar> <fieldIndex> <newValue> [FAIL|QUIET])
#
# ======================================================================================================================

function(record)
    if (${ARGC} LESS 2)
        msg(ALWAYS FATAL_ERROR "record: expected record(<VERB> <recVar> ...)")
    endif ()

    set(_recVerb "${ARGV0}")
    set(_recVar "${ARGV1}")
    string(TOUPPER "${_recVerb}" _recVerbUC)

    # Pull latest value from GLOBAL store (if enabled / previously created)
    _hs__global_load_if_set("${_recVar}")

    # -------------------- Extended: CREATE --------------------

    if (_recVerbUC STREQUAL "CREATE")
        if (${ARGC} LESS 2 OR ${ARGC} GREATER 4)
            msg(ALWAYS FATAL_ERROR "record(CREATE): expected record(CREATE <recVar> [<name>] [numFields])")
        endif ()

        set(_name)
        unset(_n)

        set(X 2)
        while (X LESS ${ARGC})
            set(argv ARGV${X})
            set(arg "${${argv}}")

            if (NOT _name)
                set(_name "${arg}")
                if (_name MATCHES "^[a-zA-Z_][a-zA-Z0-9_-]*$")
                    _hs__assert_no_ctrl_chars("record(CREATE) name" "${_name}")
                else ()
                    set(_name)
                    if (NOT DEFINED _n)
                        set(_n ${arg})
                        if (NOT _n MATCHES "^[0-9]+$")
                            msg(ALWAYS FATAL_ERROR "record(CREATE): <numFields> must be a non-negative integer, got '${_n}'")
                        endif ()
                    endif ()
                endif ()
            elseif (NOT DEFINED _n)
                set(_n ${arg})
                if (NOT _n MATCHES "^[0-9]+$")
                    message(FATAL_ERROR "record(CREATE): <numFields> must be a non-negative integer, got '${_n}'")
                endif ()
            endif ()
            math(EXPR X "${X} + 1")
        endwhile ()

        if (NOT DEFINED _n)
            set(_n 0)
        endif ()
        if (NOT _name)
            set(_name "${_recVar}")
        endif ()

        if (_n EQUAL 0)
            # Empty record: just name, no fields
            _hs__store(${_recVar} "${FS}${_name}")
        else ()
            # Create: {FS}NAME{FS}field1{FS}field2...
            set(_tmpList "${_name}")
            foreach (_i RANGE 1 ${_n})
                list(APPEND _tmpList "${RECORD_EMPTY_FIELD_SENTINEL}")
            endforeach ()
            string(REPLACE "${list_sep}" "${FS}" _result "${_tmpList}")

            _hs__get_object_type("${_result}" Ak As)
            if (Ak STREQUAL "UNKNOWN")
                set(dodgyExtraFS "${FS}")
            endif ()
            _hs__store(${_recVar} "${dodgyExtraFS}${_result}")
        endif ()
        return()

        # -------------------- Extended: FIND --------------------

    elseif (_recVerbUC STREQUAL "FIND")
        if (NOT ${ARGC} EQUAL 4)
            msg(ALWAYS FATAL_ERROR "record(FIND): expected record(FIND <recVar> EQUAL|MATCHING <pattern> <outVarName>)")
        endif ()

        # undefine the output variable
        set(${ARGV3} "" PARENT_SCOPE)

        set(_recValue "${${_recVar}}")
        set(_pattern "${ARGV2}")

        _hs__record_to_list("${_recValue}" _lst)
        list(POP_FRONT _lst dc dc dc dc)
        list(FIND _lst "${_pattern}" outVar)

        if (NOT outVar EQUAL -1)
            set(${ARGV3} "${outVar}" PARENT_SCOPE)
        endif ()
        return()

        # -------------------- Extended: LENGTH --------------------
    elseif (_recVerbUC STREQUAL "LENGTH")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "record(LENGTH): expected record(LENGTH <recVar> <outVarName>)")
        endif ()

        # undefine the output variable
        set(${ARGV2} "" PARENT_SCOPE)

        set(_recValue "${${_recVar}}")
        _hs__record_to_list("${_recValue}" _lst)
        list(LENGTH _lst _len)

        # Account for record name
        math(EXPR _len "${_len} - 2")
        set(${ARGV2} "${_len}" PARENT_SCOPE)

        return()

        # -------------------- Extended: NAME --------------------
    elseif (_recVerbUC STREQUAL "NAME")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "record(NAME): expected record(NAME <recVar> <outVarName>)")
        endif ()

        # undefine the output variable
        set(${ARGV2} "" PARENT_SCOPE)

        set(_recValue "${${_recVar}}")
        _hs__get_object_name("${_recValue}" _name)
        if (NOT _name STREQUAL "")
            set(${ARGV2} "${_name}" PARENT_SCOPE)
        endif ()
        return()

        # -------------------- Extended: RELABEL --------------------
    elseif (_recVerbUC STREQUAL "RELABEL")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "record(RELABEL): expected record(RELABEL <recVar> <newName>)")
        endif ()

        set(_name "${ARGV2}")
        _hs__assert_no_ctrl_chars("record(${_recVar})" "${_name}")
        _hs__set_object_name("${${_recVar}}" "${_name}" _out)
        _hs__store(${_recVar} "${_out}")

        return()

        # -------------------- Extended: GET NAME --------------------
    elseif (_recVerbUC STREQUAL "GET")   # DEPRECATED: USE record(NAME)
        if (${ARGC} GREATER 2 AND "${ARGV2}" STREQUAL "NAME")
            if (NOT ${ARGC} EQUAL 4)
                msg(ALWAYS FATAL_ERROR "record(GET NAME): expected record(GET <recVar> NAME <outVarName>)")
            endif ()

            # undefine the output variable
            set(${ARGV3} "" PARENT_SCOPE)

            set(_recValue "${${_recVar}}")
            _hs__get_object_name("${_recValue}" _name)
            if (NOT _name STREQUAL "")
                set(${ARGV3} "${_name}" PARENT_SCOPE)
            endif ()
            msg(ALWAYS DEPRECATED "use record(NAME) instead")
            return()
        endif ()

        # Regular field GET (skip name at index 0)
        if (${ARGC} LESS 4)
            msg(ALWAYS FATAL_ERROR "record(GET): expected record(GET <recVar> <fieldIndex> <outVarName>... [TOUPPER|TOLOWER])")
        endif ()

        set(_recValue "${${_recVar}}")
        _hs__record_to_list("${_recValue}" _lst)
        list(LENGTH _lst _len)

        set(_ix "${ARGV2}")
        if (NOT _ix MATCHES "^[0-9]+$")
            msg(ALWAYS FATAL_ERROR "record(GET): <fieldIndex> must be a non-negative integer, got '${_ix}'")
        endif ()

        # Check for TOUPPER/TOLOWER at end
        math(EXPR _lastArg "${ARGC} - 1")
        set(_lastWord "${ARGV${_lastArg}}")
        string(TOUPPER "${_lastWord}" _lastWordUC)

        set(_caseMode "")
        set(_endIdx ${ARGC})
        if (_lastWordUC STREQUAL "TOUPPER" OR _lastWordUC STREQUAL "TOLOWER")
            set(_caseMode "${_lastWordUC}")
            set(_endIdx ${_lastArg})
        endif ()

        # Output variables from index 3 to _endIdx-1
        # NOTE: Field indices are now offset by +2 because index 0 is a marker and index 0 is the name
        set(_cur ${_ix})
        math(EXPR _cur "${_cur} + 2")  # Offset for name and leading separator!!!

        # First, undefine all the output variables
        set(_k 3)
        while (_k LESS ${_endIdx})
            set(_outName "${ARGV${_k}}")

            # undefine the output variable
            set(${_outName} "" PARENT_SCOPE)
            math(EXPR _k "${_k} + 1")
        endwhile ()

        # Second, do it
        set(_k 3)
        while (_k LESS ${_endIdx})
            set(_outName "${ARGV${_k}}")

            if (_cur LESS _len)
                list(GET _lst ${_cur} _vStore)
                _hs__field_to_user("${_vStore}" _v)

                if (_caseMode STREQUAL "TOUPPER")
                    string(TOUPPER "${_v}" _v)
                elseif (_caseMode STREQUAL "TOLOWER")
                    string(TOLOWER "${_v}" _v)
                endif ()

                if (NOT _outName STREQUAL "")
                    set(${_outName} "${_v}" PARENT_SCOPE)
                endif ()
            endif ()
            math(EXPR _k "${_k} + 1")
            math(EXPR _cur "${_cur} + 1")
        endwhile ()
        return()

        # -------------------- Extended: SET/REPLACE (adjusted for name, supports bulk setting) --------------------
    elseif (_recVerbUC STREQUAL "SET" OR _recVerbUC STREQUAL "REPLACE")
        if (${ARGC} LESS 4)
            set(mess "record(${_recVerbUC}): expected record(${_recVerbUC} <recVar> <fieldIndex> <newValue>... ")
            if (_recVerbUC STREQUAL "SET")
                set(mess "${mess}[FAIL|QUIET])")
            else ()
                set(mess "${mess})")
            endif ()
            msg(ALWAYS FATAL_ERROR "${mess}")
        endif ()

        set(_logicalIX "${ARGV2}")
        if (NOT _logicalIX MATCHES "^[0-9]+$")
            msg(ALWAYS FATAL_ERROR "record(${_recVerbUC}): <fieldIndex> must be a non-negative integer, got '${_logicalIX}'")
        endif ()
        math(EXPR _physicalIX "${_logicalIX} + 2")

        set(_mode "")
        set(_endIdx ${ARGC})

        # Check if command is SET and if last arg is FAIL or QUIET
        if (_recVerbUC STREQUAL "SET")
            math(EXPR _lastArg "${ARGC} - 1")
            set(_lastWord "${ARGV${_lastArg}}")
            string(TOUPPER "${_lastWord}" _lastWordUC)

            if (_lastWordUC STREQUAL "FAIL" OR _lastWordUC STREQUAL "QUIET")
                set(_mode "${_lastWordUC}")
                set(_endIdx ${_lastArg})
            endif ()
        endif ()

        set(_recValue "${${_recVar}}")
        _hs__record_to_list("${_recValue}" _lst)

        list(LENGTH _lst _phyicalLen)
        math(EXPR _logicalLen "${_phyicalLen} - 2")

        # Process all values from ARGV3 to _endIdx-1
        set(_k 3)
        while (_k LESS ${_endIdx})
            set(_newVal "${ARGV${_k}}")
            _hs__assert_no_ctrl_chars("record(${_recVerbUC})" "${_newVal}")
            _hs__field_to_storage("${_newVal}" _newValStore)

            if (_logicalIX GREATER_EQUAL _logicalLen)
                if (_mode STREQUAL "FAIL")
                    msg(ALWAYS FATAL_ERROR "record(${_recVerbUC}): index ${_logicalIX} out of range (len=${_logicalLen})")
                elseif (NOT _mode STREQUAL "QUIET")
                    msg(WARNING "record(${_recVerbUC}): extending record '${_recVar}' to index ${_logicalIX}")
                endif ()

                # Extend with "-" sentinel
                while (_phyicalLen LESS_EQUAL _physicalIX)
                    list(APPEND _lst "${RECORD_EMPTY_FIELD_SENTINEL}")
                    list(LENGTH _lst _phyicalLen)
                    math(EXPR _logicalLen "${_logicalLen} + 1")
                endwhile ()
            endif ()

            list(REMOVE_AT _lst ${_physicalIX})
            list(INSERT _lst ${_physicalIX} "${_newValStore}")

            math(EXPR _k "${_k} + 1")
            math(EXPR _physicalIX "${_physicalIX} + 1")
            math(EXPR _logicalIX "${_logicalIX}  + 1")
        endwhile ()

        _hs__list_to_record("${_lst}" _result)
        _hs__get_object_type("${_result}" Ak As)
        if (NOT Ak STREQUAL "RECORD")
            set(dodgyExtraFS "${FS}")
        endif ()
        _hs__store(${_recVar} "${dodgyExtraFS}${_RESULT}")

        return()

        # -------------------- Extended: APPEND / PREPEND (skip name) --------------------
    elseif (_recVerbUC STREQUAL "APPEND" OR _recVerbUC STREQUAL "PREPEND")
        if (${ARGC} LESS 3)
            msg(ALWAYS FATAL_ERROR "record(${_recVerbUC}): expected record(${_recVerbUC} <recVar> <newValue>...)")
        endif ()

        set(_recValue "${${_recVar}}")
        _hs__record_to_list("${_recValue}" _lst)

        set(_k 2)
        while (_k LESS ${ARGC})
            set(_val "${ARGV${_k}}")
            _hs__assert_no_ctrl_chars("record(${_recVerbUC})" "${_val}")
            _hs__field_to_storage("${_val}" _vStore)

            if (_recVerbUC STREQUAL "APPEND")
                list(APPEND _lst "${_vStore}")
            else ()
                # PREPEND after name (index 1)
                list(INSERT _lst 1 "${_vStore}")
            endif ()
            math(EXPR _k "${_k} + 1")
        endwhile ()

        _hs__list_to_record("${_lst}" _result)
        _hs__get_object_type("${_result}" Ak As)
        if (NOT Ak STREQUAL "RECORD")
            set(dodgyExtraFS "${FS}")
        endif ()
        _hs__store(${_recVar} "${dodgyExtraFS}${_RESULT}")

        return()

        # -------------------- Extended: POP_FRONT / POP_BACK (skip name) --------------------
    elseif (_recVerbUC STREQUAL "POP_FRONT" OR _recVerbUC STREQUAL "POP_BACK")
        if (${ARGC} LESS 3)
            msg(ALWAYS FATAL_ERROR "record(${_recVerbUC}): expected record(${_recVerbUC} <recVar> <outVarName>... [TOUPPER|TOLOWER])")
        endif ()

        set(_recValue "${${_recVar}}")
        _hs__record_to_list("${_recValue}" _lst)

        # Check for TOUPPER/TOLOWER
        math(EXPR _lastArg "${ARGC} - 1")
        set(_lastWord "${ARGV${_lastArg}}")
        string(TOUPPER "${_lastWord}" _lastWordUC)

        set(_caseMode "")
        set(_endIdx ${ARGC})
        if (_lastWordUC STREQUAL "TOUPPER" OR _lastWordUC STREQUAL "TOLOWER")
            set(_caseMode "${_lastWordUC}")
            set(_endIdx ${_lastArg})
        endif ()

        set(_k 2)
        while (_k LESS ${_endIdx})
            set("${ARGV${_k}}" "" PARENT_SCOPE)
        endwhile ()
        set(_k 2)
        while (_k LESS ${_endIdx})
            set(_outName "${ARGV${_k}}")
            list(LENGTH _lst _len)
            if (_len LESS 2)  # Need at least name + 1 field
                set(${_outName} "" PARENT_SCOPE)
            else ()
                if (_recVerbUC STREQUAL "POP_FRONT")
                    # Pop from index 1 (skip name at index 0)
                    list(GET _lst 1 _vStore)
                    list(REMOVE_AT _lst 1)
                else ()
                    math(EXPR _lastIdx "${_len} - 1")
                    list(GET _lst ${_lastIdx} _vStore)
                    list(REMOVE_AT _lst ${_lastIdx})
                endif ()

                _hs__field_to_user("${_vStore}" _v)

                if (_caseMode STREQUAL "TOUPPER")
                    string(TOUPPER "${_v}" _v)
                elseif (_caseMode STREQUAL "TOLOWER")
                    string(TOLOWER "${_v}" _v)
                endif ()

                set(${_outName} "${_v}" PARENT_SCOPE)
            endif ()
            math(EXPR _k "${_k} + 1")
        endwhile ()

        _hs__list_to_record("${_lst}" _result)
        _hs__store(${_recVar} "${_RESULT}")

        return()

        # -------------------- Extended: DUMP --------------------
    elseif (_recVerbUC STREQUAL "DUMP")
        if (ARGC LESS 2 OR ARGC GREATER 4)
            msg(ALWAYS FATAL_ERROR "record(DUMP): expected record(DUMP <recVar> [<outVarName>] [VERBOSE|RAW])")
        endif ()

        set(_verbose OFF)
        set(_raw OFF)
        set(_outVarName "")

        if (ARGC GREATER_EQUAL 3)
            if ("${ARGV2}" STREQUAL "VERBOSE")
                set(_verbose ON)
                set(_raw OFF)
            elseif ("${ARGV2}" STREQUAL "RAW")
                set(_verbose OFF)
                set(_raw ON)
            else ()
                set(_outVarName "${ARGV2}")
            endif ()
        endif ()

        if (ARGC EQUAL 4)
            if ("${ARGV3}" STREQUAL "VERBOSE")
                set(_verbose ON)
                set(_raw OFF)
            elseif ("${ARGV3}" STREQUAL "RAW")
                set(_verbose OFF)
                set(_raw ON)
            endif ()
        endif ()

        set(_recValue "${${_recVar}}")

        # Get name using the proper helper
        _hs__get_object_name("${_recValue}" _name)

        # Convert to list for field access
        _hs__record_to_list("${_recValue}" _lst)

        list(LENGTH _lst _len)
        if (_len EQUAL 0)
            set(_dumpStr "record '${_recVar}' = [] (empty/uninitialized)\n")
        elseif (_len EQUAL 1)
            # Just the name, no fields (empty record after split: ["", "Name"])
            _hs__get_object_name("${_recValue}" _name)
            set(_dumpStr "record '${_recVar}' (name='${_name}', fields=0) = []\n")
        else ()
            if (_verbose)
                # _len includes empty first element from split, so subtract 2 (empty + name)
                math(EXPR _numFields "${_len} - 2")
                set(_dumpStr "record '${_recVar}' (name='${_name}', fields=${_numFields}) = [\n")

                # Start at index 2 (skip empty and name)
                set(_i 2)
                set(_fieldIdx 0)
                while (_i LESS _len)
                    list(GET _lst ${_i} _f)
                    _hs__field_to_user("${_f}" _v)

                    if (_verbose)
                        set(_displayVal "${_v}")
                        string(LENGTH "${_displayVal}" _vlen)
                        if (_vlen GREATER 50)
                            string(SUBSTRING "${_displayVal}" 0 50 _displayVal)
                            string(APPEND _displayVal "...")
                        endif ()
                        string(APPEND _dumpStr "  [${_fieldIdx}] = \"${_displayVal}\"\n")
                    else ()
                        string(APPEND _dumpStr "  [${_fieldIdx}] = \"${_v}\"\n")
                    endif ()

                    math(EXPR _i "${_i} + 1")
                    math(EXPR _fieldIdx "${_fieldIdx} + 1")
                endwhile ()
                string(APPEND _dumpStr "]")
            elseif (_raw)
                set(_txt "${_lst}")
                string(REPLACE ";" "<FS>" _dumpStr "${_txt}")
            else ()
                list(POP_FRONT _lst _mkr _name)
                set(_txt "${_lst}")
                string(REPLACE ";" "<FS>" _txt "${_txt}")
                string(REPLACE ">-" ">" _dumpStr "${_txt}")
            endif ()
        endif ()

        if ("${_outVarName}" STREQUAL "")
            message("${_dumpStr}")
        else ()
            set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
        endif ()
        return()

        # -------------------- Extended: CONVERT --------------------
    elseif (_recVerbUC STREQUAL "CONVERT")
        if (${ARGC} GREATER 3)
            msg(ALWAYS FATAL_ERROR "record(CONVERT): expected record(CONVERT <recVar> [LIST|RECORD])")
        endif ()

        set(_target "")
        if (${ARGC} EQUAL 3)
            string(TOUPPER "${ARGV2}" _target)
        endif ()

        set(_in "${${_recVar}}")
        string(FIND "${_in}" "${FS}" _hasFS)
        string(FIND "${_in}" "${list_sep}" _hasSC)

        if ("${_target}" STREQUAL "")
            if (_hasFS GREATER_EQUAL 0 AND _hasSC LESS 0)
                set(_target "LIST")
            elseif (_hasSC GREATER_EQUAL 0 AND _hasFS LESS 0)
                set(_target "RECORD")
            else ()
                msg(ALWAYS FATAL_ERROR "record(CONVERT): ambiguous format; specify LIST or RECORD")
            endif ()
        endif ()

        if (_target STREQUAL "LIST")
            _hs__record_to_list("${_in}" _out)
        elseif (_target STREQUAL "RECORD")
            _hs__list_to_record("${_in}" _out)
        else ()
            msg(ALWAYS FATAL_ERROR "record(CONVERT): invalid target '${_target}'")
        endif ()

        _hs__store(${_recVar} "${_OUT}")

        return()

        # -------------------- Fallback: Forward to CMake list() --------------------
    else ()
        msg(ALWAYS FATAL_ERROR "record: unknown verb '${_recVerbUC}'")
    endif ()
endfunction()

# ======================================================================================================================
# array() - Named array operations
#
# Extended signature:
#   array(CREATE <arrayVarName> <name> RECORDS|ARRAYS)
#   array(NAME <arrayVarName> <outVar>
#   array(RELABEL <arrayVarName> <newName>
#   array(GET <arrayVarName> NAME <outVar>)
#   array(GET <arrayVarName> EQUAL <path> <outVar>)
#   array(GET <arrayVarName> MATCHING <regex> <outVar>)
#   array(GET <arrayVarName> <recIndex> <outVarName>...)
#   array(LENGTH <arrayVarName> <outVarName>)
#   array(SET <arrayVarName> <recIndex> RECORD|ARRAY <value> [FAIL|QUIET])
#   array(APPEND|PREPEND <arrayVarName> RECORD|ARRAY <value>...)
#   array(FIND <arrayVarName> <path> <outVarName>)
#   array(DUMP <arrayVarName> [<outVarName>] [VERBOSE])
#
# ======================================================================================================================

function(array)
    if (${ARGC} LESS 2)
        msg(ALWAYS FATAL_ERROR "array: expected array(<VERB> <arrayVarName> ...)")
    endif ()

    set(_V "${ARGV0}")
    string(TOUPPER "${_V}" _V)

    set(arrayVarName "${ARGV1}")
    set(_A "${${arrayVarName}}")

    # Pull latest value from GLOBAL store (if enabled / previously created)
    _hs__global_load_if_set("${arrayVarName}")
    _hs__array_get_kind("${_A}" _kind _sep)

    # -------------------- CREATE with NAME --------------------
    if (_V STREQUAL "CREATE")
        if (NOT ${ARGC} EQUAL 4)
            msg(ALWAYS FATAL_ERROR "array(CREATE): expected array(CREATE <arrayVarName> <label> RECORDS|ARRAYS)")
        endif ()

        set(_name "${ARGV2}")
        _hs__assert_no_ctrl_chars("array(CREATE) name" "${_name}")

        string(TOUPPER "${ARGV3}" _typeArg)
        if (_typeArg STREQUAL "RECORDS")
            set(_marker "${RS}")
        elseif (_typeArg STREQUAL "ARRAYS")
            set(_marker "${GS}")
        else ()
            msg(ALWAYS FATAL_ERROR "array(CREATE): type must be RECORDS or ARRAYS, got '${ARGV3}'")
        endif ()

        # Format: {SEP}NAME (just marker and name, no elements yet)
        _hs__store(${arrayVarName} "${_marker}${_name}")

        return()
    endif ()

    # -------------------- NAME --------------------
    if (_V STREQUAL "NAME")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "array(NAME): expected array(NAME <arrayVarName> <outVarName>)")
        endif ()

        # undefine the output variable
        set(${ARGV2} "" PARENT_SCOPE)

        _hs__get_object_name("${_A}" _name)
        set(${ARGV2} "${_name}" PARENT_SCOPE)
        return()
    endif ()

    # -------------------- Extended: RELABEL --------------------
    if (_V STREQUAL "RELABEL")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "array(RELABEL): expected array(RELABEL <recVar> <newLabel>)")
        endif ()

        set(_name "${ARGV2}")
        _hs__assert_no_ctrl_chars("array(${_V})" "${_name}")
        _hs__set_object_name("${_A}" "${_name}" _out)
        _hs__store(${ARGV1} "${_out}")

        return()
    endif ()

    # -------------------- GET NAME --------------------
    if (_V STREQUAL "GET")
        if (${ARGC} GREATER 2 AND "${ARGV2}" STREQUAL "NAME")
            if (NOT ${ARGC} EQUAL 4)
                msg(ALWAYS FATAL_ERROR "array(GET NAME): expected array(GET <arrayVarName> NAME <outVarName>)")
            endif ()

            # undefine the output variable
            set(${ARGV3} "" PARENT_SCOPE)

            _hs__get_object_name("${_A}" _name)
            set(${ARGV3} "${_name}" PARENT_SCOPE)
            msg(ALWAYS DEPRECATED "use array(NAME)")
            return()
        endif ()

        # -------------------- GET by EQUAL path --------------------
        if (${ARGC} GREATER 2 AND "${ARGV2}" STREQUAL "EQUAL")
            if (NOT ${ARGC} EQUAL 5)
                msg(ALWAYS FATAL_ERROR "array(GET EQUAL): expected array(GET <arrayVarName> EQUAL <path> <outVarName>)")
            endif ()

            set(_path "${ARGV3}")
            _hs__resolve_path("${_A}" "${_path}" _result)
            set(${ARGV4} "${_result}" PARENT_SCOPE)
            return()
        endif ()

        # -------------------- GET by MATCHING regex --------------------
        if (${ARGC} GREATER 2 AND "${ARGV2}" STREQUAL "MATCHING")
            if (NOT ${ARGC} EQUAL 5)
                msg(ALWAYS FATAL_ERROR "array(GET MATCHING): expected array(GET <arrayVarName> MATCHING <regex> <outVarName>)")
            endif ()

            set(_regex "${ARGV3}")
            _hs__array_to_list("${_A}" "${_sep}" _lst)
            set(${ARGV4} "" PARENT_SCOPE)

            # Skip element 0 (array's own name)
            list(LENGTH _lst _len)
            set(_i 1)
            while (_i LESS _len)
                list(GET _lst ${_i} _elem)
                _hs__get_object_name("${_elem}" _elemName)
                if (_elemName MATCHES "${_regex}")
                    set(${ARGV4} "${_elem}" PARENT_SCOPE)
                    return()
                endif ()
                math(EXPR _i "${_i} + 1")
            endwhile ()

            # Not found
            set(${ARGV4} "" PARENT_SCOPE)
            return()
        endif ()

        # -------------------- Regular GET by index --------------------
        if (${ARGC} LESS 4)
            msg(ALWAYS FATAL_ERROR "array(GET): expected array(GET <arrayVarName> <recIndex> <outVarName>...)")
        endif ()

        set(_recIndex "${ARGV2}")
        if (NOT _recIndex MATCHES "^[0-9]+$")
            msg(ALWAYS FATAL_ERROR "array(GET): <recIndex> must be a non-negative integer, got '${_recIndex}'")
        endif ()

        _hs__array_to_list("${_A}" "${_sep}" _lst)
        list(LENGTH _lst _len)

        # Offset index by +1 to skip array's own name at position 0
        math(EXPR _actualIdx "${_recIndex} + 1")

        set(_k 3)
        set(_cur "${_actualIdx}")
        while (_k LESS ${ARGC})
            set(_outName "${ARGV${_k}}")
            if (_cur GREATER_EQUAL _len)
                set(${_outName} "" PARENT_SCOPE)
            else ()
                list(GET _lst ${_cur} _elem)
                set(${_outName} "${_elem}" PARENT_SCOPE)
            endif ()
            math(EXPR _k "${_k} + 1")
            math(EXPR _cur "${_cur} + 1")
        endwhile ()
        return()
    endif ()

    # -------------------- LENGTH (exclude name) --------------------
    if (_V STREQUAL "LENGTH")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "array(LENGTH): expected array(LENGTH <arrayVarName> <outVarName>)")
        endif ()
        set("${ARGV2}" "" PARENT_SCOPE)
        _hs__array_to_list("${_A}" "${_sep}" _lst)
        list(LENGTH _lst _len)
        # Subtract 1 to exclude the array's own name
        if (_len GREATER 0)
            math(EXPR _len "${_len} - 1")
        endif ()
        set(${ARGV2} "${_len}" PARENT_SCOPE)
        return()
    endif ()

    # -------------------- FIND by path --------------------
    if (_V STREQUAL "FIND")
        if (NOT ${ARGC} EQUAL 4)
            msg(ALWAYS FATAL_ERROR "array(FIND): expected array(FIND <arrayVarName> <path> <outVarName>)")
        endif ()

        set(_path "${ARGV2}")
        _hs__resolve_path("${_A}" "${_path}" _result)

        if ("${_result}" STREQUAL "")
            set(${ARGV3} "" PARENT_SCOPE)
        else ()
            # Find the index of this element
            _hs__array_to_list("${_A}" "${_sep}" _lst)
            list(FIND _lst "${_result}" _idx)
            # Adjust for name offset
            if (_idx GREATER 0)
                math(EXPR _idx "${_idx} - 1")
            endif ()
            set(${ARGV3} "${_idx}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # -------------------- DUMP --------------------
    if (_V STREQUAL "DUMP")
        if (ARGC LESS 2 OR ARGC GREATER 4)
            msg(ALWAYS FATAL_ERROR "array(DUMP): expected array(DUMP <arrayVarName> [<outVarName>] [VERBOSE])")
        endif ()

        set(_verbose OFF)
        set(_outVarName "")

        if (ARGC GREATER_EQUAL 3)
            if ("${ARGV2}" STREQUAL "VERBOSE")
                set(_verbose ON)
            else ()
                set(_outVarName "${ARGV2}")
            endif ()
        endif ()

        if (ARGC EQUAL 4)
            if ("${ARGV3}" STREQUAL "VERBOSE")
                set(_verbose ON)
            endif ()
        endif ()

        _hs__array_to_list("${_A}" "${_sep}" _lst)

        list(LENGTH _lst _len)
        if (_len EQUAL 0)
            set(_dumpStr "array '${arrayVarName}' = [] (empty/uninitialized)\n")
        else ()
            list(GET _lst 0 _arrName)
            math(EXPR _numElems "${_len} - 1")

            # Show separator type
            if (_sep STREQUAL "${RS}")
                set(_sepName "<RS>")
            elseif (_sep STREQUAL "${GS}")
                set(_sepName "<GS>")
            else ()
                set(_sepName "<??>")
            endif ()

            set(_dumpStr "array '${arrayVarName}' (name='${_arrName}', kind=${_kind}, sep=${_sepName}, elements=${_numElems}) = [\n")

            set(_i 1)
            set(_elemIdx 0)
            while (_i LESS _len)
                list(GET _lst ${_i} _elem)
                _hs__get_object_name("${_elem}" _elemName)
                _hs__get_object_type("${_elem}" _elemType)

                if (_verbose)
                    # Recursively dump nested structures
                    if (_elemType STREQUAL "RECORD")
                        # Delegate to record(DUMP)
                        set(_temp_rec_var "_hs_temp_rec_${_elemIdx}")
                        set(${_temp_rec_var} "${_elem}")
                        record(DUMP ${_temp_rec_var} _elem_dump VERBOSE)
                        unset(${_temp_rec_var})
                        # Indent the nested dump
                        string(REPLACE "\n" "\n    " _elem_dump_indented "${_elem_dump}")
                        string(APPEND _dumpStr "  [${_elemIdx}] '${_elemName}' (RECORD) =\n    ${_elem_dump_indented}\n")
                    elseif (_elemType STREQUAL "ARRAY_RECORDS" OR _elemType STREQUAL "ARRAY_ARRAYS")
                        # Recursively dump array
                        set(_temp_arr_var "_hs_temp_arr_${_elemIdx}")
                        set(${_temp_arr_var} "${_elem}")
                        array(DUMP ${_temp_arr_var} _elem_dump VERBOSE)
                        unset(${_temp_arr_var})
                        # Indent the nested dump
                        string(REPLACE "\n" "\n    " _elem_dump_indented "${_elem_dump}")
                        string(APPEND _dumpStr "  [${_elemIdx}] '${_elemName}' (${_elemType}) =\n    ${_elem_dump_indented}\n")
                    else ()
                        # Unknown type - show raw
                        string(LENGTH "${_elem}" _elen)
                        if (_elen GREATER 100)
                            string(SUBSTRING "${_elem}" 0 100 _displayElem)
                            string(APPEND _displayElem "...")
                        else ()
                            set(_displayElem "${_elem}")
                        endif ()
                        string(APPEND _dumpStr "  [${_elemIdx}] '${_elemName}' (${_elemType}) = \"${_displayElem}\"\n")
                    endif ()
                else ()
                    # Non-verbose: just show name and type
                    string(APPEND _dumpStr "  [${_elemIdx}] '${_elemName}' (${_elemType})\n")
                endif ()

                math(EXPR _i "${_i} + 1")
                math(EXPR _elemIdx "${_elemIdx} + 1")
            endwhile ()
            string(APPEND _dumpStr "]")
        endif ()

        if ("${_outVarName}" STREQUAL "")
            message("${_dumpStr}")
        else ()
            set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # -------------------- APPEND / PREPEND --------------------
    if (_V STREQUAL "APPEND" OR _V STREQUAL "PREPEND")
        if (${ARGC} LESS 4)
            msg(ALWAYS FATAL_ERROR "array(${_V}): expected array(${_V} <arrayVarName> RECORD|ARRAY <value>...)")
        endif ()

        string(TOUPPER "${ARGV2}" _itemKind)

        if (_kind STREQUAL "UNSET")
            msg(ALWAYS FATAL_ERROR "array(${_V}): array is uninitialized; call array(CREATE ...) first")
        endif ()

        if (_itemKind STREQUAL "RECORD" AND NOT _kind STREQUAL "RECORDS")
            msg(ALWAYS FATAL_ERROR "array(${_V}): cannot add RECORD to an ARRAYS array")
        elseif (_itemKind STREQUAL "ARRAY" AND NOT _kind STREQUAL "ARRAYS")
            msg(ALWAYS FATAL_ERROR "array(${_V}): cannot add ARRAY to a RECORDS array")
        endif ()

        _hs__array_to_list("${_A}" "${_sep}" _lst)

        set(_k 3)
        while (_k LESS ${ARGC})
            set(_item "${ARGV${_k}}")

            if (_itemKind STREQUAL "RECORD")
                _hs__get_object_type("${_item}" _itemType)
                if (NOT _itemType STREQUAL "RECORD")
                    msg(ALWAYS FATAL_ERROR "array(${_V}): value is not a valid RECORD")
                endif ()
            else ()
                _hs__get_object_type("${_item}" _itemType)
                if (NOT _itemType STREQUAL "ARRAY_RECORDS" AND NOT _itemType STREQUAL "ARRAY_ARRAYS")
                    msg(ALWAYS FATAL_ERROR "array(${_V}): value is not a valid ARRAY")
                endif ()
            endif ()

            if (_V STREQUAL "APPEND")
                list(APPEND _lst "${_item}")
            else ()
                # PREPEND after name (index 1)
                list(INSERT _lst 1 "${_item}")
            endif ()

            math(EXPR _k "${_k} + 1")
        endwhile ()

        _hs__list_to_array("${_lst}" "${_kind}" _Aout)
        _hs__array_get_kind("${_Aout}" kk ss)
        _hs__store(${ArrayVarName} "${_AOUT}")

        return()
    endif ()

    # -------------------- SET --------------------
    if (_V STREQUAL "SET")
        if (${ARGC} LESS 5)
            msg(ALWAYS FATAL_ERROR "array(SET): expected array(SET <arrayVarName> <recIndex>|NAME <name> RECORD|ARRAY <value> [FAIL|QUIET])")
        endif ()

        # Check if setting by NAME
        if ("${ARGV2}" STREQUAL "NAME")
            if (${ARGC} LESS 6)
                msg(ALWAYS FATAL_ERROR "array(SET NAME): expected array(SET <arrayVarName> NAME <n> RECORD|ARRAY <value> [FAIL|QUIET])")
            endif ()

            set(_targetName "${ARGV3}")
            string(TOUPPER "${ARGV4}" _itemKind)
            set(_val "${ARGV5}")
            set(_mode "")
            if (${ARGC} GREATER 6)
                string(TOUPPER "${ARGV6}" _mode)
            endif ()

            # Find element by name
            if (_kind STREQUAL "UNSET")
                msg(ALWAYS FATAL_ERROR "array(SET NAME): array is uninitialized")
            endif ()

            if (_itemKind STREQUAL "RECORD" AND NOT _kind STREQUAL "RECORDS")
                msg(ALWAYS FATAL_ERROR "array(SET NAME): cannot set RECORD into an ARRAYS array")
            elseif (_itemKind STREQUAL "ARRAY" AND NOT _kind STREQUAL "ARRAYS")
                msg(ALWAYS FATAL_ERROR "array(SET NAME): cannot set ARRAY into a RECORDS array")
            endif ()

            _hs__array_to_list("${_A}" "${_sep}" _lst)
            list(LENGTH _lst _len)

            # Search for matching name (skip array's own name at index 0)
            set(_foundIdx -1)
            set(_i 1)
            while (_i LESS _len)
                list(GET _lst ${_i} _elem)
                _hs__get_object_name("${_elem}" _elemName)
                if ("${_elemName}" STREQUAL "${_targetName}")
                    set(_foundIdx ${_i})
                    break()
                endif ()
                math(EXPR _i "${_i} + 1")
            endwhile ()

            if (_foundIdx LESS 0)
                if (_mode STREQUAL "FAIL")
                    msg(ALWAYS FATAL_ERROR "array(SET NAME): element '${_targetName}' not found")
                else ()
                    msg(ALWAYS FATAL_ERROR "array(SET NAME): element '${_targetName}' not found (use APPEND to add new elements)")
                endif ()
            endif ()

            # Replace at found index
            list(REMOVE_AT _lst ${_foundIdx})
            list(INSERT _lst ${_foundIdx} "${_val}")
            _hs__list_to_array("${_lst}" "${_kind}" _Aout)
            _hs__store(${ArrayVarName} "${_AOUT}")

            return()
        endif ()

        # Normal index-based SET
        set(_ix "${ARGV2}")
        if (NOT _ix MATCHES "^[0-9]+$")
            msg(ALWAYS FATAL_ERROR "array(SET): <recIndex> must be a non-negative integer, got '${_ix}'")
        endif ()

        string(TOUPPER "${ARGV3}" _itemKind)
        set(_val "${ARGV4}")
        set(_mode "")
        if (${ARGC} GREATER 5)
            string(TOUPPER "${ARGV5}" _mode)
        endif ()

        if (_kind STREQUAL "UNSET")
            msg(ALWAYS FATAL_ERROR "array(SET): array is uninitialized")
        endif ()

        if (_itemKind STREQUAL "RECORD" AND NOT _kind STREQUAL "RECORDS")
            msg(ALWAYS FATAL_ERROR "array(SET): cannot set RECORD into an ARRAYS array")
        elseif (_itemKind STREQUAL "ARRAY" AND NOT _kind STREQUAL "ARRAYS")
            msg(ALWAYS FATAL_ERROR "array(SET): cannot set ARRAY into a RECORDS array")
        endif ()

        _hs__array_to_list("${_A}" "${_sep}" _lst)
        list(LENGTH _lst _len)

        # Offset index
        math(EXPR _actualIx "${_ix} + 1")

        if (_actualIx GREATER_EQUAL _len)
            if (_mode STREQUAL "FAIL")
                msg(ALWAYS FATAL_ERROR "array(SET): index ${_ix} out of range")
            elseif (NOT _mode STREQUAL "QUIET")
                msg(WARNING "array(SET): extending array '${arrayVarName}' to index ${_ix}")
            endif ()

            if (_kind STREQUAL "RECORDS")
                msg(ALWAYS FATAL_ERROR "array(SET): cannot auto-extend RECORDS array (empty records forbidden)")
            else ()
                while (_len LESS_EQUAL _actualIx)
                    list(APPEND _lst "${RS}unnamed")
                    list(LENGTH _lst _len)
                endwhile ()
            endif ()
        endif ()

        list(REMOVE_AT _lst ${_actualIx})
        list(INSERT _lst ${_actualIx} "${_val}")
        _hs__list_to_array("${_lst}" "${_kind}" _Aout)
        _hs__store(${ArrayVarName} "${_AOUT}")

        return()
    endif ()

    msg(ALWAYS FATAL_ERROR "array: unknown verb '${_V}'")
endfunction()

# ======================================================================================================================
# dict() - Key-value map operations
#
# Signature:
#   dict(CREATE <dictVarName> [<label>])
#   dict(NAME <dictVarName> <outVarName>)
#   dict(RELABEL <dictVarName> <newName>)
#   dict(SET <dictVarName> <key> <value>)
#   dict(GET <dictVarName> <key> <outVarName>)
#   dict(GET <dictVarName> EQUAL <path> <outVarName>)
#   dict(REMOVE <dictVarName> <key>)
#   dict(KEYS <dictVarName> <outVarName>)
#   dict(LENGTH <dictVarName> <outVarName>)
#   dict(DUMP <dictVarName> [<outVarName>])
#
# ======================================================================================================================

function(dict)
    if (${ARGC} LESS 2)
        msg(ALWAYS FATAL_ERROR "dict: expected dict(<VERB> <dictVarName> ...)")
    endif ()

    set(_V "${ARGV0}")
    string(TOUPPER "${_V}" _V)

    set(dictVarName "${ARGV1}")

    # Pull latest value from GLOBAL store (if enabled / previously created)
    _hs__global_load_if_set("${dictVarName}")

    set(_C "${${dictVarName}}")

    # Reserved key used to store dict labels (aligns with object.cmake DICT labeling)
    set(_HS_DICT_NAME_KEY "__HS_OBJ__NAME")

    # -------------------- CREATE --------------------
    if (_V STREQUAL "CREATE")
        if (${ARGC} LESS 2 OR ${ARGC} GREATER 3)
            msg(ALWAYS FATAL_ERROR "dict(CREATE): expected dict(CREATE <dictVarName> [<label>])")
        endif ()

        # Default label = variable name (keeps "everything has a label")
        set(_label "${dictVarName}")
        if (ARGC EQUAL 3 AND NOT "${ARGV2}" STREQUAL "")
            set(_label "${ARGV2}")
        endif ()

        _hs__assert_no_ctrl_chars("dict(CREATE) label" "${_label}")

        # Empty dict encoding is just the marker
        _hs__store(${dictVarName} "${US}")

        # Store the label inside the dict as a reserved key
        # (This keeps the dict encoding a pure key/value map)
        dict(SET ${dictVarName} "${_HS_DICT_NAME_KEY}" "${_label}")
        return()
    endif ()

    # -------------------- NAME --------------------
    if (_V STREQUAL "NAME")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "dict(NAME): expected dict(NAME <dictVarName> <outVarName>)")
        endif ()

        set(${ARGV2} "" PARENT_SCOPE)

        # If dict was created before this change, it may not have a stored name yet.
        dict(GET ${dictVarName} "${_HS_DICT_NAME_KEY}" _nm)
        if ("${_nm}" STREQUAL "")
            # Back-compat: fall back to variable name
            set(_nm "${dictVarName}")
        endif ()

        set(${ARGV2} "${_nm}" PARENT_SCOPE)
        return()
    endif ()

    # -------------------- RELABEL --------------------
    if (_V STREQUAL "RELABEL")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "dict(RELABEL): expected dict(RELABEL <dictVarName> <newName>)")
        endif ()

        set(_name "${ARGV2}")
        if ("${_name}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "dict(RELABEL): newName must be non-empty")
        endif ()
        _hs__assert_no_ctrl_chars("dict(RELABEL) newName" "${_name}")

        dict(SET ${dictVarName} "${_HS_DICT_NAME_KEY}" "${_name}")
        return()
    endif ()

    # -------------------- SET --------------------
    if (_V STREQUAL "SET")
        if (NOT ${ARGC} EQUAL 4)
            msg(ALWAYS FATAL_ERROR "dict(SET): expected dict(SET <dictVarName> <key> <value>)")
        endif ()

        set(_key "${ARGV2}")
        set(_value "${ARGV3}")

        _hs__assert_no_ctrl_chars("dict(SET) key" "${_key}")

        # Parse existing dict
        string(SUBSTRING "${_C}" 1 -1 _payload)
        if ("${_payload}" STREQUAL "")
            # Empty dict
            set(_kvList "")
        else ()
            string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")
        endif ()

        # Check if key exists
        list(LENGTH _kvList _kvLen)
        set(_found OFF)
        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _existingKey)
            if ("${_existingKey}" STREQUAL "${_key}")
                # Update existing value
                math(EXPR _valIdx "${_i} + 1")
                if (_valIdx LESS _kvLen)
                    list(REMOVE_AT _kvList ${_valIdx})
                    list(INSERT _kvList ${_valIdx} "${_value}")
                else ()
                    list(APPEND _kvList "${_value}")
                endif ()
                set(_found ON)
                break()
            endif ()
            math(EXPR _i "${_i} + 2")
        endwhile ()

        if (NOT _found)
            # Add new key-value pair
            list(APPEND _kvList "${_key}" "${_value}")
        endif ()

        # Rebuild dict
        if ("${_kvList}" STREQUAL "")
            _hs__store(${dictVarName} "${US}")
        else ()
            string(REPLACE "${list_sep}" "${US}" _payload "${_kvList}")
            _hs__store(${dictVarName} "${US}${_payload}")
        endif ()

        return()
    endif ()

    # -------------------- GET --------------------
    if (_V STREQUAL "GET")
        if (${ARGC} EQUAL 5 AND "${ARGV2}" STREQUAL "EQUAL")
            # Path-based GET
            set(_path "${ARGV3}")
            _hs__resolve_path("${_C}" "${_path}" _result)
            set(${ARGV4} "${_result}" PARENT_SCOPE)
            return()
        endif ()

        if (NOT ${ARGC} EQUAL 4)
            msg(ALWAYS FATAL_ERROR "dict(GET): expected dict(GET <dictVarName> <key> <outVarName>) or dict(GET <dictVarName> EQUAL <path> <outVarName>)")
        endif ()

        set(_key "${ARGV2}")
        string(SUBSTRING "${_C}" 1 -1 _payload)

        if ("${_payload}" STREQUAL "")
            set(${ARGV3} "" PARENT_SCOPE)
            return()
        endif ()

        string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")
        list(LENGTH _kvList _kvLen)

        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _existingKey)
            if ("${_existingKey}" STREQUAL "${_key}")
                math(EXPR _valIdx "${_i} + 1")
                if (_valIdx LESS _kvLen)
                    list(GET _kvList ${_valIdx} _value)
                    set(${ARGV3} "${_value}" PARENT_SCOPE)
                else ()
                    set(${ARGV3} "" PARENT_SCOPE)
                endif ()
                return()
            endif ()
            math(EXPR _i "${_i} + 2")
        endwhile ()

        # Key not found
        set(${ARGV3} "" PARENT_SCOPE)
        return()
    endif ()

    # -------------------- REMOVE --------------------
    if (_V STREQUAL "REMOVE")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "dict(REMOVE): expected dict(REMOVE <dictVarName> <key>)")
        endif ()

        set(_key "${ARGV2}")
        string(SUBSTRING "${_C}" 1 -1 _payload)

        if ("${_payload}" STREQUAL "")
            return()  # Nothing to remove
        endif ()

        string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")
        list(LENGTH _kvList _kvLen)

        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _existingKey)
            if ("${_existingKey}" STREQUAL "${_key}")
                # Remove key and value
                list(REMOVE_AT _kvList ${_i})
                if (_i LESS _kvLen)
                    list(REMOVE_AT _kvList ${_i})
                endif ()
                break()
            endif ()
            math(EXPR _i "${_i} + 2")
        endwhile ()

        # Rebuild
        if ("${_kvList}" STREQUAL "")
            _hs__store(${dictVarName} "${US}")
        else ()
            string(REPLACE "${list_sep}" "${US}" _payload "${_kvList}")
            _hs__store(${dictVarName} "${US}${_payload}")
        endif ()

        return()
    endif ()

    # -------------------- KEYS --------------------
    if (_V STREQUAL "KEYS")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "dict(KEYS): expected dict(KEYS <dictVarName> <outVarName>)")
        endif ()

        string(SUBSTRING "${_C}" 1 -1 _payload)
        set(${ARGV2} "" PARENT_SCOPE)

        if ("${_payload}" STREQUAL "")
            return()
        endif ()

        string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")

        set(_keys "")
        list(LENGTH _kvList _kvLen)
        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _key)
            list(APPEND _keys "${_key}")
            math(EXPR _i "${_i} + 2")
        endwhile ()

        set(${ARGV2} "${_keys}" PARENT_SCOPE)
        return()
    endif ()

    # -------------------- LENGTH --------------------
    if (_V STREQUAL "LENGTH")
        if (NOT ${ARGC} EQUAL 3)
            msg(ALWAYS FATAL_ERROR "dict(LENGTH): expected dict(LENGTH <dictVarName> <outVarName>)")
        endif ()

        set(${ARGV2} "0" PARENT_SCOPE)
        string(SUBSTRING "${_C}" 1 -1 _payload)

        if ("${_payload}" STREQUAL "")
            set(${ARGV2} "0" PARENT_SCOPE)
            return()
        endif ()

        string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")
        list(LENGTH _kvList _kvLen)
        math(EXPR _numPairs "${_kvLen} / 2")

        set(${ARGV2} "${_numPairs}" PARENT_SCOPE)
        return()
    endif ()

    # -------------------- DUMP --------------------
    if (_V STREQUAL "DUMP")
        if (ARGC LESS 2 OR ARGC GREATER 4)
            msg(ALWAYS FATAL_ERROR "dict(DUMP): expected dict(DUMP <dictVarName> [<outVarName>] [VERBOSE])")
        endif ()

        set(_verbose OFF)
        set(_outVarName "")

        if (ARGC GREATER_EQUAL 3)
            if ("${ARGV2}" STREQUAL "VERBOSE")
                set(_verbose ON)
            else ()
                set(_outVarName "${ARGV2}")
            endif ()
        endif ()

        if (ARGC EQUAL 4)
            if ("${ARGV3}" STREQUAL "VERBOSE")
                set(_verbose ON)
            endif ()
        endif ()

        string(SUBSTRING "${_C}" 1 -1 _payload)

        if ("${_payload}" STREQUAL "")
            set(_dumpStr "dict '${dictVarName}' = {} (empty)\n")
        else ()
            string(REPLACE "${US}" "${list_sep}" _kvList "${_payload}")
            list(LENGTH _kvList _kvLen)
            math(EXPR _numPairs "${_kvLen} / 2")

            set(_dumpStr "dict '${dictVarName}' (pairs=${_numPairs}) = {\n")

            set(_i 0)
            while (_i LESS _kvLen)
                list(GET _kvList ${_i} _key)
                math(EXPR _valIdx "${_i} + 1")
                if (_valIdx LESS _kvLen)
                    list(GET _kvList ${_valIdx} _value)
                    _hs__get_object_type("${_value}" _valueType)

                    if (_verbose)
                        # Recursively dump based on type
                        if (_valueType STREQUAL "RECORD")
                            set(_temp_rec_var "_hs_temp_rec_${_i}")
                            set(${_temp_rec_var} "${_value}")
                            record(DUMP ${_temp_rec_var} _value_dump VERBOSE)
                            unset(${_temp_rec_var})
                            string(REPLACE "\n" "\n    " _value_dump_indented "${_value_dump}")
                            string(APPEND _dumpStr "  \"${_key}\" => (${_valueType})\n    ${_value_dump_indented}\n")
                        elseif (_valueType STREQUAL "ARRAY_RECORDS" OR _valueType STREQUAL "ARRAY_ARRAYS")
                            set(_temp_arr_var "_hs_temp_arr_${_i}")
                            set(${_temp_arr_var} "${_value}")
                            array(DUMP ${_temp_arr_var} _value_dump VERBOSE)
                            unset(${_temp_arr_var})
                            string(REPLACE "\n" "\n    " _value_dump_indented "${_value_dump}")
                            string(APPEND _dumpStr "  \"${_key}\" => (${_valueType})\n    ${_value_dump_indented}\n")
                        elseif (_valueType STREQUAL "DICT")
                            set(_temp_col_var "_hs_temp_col_${_i}")
                            set(${_temp_col_var} "${_value}")
                            dict(DUMP ${_temp_col_var} _value_dump VERBOSE)
                            unset(${_temp_col_var})
                            string(REPLACE "\n" "\n    " _value_dump_indented "${_value_dump}")
                            string(APPEND _dumpStr "  \"${_key}\" => (${_valueType})\n    ${_value_dump_indented}\n")
                        else ()
                            # Unknown type
                            string(LENGTH "${_value}" _vlen)
                            if (_vlen GREATER 100)
                                string(SUBSTRING "${_value}" 0 100 _displayVal)
                                string(APPEND _displayVal "...")
                            else ()
                                set(_displayVal "${_value}")
                            endif ()
                            string(APPEND _dumpStr "  \"${_key}\" => (${_valueType}) \"${_displayVal}\"\n")
                        endif ()
                    else ()
                        # Non-verbose: just show key and type
                        string(APPEND _dumpStr "  \"${_key}\" => (${_valueType})\n")
                    endif ()
                endif ()
                math(EXPR _i "${_i} + 2")
            endwhile ()
            string(APPEND _dumpStr "}")
        endif ()

        if ("${_outVarName}" STREQUAL "")
            message("${_dumpStr}")
        else ()
            set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    msg(ALWAYS FATAL_ERROR "dict: unknown verb '${_V}'")
endfunction()
