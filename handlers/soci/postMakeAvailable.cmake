function(soci_postMakeAvailable sourceDir buildDir outDir buildType)

    unset(ADD_TO_DEFINES)

    set(definesList         ${_DefinesList})
    set(includePathsList    ${_IncludePathsList})
    set(librariesList       ${_LibrariesList})
    set(dependenciesList    ${_DependenciesList})

    if(soci IN_LIST librariesList)
        message(WARNING "raw soci library has been removed to library list")
        list(REMOVE_ITEM librariesList soci)
    endif ()
    if(soci IN_LIST dependenciesList)
        message(WARNING "raw soci library has been removed to ldependency list")
        list(REMOVE_ITEM dependenciesList soci)
    endif ()

    if(EXISTS "${sourceDir}/include")
        list(APPEND includePathsList "${sourceDir}/include")
    endif ()
    if(EXISTS "${buildDir}/include")
        list(APPEND includePathsList "${buildDir}/include")
    endif ()

    list(APPEND SOCI_PLUGINS_HANDLED soci_core soci_sqlite3)
    foreach (target IN LISTS SOCI_PLUGINS_HANDLED)
        if (TARGET ${target})               # Prefer dynamic library ...
            addTarget(${target} soci OFF)
            list(APPEND librariesList ${target})
#            list(APPEND dependenciesList ${target})

            target_include_directories(${target} PRIVATE ${_IncludePathsList})
            if(WIDGETS IN_LIST APP_FEATURES)
                target_include_directories(${target} PRIVATE ${_wxIncludePaths})
            endif ()
            set(ADD_TO_DEFINES ON)
        elseif (TARGET ${target}_static)    # ... over the static one
            addTarget(${target}_static soci OFF)
            list(APPEND librariesList ${target}_static)
#            list(APPEND dependenciesList ${target}_static)

            target_include_directories(${target}_static PRIVATE ${_IncludePathsList})
            set(ADD_TO_DEFINES ON)
        endif ()
    endforeach ()

    if (ADD_TO_DEFINES)
        list(APPEND definesList USING_DATABASE USING_soci)
    endif ()

#    include_directories(${_IncludePathsList})

    set(_DefinesList        ${definesList}      PARENT_SCOPE)
    set(_IncludePathsList   ${includePathsList} PARENT_SCOPE)
    set(_LibrariesList      ${librariesList}    PARENT_SCOPE)
    set(_DependenciesList   ${dependenciesList} PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)

endfunction()
