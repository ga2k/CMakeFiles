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

    list(APPEND SOCI_PLUGINS_HANDLED )
    foreach (target soci_core soci_sqlite3 ) #SOCI::Core SOCI::SQLite3)
        if (TARGET ${target})               # Prefer dynamic library ...
            # Strip SOCI's internal export metadata to prevent "multiple export sets" error
#            set_target_properties(${target} PROPERTIES EXPORT_NAME ${target})
#            set_property(TARGET ${target} PROPERTY EXPORT_PROPERTIES "")
            addTargetProperties(${target} soci OFF)
            list(APPEND librariesList ${target})
            list(APPEND dependenciesList ${target})
            set(ADD_TO_DEFINES ON)

#            if(WIDGETS IN_LIST APP_FEATURES)
#                target_include_directories(${target} PRIVATE ${_wxIncludePaths})
#            endif ()

        elseif (TARGET ${target}_static)    # ... over the static one
            # Strip metadata for static targets too
#            set_target_properties(${target}_static PROPERTIES EXPORT_NAME ${target}_static)
#            set_property(TARGET ${target}_static PROPERTY EXPORT_PROPERTIES "")
            addTargetProperties(${target}_static soci OFF)
            list(APPEND librariesList    ${target}_static)
            list(APPEND dependenciesList ${target})
            set(ADD_TO_DEFINES ON)
        endif ()
    endforeach ()

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
