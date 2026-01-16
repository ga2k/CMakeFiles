function(soci_postDeclare pkgname)

    FetchContent_GetProperties(soci)
    if(NOT soci_POPULATED)
        FetchContent_Populate(soci)

        # Disable install in the subdirectory
        set(SOCI_INSTALL OFF)
        add_subdirectory(${soci_SOURCE_DIR} ${soci_BINARY_DIR} EXCLUDE_FROM_ALL)
    endif()

endfunction()