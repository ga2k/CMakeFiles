include_guard(GLOBAL)

# ======================================================================================================================
# Hierarchical "list replacement" primitives:
#
#   - record : FS-separated fields (ASCII 0x1C) stored in a single CMake variable.
#              Intended to be a near drop-in replacement for CMake's `list()` command.
#
#   - array  : sequence of records OR sequence of arrays (but never mixed) stored in a single variable.
#              Uses a leading "type marker" + delimiter separators:
#                * array-of-records : leading RS (ASCII 0x1E), elements separated by RS
#                * array-of-arrays  : leading GS (ASCII 0x1D), elements separated by GS
#
# Design constraints / invariants:
#   - "Empty field" is stored as the sentinel "-" (literal hyphen).
#     When GET/POP return a field, "-" is presented to callers as "" (empty string).
#   - "Empty record" (zero fields) is forbidden. (A record may be all "-" fields though.)
#   - Nested depth is limited to: array-of-array-of-records. Therefore:
#       * Outer array-of-arrays uses GS
#       * Inner arrays (elements) are complete arrays (they themselves begin with RS or GS)
#   - Control characters (FS/GS/RS) must not appear inside user payload values.
#
# ======================================================================================================================
# "Pseudo doxygen" type notes:
#
# @typedef record_t
#   A string containing N fields separated by FS. Empty fields are encoded as "-".
#
# @typedef array_records_t
#   A string: RS <rec0> RS <rec1> ...  (leading RS is a marker and creates an unused empty element if split naively).
#
# @typedef array_arrays_t
#   A string: GS <arr0> GS <arr1> ...  where each <arrX> is itself an array_*_t including its marker.
#
# ======================================================================================================================

set(list_sep ";")
string(ASCII 28 FS) # File Separator  (record field delimiter)
string(ASCII 29 GS) # Group Separator (outer array delimiter for arrays-of-arrays)
string(ASCII 30 RS) # Record Separator (array delimiter for arrays-of-records)

set(RECORD_EMPTY_FIELD_SENTINEL "-")

# ----------------------------------------------------------------------------------------------------------------------
# Internal helpers (intentionally underscore-prefixed, not stable API)

function(_hs__assert_no_ctrl_chars _where _value)
    foreach(_c IN ITEMS "${FS}" "${GS}" "${RS}")
        string(FIND "${_value}" "${_c}" _pos)
        if(NOT _pos EQUAL -1)
            message(FATAL_ERROR "${_where}: value contains a forbidden control separator character")
        endif()
    endforeach()
endfunction()

function(_hs__field_to_storage _in _outVar)
    # Map "" -> "-" for storage
    if("${_in}" STREQUAL "")
        set(${_outVar} "${RECORD_EMPTY_FIELD_SENTINEL}" PARENT_SCOPE)
    else()
        set(${_outVar} "${_in}" PARENT_SCOPE)
    endif()
endfunction()

function(_hs__field_to_user _in _outVar)
    # Map "-" -> "" for presentation
    if("${_in}" STREQUAL "${RECORD_EMPTY_FIELD_SENTINEL}")
        set(${_outVar} "" PARENT_SCOPE)
    else()
        set(${_outVar} "${_in}" PARENT_SCOPE)
    endif()
endfunction()

function(_hs__record_to_list _rec _outVar)
    string(REPLACE "${FS}" "${list_sep}" _tmp "${_rec}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs__list_to_record _lst _outVar)
    string(REPLACE "${list_sep}" "${FS}" _tmp "${_lst}")
    set(${_outVar} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs__array_get_kind _arrayValue _kindOut _sepOut)
    # Returns:
    #   kind = RECORDS | ARRAYS | UNSET
    #   sep  = RS | GS | ""
    if("${_arrayValue}" STREQUAL "")
        set(${_kindOut} "UNSET" PARENT_SCOPE)
        set(${_sepOut} "" PARENT_SCOPE)
        return()
    endif()

    string(SUBSTRING "${_arrayValue}" 0 1 _m)
    if(_m STREQUAL "${RS}")
        set(${_kindOut} "RECORDS" PARENT_SCOPE)
        set(${_sepOut} "${RS}" PARENT_SCOPE)
    elseif(_m STREQUAL "${GS}")
        set(${_kindOut} "ARRAYS" PARENT_SCOPE)
        set(${_sepOut} "${GS}" PARENT_SCOPE)
    else()
        message(FATAL_ERROR "array: missing type marker (value must start with RS for records or GS for arrays)")
    endif()
endfunction()

function(_hs__array_to_list _arrayValue _sep _outVar)
    # Converts the array to a real CMake list of elements (records or arrays), stripping the leading marker.
    # Note: Leading marker creates an empty element; we strip it by removing the first character.
    string(LENGTH "${_arrayValue}" _L)
    if(_L LESS 1)
        set(${_outVar} "" PARENT_SCOPE)
        return()
    endif()

    string(SUBSTRING "${_arrayValue}" 1 -1 _payload)
    if("${_payload}" STREQUAL "")
        set(${_outVar} "" PARENT_SCOPE)
        return()
    endif()

    string(REPLACE "${_sep}" "${list_sep}" _lst "${_payload}")
    set(${_outVar} "${_lst}" PARENT_SCOPE)
endfunction()

function(_hs__list_to_array _lst _kind _outVar)
    if("${_kind}" STREQUAL "RECORDS")
        set(_sep "${RS}")
    elseif("${_kind}" STREQUAL "ARRAYS")
        set(_sep "${GS}")
    else()
        message(FATAL_ERROR "_hs__list_to_array: invalid kind '${_kind}'")
    endif()

    if("${_lst}" STREQUAL "")
        # Typed empty array
        set(${_outVar} "${_sep}" PARENT_SCOPE)
        return()
    endif()

    string(REPLACE "${list_sep}" "${_sep}" _payload "${_lst}")
    set(${_outVar} "${_sep}${_payload}" PARENT_SCOPE)
endfunction()

# ======================================================================================================================
# record() - drop-in-ish list replacement
#
# Most verbs are forwarded to list() by temporarily converting FS<->";".
# Extended verbs/behaviors are implemented explicitly (GET case conversion, SET growth policy, CONVERT, CREATE, DUMP, etc.).
#
# Supported extensions:
#   record(GET <recVar> <fieldIndex> <outVar>... TOUPPER|TOLOWER)
#   record(POP_FRONT|POP_BACK <recVar> <outVar>... TOUPPER|TOLOWER)
#   record(SET <recVar> <fieldIndex> <newValue> [FAIL|QUIET])
#   record(APPEND|PREPEND <recVar> <newValue>...)
#   record(CONVERT <recVar> [LIST|RECORD])
#   record(CREATE <recVar> <numFields>)
#   record(DUMP <recVar> [<outVar>])
#
# NOTE: record() is a MACRO so outputs behave like list() (affecting the caller scope).
# ======================================================================================================================

macro(record)
    if(${ARGC} LESS 2)
        message(FATAL_ERROR "record: expected record(<VERB> <recVar> ...)")
    endif()

    set(_recVerb "${ARGV0}")
    set(_recVar  "${ARGV1}")
    string(TOUPPER "${_recVerb}" _recVerbUC)

    # -------------------- Extended: CONVERT --------------------
    if(_recVerbUC STREQUAL "CONVERT")
        if(${ARGC} GREATER 3)
            message(FATAL_ERROR "record(CONVERT): expected record(CONVERT <recVar> [LIST|RECORD])")
        endif()

        set(_target "")
        if(${ARGC} EQUAL 3)
            string(TOUPPER "${ARGV2}" _target)
        endif()

        set(_in "${${_recVar}}")
        string(FIND "${_in}" "${FS}" _hasFS)
        string(FIND "${_in}" "${list_sep}" _hasSC)

        if("${_target}" STREQUAL "")
            # convert to "other" if detectable; else ambiguous
            if(_hasFS GREATER_EQUAL 0 AND _hasSC LESS 0)
                set(_target "LIST")
            elseif(_hasSC GREATER_EQUAL 0 AND _hasFS LESS 0)
                set(_target "RECORD")
            else()
                message(FATAL_ERROR "record(CONVERT): ambiguous contents; specify LIST or RECORD")
            endif()
        endif()

        if(_target STREQUAL "LIST")
            string(REPLACE "${FS}" "${list_sep}" ${_recVar} "${_in}")
        elseif(_target STREQUAL "RECORD")
            string(REPLACE "${list_sep}" "${FS}" ${_recVar} "${_in}")
        else()
            message(FATAL_ERROR "record(CONVERT): invalid target '${ARGV2}' (expected LIST|RECORD)")
        endif()
        unset(_in)
        unset(_hasFS)
        unset(_hasSC)
        unset(_target)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    # -------------------- Extended: CREATE --------------------
    if(_recVerbUC STREQUAL "CREATE")
        if(NOT ${ARGC} EQUAL 3)
            message(FATAL_ERROR "record(CREATE): expected record(CREATE <recVar> <numFields>)")
        endif()
        set(_n "${ARGV2}")
        if(NOT _n MATCHES "^[0-9]+$")
            message(FATAL_ERROR "record(CREATE): <numFields> must be a non-negative integer, got '${_n}'")
        endif()
        if(_n EQUAL 0)
            message(FATAL_ERROR "record(CREATE): empty record is forbidden (numFields must be >= 1)")
        endif()

        # Create a record with N fields all set to "-" sentinel.
        set(_tmpList "")
        foreach(_i RANGE 1 ${_n})
            list(APPEND _tmpList "${RECORD_EMPTY_FIELD_SENTINEL}")
        endforeach()
        string(REPLACE "${list_sep}" "${FS}" ${_recVar} "${_tmpList}")

        unset(_n)
        unset(_tmpList)
        unset(_i)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    # -------------------- Extended: DUMP --------------------
    if(_recVerbUC STREQUAL "DUMP")
        if(NOT (${ARGC} EQUAL 2 OR ${ARGC} EQUAL 3))
            message(FATAL_ERROR "record(DUMP): expected record(DUMP <recVar> [<outVar>])")
        endif()

        set(_txt "${${_recVar}}")
        string(REPLACE "${FS}" "<FS>" _txt "${_txt}")
        if(${ARGC} EQUAL 3)
            set(${ARGV2} "${_txt}")
        else()
            message(STATUS "record(${_recVar})='${_txt}'")
        endif()

        unset(_txt)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    # -------------------- Extended: APPEND / PREPEND --------------------
    if(_recVerbUC STREQUAL "APPEND" OR _recVerbUC STREQUAL "PREPEND")
        if(${ARGC} LESS 3)
            message(FATAL_ERROR "record(${_recVerbUC}): expected record(${_recVerbUC} <recVar> <newValue>...)")
        endif()

        set(_rec "${${_recVar}}")
        _hs__record_to_list("${_rec}" _lst)

        # Add new fields (encode "" as "-" sentinel)
        # Note: We iterate ARGV2..ARGVn via a manual index because CMake has no safe "foreach over arg index range"
        set(_k 2)
        while(_k LESS ${ARGC})
            set(_v "${ARGV${_k}}")
            _hs__assert_no_ctrl_chars("record(${_recVerbUC})" "${_v}")
            _hs__field_to_storage("${_v}" _vStore)

            if(_recVerbUC STREQUAL "APPEND")
                list(APPEND _lst "${_vStore}")
            else()
                list(INSERT _lst 0 "${_vStore}")
            endif()

            math(EXPR _k "${_k} + 1")
        endwhile()

        _hs__list_to_record("${_lst}" _recOut)
        set(${_recVar} "${_recOut}")

        unset(_rec)
        unset(_lst)
        unset(_k)
        unset(_v)
        unset(_vStore)
        unset(_recOut)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    # -------------------- Extended: SET growth policy --------------------
    if(_recVerbUC STREQUAL "SET")
        if(${ARGC} LESS 5)
            message(FATAL_ERROR "record(SET): expected record(SET <recVar> <fieldIndex> <newValue> [FAIL|QUIET])")
        endif()

        set(_ix "${ARGV2}")
        set(_val "${ARGV3}")
        set(_mode "")
        if(${ARGC} GREATER 4)
            string(TOUPPER "${ARGV4}" _mode)
        endif()

        if(NOT _ix MATCHES "^[0-9]+$")
            message(FATAL_ERROR "record(SET): <fieldIndex> must be a non-negative integer, got '${_ix}'")
        endif()
        _hs__assert_no_ctrl_chars("record(SET)" "${_val}")
        _hs__field_to_storage("${_val}" _valStore)

        set(_rec "${${_recVar}}")
        _hs__record_to_list("${_rec}" _lst)
        list(LENGTH _lst _len)

        if(_ix GREATER_EQUAL _len)
            if(_mode STREQUAL "FAIL")
                message(FATAL_ERROR "record(SET): index ${_ix} out of range (len=${_len}) for ${_recVar}")
            elseif(NOT _mode STREQUAL "QUIET")
                message(WARNING "record(SET): extending record '${_recVar}' to index ${_ix}")
            endif()

            # Extend with "-" until we can set _ix
            while(_len LESS_EQUAL _ix)
                list(APPEND _lst "${RECORD_EMPTY_FIELD_SENTINEL}")
                list(LENGTH _lst _len)
            endwhile()
        endif()

        list(SET _lst ${_ix} "${_valStore}")

        _hs__list_to_record("${_lst}" _recOut)
        set(${_recVar} "${_recOut}")

        unset(_ix)
        unset(_val)
        unset(_mode)
        unset(_valStore)
        unset(_rec)
        unset(_lst)
        unset(_len)
        unset(_recOut)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    # -------------------- Extended: GET / POP_* with multi-out and case + "-"->"" --------------------
    if(_recVerbUC STREQUAL "GET")
        # record(GET <recVar> <fieldIndex> <outVar>... [TOUPPER|TOLOWER])
        if(${ARGC} LESS 4)
            message(FATAL_ERROR "record(GET): expected record(GET <recVar> <fieldIndex> <outVar>... [TOUPPER|TOLOWER])")
        endif()

        set(_ix "${ARGV2}")
        if(NOT _ix MATCHES "^[0-9]+$")
            message(FATAL_ERROR "record(GET): <fieldIndex> must be a non-negative integer, got '${_ix}'")
        endif()

        set(_case "")
        set(_last "${ARGV${ARGC}-1}")
        if(_last STREQUAL "TOUPPER" OR _last STREQUAL "TOLOWER")
            set(_case "${_last}")
            math(EXPR _outEnd "${ARGC}-2")
        else()
            math(EXPR _outEnd "${ARGC}-1")
        endif()

        set(_rec "${${_recVar}}")
        _hs__record_to_list("${_rec}" _lst)

        set(_k 3)
        set(_cur "${_ix}")
        while(_k LESS_EQUAL _outEnd)
            set(_outVarName "${ARGV${_k}}")

            list(LENGTH _lst _len)
            if(_cur GREATER_EQUAL _len)
                unset(${_outVarName})
            else()
                list(GET _lst ${_cur} _vStore)
                _hs__field_to_user("${_vStore}" _v)

                if(_case STREQUAL "TOUPPER")
                    string(TOUPPER "${_v}" _v)
                elseif(_case STREQUAL "TOLOWER")
                    string(TOLOWER "${_v}" _v)
                endif()

                set(${_outVarName} "${_v}")
            endif()

            math(EXPR _k "${_k} + 1")
            math(EXPR _cur "${_cur} + 1")
        endwhile()

        unset(_ix)
        unset(_case)
        unset(_last)
        unset(_outEnd)
        unset(_rec)
        unset(_lst)
        unset(_k)
        unset(_cur)
        unset(_outVarName)
        unset(_vStore)
        unset(_v)
        unset(_len)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    if(_recVerbUC STREQUAL "POP_FRONT" OR _recVerbUC STREQUAL "POP_BACK")
        # record(POP_FRONT|POP_BACK <recVar> <outVar>... [TOUPPER|TOLOWER])
        if(${ARGC} LESS 3)
            message(FATAL_ERROR "record(${_recVerbUC}): expected record(${_recVerbUC} <recVar> <outVar>... [TOUPPER|TOLOWER])")
        endif()

        set(_case "")
        set(_last "${ARGV${ARGC}-1}")
        if(_last STREQUAL "TOUPPER" OR _last STREQUAL "TOLOWER")
            set(_case "${_last}")
            math(EXPR _outEnd "${ARGC}-2")
        else()
            math(EXPR _outEnd "${ARGC}-1")
        endif()

        set(_rec "${${_recVar}}")
        _hs__record_to_list("${_rec}" _lst)

        set(_k 2)
        while(_k LESS_EQUAL _outEnd)
            set(_outVarName "${ARGV${_k}}")

            list(LENGTH _lst _len)
            if(_len EQUAL 0)
                unset(${_outVarName})
            else()
                if(_recVerbUC STREQUAL "POP_FRONT")
                    list(POP_FRONT _lst _vStore)
                else()
                    list(POP_BACK _lst _vStore)
                endif()

                _hs__field_to_user("${_vStore}" _v)

                if(_case STREQUAL "TOUPPER")
                    string(TOUPPER "${_v}" _v)
                elseif(_case STREQUAL "TOLOWER")
                    string(TOLOWER "${_v}" _v)
                endif()

                set(${_outVarName} "${_v}")
            endif()

            math(EXPR _k "${_k} + 1")
        endwhile()

        _hs__list_to_record("${_lst}" _recOut)
        set(${_recVar} "${_recOut}")

        unset(_case)
        unset(_last)
        unset(_outEnd)
        unset(_rec)
        unset(_lst)
        unset(_k)
        unset(_outVarName)
        unset(_vStore)
        unset(_v)
        unset(_len)
        unset(_recOut)
        unset(_recVerb)
        unset(_recVar)
        unset(_recVerbUC)
        return()
    endif()

    # -------------------- Default: forward to list() --------------------
    # Convert record->list, run list(), convert list->record back.
    set(_rec "${${_recVar}}")
    _hs__record_to_list("${_rec}" __hs__rec_tmp_list)

    # Forward: list(<verb> __hs__rec_tmp_list <rest...>)
    # Note: list() will operate in caller scope because record() is a macro.
    if(${ARGC} GREATER 2)
        list(${_recVerb} __hs__rec_tmp_list ${ARGV2} ${ARGN})
    else()
        list(${_recVerb} __hs__rec_tmp_list)
    endif()

    _hs__list_to_record("${__hs__rec_tmp_list}" _recOut)
    set(${_recVar} "${_recOut}")

    unset(_rec)
    unset(__hs__rec_tmp_list)
    unset(_recOut)
    unset(_recVerb)
    unset(_recVar)
    unset(_recVerbUC)
endmacro()

# ======================================================================================================================
# array()
#
# Keyworded API to remove ambiguity:
#
#   array(CREATE <arrayVar> RECORDS|ARRAYS)         # create typed empty array (with marker only)
#   array(APPEND  <arrayVar> RECORD <rec>...)       # append record(s)
#   array(APPEND  <arrayVar> ARRAY  <arr>...)       # append array(s)
#   array(PREPEND <arrayVar> RECORD <rec>...)
#   array(PREPEND <arrayVar> ARRAY  <arr>...)
#
# List-like operations (operate on elements = records or arrays):
#   array(LENGTH <arrayVar> <outVar>)
#   array(GET    <arrayVar> <recIndex> <outVar>...)                 # get element(s)
#   array(GET    <arrayVar> <recIndex> <fieldIndex> <outVar>...)    # get field(s) from a record element
#   array(SET    <arrayVar> <recIndex> RECORD <rec> [FAIL|QUIET])
#   array(SET    <arrayVar> <recIndex> ARRAY  <arr> [FAIL|QUIET])
#   array(FIND   <arrayVar> <fieldIndex> MATCHING <regex> <outVar>) # records-only
#   array(DUMP   <arrayVar> [<outVar>])
#
# NOTE: array() is a FUNCTION (it updates <arrayVar> via PARENT_SCOPE).
# ======================================================================================================================

function(array verb arrayVar)
    if(NOT verb OR NOT arrayVar)
        message(FATAL_ERROR "array: expected array(<VERB> <arrayVar> ...)")
    endif()

    string(TOUPPER "${verb}" _V)

    if(DEFINED ${arrayVar})
        set(_A "${${arrayVar}}")
    else()
        set(_A "")
    endif()

    # -------------------- CREATE --------------------
    if(_V STREQUAL "CREATE")
        if(NOT ${ARGC} EQUAL 3)
            message(FATAL_ERROR "array(CREATE): expected array(CREATE <arrayVar> RECORDS|ARRAYS)")
        endif()
        string(TOUPPER "${ARGV2}" _kind)
        if(_kind STREQUAL "RECORDS")
            set(${arrayVar} "${RS}" PARENT_SCOPE)
        elseif(_kind STREQUAL "ARRAYS")
            set(${arrayVar} "${GS}" PARENT_SCOPE)
        else()
            message(FATAL_ERROR "array(CREATE): invalid kind '${ARGV2}' (expected RECORDS|ARRAYS)")
        endif()
        return()
    endif()

    # -------------------- DUMP --------------------
    if(_V STREQUAL "DUMP")
        if(NOT (${ARGC} EQUAL 2 OR ${ARGC} EQUAL 3))
            message(FATAL_ERROR "array(DUMP): expected array(DUMP <arrayVar> [<outVar>])")
        endif()
        set(_txt "${_A}")
        string(REPLACE "${GS}" "<GS>" _txt "${_txt}")
        string(REPLACE "${RS}" "<RS>" _txt "${_txt}")
        string(REPLACE "${FS}" "<FS>" _txt "${_txt}")
        if(${ARGC} EQUAL 3)
            set(${ARGV2} "${_txt}" PARENT_SCOPE)
        else()
            message(STATUS "array(${arrayVar})='${_txt}'")
        endif()
        return()
    endif()

    # Determine array kind (or UNSET)
    _hs__array_get_kind("${_A}" _kind _sep)

    # -------------------- APPEND / PREPEND (keyworded) --------------------
    if(_V STREQUAL "APPEND" OR _V STREQUAL "PREPEND")
        if(${ARGC} LESS 4)
            message(FATAL_ERROR "array(${_V}): expected array(${_V} <arrayVar> RECORD|ARRAY <value>...)")
        endif()
        string(TOUPPER "${ARGV2}" _itemKind)
        if(NOT (_itemKind STREQUAL "RECORD" OR _itemKind STREQUAL "ARRAY"))
            message(FATAL_ERROR "array(${_V}): expected RECORD|ARRAY after <arrayVar>")
        endif()

        # If array is UNSET, choose kind now
        if(_kind STREQUAL "UNSET")
            if(_itemKind STREQUAL "RECORD")
                set(_kind "RECORDS")
            else()
                set(_kind "ARRAYS")
            endif()
            _hs__list_to_array("" "${_kind}" _A) # set marker only
            _hs__array_get_kind("${_A}" _kind _sep)
        endif()

        # Enforce homogeneity
        if(_itemKind STREQUAL "RECORD" AND NOT _kind STREQUAL "RECORDS")
            message(FATAL_ERROR "array(${_V}): cannot add RECORD to an ARRAYS array")
        endif()
        if(_itemKind STREQUAL "ARRAY" AND NOT _kind STREQUAL "ARRAYS")
            message(FATAL_ERROR "array(${_V}): cannot add ARRAY to a RECORDS array")
        endif()

        _hs__array_to_list("${_A}" "${_sep}" _lst)

        set(_k 3)
        while(_k LESS ${ARGC})
            set(_item "${ARGV${_k}}")
            if(_itemKind STREQUAL "RECORD")
                _hs__assert_no_ctrl_chars("array(${_V} RECORD)" "${_item}")
                # Records must not begin with RS/GS (type markers reserved for arrays)
                string(SUBSTRING "${_item}" 0 1 _m)
                if(_m STREQUAL "${RS}" OR _m STREQUAL "${GS}")
                    message(FATAL_ERROR "array(${_V} RECORD): record value must not start with RS/GS (looks like an array)")
                endif()
            else()
                # Arrays must begin with RS/GS
                _hs__array_get_kind("${_item}" _childKind _childSep)
            endif()

            if(_V STREQUAL "APPEND")
                list(APPEND _lst "${_item}")
            else()
                list(INSERT _lst 0 "${_item}")
            endif()

            math(EXPR _k "${_k} + 1")
        endwhile()

        _hs__list_to_array("${_lst}" "${_kind}" _Aout)
        set(${arrayVar} "${_Aout}" PARENT_SCOPE)
        return()
    endif()

    # -------------------- LENGTH --------------------
    if(_V STREQUAL "LENGTH")
        if(NOT ${ARGC} EQUAL 3)
            message(FATAL_ERROR "array(LENGTH): expected array(LENGTH <arrayVar> <outVar>)")
        endif()
        _hs__array_to_list("${_A}" "${_sep}" _lst)
        list(LENGTH _lst _len)
        set(${ARGV2} "${_len}" PARENT_SCOPE)
        return()
    endif()

    # -------------------- GET overloads --------------------
    if(_V STREQUAL "GET")
        if(${ARGC} LESS 5)
            message(FATAL_ERROR "array(GET): expected array(GET <arrayVar> <recIndex> <outVar>...) OR array(GET <arrayVar> <recIndex> <fieldIndex> <outVar>...)")
        endif()

        set(_recIndex "${ARGV2}")
        if(NOT _recIndex MATCHES "^[0-9]+$")
            message(FATAL_ERROR "array(GET): <recIndex> must be a non-negative integer, got '${_recIndex}'")
        endif()

        _hs__array_to_list("${_A}" "${_sep}" _lst)
        list(LENGTH _lst _len)

        # Detect second signature: 4th arg is an integer => fieldIndex
        set(_maybeField "${ARGV3}")
        if(_maybeField MATCHES "^[0-9]+$")
            if(NOT _kind STREQUAL "RECORDS")
                message(FATAL_ERROR "array(GET recIndex fieldIndex ...): only valid for RECORDS arrays")
            endif()
            set(_fieldIndex "${_maybeField}")

            # Collect fields from the record at recIndex
            if(_recIndex GREATER_EQUAL _len)
                # outVars all unset
                set(_k 4)
                while(_k LESS ${ARGC})
                    unset("${ARGV${_k}}" PARENT_SCOPE)
                    math(EXPR _k "${_k} + 1")
                endwhile()
                return()
            endif()

            list(GET _lst ${_recIndex} _rec)
            # Forward to record(GET ...) in caller via PARENT_SCOPE sets:
            # We are in a function, so we must set outputs ourselves.
            _hs__record_to_list("${_rec}" _recList)

            set(_k 4)
            set(_cur "${_fieldIndex}")
            while(_k LESS ${ARGC})
                set(_outName "${ARGV${_k}}")
                list(LENGTH _recList _rlen)
                if(_cur GREATER_EQUAL _rlen)
                    set(${_outName} "" PARENT_SCOPE)
                else()
                    list(GET _recList ${_cur} _vStore)
                    _hs__field_to_user("${_vStore}" _v)
                    set(${_outName} "${_v}" PARENT_SCOPE)
                endif()
                math(EXPR _k "${_k} + 1")
                math(EXPR _cur "${_cur} + 1")
            endwhile()
            return()
        endif()

        # First signature: return element(s)
        set(_k 3)
        set(_cur "${_recIndex}")
        while(_k LESS ${ARGC})
            set(_outName "${ARGV${_k}}")
            if(_cur GREATER_EQUAL _len)
                set(${_outName} "" PARENT_SCOPE)
            else()
                list(GET _lst ${_cur} _elem)
                set(${_outName} "${_elem}" PARENT_SCOPE)
            endif()
            math(EXPR _k "${_k} + 1")
            math(EXPR _cur "${_cur} + 1")
        endwhile()
        return()
    endif()

    # -------------------- SET (keyworded) --------------------
    if(_V STREQUAL "SET")
        if(${ARGC} LESS 6)
            message(FATAL_ERROR "array(SET): expected array(SET <arrayVar> <recIndex> RECORD|ARRAY <value> [FAIL|QUIET])")
        endif()

        set(_ix "${ARGV2}")
        if(NOT _ix MATCHES "^[0-9]+$")
            message(FATAL_ERROR "array(SET): <recIndex> must be a non-negative integer, got '${_ix}'")
        endif()

        string(TOUPPER "${ARGV3}" _itemKind)
        set(_val "${ARGV4}")
        set(_mode "")
        if(${ARGC} GREATER 5)
            string(TOUPPER "${ARGV5}" _mode)
        endif()

        if(_kind STREQUAL "UNSET")
            message(FATAL_ERROR "array(SET): array is untyped/empty; call array(CREATE ...) or array(APPEND ...) first")
        endif()

        if(_itemKind STREQUAL "RECORD" AND NOT _kind STREQUAL "RECORDS")
            message(FATAL_ERROR "array(SET): cannot set RECORD into an ARRAYS array")
        elseif(_itemKind STREQUAL "ARRAY" AND NOT _kind STREQUAL "ARRAYS")
            message(FATAL_ERROR "array(SET): cannot set ARRAY into a RECORDS array")
        endif()

        _hs__array_to_list("${_A}" "${_sep}" _lst)
        list(LENGTH _lst _len)

        if(_ix GREATER_EQUAL _len)
            if(_mode STREQUAL "FAIL")
                message(FATAL_ERROR "array(SET): index ${_ix} out of range (len=${_len})")
            elseif(NOT _mode STREQUAL "QUIET")
                message(WARNING "array(SET): extending array '${arrayVar}' to index ${_ix}")
            endif()
            # extend with placeholders (forbidden empty record/array => choose typed empty array if ARRAYS, or sentinel record?)
            # Since you forbid empty records, we cannot auto-extend RECORDS arrays safely. Force FAIL unless QUIET/WARN?:
            if(_kind STREQUAL "RECORDS")
                message(FATAL_ERROR "array(SET): cannot extend RECORDS array automatically because empty records are forbidden")
            else()
                # For ARRAYS, we can extend with typed empty arrays (marker only), since empty arrays are valid.
                while(_len LESS_EQUAL _ix)
                    list(APPEND _lst "${RS}") # default to empty array-of-records as placeholder
                    list(LENGTH _lst _len)
                endwhile()
            endif()
        endif()

        list(SET _lst ${_ix} "${_val}")
        _hs__list_to_array("${_lst}" "${_kind}" _Aout)
        set(${arrayVar} "${_Aout}" PARENT_SCOPE)
        return()
    endif()

    # -------------------- FIND (records-only) --------------------
    if(_V STREQUAL "FIND")
        if(NOT ${ARGC} EQUAL 6)
            message(FATAL_ERROR "array(FIND): expected array(FIND <arrayVar> <fieldIndex> MATCHING <regex> <outVar>)")
        endif()
        if(NOT _kind STREQUAL "RECORDS")
            message(FATAL_ERROR "array(FIND): only valid for RECORDS arrays")
        endif()

        set(_fieldIndex "${ARGV2}")
        if(NOT _fieldIndex MATCHES "^[0-9]+$")
            message(FATAL_ERROR "array(FIND): <fieldIndex> must be a non-negative integer, got '${_fieldIndex}'")
        endif()

        if(NOT "${ARGV3}" STREQUAL "MATCHING")
            message(FATAL_ERROR "array(FIND): expected keyword MATCHING")
        endif()

        set(_re "${ARGV4}")
        set(_outVar "${ARGV5}")

        _hs__array_to_list("${_A}" "${_sep}" _lst)

        set(_i 0)
        set(_found -1)
        foreach(_rec IN LISTS _lst)
            _hs__record_to_list("${_rec}" _recList)
            list(LENGTH _recList _rlen)
            if(_fieldIndex LESS _rlen)
                list(GET _recList ${_fieldIndex} _vStore)
                _hs__field_to_user("${_vStore}" _v)
                if(_v MATCHES "${_re}")
                    set(_found ${_i})
                    break()
                endif()
            endif()
            math(EXPR _i "${_i} + 1")
        endforeach()

        set(${_outVar} "${_found}" PARENT_SCOPE)
        return()
    endif()

    message(FATAL_ERROR "array: unknown verb '${verb}'")
endfunction()