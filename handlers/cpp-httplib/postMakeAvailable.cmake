function(cpp-httplib_postMakeAvailable sourceDir buildDir outDir buildType)

    set(librariesList    ${_LibrariesList})
    set(dependenciesList ${_DependenciesList})

    if (TARGET httplib::httplib)
        list(APPEND librariesList    httplib::httplib)
        list(APPEND dependenciesList httplib::httplib)
    elseif (TARGET httplib)
        list(APPEND librariesList    httplib)
        list(APPEND dependenciesList httplib)
    endif ()

    list(APPEND librariesList    ${_LibrariesList})
    list(REMOVE_DUPLICATES       librariesList)
    set(_LibrariesList    ${librariesList}    PARENT_SCOPE)

    list(APPEND dependenciesList ${_DependenciesList})
    list(REMOVE_DUPLICATES       dependenciesList)
    set(_DependenciesList ${dependenciesList} PARENT_SCOPE)

endfunction()
