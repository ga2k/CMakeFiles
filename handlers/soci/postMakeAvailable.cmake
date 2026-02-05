function(soci_postMakeAvailable sourceDir buildDir outDir buildType)

    unset(ADD_TO_DEFINES)

    set(definesList         ${_DefinesList})
    set(includePathsList    ${_IncludePathsList})
    set(librariesList       ${_LibrariesList})
    set(dependenciesList    ${_DependenciesList})

    if(EXISTS "${sourceDir}/include")
        list(APPEND includePathsList "${sourceDir}/include")
    endif ()
    if(EXISTS "${buildDir}/include")
        list(APPEND includePathsList "${buildDir}/include")
    endif ()

    set(SOCI_PLUGINS_HANDLED ON)

    unset(_soci_targets)

    # Prefer real build targets when present; fall back to imported targets from find_package().
    if (TARGET soci_core)
        list(APPEND _soci_targets soci_core)
    elseif (TARGET soci_core_static)
        list(APPEND _soci_targets soci_core_static)
    elseif (TARGET SOCI::Core)
        list(APPEND _soci_targets SOCI::Core)
    endif ()

    if (TARGET soci_sqlite3)
        list(APPEND _soci_targets soci_sqlite3)
    elseif (TARGET soci_sqlite3_static)
        list(APPEND _soci_targets soci_sqlite3_static)
    elseif (TARGET SOCI::SQLite3)
        list(APPEND _soci_targets SOCI::SQLite3)
    endif ()

    foreach (target IN LISTS _soci_targets)
        set(_real_target "${target}")
        get_target_property(_aliased ${target} ALIASED_TARGET)
        if (_aliased)
            set(_real_target "${_aliased}")
        endif ()

        get_target_property(_imported ${_real_target} IMPORTED)

        # Only retarget/build-customize real build targets (never imported ones).
        if (NOT _imported)
            set_target_properties(${_real_target} PROPERTIES EXPORT_NAME ${_real_target})
            addTargetProperties(${_real_target} soci ON)
        endif ()

        list(APPEND librariesList ${_real_target})
        list(APPEND dependenciesList ${_real_target})
        set(ADD_TO_DEFINES ON)
    endforeach ()

    unset(_soci_targets)
    unset(_real_target)
    unset(_aliased)
    unset(_imported)

    if (ADD_TO_DEFINES)
        list(APPEND definesList USING_DATABASE USING_soci)
    endif ()


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
