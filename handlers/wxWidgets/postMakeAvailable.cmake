function(wxWidgets_postMakeAvailable pkgname)
    message(NOTICE "wxWidgets source build: exporting variables for project")

    # When building from source via FetchContent, the targets (like wx::core, wx::base)
    # are available directly. We need to populate the variables that the rest of
    # the framework expects.

    # Components the project seems to use (from process.cmake)
    set(components core base gl net xml html aui ribbon richtext propgrid stc webview media)

    set(local_libs)
    foreach(comp IN LISTS components)
        if (TARGET wx::${comp})
            list(APPEND local_libs wx::${comp})
        endif()
    endforeach()

    # Export to the scope fetchContents expects
    set(_wxLibraries ${local_libs} PARENT_SCOPE)

    # Include directories:
    # - The main include directory
    # - The setup.h directory (varies by toolkit/platform)
    string(TOLOWER "${pkgname}" pkglc)
    set(local_includes "${${pkglc}_SOURCE_DIR}/include")

    # Path to setup.h varies. In CMake builds it's usually in the build tree's lib/wx/include/...
    # We add the common patterns found in wxWidgets CMake
    file(GLOB setup_h_dir LIST_DIRECTORIES true "${${pkglc}_BINARY_DIR}/lib/wx/include/*")
    if (setup_h_dir)
        list(APPEND local_includes ${setup_h_dir})
    endif()

    # On Windows/MSVC it might be different
    if (WIN32)
        list(APPEND local_includes "${${pkglc}_BINARY_DIR}/lib/vc_x64_dll/mswu")
    endif()

    set(_wxIncludePaths ${local_includes} PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)
endfunction()

wxWidgets_postMakeAvailable(${this_pkgname})
