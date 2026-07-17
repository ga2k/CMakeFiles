# handleTarget()'s generic naming fallback only tries curl::curl / curl / HoffSoft::curl,
# none of which curl's own CMakeLists.txt creates. What it actually creates (lib/CMakeLists.txt,
# unconditionally, regardless of static/shared) is an alias named ${PROJECT_NAME}::${LIB_NAME},
# i.e. curl::libcurl, pointing at whichever of libcurl_shared/libcurl_static was built. Resolve
# that here and wire it into the link lists ourselves, the same way soci_postMakeAvailable does
# for soci_core/soci_sqlite3.
function(curl_postMakeAvailable sourceDir buildDir outDir buildType)

    if (curl_ALREADY_FOUND)
        set(HANDLED ON PARENT_SCOPE)
        return()
    endif ()

    set(definesList      ${_DefinesList})
    set(includePathsList ${_IncludePathsList})
    set(librariesList    ${_LibrariesList})
    set(dependenciesList ${_DependenciesList})

    unset(_curl_target)
    foreach (_candidate IN ITEMS curl::libcurl libcurl HoffSoft::libcurl libcurl_shared libcurl_static)
        if (TARGET ${_candidate})
            set(_curl_target "${_candidate}")
            break()
        endif ()
    endforeach ()

    if (_curl_target)
        set(_real_target "${_curl_target}")
        get_target_property(_aliased ${_curl_target} ALIASED_TARGET)
        if (_aliased)
            set(_real_target "${_aliased}")
        endif ()

        get_target_property(_imported ${_real_target} IMPORTED)
        if (NOT _imported)
            set_target_properties(${_real_target} PROPERTIES EXPORT_NAME ${_real_target})
            addTargetProperties(${_real_target} curl ON)
        endif ()

        list(APPEND librariesList ${_real_target})
        list(APPEND dependenciesList ${_real_target})
        list(APPEND definesList USING_CURL)

        unset(_real_target)
        unset(_aliased)
        unset(_imported)
    else ()
        message(WARNING "curl: no known target found after FetchContent_MakeAvailable "
                "(checked curl::libcurl, libcurl, libcurl_shared, libcurl_static) — "
                "hs::SmtpClient will fail to link")
    endif ()
    unset(_curl_target)

    list(APPEND definesList         ${_DefinesList}                 )
    list(REMOVE_DUPLICATES            definesList                   )
    set(        _DefinesList        ${definesList}      PARENT_SCOPE)
    list(APPEND includePathsList    ${_IncludePathsList}            )
    list(REMOVE_DUPLICATES            includePathsList              )
    set(        _IncludePathsList   ${includePathsList} PARENT_SCOPE)
    list(APPEND librariesList       ${_LibrariesList}               )
    list(REMOVE_DUPLICATES            librariesList                 )
    set(        _LibrariesList      ${librariesList}    PARENT_SCOPE)
    list(APPEND dependenciesList    ${_DependenciesList}            )
    list(REMOVE_DUPLICATES            dependenciesList              )
    set(        _DependenciesList   ${dependenciesList} PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)

endfunction()
