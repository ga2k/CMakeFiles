function(wxWidgets_postMakeAvailable sourceDir buildDir outDir buildType components)

    include(${CMAKE_CURRENT_LIST_DIR}/helpers.cmake)
    wxWidgets_export_variables(${this_pkgname})

    set(HANDLED ON PARENT_SCOPE)

endfunction()
