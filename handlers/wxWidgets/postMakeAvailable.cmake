function(wxWidgets_postMakeAvailable sourceDir buildDir outDir buildType)
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)
    wxWidgets_export_variables(${this_pkgname})

    set (_wxLibraries    "${_wxLibraries}"    PARENT_SCOPE)
    set (_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)
endfunction()
