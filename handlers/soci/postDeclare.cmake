function(soci_postDeclare pkgname)

    if(SKIP_INSTALL_RULES)
        set(CMAKE_SKIP_INSTALL_RULES OFF CACHE BOOL "" FORCE)
        unset(SKIP_INSTALL_RULES CACHE)
    endif ()

endfunction()