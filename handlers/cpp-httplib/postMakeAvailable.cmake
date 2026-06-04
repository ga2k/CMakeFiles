function(cpp-httplib_postMakeAvailable sourceDir buildDir outDir buildType)

    # httplib is header-only. Include path is handled by INCDIR in standardPackageData.cmake.
    # OpenSSL link libraries are handled by the SSL feature.
    # We only need to propagate the interface compile definitions (e.g. CPPHTTPLIB_OPENSSL_SUPPORT).

    set(definesList ${_DefinesList})

    foreach (_httplibTarget IN ITEMS httplib::httplib httplib)
        if (TARGET ${_httplibTarget})
            get_target_property(_httplibDefs ${_httplibTarget} INTERFACE_COMPILE_DEFINITIONS)
            if (_httplibDefs)
                list(APPEND definesList ${_httplibDefs})
            endif ()
            break()
        endif ()
    endforeach ()

    list(APPEND definesList ${_DefinesList})
    list(REMOVE_DUPLICATES  definesList)
    set(_DefinesList ${definesList} PARENT_SCOPE)

endfunction()
