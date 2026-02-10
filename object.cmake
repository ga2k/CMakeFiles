include_guard(GLOBAL)

# object.cmake
# Global-store-backed "object(...)" API.
#
# - Callers receive only opaque, auto-generated handle tokens (strings).
# - Encoded object blobs are stored only in GLOBAL properties via globalObj*().
# - Object labels used by NAME/PATH/... are embedded in the blob (CREATE LABEL / RENAME).
# - Objects created without a label have label "<unnamed>".
# - RENAME MUST be performed before any other mutable operation on an "<unnamed>" object.

if (NOT COMMAND globalObjSet)
    include(${CMAKE_SOURCE_DIR}/cmake/global.cmake)
endif ()

# -------------------------------------------------------------------------------------------------
# Object label and mutation gating helpers

function(_hs_obj__get_label_from_blob blob outLabel)
    set(${outLabel} "" PARENT_SCOPE)

    _hs__get_object_type("${blob}" _t)
    if (_t STREQUAL "DICT")
        dict(CREATE _tmp "_")
        set(_tmp "${blob}")
        dict(GET _tmp "__HS_OBJ__NAME" _nm)
        if ("${_nm}" STREQUAL "")
            set(_nm "<unnamed>")
        endif ()
        set(${outLabel} "${_nm}" PARENT_SCOPE)
        return()
    endif ()

    _hs__get_object_name("${blob}" _nm)
    if ("${_nm}" STREQUAL "")
        set(_nm "<unnamed>")
    endif ()
    set(${outLabel} "${_nm}" PARENT_SCOPE)
endfunction()

function(_hs_obj__assert_mutable_allowed token blob opName)
    _hs_obj__get_label_from_blob("${blob}" _lbl)
    if ("${_lbl}" STREQUAL "<unnamed>" AND NOT "${opName}" STREQUAL "RENAME")
        _hs_obj__meta_diag("${blob}" _diag)
        msg(ALWAYS FATAL_ERROR
                "object(${opName}): object '${token}' has label '<unnamed>'. "
                "You MUST object(RENAME ...) it before any other mutation.\n"
                "  LookedAt : ${_diag}"
        )
    endif ()
endfunction()

# -------------------------------------------------------------------------------------------------
# DUMP helpers (formatting)

function(_hs_obj__spaces _n _out)
    if (_n LESS_EQUAL 0)
        set(${_out} "" PARENT_SCOPE)
        return()
    endif ()
    string(REPEAT " " ${_n} _s)
    set(${_out} "${_s}" PARENT_SCOPE)
endfunction()

function(_hs_obj__indent_lines _txt _indent _out)
    if ("${_txt}" STREQUAL "")
        set(${_out} "" PARENT_SCOPE)
        return()
    endif ()
    string(REPLACE "\n" "\n${_indent}" _t "${_txt}")
    set(${_out} "${_indent}${_t}" PARENT_SCOPE)
endfunction()

function(_hs_obj__dump_record_pretty _recBlob _indent _outStr)
    set(${_outStr} "" PARENT_SCOPE)

    _hs_obj__rec_get_kv("${_recBlob}" "${_HS_REC_META_MODE}" _hm _modeVal)
    if (NOT _hm)
        set(${_outStr} "${_indent}<corrupt record: missing MODE>\n" PARENT_SCOPE)
        return()
    endif ()

    _hs_obj__rec_get_kv("${_recBlob}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
    if (NOT _hs OR "${_sizeStr}" STREQUAL "")
        set(_sizeStr "0")
    endif ()

    if (NOT _sizeStr MATCHES "^[0-9]+$")
        set(${_outStr} "${_indent}<corrupt record: bad SIZE '${_sizeStr}'>\n" PARENT_SCOPE)
        return()
    endif ()

    # ---------- POSITIONAL ----------
    if ("${_modeVal}" STREQUAL "POSITIONAL")
        set(_size "${_sizeStr}")

        # compute width for indices (so [10] aligns with [0])
        if (_size GREATER 0)
            math(EXPR _last "${_size} - 1")
            set(_lastStr "${_last}")
            string(LENGTH "${_lastStr}" _w)
        else ()
            set(_w 1)
        endif ()

        set(_s "")
        set(_i 0)
        while (_i LESS _size)
            _hs_obj__rec_get_kv("${_recBlob}" "${_i}" _found _val)
            if (NOT _found OR "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                set(_disp "")
            else ()
                set(_disp "${_val}")
            endif ()

            # left pad index to width _w
            set(_iStr "${_i}")
            string(LENGTH "${_iStr}" _iLen)
            math(EXPR _pad "${_w} - ${_iLen}")
            _hs_obj__spaces(${_pad} _p)

            string(APPEND _s "${_indent}[${_p}${_iStr}] => '${_disp}'\n")
            math(EXPR _i "${_i} + 1")
        endwhile ()

        set(${_outStr} "${_s}" PARENT_SCOPE)
        return()
    endif ()

    # ---------- SCHEMA ----------
    if ("${_modeVal}" STREQUAL "SCHEMA")
        _hs_obj__rec_get_kv("${_recBlob}" "${_HS_REC_META_FIELDS}" _hf _fieldsStore)
        if (NOT _hf OR "${_fieldsStore}" STREQUAL "")
            set(${_outStr} "${_indent}<schema record missing FIELDS>\n" PARENT_SCOPE)
            return()
        endif ()

        # Decode stored field list (token-separated string) into a CMake list
        string(REPLACE "${_HS_REC_FIELDS_SEP}" ";" _fields "${_fieldsStore}")
        set(_fieldList "${_fields}")

        # compute max field-name length for right alignment
        set(_max 0)
        foreach (_fn IN LISTS _fieldList)
            string(LENGTH "${_fn}" _L)
            if (_L GREATER _max)
                set(_max ${_L})
            endif ()
        endforeach ()

        set(_s "")
        foreach (_fn IN LISTS _fieldList)
            _hs_obj__rec_get_kv("${_recBlob}" "${_fn}" _found _val)
            if (NOT _found OR "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                set(_disp "")
            else ()
                set(_disp "${_val}")
            endif ()

            string(LENGTH "${_fn}" _L)
            math(EXPR _pad "${_max} - ${_L}")
            _hs_obj__spaces(${_pad} _p)

            # right aligned: <spaces>'name' => 'value'
            string(APPEND _s "${_indent}${_p}'${_fn}' => '${_disp}'\n")
        endforeach ()

        set(${_outStr} "${_s}" PARENT_SCOPE)
        return()
    endif ()

    set(${_outStr} "${_indent}<unknown record MODE '${_modeVal}'>\n" PARENT_SCOPE)
endfunction()

# -------------------------------------------------------------------------------------------------
# CATALOG (read-only view)
#
# Stored as a DICT blob with reserved keys:
set(_HS_CAT_NAME_KEY "__HS_OBJ__NAME")
set(_HS_CAT_KIND_KEY "__HS_OBJ__KIND")    # value: "CATALOG"
set(_HS_CAT_SOURCES_KEY "__HS_CAT__SOURCES") # value: ";"-separated handle-token list

function(_hs_obj__is_catalog_blob _blob _outBool)
    set(${_outBool} OFF PARENT_SCOPE)
    _hs__get_object_type("${_blob}" _t)
    if (NOT _t STREQUAL "DICT")
        return()
    endif ()
    dict(CREATE _tmp "_")
    set(_tmp "${_blob}")
    dict(GET _tmp "${_HS_CAT_KIND_KEY}" _k)
    if ("${_k}" STREQUAL "CATALOG")
        set(${_outBool} ON PARENT_SCOPE)
    endif ()
endfunction()

function(_hs_obj__catalog_get_sources _catBlob _outList)
    set(${_outList} "" PARENT_SCOPE)
    dict(CREATE _tmp "_")
    set(_tmp "${_catBlob}")
    dict(GET _tmp "${_HS_CAT_SOURCES_KEY}" _s)
    if ("${_s}" STREQUAL "")
        return()
    endif ()
    # sources stored as normal CMake list string (;) already
    set(${_outList} "${_s}" PARENT_SCOPE)
endfunction()

function(_hs_obj__catalog_create_blob _outBlob _label _sources)
    if (NOT _label OR "${_label}" STREQUAL "")
        set(_label "<unnamed>")
    endif ()

    dict(CREATE _tmp "_")
    dict(SET _tmp "${_HS_CAT_NAME_KEY}" "${_label}")
    dict(SET _tmp "${_HS_CAT_KIND_KEY}" "CATALOG")
    dict(SET _tmp "${_HS_CAT_SOURCES_KEY}" "${_sources}")

    set(${_outBlob} "${_tmp}" PARENT_SCOPE)
endfunction()

function(_hs_obj__iter_descendants_first_scalar_match _blob _patternParts _prefixParts _outFoundScalar)
    # Depth-first search for the FIRST match whose value is scalar (DICT value).
    # Returns "" if none.
    set(${_outFoundScalar} "" PARENT_SCOPE)

    _hs__get_object_type("${_blob}" _t)

    # RECORD is a leaf; no scalar children
    if (_t STREQUAL "RECORD")
        return()
    endif ()

    if (_t STREQUAL "DICT")
        string(SUBSTRING "${_blob}" 1 -1 _payload)
        if ("${_payload}" STREQUAL "")
            return()
        endif ()
        string(REPLACE "${US}" ";" _kvList "${_payload}")
        list(LENGTH _kvList _kvLen)

        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _key)
            math(EXPR _vi "${_i} + 1")
            if (_vi GREATER_EQUAL _kvLen)
                break()
            endif ()
            list(GET _kvList ${_vi} _val)

            set(_cand "${_prefixParts}")
            list(APPEND _cand "${_key}")

            _hs_obj__path_glob_match("${_patternParts}" "${_cand}" _isHit)
            if (_isHit)
                _hs__get_object_type("${_val}" _vt)
                if (_vt STREQUAL "UNKNOWN" OR _vt STREQUAL "UNSET")
                    set(${_outFoundScalar} "${_val}" PARENT_SCOPE)
                    return()
                endif ()
            endif ()

            # Recurse if object
            _hs__get_object_type("${_val}" _vt2)
            if (NOT (_vt2 STREQUAL "UNKNOWN" OR _vt2 STREQUAL "UNSET"))
                _hs_obj__iter_descendants_first_scalar_match("${_val}" "${_patternParts}" "${_cand}" _sub)
                if (NOT "${_sub}" STREQUAL "")
                    set(${_outFoundScalar} "${_sub}" PARENT_SCOPE)
                    return()
                endif ()
            endif ()

            math(EXPR _i "${_i} + 2")
        endwhile ()
        return()
    endif ()

    if (_t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
        _hs__array_get_kind("${_blob}" _arrKind _arrSep)
        _hs__array_to_list("${_blob}" "${_arrSep}" _lst)
        list(LENGTH _lst _len)

        set(_ix 1)
        while (_ix LESS _len)
            list(GET _lst ${_ix} _elem)
            _hs__get_object_name("${_elem}" _elemName)

            set(_cand "${_prefixParts}")
            list(APPEND _cand "${_elemName}")

            # Arrays contain only objects; scalar hits cannot occur here directly, only via dicts below.
            _hs_obj__iter_descendants_first_scalar_match("${_elem}" "${_patternParts}" "${_cand}" _sub)
            if (NOT "${_sub}" STREQUAL "")
                set(${_outFoundScalar} "${_sub}" PARENT_SCOPE)
                return()
            endif ()

            math(EXPR _ix "${_ix} + 1")
        endwhile ()
        return()
    endif ()
endfunction()

function(_hs_obj__collect_descendant_matches_to_dict _blob _patternParts _prefixParts _dictVar)
    # Collect ALL matches into an existing dict variable _dictVar:
    #   key   = matched path string "A/B/C"
    #   value = matched value (scalar or object blob)
    #
    # NOTE: Caller owns creation of _dictVar and later stores it in global store.
    _hs__get_object_type("${_blob}" _t)

    if (_t STREQUAL "RECORD")
        return()
    endif ()

    if (_t STREQUAL "DICT")
        string(SUBSTRING "${_blob}" 1 -1 _payload)
        if (NOT "${_payload}" STREQUAL "")
            string(REPLACE "${US}" ";" _kvList "${_payload}")
            list(LENGTH _kvList _kvLen)

            set(_i 0)
            while (_i LESS _kvLen)
                list(GET _kvList ${_i} _key)
                math(EXPR _vi "${_i} + 1")
                if (_vi GREATER_EQUAL _kvLen)
                    break()
                endif ()
                list(GET _kvList ${_vi} _val)

                set(_cand "${_prefixParts}")
                list(APPEND _cand "${_key}")

                _hs_obj__path_glob_match("${_patternParts}" "${_cand}" _isHit)
                if (_isHit)
                    string(JOIN "/" _pathStr ${_cand})
                    dict(SET ${_dictVar} "${_pathStr}" "${_val}")
                endif ()

                _hs__get_object_type("${_val}" _vt)
                if (NOT (_vt STREQUAL "UNKNOWN" OR _vt STREQUAL "UNSET"))
                    _hs_obj__collect_descendant_matches_to_dict("${_val}" "${_patternParts}" "${_cand}" "${_dictVar}")
                endif ()

                math(EXPR _i "${_i} + 2")
            endwhile ()
        endif ()
        return()
    endif ()

    if (_t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
        _hs__array_get_kind("${_blob}" _arrKind _arrSep)
        _hs__array_to_list("${_blob}" "${_arrSep}" _lst)
        list(LENGTH _lst _len)

        set(_ix 1)
        while (_ix LESS _len)
            list(GET _lst ${_ix} _elem)
            _hs__get_object_name("${_elem}" _elemName)

            set(_cand "${_prefixParts}")
            list(APPEND _cand "${_elemName}")

            _hs_obj__path_glob_match("${_patternParts}" "${_cand}" _isHit)
            if (_isHit)
                string(JOIN "/" _pathStr ${_cand})
                dict(SET ${_dictVar} "${_pathStr}" "${_elem}")
            endif ()

            _hs_obj__collect_descendant_matches_to_dict("${_elem}" "${_patternParts}" "${_cand}" "${_dictVar}")
            math(EXPR _ix "${_ix} + 1")
        endwhile ()
        return()
    endif ()
endfunction()

# -------------------------------------------------------------------------------------------------
# PATH MATCHING helpers (glob over path segments)
#
# Pattern is a slash-separated string with segments:
#   *   matches exactly one segment
#   **  matches zero or more segments
#
# Example: "A/**/C" matches "A/C", "A/B/C", "A/B/D/C", ...
function(_hs_obj__split_path _path _outList)
    if ("${_path}" STREQUAL "")
        set(${_outList} "" PARENT_SCOPE)
        return()
    endif ()
    string(REPLACE "/" ";" _parts "${_path}")
    set(${_outList} "${_parts}" PARENT_SCOPE)
endfunction()

function(_hs_obj__path_glob_match _patternParts _pathParts _outBool)
    # Recursive segment matcher for (*, **, literals)
    set(${_outBool} OFF PARENT_SCOPE)

    list(LENGTH _patternParts _pLen)
    list(LENGTH _pathParts _sLen)

    if (_pLen EQUAL 0)
        if (_sLen EQUAL 0)
            set(${_outBool} ON PARENT_SCOPE)
        endif ()
        return()
    endif ()

    list(GET _patternParts 0 _p0)

    if ("${_p0}" STREQUAL "**")
        # Try zero segments
        list(SUBLIST _patternParts 1 -1 _pRest)
        _hs_obj__path_glob_match("${_pRest}" "${_pathParts}" _ok0)
        if (_ok0)
            set(${_outBool} ON PARENT_SCOPE)
            return()
        endif ()

        # Try consuming one segment (if any)
        if (_sLen GREATER 0)
            list(SUBLIST _pathParts 1 -1 _sRest)
            _hs_obj__path_glob_match("${_patternParts}" "${_sRest}" _ok1)
            if (_ok1)
                set(${_outBool} ON PARENT_SCOPE)
                return()
            endif ()
        endif ()
        return()
    endif ()

    if (_sLen EQUAL 0)
        return()
    endif ()

    list(GET _pathParts 0 _s0)
    list(SUBLIST _patternParts 1 -1 _pRest)
    list(SUBLIST _pathParts 1 -1 _sRest)

    if ("${_p0}" STREQUAL "*" OR "${_p0}" STREQUAL "${_s0}")
        _hs_obj__path_glob_match("${_pRest}" "${_sRest}" _ok)
        if (_ok)
            set(${_outBool} ON PARENT_SCOPE)
        endif ()
    endif ()
endfunction()

function(_hs_obj__iter_descendants_first_match _blob _patternParts _prefixParts _outFoundBlob)
    # Depth-first search. Returns "" if none.
    set(${_outFoundBlob} "" PARENT_SCOPE)

    _hs__get_object_type("${_blob}" _t)

    # RECORD is a leaf (no children for PATH traversal)
    if (_t STREQUAL "RECORD")
        return()
    endif ()

    # DICT: children by keys (values may be scalar or objects)
    if (_t STREQUAL "DICT")
        string(SUBSTRING "${_blob}" 1 -1 _payload)
        if ("${_payload}" STREQUAL "")
            return()
        endif ()
        string(REPLACE "${US}" ";" _kvList "${_payload}")
        list(LENGTH _kvList _kvLen)

        set(_i 0)
        while (_i LESS _kvLen)
            list(GET _kvList ${_i} _key)
            math(EXPR _vi "${_i} + 1")
            if (_vi GREATER_EQUAL _kvLen)
                break()
            endif ()
            list(GET _kvList ${_vi} _val)

            # Build candidate path
            set(_cand "${_prefixParts}")
            list(APPEND _cand "${_key}")

            _hs_obj__path_glob_match("${_patternParts}" "${_cand}" _isHit)
            if (_isHit)
                set(${_outFoundBlob} "${_val}" PARENT_SCOPE)
                return()
            endif ()

            # Recurse only if _val is an object (not scalar)
            _hs__get_object_type("${_val}" _vt)
            if (NOT (_vt STREQUAL "UNKNOWN" OR _vt STREQUAL "UNSET"))
                _hs_obj__iter_descendants_first_match("${_val}" "${_patternParts}" "${_cand}" _sub)
                if (NOT "${_sub}" STREQUAL "")
                    set(${_outFoundBlob} "${_sub}" PARENT_SCOPE)
                    return()
                endif ()
            endif ()

            math(EXPR _i "${_i} + 2")
        endwhile ()
        return()
    endif ()

    # ARRAY: children by element object names (index order)
    if (_t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
        _hs__array_get_kind("${_blob}" _arrKind _arrSep)
        _hs__array_to_list("${_blob}" "${_arrSep}" _lst)
        list(LENGTH _lst _len)

        # element 0 is array's own name
        set(_ix 1)
        while (_ix LESS _len)
            list(GET _lst ${_ix} _elem)
            _hs__get_object_name("${_elem}" _elemName)

            set(_cand "${_prefixParts}")
            list(APPEND _cand "${_elemName}")

            _hs_obj__path_glob_match("${_patternParts}" "${_cand}" _isHit)
            if (_isHit)
                set(${_outFoundBlob} "${_elem}" PARENT_SCOPE)
                return()
            endif ()

            # Recurse (arrays contain only records/arrays by our invariants)
            _hs_obj__iter_descendants_first_match("${_elem}" "${_patternParts}" "${_cand}" _sub)
            if (NOT "${_sub}" STREQUAL "")
                set(${_outFoundBlob} "${_sub}" PARENT_SCOPE)
                return()
            endif ()

            math(EXPR _ix "${_ix} + 1")
        endwhile ()
        return()
    endif ()

    # Unknown kind: no traversal
endfunction()

# -------------------------------------------------------------------------------------------------
# Handle utilities

function(_hs_obj__new_handle outToken)
    get_property(_n GLOBAL PROPERTY "HS_OBJ_NEXT_ID")
    if (NOT _n)
        set(_n 0)
    endif ()
    math(EXPR _n "${_n} + 1")
    set_property(GLOBAL PROPERTY "HS_OBJ_NEXT_ID" "${_n}")
    set(${outToken} "HS_HNDL_${_n}" PARENT_SCOPE)
endfunction()

function(_hs_obj__resolve_handle_token inVar outToken)
    if (NOT inVar OR "${inVar}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "object: missing handle variable name")
    endif ()
    if (NOT DEFINED ${inVar})
        msg(ALWAYS FATAL_ERROR "object: handle variable '${inVar}' is not defined")
    endif ()

    set(_tok "${${inVar}}")
    if ("${_tok}" STREQUAL "")
        msg(ALWAYS FATAL_ERROR "object: handle variable '${inVar}' is empty")
    endif ()

    set(${outToken} "${_tok}" PARENT_SCOPE)
endfunction()

function(_hs_obj__load_blob token outBlob)
    globalObjIsSet("${token}" _isSet)
    if (NOT _isSet)
        msg(ALWAYS FATAL_ERROR "object: unknown handle token '${token}' (not in global store)")
    endif ()

    globalObjGet("${token}" _blob)
    if (NOT _blob)
        set(_blob "")
    endif ()

    set(${outBlob} "${_blob}" PARENT_SCOPE)
endfunction()

function(_hs_obj__store_blob token blob)
    globalObjSet("${token}" "${blob}")
endfunction()

# -------------------------------------------------------------------------------------------------
# Object label and mutation gating helpers

function(_hs_obj__get_label_from_blob blob outLabel)
    set(${outLabel} "" PARENT_SCOPE)

    _hs__get_object_type("${blob}" _t)
    if (_t STREQUAL "DICT")
        dict(CREATE _tmp "_")
        set(_tmp "${blob}")
        dict(GET _tmp "__HS_OBJ__NAME" _nm)
        if ("${_nm}" STREQUAL "")
            set(_nm "<unnamed>")
        endif ()
        set(${outLabel} "${_nm}" PARENT_SCOPE)
        return()
    endif ()

    _hs__get_object_name("${blob}" _nm)
    if ("${_nm}" STREQUAL "")
        set(_nm "<unnamed>")
    endif ()
    set(${outLabel} "${_nm}" PARENT_SCOPE)
endfunction()

function(_hs_obj__assert_mutable_allowed token blob opName)
    _hs_obj__get_label_from_blob("${blob}" _lbl)
    if ("${_lbl}" STREQUAL "<unnamed>" AND NOT "${opName}" STREQUAL "RENAME")
        msg(ALWAYS FATAL_ERROR
                "object(${opName}): object '${token}' has label '<unnamed>'. "
                "You MUST object(RENAME ...) it before any other mutation."
        )
    endif ()
endfunction()

# -------------------------------------------------------------------------------------------------
# RECORD storage: dict-like key->string, implemented in a RECORD blob (FS-separated kv pairs)
#
#   {FS}<recordLabel>{FS}<k1>{FS}<v1>{FS}<k2>{FS}<v2>...
#
# UNSET sentinel: used for "field exists but not written yet" so reads return NOTFOUND.
set(_HS_REC_UNSET_VALUE "__HS_REC__UNSET__")

set(_HS_REC_META_PREFIX "__HS_REC__")
set(_HS_REC_META_MODE "${_HS_REC_META_PREFIX}MODE")    # POSITIONAL | SCHEMA
set(_HS_REC_META_FIELDS "${_HS_REC_META_PREFIX}FIELDS")  # ";" list of field labels in order
set(_HS_REC_META_FIXED "${_HS_REC_META_PREFIX}FIXED")   # "0" | "1"
set(_HS_REC_META_SIZE "${_HS_REC_META_PREFIX}SIZE")    # integer length (for POSITIONAL records)

# IMPORTANT:
# We must NOT store a literal CMake list (semicolon-separated) inside a record value.
# Doing so corrupts the record's kv decoding (because record->list conversion uses ';').
# So we store field lists using a dedicated separator token, then decode only when iterating.
set(_HS_REC_FIELDS_SEP "»«")

function(_hs_obj__meta_diag _blob _outStr)
    # Produce a compact, single-string diagnostic describing what we are looking at.
    # Safe to include in fatal errors.
    set(${_outStr} "" PARENT_SCOPE)

    _hs__get_object_type("${_blob}" _t)
    _hs_obj__get_label_from_blob("${_blob}" _lbl)

    set(_s "")
    string(APPEND _s "kind=${_t}, label='${_lbl}'")

    if (_t STREQUAL "RECORD")
        _hs_obj__rec_get_kv("${_blob}" "${_HS_REC_META_MODE}" _hm _mode)
        _hs_obj__rec_get_kv("${_blob}" "${_HS_REC_META_SIZE}" _hs _size)
        _hs_obj__rec_get_kv("${_blob}" "${_HS_REC_META_FIXED}" _hf _fixed)
        _hs_obj__rec_get_kv("${_blob}" "${_HS_REC_META_FIELDS}" _hfl _fieldsStore)

        if (NOT _hm)
            set(_mode "<missing>")
        elseif ("${_mode}" STREQUAL "")
            set(_mode "<empty>")
        endif ()

        if (NOT _hs)
            set(_size "<missing>")
        elseif ("${_size}" STREQUAL "")
            set(_size "<empty>")
        endif ()

        if (NOT _hf)
            set(_fixed "<missing>")
        elseif ("${_fixed}" STREQUAL "")
            set(_fixed "<empty>")
        endif ()

        if (NOT _hfl)
            set(_fieldsStore "<missing>")
        elseif ("${_fieldsStore}" STREQUAL "")
            set(_fieldsStore "<empty>")
        endif ()

        # Decode stored fields for readability (keeps it on one line)
        set(_fieldsDecoded "${_fieldsStore}")
        if (NOT "${_fieldsStore}" STREQUAL "<missing>" AND NOT "${_fieldsStore}" STREQUAL "<empty>")
            string(REPLACE "${_HS_REC_FIELDS_SEP}" ";" _fieldsDecoded "${_fieldsStore}")
        endif ()

        string(APPEND _s ", meta={MODE='${_mode}', SIZE='${_size}', FIXED='${_fixed}', FIELDS_STORE='${_fieldsStore}', FIELDS='${_fieldsDecoded}'}")
    endif ()

    # Show marker sanity (helps spot accidental scalar blobs)
    string(SUBSTRING "${_blob}" 0 1 _m0)
    string(APPEND _s ", marker='${_m0}'")

    set(${_outStr} "${_s}" PARENT_SCOPE)
endfunction()

function(_hs_obj__rec_to_list recValue outListVar)
    _hs__record_to_list("${recValue}" _lst)
    set(${outListVar} "${_lst}" PARENT_SCOPE)
endfunction()

function(_hs_obj__rec_set_kv recValue key userVal outRecValue)
    _hs__assert_no_ctrl_chars("object(RECORD key)" "${key}")
    _hs__assert_no_ctrl_chars("object(RECORD value)" "${userVal}")

    _hs_obj__rec_to_list("${recValue}" _lst)
    list(LENGTH _lst _len)

    # --- Diagnostics helpers (local to this function) ---
    _hs__get_object_name("${recValue}" _recLabel)
    if ("${_recLabel}" STREQUAL "")
        set(_recLabel "<unknown>")
    endif ()
    string(SUBSTRING "${recValue}" 0 1 _firstChar)
    if ("${_firstChar}" STREQUAL "${FS}")
        set(_hasLeadingFS "yes")
    else ()
        set(_hasLeadingFS "no")
    endif ()

    # Provide a small preview of the decoded list to help debug corruption without spamming logs.
    set(_previewN 10)
    if (_len LESS _previewN)
        set(_previewN "${_len}")
    endif ()
    set(_preview "")
    if (_previewN GREATER 0)
        math(EXPR _previewLast "${_previewN} - 1")
        foreach (_px RANGE 0 ${_previewLast})
            list(GET _lst ${_px} _pv)
            string(REPLACE "\n" "\\n" _pv "${_pv}")
            if (_px EQUAL 0)
                set(_preview "[${_px}]='${_pv}'")
            else ()
                string(APPEND _preview ", [${_px}]='${_pv}'")
            endif ()
        endforeach ()
    endif ()

    if (_len LESS 2)
        msg(ALWAYS FATAL_ERROR
                "object(RECORD): corrupt encoding while setting key/value.\n"
                "  Operation : SET_KV\n"
                "  Record    : label='${_recLabel}', hasLeadingFS=${_hasLeadingFS}\n"
                "  Expected  : encoded as {FS}<label>{FS}<k1>{FS}<v1>... so the decoded list must have >= 2 elements\n"
                "             (typically [0] is empty due to leading FS, [1] is the label).\n"
                "  Got       : listLen=${_len}\n"
                "  Key       : '${key}'\n"
                "  Value     : '<provided>' (storage conversion happens after structure validation)\n"
                "  Preview   : ${_preview}\n"
                "  RawFirst  : firstChar='${_firstChar}' (expected FS)"
        )
    endif ()

    # Structural invariant: kv pairs start at index 2, so remaining length must be even.
    math(EXPR _tailLen "${_len} - 2")
    math(EXPR _tailOdd "${_tailLen} % 2")
    if (NOT _tailOdd EQUAL 0)
        msg(ALWAYS FATAL_ERROR
                "object(RECORD): corrupt encoding while setting key/value.\n"
                "  Problem   : odd kv length (dangling key without value)\n"
                "  Record    : label='${_recLabel}', hasLeadingFS=${_hasLeadingFS}\n"
                "  Expected  : (listLen - 2) must be even; keys/values are stored as pairs starting at list index 2\n"
                "  Got       : listLen=${_len}, tailLen=${_tailLen} (tailLen%2=${_tailOdd})\n"
                "  Key       : '${key}'\n"
                "  Preview   : ${_preview}"
        )
    endif ()

    _hs__field_to_storage("${userVal}" _vStore)

    set(_i 2)
    set(_found OFF)
    while (_i LESS _len)
        list(GET _lst ${_i} _k)
        math(EXPR _vi "${_i} + 1")
        if (_vi GREATER_EQUAL _len)
            # This should now be unreachable due to the tail parity check above, but keep it
            # as a belt-and-suspenders assertion with richer context.
            msg(ALWAYS FATAL_ERROR
                    "object(RECORD): corrupt encoding while scanning kv pairs (unexpected end-of-list).\n"
                    "  Record    : label='${_recLabel}', hasLeadingFS=${_hasLeadingFS}\n"
                    "  Expected  : value index (i+1) to be < listLen for each key/value pair\n"
                    "  Got       : i=${_i}, vi=${_vi}, listLen=${_len}\n"
                    "  CurrentK  : '${_k}'\n"
                    "  TargetK   : '${key}'\n"
                    "  Preview   : ${_preview}"
            )
        endif ()

        if ("${_k}" STREQUAL "${key}")
            list(REMOVE_AT _lst ${_vi})
            list(INSERT _lst ${_vi} "${_vStore}")
            set(_found ON)
            break()
        endif ()

        math(EXPR _i "${_i} + 2")
    endwhile ()

    if (NOT _found)
        list(APPEND _lst "${key}" "${_vStore}")
    endif ()

    _hs__list_to_record("${_lst}" _out)
    if (NOT "${_out}" MATCHES "^${FS}")
        set(_out "${FS}${_out}")
    endif ()

    set(${outRecValue} "${_out}" PARENT_SCOPE)
endfunction()
function(_hs_obj__rec_remove_kv recValue key outRecValue)
    _hs_obj__rec_to_list("${recValue}" _lst)
    list(LENGTH _lst _len)
    if (_len LESS 2)
        set(${outRecValue} "${recValue}" PARENT_SCOPE)
        return()
    endif ()

    set(_i 2)
    while (_i LESS _len)
        list(GET _lst ${_i} _k)
        math(EXPR _vi "${_i} + 1")
        if (_vi GREATER_EQUAL _len)
            break()
        endif ()

        if ("${_k}" STREQUAL "${key}")
            list(REMOVE_AT _lst ${_vi})
            list(REMOVE_AT _lst ${_i})
            break()
        endif ()

        math(EXPR _i "${_i} + 2")
        list(LENGTH _lst _len)
    endwhile ()

    _hs__list_to_record("${_lst}" _out)
    if (NOT "${_out}" MATCHES "^${FS}")
        set(_out "${FS}${_out}")
    endif ()
    set(${outRecValue} "${_out}" PARENT_SCOPE)
endfunction()

function(_hs_obj__rec_get_kv recValue key outFound outUserVal)
    set(${outFound} "0" PARENT_SCOPE)
    set(${outUserVal} "" PARENT_SCOPE)

    _hs_obj__rec_to_list("${recValue}" _lst)
    list(LENGTH _lst _len)
    if (_len LESS 2)
        return()
    endif ()

    set(_i 2)
    while (_i LESS _len)
        list(GET _lst ${_i} _k)
        math(EXPR _vi "${_i} + 1")
        if (_vi GREATER_EQUAL _len)
            return()
        endif ()

        if ("${_k}" STREQUAL "${key}")
            list(GET _lst ${_vi} _vStore)
            _hs__field_to_user("${_vStore}" _vUser)
            set(${outFound} "1" PARENT_SCOPE)
            set(${outUserVal} "${_vUser}" PARENT_SCOPE)
            return()
        endif ()

        math(EXPR _i "${_i} + 2")
    endwhile ()
endfunction()

function(_hs_obj__rec_create_blob outBlob label mode fields fixed size)
    if (NOT label OR "${label}" STREQUAL "")
        set(label "<unnamed>")
    endif ()

    record(CREATE _tmpRec "${label}" 0)
    set(_rec "${_tmpRec}")

    # Encode fields list into a single scalar string (no ';')
    set(_fieldsStore "")
    if (NOT "${fields}" STREQUAL "")
        string(JOIN "${_HS_REC_FIELDS_SEP}" _fieldsStore ${fields})
    endif ()

    _hs_obj__rec_set_kv("${_rec}" "${_HS_REC_META_MODE}" "${mode}" _rec)
    _hs_obj__rec_set_kv("${_rec}" "${_HS_REC_META_FIELDS}" "${_fieldsStore}" _rec)
    _hs_obj__rec_set_kv("${_rec}" "${_HS_REC_META_FIXED}" "${fixed}" _rec)
    _hs_obj__rec_set_kv("${_rec}" "${_HS_REC_META_SIZE}" "${size}" _rec)

    foreach (_k IN LISTS fields)
        if (_k MATCHES "^__HS_REC__")
            msg(ALWAYS FATAL_ERROR "object(CREATE RECORD): field name '${_k}' is reserved")
        endif ()
        _hs_obj__rec_set_kv("${_rec}" "${_k}" "${_HS_REC_UNSET_VALUE}" _rec)
    endforeach ()

    set(${outBlob} "${_rec}" PARENT_SCOPE)
endfunction()

function(_hs_obj__rec_ensure_index_capacity recValue targetIndex outRecValue)
    # Ensure indices 0..targetIndex exist as keys, filled with UNSET.
    _hs_obj__rec_get_kv("${recValue}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
    if (NOT _hs OR "${_sizeStr}" STREQUAL "")
        set(_size 0)
    else ()
        set(_size "${_sizeStr}")
    endif ()

    if (NOT _size MATCHES "^[0-9]+$")
        _hs_obj__meta_diag("${recValue}" _diag)
        msg(ALWAYS FATAL_ERROR
                "object(RECORD): corrupt SIZE meta '${_size}'.\n"
                "  LookedAt : ${_diag}"
        )
    endif ()

    set(_rec "${recValue}")

    if (targetIndex LESS _size)
        set(${outRecValue} "${_rec}" PARENT_SCOPE)
        return()
    endif ()

    foreach (_i RANGE ${_size} ${targetIndex})
        _hs_obj__rec_set_kv("${_rec}" "${_i}" "${_HS_REC_UNSET_VALUE}" _rec)
    endforeach ()

    math(EXPR _newSize "${targetIndex} + 1")
    _hs_obj__rec_set_kv("${_rec}" "${_HS_REC_META_SIZE}" "${_newSize}" _rec)

    # Also refresh FIELDS order list for positional records
    set(_fields "")
    if (_newSize GREATER 0)
        math(EXPR _last "${_newSize} - 1")
        foreach (_i RANGE 0 ${_last})
            list(APPEND _fields "${_i}")
        endforeach ()
    endif ()

    # Store as a single scalar string, not a CMake list
    set(_fieldsStore "")
    if (NOT "${_fields}" STREQUAL "")
        string(JOIN "${_HS_REC_FIELDS_SEP}" _fieldsStore ${_fields})
    endif ()
    _hs_obj__rec_set_kv("${_rec}" "${_HS_REC_META_FIELDS}" "${_fieldsStore}" _rec)

    set(${outRecValue} "${_rec}" PARENT_SCOPE)
endfunction()

# -------------------------------------------------------------------------------------------------
# foreachobject() - callback-based iteration (CMake-friendly)
#
# Usage:
#   foreachobject(FROM rootHandleVar CHILDREN CALL myFn)
#
# Where myFn is a command that accepts one argument: the child handle token.
function(foreachobject)
    if (NOT (ARGC EQUAL 5 AND "${ARGV0}" STREQUAL "FROM" AND "${ARGV2}" STREQUAL "CHILDREN" AND "${ARGV3}" STREQUAL "CALL"))
        msg(ALWAYS FATAL_ERROR "foreachobject: expected foreachobject(FROM <handleVar> CHILDREN CALL <fn>)")
    endif ()

    set(_srcHandleVar "${ARGV1}")
    set(_fn "${ARGV4}")

    if (NOT COMMAND "${_fn}")
        msg(ALWAYS FATAL_ERROR "foreachobject: '${_fn}' is not a command")
    endif ()

    object(ITER_HANDLES __HS_FOREACHOBJECT__LIST FROM ${_srcHandleVar} CHILDREN)

    foreach (_h IN LISTS __HS_FOREACHOBJECT__LIST)
        cmake_language(CALL "${_fn}" "${_h}")
    endforeach ()

    unset(__HS_FOREACHOBJECT__LIST)
endfunction()

# -------------------------------------------------------------------------------------------------
# Public API: object(...)

function(object)
    if (ARGC LESS 1)
        msg(ALWAYS FATAL_ERROR "object: expected object(<VERB> ...)")
    endif ()

    list(POP_FRONT ARGN _verb)
    string(TOUPPER "${_verb}" _verb)

    # ----------------------------------------------------------------------------------------------
    # CREATE
    #
    # Implemented:
    #   - RECORD (existing; LENGTH/FIELDS optional)
    #   - DICT
    #   - ARRAY
    #
    # Handles are always auto-generated tokens; blobs live only in GLOBAL store.
    if (_verb STREQUAL "CREATE")
        set(_opts FIXED)
        set(_one KIND LABEL LENGTH TYPE)
        set(_multi FIELDS)
        cmake_parse_arguments(OC "${_opts}" "${_one}" "${_multi}" ${ARGN})

        if (NOT OC_UNPARSED_ARGUMENTS)
            msg(ALWAYS FATAL_ERROR "object(CREATE): missing <outHandleVar>")
        endif ()
        list(POP_FRONT OC_UNPARSED_ARGUMENTS _outHandleVar)

        if (NOT OC_KIND)
            msg(ALWAYS FATAL_ERROR "object(CREATE): KIND is required (RECORD|DICT|ARRAY)")
        endif ()
        string(TOUPPER "${OC_KIND}" _kind)

        if (DEFINED OC_FIELDS AND DEFINED OC_LENGTH)
            msg(ALWAYS FATAL_ERROR "object(CREATE RECORD): use either FIELDS or LENGTH, not both")
        endif ()

        if (NOT OC_LABEL)
            set(OC_LABEL "<unnamed>")
        endif ()

        # Allocate handle token now (common for all kinds)
        _hs_obj__new_handle(_tok)

        # -------------------- CREATE DICT --------------------
        if (_kind STREQUAL "DICT")
            # Create dict blob. We support a label by storing a reserved scalar key.
            if (NOT "${OC_LABEL}" STREQUAL "<unnamed>")
                _hs__assert_no_ctrl_chars("object(CREATE DICT LABEL)" "${OC_LABEL}")
            endif ()

            # IMPORTANT: object-layer DICT blob must start as an *empty* dict encoding.
            # Don't use dict(CREATE ...) here because that helper currently bakes extra tokens
            # into the payload; we want a clean {US}-prefixed empty dict.
            set(_tmp "${US}")

            # Store label (including "<unnamed>") explicitly so NAME/PATH can use it later.
            dict(SET _tmp "__HS_OBJ__NAME" "${OC_LABEL}")

            _hs_obj__store_blob("${_tok}" "${_tmp}")
            set(${_outHandleVar} "${_tok}" PARENT_SCOPE)
            return()
        endif ()
        # -------------------- CREATE ARRAY --------------------
        if (_kind STREQUAL "ARRAY")
            # Require TYPE = RECORDS|ARRAYS to define element-kind invariant.
            if (NOT OC_TYPE)
                msg(ALWAYS FATAL_ERROR "object(CREATE ARRAY): TYPE is required (RECORDS|ARRAYS)")
            endif ()

            string(TOUPPER "${OC_TYPE}" _arrType)
            if (NOT (_arrType STREQUAL "RECORDS" OR _arrType STREQUAL "ARRAYS"))
                msg(ALWAYS FATAL_ERROR "object(CREATE ARRAY): TYPE must be RECORDS or ARRAYS, got '${OC_TYPE}'")
            endif ()

            if (NOT "${OC_LABEL}" STREQUAL "<unnamed>")
                _hs__assert_no_ctrl_chars("object(CREATE ARRAY LABEL)" "${OC_LABEL}")
            endif ()

            # array(CREATE <var> <label> RECORDS|ARRAYS)
            array(CREATE _tmpArr "${OC_LABEL}" "${_arrType}")

            _hs_obj__store_blob("${_tok}" "${_tmpArr}")
            set(${_outHandleVar} "${_tok}" PARENT_SCOPE)
            return()
        endif ()

        # -------------------- CREATE RECORD --------------------
        if (_kind STREQUAL "RECORD")

            # default values when neither LENGTH nor FIELDS
            set(_mode "POSITIONAL")
            set(_fields "")
            set(_size 0)
            set(_fixed "0")

            if (DEFINED OC_FIELDS)
                set(_mode "SCHEMA")
                set(_fields "${OC_FIELDS}")
                if ("${_fields}" STREQUAL "")
                    msg(ALWAYS FATAL_ERROR "object(CREATE RECORD): FIELDS must not be empty")
                endif ()
                list(LENGTH _fields _size)
                set(_fixed "1") # auto-fixed when FIELDS supplied
            elseif (DEFINED OC_LENGTH)
                if (NOT OC_LENGTH MATCHES "^[0-9]+$")
                    msg(ALWAYS FATAL_ERROR "object(CREATE RECORD): LENGTH must be a non-negative integer, got '${OC_LENGTH}'")
                endif ()
                set(_mode "POSITIONAL")
                set(_size "${OC_LENGTH}")
                if (_size GREATER 0)
                    math(EXPR _last "${_size} - 1")
                    foreach (_i RANGE 0 ${_last})
                        list(APPEND _fields "${_i}")
                    endforeach ()
                endif ()
                if (OC_FIXED)
                    set(_fixed "1")
                endif ()
            else ()
                # neither LENGTH nor FIELDS => empty indexed record
                if (OC_FIXED)
                    # Fixed empty is allowed (can only ever hold 0 fields)
                    set(_fixed "1")
                endif ()
            endif ()

#            _hs_obj__new_handle(_tok)
            _hs_obj__rec_create_blob(_blob "${OC_LABEL}" "${_mode}" "${_fields}" "${_fixed}" "${_size}")
            _hs_obj__store_blob("${_tok}" "${_blob}")

            set(${_outHandleVar} "${_tok}" PARENT_SCOPE)
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(CREATE): unsupported KIND '${_kind}'")

    endif ()

    # ----------------------------------------------------------------------------------------------
    # CREATE_VIEW (CATALOG)
    #
    # object(CREATE_VIEW outHandle FROM <h1> [<h2> ...] [LABEL "<label>"])
    #
    # Creates a read-only catalog/view over one or more source handles.
    # Read operations consult sources in-order. Mutations on the view FATAL_ERROR.
    if (_verb STREQUAL "CREATE_VIEW")
        if (ARGC LESS 4 OR NOT "${ARGV2}" STREQUAL "FROM")
            msg(ALWAYS FATAL_ERROR "object(CREATE_VIEW): expected object(CREATE_VIEW <outHandleVar> FROM <h1> [<h2> ...] [LABEL <label>])")
        endif ()

        set(_outHandleVar "${ARGV1}")

        # Parse: FROM <h1> <h2> ... [LABEL <label>]
        set(_label "<unnamed>")
        set(_srcHandleVars "")

        set(_i 3)
        while (_i LESS ARGC)
            if ("${ARGV${_i}}" STREQUAL "LABEL")
                math(EXPR _j "${_i} + 1")
                if (_j GREATER_EQUAL ARGC)
                    msg(ALWAYS FATAL_ERROR "object(CREATE_VIEW): LABEL requires a value")
                endif ()
                set(_label "${ARGV${_j}}")
                math(EXPR _i "${_i} + 2")
                continue()
            endif ()

            list(APPEND _srcHandleVars "${ARGV${_i}}")
            math(EXPR _i "${_i} + 1")
        endwhile ()

        if ("${_srcHandleVars}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "object(CREATE_VIEW): at least one source handle is required")
        endif ()

        # Resolve to handle TOKENS (not blobs), store the tokens in the catalog
        set(_sourceTokens "")
        foreach (_hv IN LISTS _srcHandleVars)
            _hs_obj__resolve_handle_token("${_hv}" _tok)
            # Ensure the source exists
            _hs_obj__load_blob("${_tok}" _dc)
            list(APPEND _sourceTokens "${_tok}")
        endforeach ()

        _hs_obj__new_handle(_catTok)
        _hs_obj__catalog_create_blob(_catBlob "${_label}" "${_sourceTokens}")
        _hs_obj__store_blob("${_catTok}" "${_catBlob}")

        set(${_outHandleVar} "${_catTok}" PARENT_SCOPE)
        return()
    endif ()

    # ----------------------------------------------------------------------------------------------
    # KIND
    if (_verb STREQUAL "KIND")
        if (NOT ARGC EQUAL 3)
            msg(ALWAYS FATAL_ERROR "object(KIND): expected object(KIND <handleVar> <outKindVar>)")
        endif ()

        _hs_obj__resolve_handle_token("${ARGV1}" _tok)
        _hs_obj__load_blob("${_tok}" _blob)

        _hs_obj__is_catalog_blob("${_blob}" _isCat)
        if (_isCat)
            set(${ARGV2} "CATALOG" PARENT_SCOPE)
            return()
        endif ()

        _hs__get_object_type("${_blob}" _t)
        if (_t STREQUAL "RECORD")
            set(${ARGV2} "RECORD" PARENT_SCOPE)
        elseif (_t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
            set(${ARGV2} "ARRAY" PARENT_SCOPE)
        elseif (_t STREQUAL "DICT")
            set(${ARGV2} "DICT" PARENT_SCOPE)
        elseif (_t STREQUAL "UNSET")
            set(${ARGV2} "UNSET" PARENT_SCOPE)
        else ()
            set(${ARGV2} "UNKNOWN" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # ----------------------------------------------------------------------------------------------
    # NAME
    #
    # object(NAME outStr FROM <handleVar>)
    #
    # Returns the object's embedded label:
    # - RECORD / ARRAY: embedded object name
    # - DICT: stored in reserved key "__HS_OBJ__NAME" (falls back to "<unnamed>" if missing)
    if (_verb STREQUAL "NAME")
        if (NOT (ARGC EQUAL 4 AND "${ARGV2}" STREQUAL "FROM"))
            msg(ALWAYS FATAL_ERROR "object(NAME): expected object(NAME <outStrVar> FROM <handleVar>)")
        endif ()

        set(_outStr "${ARGV1}")
        set(_srcHandleVar "${ARGV3}")
        set(${_outStr} "" PARENT_SCOPE)

        _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
        _hs_obj__load_blob("${_tok}" _blob)

        _hs_obj__is_catalog_blob("${_blob}" _isCat)
        if (_isCat)
            dict(CREATE _tmp "_")
            set(_tmp "${_blob}")
            dict(GET _tmp "${_HS_CAT_NAME_KEY}" _nm)
            if ("${_nm}" STREQUAL "")
                set(_nm "<unnamed>")
            endif ()
            set(${_outStr} "${_nm}" PARENT_SCOPE)
            return()
        endif ()

        _hs__get_object_type("${_blob}" _t)
        if (_t STREQUAL "DICT")
            dict(CREATE _tmp "_")
            set(_tmp "${_blob}")
            dict(GET _tmp "__HS_OBJ__NAME" _nm)
            if ("${_nm}" STREQUAL "")
                set(_nm "<unnamed>")
            endif ()
            set(${_outStr} "${_nm}" PARENT_SCOPE)
            return()
        endif ()

        # RECORD / ARRAY_* use embedded name
        _hs__get_object_name("${_blob}" _nm)
        if ("${_nm}" STREQUAL "")
            set(_nm "<unnamed>")
        endif ()
        set(${_outStr} "${_nm}" PARENT_SCOPE)
        return()
    endif ()

    # ----------------------------------------------------------------------------------------------
    # ASSERT_KIND
    if (_verb STREQUAL "ASSERT_KIND")
        if (ARGC LESS 3)
            msg(ALWAYS FATAL_ERROR "object(ASSERT_KIND): expected object(ASSERT_KIND <handleVar> <expectedKind>...)")
        endif ()

        object(KIND ${ARGV1} _k)

        set(_ok OFF)
        set(_i 2)
        while (_i LESS ARGC)
            if ("${_k}" STREQUAL "${ARGV${_i}}")
                set(_ok ON)
                break()
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()

        if (NOT _ok)
            msg(ALWAYS FATAL_ERROR "object(ASSERT_KIND): kind is '${_k}', expected one of '${ARGN}'")
        endif ()
        return()
    endif ()

    # ----------------------------------------------------------------------------------------------
    # RENAME (any object kind) -- unchanged from prior version (kept)
    if (_verb STREQUAL "RENAME")
        if (NOT ARGC EQUAL 3)
            msg(ALWAYS FATAL_ERROR "object(RENAME): expected object(RENAME <handleVar> <newLabel>)")
        endif ()

        _hs_obj__resolve_handle_token("${ARGV1}" _tok)
        set(_newLabel "${ARGV2}")

        if ("${_newLabel}" STREQUAL "" OR "${_newLabel}" STREQUAL "<unnamed>")
            msg(ALWAYS FATAL_ERROR "object(RENAME): new label must be non-empty and not '<unnamed>'")
        endif ()

        _hs__assert_no_ctrl_chars("object(RENAME)" "${_newLabel}")

        _hs_obj__load_blob("${_tok}" _blob)
        _hs__get_object_type("${_blob}" _t)

        if (_t STREQUAL "RECORD" OR _t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
            _hs__set_object_name("${_blob}" "${_newLabel}" _out)
            _hs_obj__store_blob("${_tok}" "${_out}")
            return()
        elseif (_t STREQUAL "DICT")
            set(_nameKey "__HS_OBJ__NAME")
            dict(CREATE _tmp "_")
            set(_tmp "${_blob}")
            dict(SET _tmp "${_nameKey}" "${_newLabel}")
            _hs_obj__store_blob("${_tok}" "${_tmp}")
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(RENAME): unsupported/unknown kind '${_t}'")
    endif ()

    # ----------------------------------------------------------------------------------------------
    # FIELD_NAMES (mutator) - converts indexed record to named-field record
    #
    # object(FIELD_NAMES <handleVar> NAMES "A;B;C")
    # - Requires POSITIONAL mode
    # - Requires size match exactly
    # - Converts keys "0","1",... to the provided names
    # - Switches MODE to SCHEMA, sets FIELDS to the provided list, and forbids INDEX ops thereafter
    if (_verb STREQUAL "FIELD_NAMES")
        if (NOT ARGC EQUAL 4 OR NOT "${ARGV2}" STREQUAL "NAMES")
            msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): expected object(FIELD_NAMES <handleVar> NAMES \"A;B;C\")")
        endif ()

        _hs_obj__resolve_handle_token("${ARGV1}" _tok)
        set(_names "${ARGV3}")

        _hs_obj__load_blob("${_tok}" _rec)
        _hs__get_object_type("${_rec}" _t)
        if (NOT _t STREQUAL "RECORD")
            msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): only valid for RECORD")
        endif ()

        _hs_obj__assert_mutable_allowed("${_tok}" "${_rec}" "FIELD_NAMES")

        _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_MODE}" _hm _modeVal)
        if (NOT _hm)
            _hs_obj__meta_diag("${_rec}" _diag)
            msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): RECORD missing MODE meta\n"
                    "  LookedAt : ${_diag}"
            )
        endif ()
        if (NOT "${_modeVal}" STREQUAL "POSITIONAL")
            if (NOT _hm)
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): only allowed for indexed (POSITIONAL) records\n"
                        "  LookedAt : ${_diag}"
                )
            endif ()
        endif ()

        _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
        if (NOT _hs)
            set(_sizeStr "0")
        endif ()

        if (NOT _sizeStr MATCHES "^[0-9]+$")
            if (NOT _hm)
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): corrupt SIZE meta '${_sizeStr}'\n"
                        "  LookedAt : ${_diag}"
                )
            endif ()
        endif ()

        list(LENGTH _names _nNames)
        if (NOT _nNames EQUAL _sizeStr)
            _hs_obj__meta_diag("${_rec}" _diag)
            msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): NAMES count (${_nNames}) must equal record size (${_sizeStr})\n"
                    "  LookedAt : ${_diag}")
        endif ()

        # Rename keys
        set(_i 0)
        set(_out "${_rec}")
        foreach (_nm IN LISTS _names)
            if ("${_nm}" STREQUAL "" OR "${_nm}" STREQUAL "<unnamed>")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): invalid field name '${_nm}'\n"
                        "  LookedAt : ${_diag}")
            endif ()

            _hs_obj__rec_get_kv("${_out}" "${_i}" _found _val)
            if (NOT _found)
                # Should not happen if size is consistent, but keep strict
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(FIELD_NAMES): missing positional key '${_i}'\n"
                        "  LookedAt : ${_diag}")
            endif ()

            _hs_obj__rec_remove_kv("${_out}" "${_i}" _out)
            _hs_obj__rec_set_kv("${_out}" "${_nm}" "${_val}" _out)

            math(EXPR _i "${_i} + 1")
        endforeach ()

        _hs_obj__rec_set_kv("${_out}" "${_HS_REC_META_MODE}" "SCHEMA" _out)
        _hs_obj__rec_set_kv("${_out}" "${_HS_REC_META_FIELDS}" "${_names}" _out)
        _hs_obj__rec_set_kv("${_out}" "${_HS_REC_META_FIXED}" "1" _out) # naming locks schema => fixed

        _hs_obj__store_blob("${_tok}" "${_out}")
        return()
    endif ()

    # ----------------------------------------------------------------------------------------------
    # SET (mutator)
    #
    # RECORD:
    #   object(SET <handleVar> INDEX <startIndex> <v1> <v2> ... )
    #   object(SET <handleVar> NAME EQUAL <fieldName> VALUE <v>)
    #
    # DICT:
    #   object(SET <dictHandleVar> NAME EQUAL <key> HANDLE <childHandleVar> [REPLACE])
    #   object(SET <dictHandleVar> NAME EQUAL <key> STRING <value>        [REPLACE])
    #
    # Dict overwrite policy:
    # - If key exists and REPLACE is NOT specified => FATAL_ERROR
    if (_verb STREQUAL "SET")

        # Fast-path: if first arg is a handleVar, block writes to catalog
        if (ARGC GREATER 1)
            # Only check if it's a defined variable (handle var)
            if (DEFINED ${ARGV1})
                _hs_obj__resolve_handle_token("${ARGV1}" _mtok)
                _hs_obj__load_blob("${_mtok}" _mblob)
                _hs_obj__is_catalog_blob("${_mblob}" _isCat)
                if (_isCat)
                    msg(ALWAYS FATAL_ERROR "object(${_verb}): CATALOG is a read-only view")
                endif ()
            endif ()
        endif ()

        if (ARGC LESS 5)
            msg(ALWAYS FATAL_ERROR "object(SET): insufficient arguments")
        endif ()

        _hs_obj__resolve_handle_token("${ARGV1}" _tok)
        _hs_obj__load_blob("${_tok}" _objBlob)
        _hs__get_object_type("${_objBlob}" _t)

        # -------------------- DICT SET --------------------
        if (_t STREQUAL "DICT")
            _hs_obj__assert_mutable_allowed("${_tok}" "${_objBlob}" "SET")

            if (NOT ("${ARGV2}" STREQUAL "NAME" AND "${ARGV3}" STREQUAL "EQUAL"))
                msg(ALWAYS FATAL_ERROR "object(SET DICT): expected object(SET <dictHandleVar> NAME EQUAL <key> HANDLE <childHandleVar> [REPLACE]) or object(SET <dictHandleVar> NAME EQUAL <key> STRING <value> [REPLACE])")
            endif ()

            set(_key "${ARGV4}")

            # Parse tail: HANDLE <h> | STRING <v> plus optional REPLACE at end
            set(_replace OFF)
            math(EXPR _last "${ARGC} - 1")
            if ("${ARGV${_last}}" STREQUAL "REPLACE")
                set(_replace ON)
                math(EXPR _tailEnd "${_last} - 1")
            else ()
                set(_tailEnd "${_last}")
            endif ()

            if (_tailEnd LESS 5)
                msg(ALWAYS FATAL_ERROR "object(SET DICT): missing HANDLE/STRING payload")
            endif ()

            set(_mode "${ARGV5}")

            dict(CREATE _tmp "_")
            set(_tmp "${_objBlob}")

            # Does key already exist?
            dict(GET _tmp "${_key}" _existing)
            if (NOT "${_existing}" STREQUAL "")
                if (NOT _replace)
                    msg(ALWAYS FATAL_ERROR "object(SET DICT): key '${_key}' already exists; specify REPLACE to overwrite")
                endif ()
            endif ()

            if ("${_mode}" STREQUAL "HANDLE")
                if (NOT _tailEnd EQUAL 6)
                    msg(ALWAYS FATAL_ERROR "object(SET DICT HANDLE): expected object(SET <dict> NAME EQUAL <key> HANDLE <childHandleVar> [REPLACE])")
                endif ()

                set(_childHandleVar "${ARGV6}")
                _hs_obj__resolve_handle_token("${_childHandleVar}" _childTok)
                _hs_obj__load_blob("${_childTok}" _childBlob)

                # Enforce "named before insertion" (same rationale as arrays)
                _hs_obj__get_label_from_blob("${_childBlob}" _childLabel)
                if ("${_childLabel}" STREQUAL "<unnamed>")
                    msg(ALWAYS FATAL_ERROR "object(SET DICT HANDLE): cannot store an '<unnamed>' object; object(RENAME ...) it first")
                endif ()

                dict(SET _tmp "${_key}" "${_childBlob}")
                _hs_obj__store_blob("${_tok}" "${_tmp}")
                return()

            elseif ("${_mode}" STREQUAL "STRING")
                # STRING value may contain spaces; cmake_parse_arguments isn't used here,
                # so we take exactly one argument for now.
                # If you later want multi-word strings without quoting, we can add STRING_ALL remaining args.
                if (NOT _tailEnd EQUAL 6)
                    msg(ALWAYS FATAL_ERROR "object(SET DICT STRING): expected object(SET <dict> NAME EQUAL <key> STRING <value> [REPLACE])")
                endif ()

                set(_val "${ARGV6}")
                _hs__assert_no_ctrl_chars("object(SET DICT STRING)" "${_val}")

                dict(SET _tmp "${_key}" "${_val}")
                _hs_obj__store_blob("${_tok}" "${_tmp}")
                return()
            else ()
                msg(ALWAYS FATAL_ERROR "object(SET DICT): expected HANDLE or STRING, got '${_mode}'")
            endif ()
        endif ()

        # -------------------- RECORD SET (existing implementation) --------------------

        if (NOT _t STREQUAL "RECORD")
            msg(ALWAYS FATAL_ERROR "object(SET): only implemented for RECORD and DICT right now")
        endif ()

        set(_rec "${_objBlob}")
        _hs_obj__assert_mutable_allowed("${_tok}" "${_rec}" "SET")

        _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_MODE}" _hm _modeVal)
        if (NOT _hm)
            _hs_obj__meta_diag("${_rec}" _diag)
            msg(ALWAYS FATAL_ERROR "object(SET): RECORD missing MODE meta\n"
                    "  LookedAt : ${_diag}")
        endif ()

        # Named set
        if ("${ARGV2}" STREQUAL "NAME" AND "${ARGV3}" STREQUAL "EQUAL")
            if (NOT ARGC EQUAL 7 OR NOT "${ARGV5}" STREQUAL "VALUE")
                msg(ALWAYS FATAL_ERROR "object(SET NAME): expected object(SET <handleVar> NAME EQUAL <fieldName> VALUE <v>)")
            endif ()

            if (NOT "${_modeVal}" STREQUAL "SCHEMA")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(SET NAME): only allowed for named (SCHEMA) records\n"
                        "  LookedAt : ${_diag}")
            endif ()

            set(_field "${ARGV4}")
            set(_val "${ARGV6}")

            # Must be an existing field name
            _hs_obj__rec_get_kv("${_rec}" "${_field}" _found _old)
            if (NOT _found)
                msg(ALWAYS FATAL_ERROR "object(SET NAME): no such field '${_field}'")
            endif ()

            _hs_obj__rec_set_kv("${_rec}" "${_field}" "${_val}" _out)
            _hs_obj__store_blob("${_tok}" "${_out}")
            return()
        endif ()

        # Indexed bulk set
        if ("${ARGV2}" STREQUAL "INDEX")
            if (NOT "${_modeVal}" STREQUAL "POSITIONAL")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(SET INDEX): INDEX is only allowed for indexed (POSITIONAL) records\n"
                        "  LookedAt : ${_diag}")
            endif ()

            set(_start "${ARGV3}")
            if (NOT _start MATCHES "^[0-9]+$")
                msg(ALWAYS FATAL_ERROR "object(SET INDEX): start index must be non-negative integer, got '${_start}'")
            endif ()

            _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_FIXED}" _hf _fixedVal)
            if (NOT _hf)
                set(_fixedVal "0")
            endif ()

            _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
            if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                set(_sizeStr "0")
            endif ()

            if (NOT _sizeStr MATCHES "^[0-9]+$")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(SET INDEX): corrupt SIZE meta '${_sizeStr}'\n"
                        "  LookedAt : ${_diag}")
            endif ()

            # how many values to write?
            math(EXPR _firstValArg 4)         # ARGV4 is first value after "SET h INDEX n"
            math(EXPR _last "${ARGC} - 1")
            if (_firstValArg GREATER _last)
                msg(ALWAYS FATAL_ERROR "object(SET INDEX): at least one value required")
            endif ()
            math(EXPR _count "${ARGC} - 4")
            math(EXPR _end "${_start} + ${_count} - 1")

            if ("${_fixedVal}" STREQUAL "1" AND _end GREATER_EQUAL _sizeStr)
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(SET INDEX): fixed-length record (size=${_sizeStr}) cannot be written past index ${_sizeStr}-1\n"
                        "  LookedAt : ${_diag}")
            endif ()

            # Extend if needed (non-fixed)
            set(_out "${_rec}")
            if (_end GREATER_EQUAL _sizeStr)
                _hs_obj__rec_ensure_index_capacity("${_out}" "${_end}" _out)
            endif ()

            # Write values
            set(_ix "${_start}")
            set(_k 4)
            while (_k LESS ARGC)
                set(_v "${ARGV${_k}}")
                _hs_obj__rec_set_kv("${_out}" "${_ix}" "${_v}" _out)
                math(EXPR _ix "${_ix} + 1")
                math(EXPR _k "${_k} + 1")
            endwhile ()

            _hs_obj__store_blob("${_tok}" "${_out}")
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(SET): unsupported syntax")
    endif ()


    # ----------------------------------------------------------------------------------------------
    # APPEND
    #
    # ARRAY (existing):
    #   object(APPEND <arrayHandleVar> RECORD <recordHandleVar>)
    #   object(APPEND <arrayHandleVar> ARRAY  <arrayHandleVar>)
    #
    # RECORD (new):
    #   object(APPEND <recHandleVar> FIELD <value>)
    #   - only POSITIONAL records
    #   - cannot append to SCHEMA (named) records
    #   - cannot append to FIXED positional records
    if (_verb STREQUAL "APPEND")
        # Fast-path: if first arg is a handleVar, block writes to catalog
        if (ARGC GREATER 1)
            if (DEFINED ${ARGV1})
                _hs_obj__resolve_handle_token("${ARGV1}" _mtok)
                _hs_obj__load_blob("${_mtok}" _mblob)
                _hs_obj__is_catalog_blob("${_mblob}" _isCat)
                if (_isCat)
                    msg(ALWAYS FATAL_ERROR "object(APPEND): CATALOG is a read-only view")
                endif ()
            endif ()
        endif ()

        if (ARGC EQUAL 4 AND "${ARGV2}" STREQUAL "FIELD")
            # ---- RECORD append ----
            set(_recHandleVar "${ARGV1}")
            set(_val "${ARGV3}")

            _hs_obj__resolve_handle_token("${_recHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _rec)
            _hs__get_object_type("${_rec}" _t)

            if (NOT _t STREQUAL "RECORD")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(APPEND FIELD): target is not a RECORD\n"
                        "  LookedAt : ${_diag}")
            endif ()

            _hs_obj__assert_mutable_allowed("${_tok}" "${_rec}" "APPEND")

            _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_MODE}" _hm _modeVal)
            if (NOT _hm)
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(APPEND FIELD): RECORD missing MODE meta\n"
                        "  LookedAt : ${_diag}")
            endif ()
            if (NOT "${_modeVal}" STREQUAL "POSITIONAL")
                msg(ALWAYS FATAL_ERROR "object(APPEND FIELD): cannot APPEND to a named (SCHEMA) record")
            endif ()

            _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_FIXED}" _hf _fixedVal)
            if (NOT _hf OR "${_fixedVal}" STREQUAL "")
                set(_fixedVal "0")
            endif ()
            if ("${_fixedVal}" STREQUAL "1")
                msg(ALWAYS FATAL_ERROR "object(APPEND FIELD): cannot APPEND to a fixed-length positional record")
            endif ()

            _hs_obj__rec_get_kv("${_rec}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
            if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                set(_sizeStr "0")
            endif ()
            if (NOT _sizeStr MATCHES "^[0-9]+$")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(APPEND FIELD): corrupt SIZE meta '${_sizeStr}'\n"
                        "  LookedAt : ${_diag}")
            endif ()

            # append at index = current size
            set(_out "${_rec}")
            _hs_obj__rec_ensure_index_capacity("${_out}" "${_sizeStr}" _out)
            _hs_obj__rec_set_kv("${_out}" "${_sizeStr}" "${_val}" _out)

            _hs_obj__store_blob("${_tok}" "${_out}")
            return()
        endif ()

        # ---- ARRAY append (existing behavior) ----
        if (NOT (ARGC EQUAL 4 AND ("${ARGV2}" STREQUAL "RECORD" OR "${ARGV2}" STREQUAL "ARRAY")))
            msg(ALWAYS FATAL_ERROR "object(APPEND): expected object(APPEND <arrayHandleVar> RECORD <recordHandleVar>) or object(APPEND <arrayHandleVar> ARRAY <arrayHandleVar>) or object(APPEND <recHandleVar> FIELD <value>)")
        endif ()

        set(_arrayHandleVar "${ARGV1}")
        set(_itemKind "${ARGV2}")
        set(_itemHandleVar "${ARGV3}")

        _hs_obj__resolve_handle_token("${_arrayHandleVar}" _arrTok)
        _hs_obj__load_blob("${_arrTok}" _arrBlob)

        _hs__get_object_type("${_arrBlob}" _arrType)
        if (NOT (_arrType STREQUAL "ARRAY_RECORDS" OR _arrType STREQUAL "ARRAY_ARRAYS"))
            _hs_obj__meta_diag("${_rec}" _diag)
            msg(ALWAYS FATAL_ERROR "object(APPEND): target is not an ARRAY\n"
                    "  LookedAt : ${_diag}")
        endif ()

        _hs_obj__assert_mutable_allowed("${_arrTok}" "${_arrBlob}" "APPEND")

        _hs_obj__resolve_handle_token("${_itemHandleVar}" _itemTok)
        _hs_obj__load_blob("${_itemTok}" _itemBlob)
        _hs__get_object_type("${_itemBlob}" _itemType)

        if (_itemType STREQUAL "DICT" OR _itemType STREQUAL "UNKNOWN" OR _itemType STREQUAL "UNSET")
            msg(ALWAYS FATAL_ERROR "object(APPEND): arrays may contain only RECORD or ARRAY, got '${_itemType}'")
        endif ()

        _hs_obj__get_label_from_blob("${_itemBlob}" _itemLabel)
        if ("${_itemLabel}" STREQUAL "<unnamed>")
            _hs_obj__meta_diag("${_rec}" _diag)
            msg(ALWAYS FATAL_ERROR "object(APPEND): cannot insert an '<unnamed>' object into an array; object(RENAME ...) it first\n"
                    "  LookedAt : ${_diag}")
        endif ()

        _hs__array_get_kind("${_arrBlob}" _arrKind _arrSep)
        if (_arrKind STREQUAL "RECORDS")
            if (NOT _itemType STREQUAL "RECORD")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(APPEND): cannot append non-RECORD into a RECORDS array\n"
                        "  LookedAt : ${_diag}")
            endif ()
        elseif (_arrKind STREQUAL "ARRAYS")
            if (NOT (_itemType STREQUAL "ARRAY_RECORDS" OR _itemType STREQUAL "ARRAY_ARRAYS"))
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(APPEND): cannot append non-ARRAY into an ARRAYS array\n"
                        "  LookedAt : ${_diag}")
            endif ()
        else ()
            _hs_obj__meta_diag("${_rec}" _diag)
            msg(ALWAYS FATAL_ERROR "object(APPEND): corrupt/unknown array kind '${_arrKind}'\n"
                    "  LookedAt : ${_diag}")
        endif ()

        _hs__array_to_list("${_arrBlob}" "${_arrSep}" _lst)
        list(LENGTH _lst _len)

        set(_i 1)
        while (_i LESS _len)
            list(GET _lst ${_i} _elem)
            _hs__get_object_name("${_elem}" _elemName)
            if ("${_elemName}" STREQUAL "${_itemLabel}")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(APPEND): duplicate element name '${_itemLabel}' in array\n"
                        "  LookedAt : ${_diag}")
            endif ()
            math(EXPR _i "${_i} + 1")
        endwhile ()

        list(APPEND _lst "${_itemBlob}")
        _hs__list_to_array("${_lst}" "${_arrKind}" _newArrBlob)

        _hs_obj__store_blob("${_arrTok}" "${_newArrBlob}")
        return()
    endif ()




    # ----------------------------------------------------------------------------------------------
    # STRING
    #
    # RECORD:
    #   object(STRING outStr FROM h NAME  EQUAL <fieldLabel>)   # SCHEMA only (field name)
    #   object(STRING outStr FROM h INDEX <n>)                  # POSITIONAL only
    #
    # New (record value search):
    #   object(STRING outStr FROM h VALUE EQUAL    <value>)     # returns index or field label
    #   object(STRING outStr FROM h VALUE MATCHING <regex>)     # 0 => NOTFOUND
    #                                                         # 1 => "foundValue@<index|label>"
    #                                                         # >1 => returns a DICT *HANDLE TOKEN* in outStr
    #
    # DICT:
    #   object(STRING outStr FROM h NAME EQUAL <key>)
    #
    # Missing value returns literal "NOTFOUND" (string contract), except VALUE MATCHING multi-hit case (see above).
    if (_verb STREQUAL "STRING")
        if (ARGC LESS 4 OR NOT "${ARGV2}" STREQUAL "FROM")
            msg(ALWAYS FATAL_ERROR "object(STRING): expected object(STRING <outStrVar> FROM <handleVar> ...)")
        endif ()

        set(_outStr "${ARGV1}")
        set(_srcHandleVar "${ARGV3}")

        set(${_outStr} "" PARENT_SCOPE)

        _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
        _hs_obj__load_blob("${_tok}" _blob)
        _hs__get_object_type("${_blob}" _t)
        _hs_obj__is_catalog_blob("${_blob}" _isCat)

        if (_isCat)
            _hs_obj__catalog_get_sources("${_blob}" _sources)

            # PATH EQUAL "A/B/C" -> scalar only
            if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "PATH" AND "${ARGV5}" STREQUAL "EQUAL")
                set(_path "${ARGV6}")
                foreach (_st IN LISTS _sources)
                    _hs_obj__load_blob("${_st}" _srcBlob)
                    _hs__resolve_path("${_srcBlob}" "${_path}" _found)
                    if (NOT "${_found}" STREQUAL "")
                        _hs__get_object_type("${_found}" _ft)
                        if (NOT (_ft STREQUAL "UNKNOWN" OR _ft STREQUAL "UNSET"))
                            msg(ALWAYS FATAL_ERROR "object(STRING PATH): path '${_path}' resolves to an object in a catalog source; use GET")
                        endif ()
                        set(${_outStr} "${_found}" PARENT_SCOPE)
                        return()
                    endif ()
                endforeach ()
                set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                return()
            endif ()

            # NAME EQUAL <key> -> dict scalar lookup in sources
            if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "EQUAL")
                set(_key "${ARGV6}")
                foreach (_st IN LISTS _sources)
                    _hs_obj__load_blob("${_st}" _srcBlob)
                    _hs__get_object_type("${_srcBlob}" _stKind)
                    if (NOT _stKind STREQUAL "DICT")
                        continue()
                    endif ()
                    dict(CREATE _tmp "_")
                    set(_tmp "${_srcBlob}")
                    dict(GET _tmp "${_key}" _val)
                    if (NOT "${_val}" STREQUAL "")
                        _hs__get_object_type("${_val}" _vt)
                        if (NOT (_vt STREQUAL "UNKNOWN" OR _vt STREQUAL "UNSET"))
                            msg(ALWAYS FATAL_ERROR "object(STRING NAME): key '${_key}' resolves to an object in a catalog source; use GET")
                        endif ()
                        set(${_outStr} "${_val}" PARENT_SCOPE)
                        return()
                    endif ()
                endforeach ()
                set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                return()
            endif ()

            msg(ALWAYS FATAL_ERROR "object(STRING): unsupported selector for CATALOG (implemented: NAME EQUAL, PATH EQUAL)")
        endif ()

        if (_t STREQUAL "RECORD")
            set(_recVal "${_blob}")

            _hs_obj__rec_get_kv("${_recVal}" "${_HS_REC_META_MODE}" _hm _modeVal)
            if (NOT _hm)
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(STRING): RECORD missing MODE meta\n"
                        "  LookedAt : ${_diag}")
            endif ()

            # NAME EQUAL <fieldName> (SCHEMA only)
            if (ARGC GREATER_EQUAL 7 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "EQUAL")
                if (NOT "${_modeVal}" STREQUAL "SCHEMA")
                    msg(ALWAYS FATAL_ERROR "object(STRING RECORD NAME): only allowed for named (SCHEMA) records")
                endif ()

                set(_key "${ARGV6}")
                _hs_obj__rec_get_kv("${_recVal}" "${_key}" _found _val)
                if (NOT _found OR "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                    set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                    return()
                endif ()
                set(${_outStr} "${_val}" PARENT_SCOPE)
                return()
            endif ()

            # INDEX <n> (POSITIONAL only)
            if (ARGC GREATER_EQUAL 6 AND "${ARGV4}" STREQUAL "INDEX")
                if (NOT "${_modeVal}" STREQUAL "POSITIONAL")
                    msg(ALWAYS FATAL_ERROR "object(STRING RECORD INDEX): INDEX is only allowed for indexed (POSITIONAL) records")
                endif ()

                set(_ix "${ARGV5}")
                if (NOT _ix MATCHES "^[0-9]+$")
                    msg(ALWAYS FATAL_ERROR "object(STRING RECORD INDEX): index must be non-negative integer, got '${_ix}'")
                endif ()

                _hs_obj__rec_get_kv("${_recVal}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
                if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                    set(_sizeStr "0")
                endif ()

                if (_ix GREATER_EQUAL _sizeStr)
                    set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                    return()
                endif ()

                _hs_obj__rec_get_kv("${_recVal}" "${_ix}" _found _val)
                if (NOT _found OR "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                    set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                    return()
                endif ()

                set(${_outStr} "${_val}" PARENT_SCOPE)
                return()
            endif ()

            # VALUE EQUAL <value>  (POSITIONAL+SCHEMA)
            if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "VALUE" AND "${ARGV5}" STREQUAL "EQUAL")
                set(_needle "${ARGV6}")

                set(_hitId "")
                set(_hitVal "")

                if ("${_modeVal}" STREQUAL "POSITIONAL")
                    _hs_obj__rec_get_kv("${_recVal}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
                    if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                        set(_sizeStr "0")
                    endif ()

                    set(_i 0)
                    while (_i LESS _sizeStr)
                        _hs_obj__rec_get_kv("${_recVal}" "${_i}" _found _val)
                        if (_found AND NOT "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                            if ("${_val}" STREQUAL "${_needle}")
                                set(_hitId "${_i}")
                                set(_hitVal "${_val}")
                                break()
                            endif ()
                        endif ()
                        math(EXPR _i "${_i} + 1")
                    endwhile ()
                else () # SCHEMA
                    _hs_obj__rec_get_kv("${_recVal}" "${_HS_REC_META_FIELDS}" _hf _fieldsStore)
                    if (NOT _hf OR "${_fieldsStore}" STREQUAL "")
                        set(_fieldsStore "")
                    endif ()

                    # Decode stored field list (token-separated string) into a CMake list
                    string(REPLACE "${_HS_REC_FIELDS_SEP}" ";" _fields "${_fieldsStore}")

                    foreach (_fn IN LISTS _fields)
                        _hs_obj__rec_get_kv("${_recVal}" "${_fn}" _found _val)
                        if (_found AND NOT "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                            if ("${_val}" STREQUAL "${_needle}")
                                set(_hitId "${_fn}")
                                set(_hitVal "${_val}")
                                break()
                            endif ()
                        endif ()
                    endforeach ()
                endif ()

                if ("${_hitId}" STREQUAL "")
                    set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                else ()
                    # For VALUE EQUAL, return the index or field label
                    set(${_outStr} "${_hitId}" PARENT_SCOPE)
                endif ()
                return()
            endif ()

            # VALUE MATCHING <regex>  (POSITIONAL+SCHEMA)
            if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "VALUE" AND "${ARGV5}" STREQUAL "MATCHING")
                set(_regex "${ARGV6}")

                set(_hitCount 0)
                set(_oneId "")
                set(_oneVal "")

                # Multi-hit collector: key=id, value=value
                set(_matchesKv "")
                set(_maxKeyLen 0)

                if ("${_modeVal}" STREQUAL "POSITIONAL")
                    _hs_obj__rec_get_kv("${_recVal}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
                    if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                        set(_sizeStr "0")
                    endif ()

                    set(_i 0)
                    while (_i LESS _sizeStr)
                        _hs_obj__rec_get_kv("${_recVal}" "${_i}" _found _val)
                        if (_found AND NOT "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                            if ("${_val}" MATCHES "${_regex}")
                                math(EXPR _hitCount "${_hitCount} + 1")
                                if (_hitCount EQUAL 1)
                                    set(_oneId "${_i}")
                                    set(_oneVal "${_val}")
                                endif ()
                                list(APPEND _matchesKv "${_i}" "${_val}")
                                string(LENGTH "${_i}" _kl)
                                if (_kl GREATER _maxKeyLen)
                                    set(_maxKeyLen ${_kl})
                                endif ()
                            endif ()
                        endif ()
                        math(EXPR _i "${_i} + 1")
                    endwhile ()
                else () # SCHEMA
                    _hs_obj__rec_get_kv("${_recVal}" "${_HS_REC_META_FIELDS}" _hf _fieldsStore)
                    if (NOT _hf OR "${_fields}" STREQUAL "")
                        set(_fields "")
                    else ()
                        # Decode stored field list (token-separated string) into a CMake list
                        string(REPLACE "${_HS_REC_FIELDS_SEP}" ";" _fields "${_fieldsStore}")
                    endif ()

                    foreach (_fn IN LISTS _fields)
                        _hs_obj__rec_get_kv("${_recVal}" "${_fn}" _found _val)
                        if (_found AND NOT "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                            if ("${_val}" MATCHES "${_regex}")
                                math(EXPR _hitCount "${_hitCount} + 1")
                                if (_hitCount EQUAL 1)
                                    set(_oneId "${_fn}")
                                    set(_oneVal "${_val}")
                                endif ()
                                list(APPEND _matchesKv "${_fn}" "${_val}")
                                string(LENGTH "${_fn}" _kl)
                                if (_kl GREATER _maxKeyLen)
                                    set(_maxKeyLen ${_kl})
                                endif ()
                            endif ()
                        endif ()
                    endforeach ()
                endif ()

                if (_hitCount EQUAL 0)
                    set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                    return()
                endif ()

                if (_hitCount EQUAL 1)
                    set(${_outStr} "${_oneVal}@${_oneId}" PARENT_SCOPE)
                    return()
                endif ()

                # Multiple matches => return a DICT handle in outStr (documented above).
                object(CREATE __HS_VALUE_MATCHES_DICT KIND DICT LABEL VALUE_MATCHES)

                # Populate dict with aligned keys (optional nicety: we keep keys raw)
                list(LENGTH _matchesKv _mLen)
                set(_j 0)
                while (_j LESS _mLen)
                    list(GET _matchesKv ${_j} _k)
                    math(EXPR _vj "${_j} + 1")
                    if (_vj GREATER_EQUAL _mLen)
                        break()
                    endif ()
                    list(GET _matchesKv ${_vj} _v)
                    object(SET __HS_VALUE_MATCHES_DICT NAME EQUAL "${_k}" STRING "${_v}" REPLACE)
                    math(EXPR _j "${_j} + 2")
                endwhile ()

                set(${_outStr} "${__HS_VALUE_MATCHES_DICT}" PARENT_SCOPE)
                return()
            endif ()

            msg(ALWAYS FATAL_ERROR "object(STRING RECORD): unsupported selector (implemented: NAME EQUAL, INDEX, VALUE EQUAL, VALUE MATCHING)")
        endif ()

        if (_t STREQUAL "DICT")
            if (NOT (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "EQUAL"))
                msg(ALWAYS FATAL_ERROR "object(STRING DICT): expected object(STRING <outStrVar> FROM <dictHandleVar> NAME EQUAL <key>)")
            endif ()

            set(_key "${ARGV6}")

            dict(CREATE _tmp "_")
            set(_tmp "${_blob}")
            dict(GET _tmp "${_key}" _val)

            if ("${_val}" STREQUAL "")
                set(${_outStr} "NOTFOUND" PARENT_SCOPE)
                return()
            endif ()

            _hs__get_object_type("${_val}" _valType)
            if (NOT (_valType STREQUAL "UNKNOWN" OR _valType STREQUAL "UNSET"))
                msg(ALWAYS FATAL_ERROR
                        "object(STRING DICT): key '${_key}' holds an object blob; use object(GET ... FROM <dict> NAME EQUAL <key>)")
            endif ()

            set(${_outStr} "${_val}" PARENT_SCOPE)
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(STRING): not implemented for kind '${_t}'")
    endif ()

    # ----------------------------------------------------------------------------------------------
    # GET
    #
    # RECORD: always FATAL_ERROR (scalar-only)
    #
    # PATH traversal (new):
    #   object(GET outHandle FROM rootHandleVar PATH EQUAL "A/B/C")
    #   - If not found: outHandle = "" (so `if(NOT outHandle)` works)
    #   - If found but destination is scalar: FATAL_ERROR (GET returns handles only)
    #
    #   object(GET outHandle FROM rootHandleVar NAME MATCHING <regex>)
    #   object(GET outHandle FROM rootHandleVar PATH MATCHING <globPath>)
    #
    # DICT:
    #   object(GET outHandle FROM dictHandleVar NAME EQUAL <key>)
    #
    # ARRAY:
    #   object(GET outHandle FROM arrayHandleVar INDEX <n>)
    #
    # GET always returns handles to object blobs; scalars are a hard error here.
    if (_verb STREQUAL "GET")
        if (ARGC LESS 4 OR NOT "${ARGV2}" STREQUAL "FROM")
            msg(ALWAYS FATAL_ERROR "object(GET): expected object(GET <outHandleVar> FROM <srcHandleVar> ...)")
        endif ()

        set(_outHandleVar "${ARGV1}")
        set(_srcHandleVar "${ARGV3}")

        # default to NOTFOUND
        set(${_outHandleVar} "" PARENT_SCOPE)

        object(KIND ${_srcHandleVar} _k)
        if (_k STREQUAL "RECORD")
            msg(ALWAYS FATAL_ERROR "object(GET): RECORD contains only scalar fields; use object(STRING ...)")
        endif ()

        # If source is a CATALOG, redirect lookups into its sources in order.
        _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
        _hs_obj__load_blob("${_tok}" _rootBlob)
        _hs_obj__is_catalog_blob("${_rootBlob}" _isCat)

        if (_isCat)
            _hs_obj__catalog_get_sources("${_rootBlob}" _sources)

            # PATH EQUAL "A/B/C"
            if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "PATH" AND "${ARGV5}" STREQUAL "EQUAL")
                set(_path "${ARGV6}")
                foreach (_st IN LISTS _sources)
                    _hs_obj__load_blob("${_st}" _srcBlob)
                    _hs__resolve_path("${_srcBlob}" "${_path}" _foundBlob)
                    if (NOT "${_foundBlob}" STREQUAL "")
                        _hs__get_object_type("${_foundBlob}" _ft)
                        if (_ft STREQUAL "UNKNOWN" OR _ft STREQUAL "UNSET")
                            msg(ALWAYS FATAL_ERROR "object(GET PATH): path '${_path}' resolved to a scalar in a catalog source; GET returns handles only")
                        endif ()
                        _hs_obj__new_handle(_childTok)
                        _hs_obj__store_blob("${_childTok}" "${_foundBlob}")
                        set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
                        return()
                    endif ()
                endforeach ()
                return() # NOTFOUND => ""
            endif ()

            # NAME EQUAL <key> (treat as dict lookup in sources)
            if (ARGC EQUAL 8 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "EQUAL")
                set(_key "${ARGV6}")
                foreach (_st IN LISTS _sources)
                    _hs_obj__load_blob("${_st}" _srcBlob)
                    _hs__get_object_type("${_srcBlob}" _stKind)
                    if (NOT _stKind STREQUAL "DICT")
                        continue()
                    endif ()
                    dict(CREATE _tmp "_")
                    set(_tmp "${_srcBlob}")
                    dict(GET _tmp "${_key}" _val)
                    if (NOT "${_val}" STREQUAL "")
                        _hs__get_object_type("${_val}" _valType)
                        if (_valType STREQUAL "UNKNOWN" OR _valType STREQUAL "UNSET")
                            msg(ALWAYS FATAL_ERROR "object(GET NAME EQUAL): key '${_key}' resolved to a scalar in a catalog source; GET returns handles only")
                        endif ()
                        _hs_obj__new_handle(_childTok)
                        _hs_obj__store_blob("${_childTok}" "${_val}")
                        set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
                        return()
                    endif ()
                endforeach ()
                return()
            endif ()

            # NAME MATCHING <regex>
            if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "MATCHING")
                set(_regex "${ARGV6}")
                foreach (_st IN LISTS _sources)
                    _hs_obj__load_blob("${_st}" _srcBlob)
                    _hs__get_object_type("${_srcBlob}" _stKind)
                    if (NOT _stKind STREQUAL "DICT")
                        continue()
                    endif ()
                    string(SUBSTRING "${_srcBlob}" 1 -1 _payload)
                    if ("${_payload}" STREQUAL "")
                        continue()
                    endif ()
                    string(REPLACE "${US}" ";" _kvList "${_payload}")
                    list(LENGTH _kvList _kvLen)
                    set(_i 0)
                    while (_i LESS _kvLen)
                        list(GET _kvList ${_i} _k)
                        math(EXPR _vi "${_i} + 1")
                        if (_vi GREATER_EQUAL _kvLen)
                            break()
                        endif ()
                        list(GET _kvList ${_vi} _v)
                        if ("${_k}" MATCHES "${_regex}")
                            _hs__get_object_type("${_v}" _vt)
                            if (_vt STREQUAL "UNKNOWN" OR _vt STREQUAL "UNSET")
                                msg(ALWAYS FATAL_ERROR "object(GET NAME MATCHING): matched key '${_k}' but value is scalar in a catalog source; GET returns handles only")
                            endif ()
                            _hs_obj__new_handle(_childTok)
                            _hs_obj__store_blob("${_childTok}" "${_v}")
                            set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
                            return()
                        endif ()
                        math(EXPR _i "${_i} + 2")
                    endwhile ()
                endforeach ()
                return()
            endif ()

            msg(ALWAYS FATAL_ERROR "object(GET): unsupported selector for CATALOG (implemented: NAME EQUAL, NAME MATCHING, PATH EQUAL)")
        endif ()

        # --- NAME MATCHING <regex>
        if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "MATCHING")
            set(_regex "${ARGV6}")

            _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _rootBlob)
            _hs__get_object_type("${_rootBlob}" _rt)

            # DICT: match keys
            if (_rt STREQUAL "DICT")
                string(SUBSTRING "${_rootBlob}" 1 -1 _payload)
                if (NOT "${_payload}" STREQUAL "")
                    string(REPLACE "${US}" ";" _kvList "${_payload}")
                    list(LENGTH _kvList _kvLen)

                    set(_i 0)
                    while (_i LESS _kvLen)
                        list(GET _kvList ${_i} _key)
                        math(EXPR _vi "${_i} + 1")
                        if (_vi GREATER_EQUAL _kvLen)
                            break()
                        endif ()
                        list(GET _kvList ${_vi} _val)

                        if ("${_key}" MATCHES "${_regex}")
                            _hs__get_object_type("${_val}" _valType)
                            if (_valType STREQUAL "UNKNOWN" OR _valType STREQUAL "UNSET")
                                msg(ALWAYS FATAL_ERROR "object(GET NAME MATCHING): matched key '${_key}' but value is scalar; use STRING")
                            endif ()

                            _hs_obj__new_handle(_childTok)
                            _hs_obj__store_blob("${_childTok}" "${_val}")
                            set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
                            return()
                        endif ()

                        math(EXPR _i "${_i} + 2")
                    endwhile ()
                endif ()

                return() # NOTFOUND => ""
            endif ()

            # ARRAY: match element names (record/array object names)
            if (_rt STREQUAL "ARRAY_RECORDS" OR _rt STREQUAL "ARRAY_ARRAYS")
                _hs__array_get_kind("${_rootBlob}" _arrKind _arrSep)
                _hs__array_to_list("${_rootBlob}" "${_arrSep}" _lst)
                list(LENGTH _lst _len)

                set(_ix 1)
                while (_ix LESS _len)
                    list(GET _lst ${_ix} _elem)
                    _hs__get_object_name("${_elem}" _elemName)

                    if ("${_elemName}" MATCHES "${_regex}")
                        _hs_obj__new_handle(_childTok)
                        _hs_obj__store_blob("${_childTok}" "${_elem}")
                        set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
                        return()
                    endif ()

                    math(EXPR _ix "${_ix} + 1")
                endwhile ()

                return() # NOTFOUND => ""
            endif ()

            msg(ALWAYS FATAL_ERROR "object(GET NAME MATCHING): unsupported root kind '${_rt}' (expected DICT or ARRAY)")
        endif ()

        # --- PATH MATCHING <globPath>
        if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "PATH" AND "${ARGV5}" STREQUAL "MATCHING")
            set(_globPath "${ARGV6}")

            _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _rootBlob)

            _hs_obj__split_path("${_globPath}" _patternParts)

            # Start from empty prefix
            set(_prefixParts "")
            _hs_obj__iter_descendants_first_match("${_rootBlob}" "${_patternParts}" "${_prefixParts}" _foundBlob)

            if ("${_foundBlob}" STREQUAL "")
                return() # NOTFOUND => ""
            endif ()

            _hs__get_object_type("${_foundBlob}" _foundType)
            if (_foundType STREQUAL "UNKNOWN" OR _foundType STREQUAL "UNSET")
                msg(ALWAYS FATAL_ERROR "object(GET PATH MATCHING): matched a scalar; GET returns handles only")
            endif ()

            _hs_obj__new_handle(_childTok)
            _hs_obj__store_blob("${_childTok}" "${_foundBlob}")
            set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
            return()
        endif ()

        # --- PATH traversal (DICT/ARRAY): PATH EQUAL "A/B/C"
        # Returns:
        #   outHandleVar = "" if not found
        #   outHandleVar = new handle token if found and is an object blob
        if (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "PATH" AND "${ARGV5}" STREQUAL "EQUAL")
            set(_path "${ARGV6}")

            _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _rootBlob)

            # Use existing resolver (returns object blob or "" if not found)
            _hs__resolve_path("${_rootBlob}" "${_path}" _foundBlob)

            if ("${_foundBlob}" STREQUAL "")
                return() # NOTFOUND => ""
            endif ()

            _hs__get_object_type("${_foundBlob}" _foundType)
            if (_foundType STREQUAL "UNKNOWN" OR _foundType STREQUAL "UNSET")
                msg(ALWAYS FATAL_ERROR
                        "object(GET PATH): path '${_path}' resolved to a scalar/invalid value; "
                        "GET returns handles only"
                )
            endif ()

            _hs_obj__new_handle(_childTok)
            _hs_obj__store_blob("${_childTok}" "${_foundBlob}")
            set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
            return()
        endif ()

        # --- DICT: NAME EQUAL <key>
        if (_k STREQUAL "DICT")
            if (NOT (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "NAME" AND "${ARGV5}" STREQUAL "EQUAL"))
                msg(ALWAYS FATAL_ERROR "object(GET DICT): expected object(GET <outHandleVar> FROM <dictHandleVar> NAME EQUAL <key>)")
            endif ()

            set(_key "${ARGV6}")

            _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _dictBlob)

            dict(CREATE _tmp "_")
            set(_tmp "${_dictBlob}")
            dict(GET _tmp "${_key}" _val)

            if ("${_val}" STREQUAL "")
                # key not found => NOTFOUND (empty out handle)
                return()
            endif ()

            # Enforce GET returns handles to objects only
            _hs__get_object_type("${_val}" _valType)
            if (_valType STREQUAL "UNKNOWN" OR _valType STREQUAL "UNSET")
                msg(ALWAYS FATAL_ERROR
                        "object(GET DICT): key '${_key}' exists but value is not an object blob; "
                        "GET returns handles only"
                )
            endif ()

            _hs_obj__new_handle(_childTok)
            _hs_obj__store_blob("${_childTok}" "${_val}")
            set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
            return()
        endif ()

        # --- ARRAY: INDEX <n>
        if (_k STREQUAL "ARRAY")
            if (NOT (ARGC EQUAL 7 AND "${ARGV4}" STREQUAL "INDEX"))
                msg(ALWAYS FATAL_ERROR "object(GET ARRAY): expected object(GET <outHandleVar> FROM <arrayHandleVar> INDEX <n>)")
            endif ()

            set(_ix "${ARGV5}")
            if (NOT _ix MATCHES "^[0-9]+$")
                msg(ALWAYS FATAL_ERROR "object(GET ARRAY): index must be non-negative integer, got '${_ix}'")
            endif ()

            _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _arrBlob)

            _hs__array_get_kind("${_arrBlob}" _arrKind _arrSep)
            _hs__array_to_list("${_arrBlob}" "${_arrSep}" _lst)
            list(LENGTH _lst _len)

            math(EXPR _actual "${_ix} + 1")
            if (_actual GREATER_EQUAL _len)
                return()
            endif ()

            list(GET _lst ${_actual} _elem)
            _hs__get_object_type("${_elem}" _elemType)

            if (_elemType STREQUAL "UNKNOWN" OR _elemType STREQUAL "UNSET")
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(GET ARRAY): element at index ${_ix} is scalar/invalid; arrays may contain only RECORD or ARRAY\n"
                        "  LookedAt : ${_diag}")
            endif ()

            if (NOT (_elemType STREQUAL "RECORD" OR _elemType STREQUAL "ARRAY_RECORDS" OR _elemType STREQUAL "ARRAY_ARRAYS"))
                _hs_obj__meta_diag("${_rec}" _diag)
                msg(ALWAYS FATAL_ERROR "object(GET ARRAY): arrays may contain only RECORD or ARRAY, got element kind '${_elemType}' at index ${_ix}\n"
                        "  LookedAt : ${_diag}")
            endif ()

            _hs_obj__new_handle(_childTok)
            _hs_obj__store_blob("${_childTok}" "${_elem}")
            set(${_outHandleVar} "${_childTok}" PARENT_SCOPE)
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(GET): not implemented yet for kind '${_k}'")
    endif ()

    if (_verb STREQUAL "MATCHES")
        # PATH MATCHING <globPath> -> returns a DICT handle of:
        #   key   = matched path "A/B/C"
        #   value = matched value (scalar or object blob)
        if (ARGC EQUAL 7 AND "${ARGV2}" STREQUAL "FROM" AND "${ARGV4}" STREQUAL "PATH" AND "${ARGV5}" STREQUAL "MATCHING")
            set(_outHandleVar "${ARGV1}")
            set(_srcHandleVar "${ARGV3}")
            set(_globPath "${ARGV6}")

            set(${_outHandleVar} "" PARENT_SCOPE)

            _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
            _hs_obj__load_blob("${_tok}" _rootBlob)

            _hs_obj__split_path("${_globPath}" _patternParts)

            dict(CREATE _tmpMatches "PATH_MATCHES")
            set(_prefixParts "")
            _hs_obj__collect_descendant_matches_to_dict("${_rootBlob}" "${_patternParts}" "${_prefixParts}" _tmpMatches)

            _hs_obj__new_handle(_matchesTok)
            _hs_obj__store_blob("${_matchesTok}" "${_tmpMatches}")
            set(${_outHandleVar} "${_matchesTok}" PARENT_SCOPE)
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(MATCHES): unsupported syntax (implemented: FROM <h> PATH MATCHING <globPath>)")
    endif ()

    # ----------------------------------------------------------------------------------------------
    # KEYS
    #
    # object(KEYS outListVar FROM dictHandleVar)
    #
    # Returns a CMake list of keys (order = dict storage order).
    # If dict is empty => outListVar becomes "".
    if (_verb STREQUAL "KEYS")
        if (NOT (ARGC EQUAL 4 AND "${ARGV2}" STREQUAL "FROM"))
            msg(ALWAYS FATAL_ERROR "object(KEYS): expected object(KEYS <outListVar> FROM <dictHandleVar>)")
        endif ()

        set(_outListVar "${ARGV1}")
        set(_srcHandleVar "${ARGV3}")
        set(${_outListVar} "" PARENT_SCOPE)

        _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
        _hs_obj__load_blob("${_tok}" _blob)
        _hs_obj__is_catalog_blob("${_blob}" _isCat)
        if (_isCat)
            _hs_obj__catalog_get_sources("${_blob}" _sources)
            set(_keys "")
            foreach (_st IN LISTS _sources)
                _hs_obj__load_blob("${_st}" _srcBlob)
                _hs__get_object_type("${_srcBlob}" _stKind)
                if (NOT _stKind STREQUAL "DICT")
                    continue()
                endif ()
                dict(CREATE _tmp "_")
                set(_tmp "${_srcBlob}")
                dict(KEYS _tmp _k)
                list(APPEND _keys ${_k})
            endforeach ()
            if (_keys)
                list(REMOVE_DUPLICATES _keys)
            endif ()
            set(${_outListVar} "${_keys}" PARENT_SCOPE)
            return()
        endif ()

        _hs__get_object_type("${_blob}" _t)

        if (NOT _t STREQUAL "DICT")
            msg(ALWAYS FATAL_ERROR "object(KEYS): only implemented for DICT (got '${_t}')")
        endif ()

        dict(CREATE _tmp "_")
        set(_tmp "${_blob}")
        dict(KEYS _tmp _keys)

        set(${_outListVar} "${_keys}" PARENT_SCOPE)
        return()
    endif ()

    # ----------------------------------------------------------------------------------------------
    # ITER_HANDLES
    #
    # object(ITER_HANDLES outListVar FROM <handleVar> CHILDREN)
    #
    # Returns a CMake list of NEW handle tokens for each *immediate child object*.
    # - DICT: iterates entries; includes only values that are object blobs (skips scalar values)
    # - ARRAY: iterates elements (index order)
    #
    # If no children => outListVar = ""
    if (_verb STREQUAL "ITER_HANDLES")
        if (NOT (ARGC EQUAL 5 AND "${ARGV2}" STREQUAL "FROM" AND "${ARGV4}" STREQUAL "CHILDREN"))
            msg(ALWAYS FATAL_ERROR "object(ITER_HANDLES): expected object(ITER_HANDLES <outListVar> FROM <handleVar> CHILDREN)")
        endif ()

        set(_outListVar "${ARGV1}")
        set(_srcHandleVar "${ARGV3}")

        set(${_outListVar} "" PARENT_SCOPE)

        _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
        _hs_obj__load_blob("${_tok}" _blob)
        _hs__get_object_type("${_blob}" _t)

        set(_outList "")

        if (_t STREQUAL "DICT")
            # Iterate dict entries in storage order and return handles for object values only.
            string(SUBSTRING "${_blob}" 1 -1 _payload)
            if (NOT "${_payload}" STREQUAL "")
                string(REPLACE "${US}" ";" _kvList "${_payload}")
                list(LENGTH _kvList _kvLen)

                set(_i 0)
                while (_i LESS _kvLen)
                    list(GET _kvList ${_i} _key)
                    math(EXPR _vi "${_i} + 1")
                    if (_vi GREATER_EQUAL _kvLen)
                        break()
                    endif ()
                    list(GET _kvList ${_vi} _val)

                    _hs__get_object_type("${_val}" _valType)
                    if (NOT (_valType STREQUAL "UNKNOWN" OR _valType STREQUAL "UNSET"))
                        _hs_obj__new_handle(_childTok)
                        _hs_obj__store_blob("${_childTok}" "${_val}")
                        list(APPEND _outList "${_childTok}")
                    endif ()

                    math(EXPR _i "${_i} + 2")
                endwhile ()
            endif ()

            set(${_outListVar} "${_outList}" PARENT_SCOPE)
            return()
        endif ()

        if (_t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
            # Iterate array elements in index order; each element is an object blob by invariant.
            _hs__array_get_kind("${_blob}" _arrKind _arrSep)
            _hs__array_to_list("${_blob}" "${_arrSep}" _lst)
            list(LENGTH _lst _len)

            set(_ix 1) # element 0 is array's own name
            while (_ix LESS _len)
                list(GET _lst ${_ix} _elem)

                _hs__get_object_type("${_elem}" _elemType)
                if (NOT (_elemType STREQUAL "RECORD" OR _elemType STREQUAL "ARRAY_RECORDS" OR _elemType STREQUAL "ARRAY_ARRAYS"))
                    msg(ALWAYS FATAL_ERROR "object(ITER_HANDLES): array contained non-(RECORD|ARRAY) element kind '${_elemType}' (invariant violation)")
                endif ()

                _hs_obj__new_handle(_childTok)
                _hs_obj__store_blob("${_childTok}" "${_elem}")
                list(APPEND _outList "${_childTok}")

                math(EXPR _ix "${_ix} + 1")
            endwhile ()

            set(${_outListVar} "${_outList}" PARENT_SCOPE)
            return()
        endif ()

        msg(ALWAYS FATAL_ERROR "object(ITER_HANDLES): only implemented for DICT and ARRAY (got '${_t}')")
    endif ()

    # ----------------------------------------------------------------------------------------------
    # DUMP
    #
    # object(DUMP <handleVar> [<outVar>] [VERBOSE])
    #
    # - Summary by default
    # - VERBOSE prints a deeper representation
    # - If <outVar> is provided, returns the dump string instead of message()
    if (_verb STREQUAL "DUMP")
        if (ARGC LESS 2 OR ARGC GREATER 4)
            msg(ALWAYS FATAL_ERROR "object(DUMP): expected object(DUMP <handleVar> [<outVar>] [VERBOSE])")
        endif ()

        set(_srcHandleVar "${ARGV1}")
        set(_outVarName "")
        set(_verbose OFF)

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
            else ()
                msg(ALWAYS FATAL_ERROR "object(DUMP): last argument must be VERBOSE (if present)")
            endif ()
        endif ()

        # ---------- local helpers (kept inside DUMP to avoid scattering changes) ----------
        function(_hs_obj__spaces _n _out)
            if (_n LESS_EQUAL 0)
                set(${_out} "" PARENT_SCOPE)
                return()
            endif ()
            string(REPEAT " " ${_n} _s)
            set(${_out} "${_s}" PARENT_SCOPE)
        endfunction()

        function(_hs_obj__dump_record_pretty _recBlob _indent _outStr)
            set(${_outStr} "" PARENT_SCOPE)

            _hs_obj__rec_get_kv("${_recBlob}" "${_HS_REC_META_MODE}" _hm _modeVal)
            if (NOT _hm)
                set(${_outStr} "${_indent}<corrupt record: missing MODE>\n" PARENT_SCOPE)
                return()
            endif ()

            _hs_obj__rec_get_kv("${_recBlob}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
            if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                set(_sizeStr "0")
            endif ()
            if (NOT _sizeStr MATCHES "^[0-9]+$")
                set(${_outStr} "${_indent}<corrupt record: bad SIZE '${_sizeStr}'>\n" PARENT_SCOPE)
                return()
            endif ()

            # POSITIONAL: print [idx] => 'value' with idx padded so "=>" aligns
            if ("${_modeVal}" STREQUAL "POSITIONAL")
                set(_size "${_sizeStr}")

                if (_size GREATER 0)
                    math(EXPR _last "${_size} - 1")
                    set(_lastStr "${_last}")
                    string(LENGTH "${_lastStr}" _w)
                else ()
                    set(_w 1)
                endif ()

                set(_s "")
                set(_i 0)
                while (_i LESS _size)
                    _hs_obj__rec_get_kv("${_recBlob}" "${_i}" _found _val)
                    if (NOT _found OR "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                        set(_disp "")
                    else ()
                        set(_disp "${_val}")
                    endif ()

                    set(_iStr "${_i}")
                    string(LENGTH "${_iStr}" _iLen)
                    math(EXPR _pad "${_w} - ${_iLen}")
                    _hs_obj__spaces(${_pad} _p)

                    string(APPEND _s "${_indent}[${_p}${_iStr}] => '${_disp}'\n")
                    math(EXPR _i "${_i} + 1")
                endwhile ()

                set(${_outStr} "${_s}" PARENT_SCOPE)
                return()
            endif ()

            # SCHEMA: right-align field names so "=>" aligns
            if ("${_modeVal}" STREQUAL "SCHEMA")
                _hs_obj__rec_get_kv("${_recBlob}" "${_HS_REC_META_FIELDS}" _hf _fieldsStore)
                if (NOT _hf OR "${_fieldsStore}" STREQUAL "")
                    set(${_outStr} "${_indent}<schema record missing FIELDS>\n" PARENT_SCOPE)
                    return()
                endif ()

                # Decode stored field list (token-separated string) into a CMake list
                string(REPLACE "${_HS_REC_FIELDS_SEP}" ";" _fields "${_fieldsStore}")
                set(_fieldList "${_fields}")

                set(_max 0)
                foreach (_fn IN LISTS _fieldList)
                    string(LENGTH "${_fn}" _L)
                    if (_L GREATER _max)
                        set(_max ${_L})
                    endif ()
                endforeach ()

                set(_s "")
                foreach (_fn IN LISTS _fieldList)
                    _hs_obj__rec_get_kv("${_recBlob}" "${_fn}" _found _val)
                    if (NOT _found OR "${_val}" STREQUAL "${_HS_REC_UNSET_VALUE}")
                        set(_disp "")
                    else ()
                        set(_disp "${_val}")
                    endif ()

                    string(LENGTH "${_fn}" _L)
                    math(EXPR _pad "${_max} - ${_L}")
                    _hs_obj__spaces(${_pad} _p)

                    string(APPEND _s "${_indent}${_p}'${_fn}' => '${_disp}'\n")
                endforeach ()

                set(${_outStr} "${_s}" PARENT_SCOPE)
                return()
            endif ()

            set(${_outStr} "${_indent}<unknown record MODE '${_modeVal}'>\n" PARENT_SCOPE)
        endfunction()

        # ---------- load object ----------
        _hs_obj__resolve_handle_token("${_srcHandleVar}" _tok)
        _hs_obj__load_blob("${_tok}" _blob)

        set(_dumpStr "")
        set(_label "<unnamed>")
        _hs_obj__get_label_from_blob("${_blob}" _label)

        # ---------- CATALOG ----------
        _hs_obj__is_catalog_blob("${_blob}" _isCat)
        if (_isCat)
            dict(CREATE _tmp "_")
            set(_tmp "${_blob}")
            dict(GET _tmp "${_HS_CAT_NAME_KEY}" _catName)
            if ("${_catName}" STREQUAL "")
                set(_catName "<unnamed>")
            endif ()
            dict(GET _tmp "${_HS_CAT_SOURCES_KEY}" _srcs)

            if ("${_srcs}" STREQUAL "")
                set(_nSrc 0)
            else ()
                set(_srcList "${_srcs}")
                list(LENGTH _srcList _nSrc)
            endif ()

            if (NOT _verbose)
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=CATALOG name='${_catName}' sources=${_nSrc}\n")
            else ()
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=CATALOG name='${_catName}' sources=${_nSrc}\n")
                if (_nSrc GREATER 0)
                    set(_ix 0)
                    foreach (_st IN LISTS _srcList)
                        _hs_obj__load_blob("${_st}" _sb)
                        _hs__get_object_type("${_sb}" _sk)
                        _hs_obj__get_label_from_blob("${_sb}" _sn)
                        string(APPEND _dumpStr "  [${_ix}] => token='${_st}' kind=${_sk} name='${_sn}'\n")
                        math(EXPR _ix "${_ix} + 1")
                    endforeach ()
                endif ()
            endif ()

            if ("${_outVarName}" STREQUAL "")
                message("${_dumpStr}")
            else ()
                set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
            endif ()
            return()
        endif ()

        _hs__get_object_type("${_blob}" _t)

        # ---------- RECORD ----------
        if (_t STREQUAL "RECORD")
            if (NOT _verbose)
                _hs_obj__rec_get_kv("${_blob}" "${_HS_REC_META_MODE}" _hm _modeVal)
                _hs_obj__rec_get_kv("${_blob}" "${_HS_REC_META_SIZE}" _hs _sizeStr)
                if (NOT _hm)
                    set(_modeVal "<missing>")
                endif ()
                if (NOT _hs OR "${_sizeStr}" STREQUAL "")
                    set(_sizeStr "0")
                endif ()
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=RECORD name='${_label}' mode=${_modeVal} size=${_sizeStr}\n")
            else ()
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=RECORD name='${_label}'\n")
                _hs_obj__dump_record_pretty("${_blob}" "  " _body)
                string(APPEND _dumpStr "${_body}")
            endif ()

            if ("${_outVarName}" STREQUAL "")
                message("${_dumpStr}")
            else ()
                set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
            endif ()
            return()
        endif ()

        # ---------- DICT ----------
        if (_t STREQUAL "DICT")
            if (NOT _verbose)
                dict(CREATE _tmp "_")
                set(_tmp "${_blob}")
                dict(KEYS _tmp _keys)
                list(REMOVE_ITEM _keys "__HS_OBJ__NAME")
                list(LENGTH _keys _nKeys)
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=DICT name='${_label}' keys=${_nKeys}\n")
            else ()
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=DICT name='${_label}'\n")

                # Decode dict payload into kv list (key0;val0;key1;val1;...)
                string(SUBSTRING "${_blob}" 1 -1 _payload)
                if ("${_payload}" STREQUAL "")
                    string(APPEND _dumpStr "  { }\n")
                else ()
                    string(REPLACE "${US}" ";" _kvList "${_payload}")
                    list(LENGTH _kvList _kvLen)

                    # Pass 1: find max key length (excluding reserved __HS_OBJ__NAME)
                    set(_maxKey 0)
                    set(_i 0)
                    while (_i LESS _kvLen)
                        list(GET _kvList ${_i} _k)
                        if (NOT "${_k}" STREQUAL "__HS_OBJ__NAME")
                            string(LENGTH "${_k}" _kl)
                            if (_kl GREATER _maxKey)
                                set(_maxKey ${_kl})
                            endif ()
                        endif ()
                        math(EXPR _i "${_i} + 2")
                    endwhile ()

                    # Pass 2: print aligned
                    set(_i 0)
                    while (_i LESS _kvLen)
                        list(GET _kvList ${_i} _key)
                        math(EXPR _vi "${_i} + 1")
                        if (_vi GREATER_EQUAL _kvLen)
                            break()
                        endif ()
                        list(GET _kvList ${_vi} _val)

                        if ("${_key}" STREQUAL "__HS_OBJ__NAME")
                            math(EXPR _i "${_i} + 2")
                            continue()
                        endif ()

                        string(LENGTH "${_key}" _kl)
                        math(EXPR _pad "${_maxKey} - ${_kl}")
                        _hs_obj__spaces(${_pad} _p)

                        _hs__get_object_type("${_val}" _valType)
                        if (_valType STREQUAL "UNKNOWN" OR _valType STREQUAL "UNSET")
                            string(APPEND _dumpStr "  ${_p}'${_key}' => '${_val}'\n")
                        else ()
                            _hs_obj__get_label_from_blob("${_val}" _childName)
                            string(APPEND _dumpStr "  ${_p}'${_key}' => (${_valType}) name='${_childName}'\n")

                            if (_valType STREQUAL "RECORD")
                                _hs_obj__dump_record_pretty("${_val}" "    " _childDump)
                                string(APPEND _dumpStr "${_childDump}")
                            endif ()
                        endif ()

                        math(EXPR _i "${_i} + 2")
                    endwhile ()
                endif ()
            endif ()

            if ("${_outVarName}" STREQUAL "")
                message("${_dumpStr}")
            else ()
                set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
            endif ()
            return()
        endif ()

        # ---------- ARRAY ----------
        if (_t STREQUAL "ARRAY_RECORDS" OR _t STREQUAL "ARRAY_ARRAYS")
            if (NOT _verbose)
                _hs__array_get_kind("${_blob}" _arrKind _arrSep)
                _hs__array_to_list("${_blob}" "${_arrSep}" _lst)
                list(LENGTH _lst _len)
                if (_len LESS 1)
                    set(_nElems 0)
                else ()
                    math(EXPR _nElems "${_len} - 1") # element 0 is array name
                endif ()
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=ARRAY name='${_label}' type=${_arrKind} length=${_nElems}\n")
            else ()
                set(_tmpArrVar "__hs_obj_dump_tmp_array")
                set(${_tmpArrVar} "${_blob}")
                array(DUMP ${_tmpArrVar} _arrDump VERBOSE)
                unset(${_tmpArrVar})
                set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=ARRAY name='${_label}'\n${_arrDump}\n")
            endif ()

            if ("${_outVarName}" STREQUAL "")
                message("${_dumpStr}")
            else ()
                set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
            endif ()
            return()
        endif ()

        set(_dumpStr "object '${_srcHandleVar}' (token='${_tok}') kind=${_t} name='${_label}' (no DUMP handler)\n")
        if ("${_outVarName}" STREQUAL "")
            message("${_dumpStr}")
        else ()
            set(${_outVarName} "${_dumpStr}" PARENT_SCOPE)
        endif ()
        return()
    endif ()

    # =================================================================================================
    # object(REMOVE RECORD|ARRAY FROM <targetHandleVar> NAME EQUAL <nameToMatch> [REPLACE WITH <newHandleVar>] [STATUS <resultVar>])
    #
    # Removes a child from an ARRAY by matching the child's label/name.
    # 
    # For ARRAY:
    #   - Searches for an element whose NAME equals <nameToMatch>
    #   - If found and no REPLACE specified: removes the element
    #   - If found and REPLACE WITH specified: replaces the element with the new object
    #   - Sets STATUS to "REMOVED", "REPLACED", or "NOT_FOUND"
    #
    # For RECORD:
    #   - Currently not implemented (could be extended to remove fields from named records)
    #
    # =================================================================================================
    if ("${_cmd}" STREQUAL "REMOVE")
        set(_expectKind "")
        set(_targetHandleVar "")
        set(_nameToMatch "")
        set(_replaceHandleVar "")
        set(_statusVar "")
        
        set(_state "KIND")
        set(_i 1)
        while (_i LESS _argc)
            list(GET ARGV ${_i} _arg)
            
            if (_state STREQUAL "KIND")
                if ("${_arg}" STREQUAL "RECORD" OR "${_arg}" STREQUAL "ARRAY")
                    set(_expectKind "${_arg}")
                    set(_state "FROM")
                else ()
                    msg(ALWAYS FATAL_ERROR "object(REMOVE): expected RECORD or ARRAY, got '${_arg}'")
                endif ()
            elseif (_state STREQUAL "FROM")
                if ("${_arg}" STREQUAL "FROM")
                    set(_state "TARGET")
                else ()
                    msg(ALWAYS FATAL_ERROR "object(REMOVE): expected FROM after ${_expectKind}, got '${_arg}'")
                endif ()
            elseif (_state STREQUAL "TARGET")
                set(_targetHandleVar "${_arg}")
                set(_state "NAME")
            elseif (_state STREQUAL "NAME")
                if ("${_arg}" STREQUAL "NAME")
                    set(_state "EQUAL")
                else ()
                    msg(ALWAYS FATAL_ERROR "object(REMOVE): expected NAME after target, got '${_arg}'")
                endif ()
            elseif (_state STREQUAL "EQUAL")
                if ("${_arg}" STREQUAL "EQUAL")
                    set(_state "MATCH_VALUE")
                else ()
                    msg(ALWAYS FATAL_ERROR "object(REMOVE): expected EQUAL after NAME, got '${_arg}'")
                endif ()
            elseif (_state STREQUAL "MATCH_VALUE")
                set(_nameToMatch "${_arg}")
                set(_state "OPTIONAL")
            elseif (_state STREQUAL "OPTIONAL")
                if ("${_arg}" STREQUAL "REPLACE")
                    set(_state "WITH")
                elseif ("${_arg}" STREQUAL "STATUS")
                    set(_state "STATUS_VAR")
                else ()
                    msg(ALWAYS FATAL_ERROR "object(REMOVE): unexpected argument '${_arg}'")
                endif ()
            elseif (_state STREQUAL "WITH")
                if ("${_arg}" STREQUAL "WITH")
                    set(_state "REPLACE_VALUE")
                else ()
                    msg(ALWAYS FATAL_ERROR "object(REMOVE): expected WITH after REPLACE, got '${_arg}'")
                endif ()
            elseif (_state STREQUAL "REPLACE_VALUE")
                set(_replaceHandleVar "${_arg}")
                set(_state "OPTIONAL")
            elseif (_state STREQUAL "STATUS_VAR")
                set(_statusVar "${_arg}")
                set(_state "OPTIONAL")
            else ()
                msg(ALWAYS FATAL_ERROR "object(REMOVE): unexpected state '${_state}' with arg '${_arg}'")
            endif ()
            
            math(EXPR _i "${_i} + 1")
        endwhile ()
        
        # Validation
        if ("${_expectKind}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "object(REMOVE): missing RECORD or ARRAY")
        endif ()
        if ("${_targetHandleVar}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "object(REMOVE): missing target handle variable")
        endif ()
        if ("${_nameToMatch}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "object(REMOVE): missing NAME EQUAL value")
        endif ()
        
        # Resolve target handle
        _hs_obj__resolve_handle_token("${_targetHandleVar}" _targetToken)
        _hs_obj__load_blob("${_targetToken}" _targetBlob)
        
        # Check mutation allowed
        _hs_obj__assert_mutable_allowed("${_targetToken}" "${_targetBlob}" "REMOVE")
        
        # Determine actual kind
        _hs__get_object_type("${_targetBlob}" _actualKind)
        
        set(_result "NOT_FOUND")
        
        # ===== REMOVE from ARRAY =====
        if ("${_expectKind}" STREQUAL "ARRAY")
            if (NOT (_actualKind STREQUAL "ARRAY_RECORDS" OR _actualKind STREQUAL "ARRAY_ARRAYS"))
                msg(ALWAYS FATAL_ERROR 
                    "object(REMOVE ARRAY): target '${_targetHandleVar}' is ${_actualKind}, not an ARRAY"
                )
            endif ()
            
            # If REPLACE is specified, validate the replacement handle
            if (NOT "${_replaceHandleVar}" STREQUAL "")
                _hs_obj__resolve_handle_token("${_replaceHandleVar}" _replaceToken)
                _hs_obj__load_blob("${_replaceToken}" _replaceBlob)
                
                # Check that replacement is not unnamed
                _hs_obj__get_label_from_blob("${_replaceBlob}" _replaceLabel)
                if ("${_replaceLabel}" STREQUAL "<unnamed>")
                    msg(ALWAYS FATAL_ERROR
                        "object(REMOVE ARRAY): replacement object '${_replaceHandleVar}' has label '<unnamed>'. "
                        "You must object(RENAME ...) it before replacement."
                    )
                endif ()
                
                # Check that replacement kind matches array type
                _hs__get_object_type("${_replaceBlob}" _replaceKind)
                if (_actualKind STREQUAL "ARRAY_RECORDS")
                    if (NOT _replaceKind STREQUAL "RECORD")
                        msg(ALWAYS FATAL_ERROR
                            "object(REMOVE ARRAY): array type is RECORDS but replacement is ${_replaceKind}"
                        )
                    endif ()
                elseif (_actualKind STREQUAL "ARRAY_ARRAYS")
                    if (NOT (_replaceKind STREQUAL "ARRAY_RECORDS" OR _replaceKind STREQUAL "ARRAY_ARRAYS"))
                        msg(ALWAYS FATAL_ERROR
                            "object(REMOVE ARRAY): array type is ARRAYS but replacement is ${_replaceKind}"
                        )
                    endif ()
                endif ()
            endif ()
            
            # Get array separator and convert to list
            _hs__array_get_kind("${_targetBlob}" _arrKind _arrSep)
            _hs__array_to_list("${_targetBlob}" "${_arrSep}" _arrList)
            
            # First element is the array name, rest are element tokens
            list(LENGTH _arrList _arrLen)
            if (_arrLen LESS 1)
                msg(ALWAYS FATAL_ERROR "object(REMOVE ARRAY): corrupt array, no name element")
            endif ()
            
            list(GET _arrList 0 _arrName)
            
            # Search for matching element
            set(_foundIndex -1)
            set(_elemIndex 0)
            set(_i 1)
            while (_i LESS _arrLen)
                list(GET _arrList ${_i} _elemToken)
                _hs_obj__load_blob("${_elemToken}" _elemBlob)
                _hs_obj__get_label_from_blob("${_elemBlob}" _elemLabel)
                
                if ("${_elemLabel}" STREQUAL "${_nameToMatch}")
                    set(_foundIndex ${_i})
                    break()
                endif ()
                
                math(EXPR _i "${_i} + 1")
                math(EXPR _elemIndex "${_elemIndex} + 1")
            endwhile ()
            
            # Process removal/replacement
            if (_foundIndex GREATER 0)
                if ("${_replaceHandleVar}" STREQUAL "")
                    # Simple removal
                    list(REMOVE_AT _arrList ${_foundIndex})
                    set(_result "REMOVED")
                else ()
                    # Replacement - check for duplicate labels
                    if (NOT "${_replaceLabel}" STREQUAL "${_nameToMatch}")
                        # New label is different, check for duplicates
                        set(_dupCheck 1)
                        while (_dupCheck LESS _arrLen)
                            if (NOT _dupCheck EQUAL _foundIndex)
                                list(GET _arrList ${_dupCheck} _checkToken)
                                _hs_obj__load_blob("${_checkToken}" _checkBlob)
                                _hs_obj__get_label_from_blob("${_checkBlob}" _checkLabel)
                                
                                if ("${_checkLabel}" STREQUAL "${_replaceLabel}")
                                    msg(ALWAYS FATAL_ERROR
                                        "object(REMOVE ARRAY): replacement would create duplicate label '${_replaceLabel}' in array"
                                    )
                                endif ()
                            endif ()
                            math(EXPR _dupCheck "${_dupCheck} + 1")
                        endwhile ()
                    endif ()
                    
                    # Replace the element
                    list(REMOVE_AT _arrList ${_foundIndex})
                    list(INSERT _arrList ${_foundIndex} "${_replaceToken}")
                    set(_result "REPLACED")
                endif ()
                
                # Rebuild the array blob
                _hs__list_to_array(_arrList "${_arrSep}" _newBlob)
                globalObjSet("${_targetToken}" "${_newBlob}")
                
                # Update parent scope variable
                set(${_targetHandleVar} "${_targetToken}" PARENT_SCOPE)
            else ()
                set(_result "NOT_FOUND")
            endif ()
            
        # ===== REMOVE from RECORD =====
        elseif ("${_expectKind}" STREQUAL "RECORD")
            msg(ALWAYS FATAL_ERROR
                "object(REMOVE RECORD): not yet implemented. "
                "RECORD removal would require field deletion from named records."
            )
        endif ()
        
        # Set status if requested
        if (NOT "${_statusVar}" STREQUAL "")
            set(${_statusVar} "${_result}" PARENT_SCOPE)
        endif ()
        
        return()
    endif ()

endfunction()