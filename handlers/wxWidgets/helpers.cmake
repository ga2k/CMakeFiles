function(wxWidgets_set_build_options)
    message(NOTICE "Configuring wxWidgets build options")

    # Common wxWidgets build options
    set(wxBUILD_SHARED   ON CACHE BOOL "" FORCE)
    set(wxBUILD_SAMPLES OFF CACHE BOOL "" FORCE)
    set(wxBUILD_TESTS   OFF CACHE BOOL "" FORCE)
    set(wxBUILD_DEMOS   OFF CACHE BOOL "" FORCE)
    set(wxBUILD_INSTALL  ON CACHE BOOL "" FORCE)
    set(wxUSE_SCINTILLA OFF CACHE BOOL "" FORCE)
    set(wxUSE_LEXILLA   OFF CACHE BOOL "" FORCE)
    set(wxUSE_STC       OFF CACHE BOOL "" FORCE)

    if (LINUX)
        set(wxBUILD_TOOLKIT "qt" CACHE STRING "" FORCE)
    elseif (APPLE)
        set(wxBUILD_TOOLKIT "osx_cocoa" CACHE STRING "" FORCE)
    elseif (WIN32)
        set(wxBUILD_TOOLKIT "msw" CACHE STRING "" FORCE)
    endif ()

    # Ensure it doesn't try to use system-installed wxWidgets when we are building from source
    set(wxWidgets_FOUND FALSE CACHE BOOL "" FORCE)
endfunction()

function(wxWidgets_export_variables pkgname)
    message(NOTICE "wxWidgets: exporting variables for project")

    # Components the project uses
    set(components core base gl net xml html aui ribbon richtext propgrid webview media)
    
    # Check both the CACHE variable and the local variable
    set(stc_enabled OFF)
    if (wxUSE_STC)
        set(stc_enabled ON)
    endif()
    
    if (stc_enabled)
        list(APPEND components stc)
    endif()

    set(local_libs)
    foreach(comp IN LISTS components)
        if (TARGET wx::${comp})
            list(APPEND local_libs wx::${comp})
        endif()
    endforeach()

    # Export to the scope fetchContents expects
    set(_wxLibraries ${local_libs} PARENT_SCOPE)

    # Include directories
    string(TOLOWER "${pkgname}" pkglc)
    # FetchContent sets <lowercaseName>_SOURCE_DIR and <lowercaseName>_BINARY_DIR
    if (NOT ${pkglc}_SOURCE_DIR)
        # Fallback if not set (though FetchContent should set it)
        set(${pkglc}_SOURCE_DIR "${EXTERNALS_DIR}/${pkgname}")
    endif()
    if (NOT ${pkglc}_BINARY_DIR)
        set(${pkglc}_BINARY_DIR "${CMAKE_BINARY_DIR}/_deps/${pkglc}-build")
    endif()

    set(local_includes "${${pkglc}_SOURCE_DIR}/include")

    # Path to setup.h varies. In CMake builds it's usually in the build tree's lib/wx/include/...
    file(GLOB setup_h_dir LIST_DIRECTORIES true "${${pkglc}_BINARY_DIR}/lib/wx/include/*")
    if (setup_h_dir)
        list(APPEND local_includes ${setup_h_dir})
    endif()

    if (WIN32)
        list(APPEND local_includes "${${pkglc}_BINARY_DIR}/lib/vc_x64_dll/mswu")
    endif()

    set(WX_OVERRIDE_PATH "${CMAKE_SOURCE_DIR}/include/overrides/wxWidgets/include")
    if (EXISTS ${WX_OVERRIDE_PATH})

        # 1. Prepend to the variable for downstream logic
        list(PREPEND _wxIncludePaths "${WX_OVERRIDE_PATH}")

        # 2. If targets already exist (e.g. from FetchContent), force it onto them immediately
        foreach(lib ${components})
            set(_dirSet OFF)
            foreach(_variant wx::${lib} wx${lib} ${lib})
                if (TARGET ${_variant})
                    # Resolve the real target if it is an alias
                    get_target_property(_aliasTarget "${_variant}" ALIASED_TARGET)
                    if (_aliasTarget)
                        set(_actualTarget "${_aliasTarget}")
                    else()
                        set(_actualTarget "${_variant}")
                    endif()

                    # Wrap in BUILD_INTERFACE to avoid "prefixed in source directory" export errors
                    target_include_directories(${_actualTarget} SYSTEM BEFORE INTERFACE
                            "$<BUILD_INTERFACE:${WX_OVERRIDE_PATH}>"
                    )
                    set(_dirSet ON)
                    break()
                endif ()
            endforeach ()
        endforeach ()
        message(STATUS "Applied wxWidgets include override: ${WX_OVERRIDE_PATH}")
    endif ()

    set(_wxIncludePaths ${local_includes} PARENT_SCOPE)
endfunction()
