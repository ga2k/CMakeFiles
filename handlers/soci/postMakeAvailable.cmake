function(soci_postMakeAvailable sourceDir buildDir outDir buildType components)

    unset(ADD_PLEASE)

    set(definesList         ${_DefinesList})
    set(includePathsList    ${_IncludePathsList})
    set(librariesList       ${_LibrariesList})

    if(EXISTS "${sourceDir}/include")
        list(APPEND includePathsList "${sourceDir}/include")
    endif ()
    if(EXISTS "${buildDir}/include")
        list(APPEND includePathsList "${buildDir}/include")
    endif ()

    list(APPEND SOCI_PLUGINS_HANDLED soci_core soci_sqlite3)
    foreach (target IN LISTS SOCI_PLUGINS_HANDLED)
        if (TARGET ${target})               # Prefer dynamic library ...
            addTarget(${target} soci ON "${components}")
            list(APPEND librariesList ${target})
            target_include_directories(${target} PRIVATE ${_IncludePathsList})
            if(WIDGETS IN_LIST APP_FEATURES)
                target_include_directories(${target} PRIVATE ${_wxIncludePaths})
            endif ()
            set(ADD_PLEASE ON)
        elseif (TARGET ${target}_static)    # ... over the static one
            addTarget(${target}_static soci ON "${components}")
            list(APPEND librariesList ${target}_static)
            target_include_directories(${target}_static PRIVATE ${_IncludePathsList})
            set(ADD_PLEASE ON)
        endif ()
    endforeach ()

    if (ADD_PLEASE)
        list(APPEND definesList USING_DATABASE USING_soci)
    endif ()

#    TODO
    include_directories(${_IncludePathsList})

    set(_DefinesList      ${definesList} PARENT_SCOPE)
    set(_IncludePathsList ${includePathsList} PARENT_SCOPE)
    set(_LibrariesList    ${librariesList} PARENT_SCOPE)
    set(HANDLED ON)

endfunction()
