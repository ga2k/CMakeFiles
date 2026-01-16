function(soci_postDeclare pkgname)

    if (SKIP_INSTALL_RULES)
        set(CMAKE_SKIP_INSTALL_RULES  ON CACHE BOOL "" FORCE)
        unset(SKIP_INSTALL_RULES         CACHE)
    endif ()

    #    FetchContent_GetProperties(soci)
#    if(NOT soci_POPULATED)
#        set(CMAKE_POLICY_DEFAULT_CMP0169 "OLD")
#
#        FetchContent_Populate(soci)
#
#        # Disable install in the subdirectory
#        set(SOCI_INSTALL OFF)
#        add_subdirectory(${soci_SOURCE_DIR} ${soci_BINARY_DIR} EXCLUDE_FROM_ALL)
#    endif()

endfunction()