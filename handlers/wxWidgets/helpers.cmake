function(wxWidgets_set_build_options)
    message(NOTICE "Configuring wxWidgets build options")

    # Common wxWidgets build options
    # @formatter:off
    set(wxBUILD_DEMOS      OFF CACHE BOOL "" FORCE)
    set(wxBUILD_INSTALL    OFF CACHE BOOL "" FORCE)
    set(wxBUILD_MONOLITHIC  ON CACHE BOOL "" FORCE)
    set(wxBUILD_SAMPLES    OFF CACHE BOOL "" FORCE)
    set(wxBUILD_SHARED      ON CACHE BOOL "" FORCE)
    set(wxBUILD_TESTS      OFF CACHE BOOL "" FORCE)
    set(wxUSE_GRID         OFF CACHE BOOL "" FORCE)
    set(wxUSE_LEXILLA      OFF CACHE BOOL "" FORCE)
    set(wxUSE_SCINTILLA    OFF CACHE BOOL "" FORCE)
    set(wxUSE_STC          OFF CACHE BOOL "" FORCE)
    set(wxUSE_UNICODE       ON CACHE BOOL "" FORCE)
    # @formatter:on
    if (LINUX)
        set(wxBUILD_TOOLKIT "gtk3" CACHE STRING "" FORCE)
    elseif (APPLE)
        set(wxBUILD_TOOLKIT "osx_cocoa" CACHE STRING "" FORCE)
    elseif (WIN32)
        set(wxBUILD_TOOLKIT "msw" CACHE STRING "" FORCE)
        set(CMAKE_RC_COMPILER "rc")
    endif ()

    # Ensure it doesn't try to use system-installed wxWidgets when we are building from source
    set(wxWidgets_FOUND FALSE CACHE BOOL "" FORCE)

endfunction()

function(wxWidgets_export_variables pkgname)
    msg("wxWidgets: exporting variables for project")

    set(_wx_is_monolithic OFF)
    if (TARGET wx::wxwidgets OR TARGET wxmono OR TARGET wx::wxmono OR TARGET wx::mono)
        set(_wx_is_monolithic ON)
    endif ()

    if (_wx_is_monolithic)
        set(wxBUILD_MONOLITHIC ON)
        set(components mono)

        # Prefer canonical wxWidgets monolithic target name if available
        if (TARGET wxmono)
            set(_wx_main_target wxmono)
        elseif (TARGET wx::wxwidgets )
            set(_wx_main_target wx::wxwidgets)
        elseif (TARGET HoffSoft::wxWidgets)
            set(_wx_main_target HoffSoft::wxWidgets)
        elseif (TARGET wx::wxmono)
            set(_wx_main_target wx::wxmono)
        elseif (TARGET wxWidgets)
            set(_wx_main_target wxWidgets)
        else ()
            set(_wx_main_target wx::mono)
        endif ()
    else ()
        set(wxBUILD_MONOLITHIC OFF)
        set(components core base aui gl html media net propgrid ribbon richtext webview xml)
        set(_wx_main_target wx::core)
    endif ()

    list(APPEND _DependenciesList ${_DependenciesList} ${_wx_main_target})
    set(_DependenciesList ${_DependenciesList} PARENT_SCOPE)

    # Check both the CACHE variable and the local variable
    set(stc_enabled OFF)
    if (wxUSE_STC)
        set(stc_enabled ON)
    endif ()

    if (stc_enabled)
        list(APPEND components stc)
    endif ()

    set(local_libraries)
    foreach (comp IN LISTS components)
        if (TARGET wx::${comp})
            list(APPEND local_libraries wx::${comp})
        endif ()
        if (TARGET wx${comp})
            list(APPEND local_libraries wx${comp})
        endif ()
    endforeach ()

    # If targets exist, extract metadata like process.cmake does
    if (TARGET ${_wx_main_target})
        # Extract Compiler Options
        get_target_property(_raw_options ${_wx_main_target} INTERFACE_COMPILE_OPTIONS)
        if (_raw_options)
            foreach (_opt IN LISTS _raw_options)
                 list(APPEND local_compilerOptions "${_opt}")
            endforeach ()
        endif ()

        # Extract Compile Definitions
        get_target_property(_raw_defs ${_wx_main_target} INTERFACE_COMPILE_DEFINITIONS)
        if (_raw_defs)
            foreach (_def IN LISTS _raw_defs)
                 list(APPEND local_defines "${_def}")
            endforeach ()
        endif ()

        # Extract Include Directories
        get_target_property(_raw_includes ${_wx_main_target} INTERFACE_INCLUDE_DIRECTORIES)
        if(_raw_includes)
            foreach(_path IN LISTS _raw_includes)
                list(APPEND local_includes "${_path}")
            endforeach()
        endif ()
    endif ()

    # Include directories (fallback/manual)
    string(TOLOWER "${pkgname}" pkglc)
    # FetchContent sets <lowercaseName>_SOURCE_DIR and <lowercaseName>_BINARY_DIR
    if (NOT ${pkglc}_SOURCE_DIR)
        # Fallback if not set (though FetchContent should set it)
        set(${pkglc}_SOURCE_DIR "${EXTERNALS_DIR}/${pkgname}")
    endif ()
    if (NOT ${pkglc}_BINARY_DIR)
        set(${pkglc}_BINARY_DIR "${CMAKE_BINARY_DIR}/_deps/${pkglc}-build")
    endif ()

    if (NOT local_includes)
        set(local_includes "${${pkglc}_SOURCE_DIR}/include")

        # Path to setup.h varies. In CMake builds it's usually in the build tree's lib/wx/include/...
        file(GLOB setup_h_dir LIST_DIRECTORIES true "${${pkglc}_BINARY_DIR}/lib/wx/include/*")
        if (setup_h_dir)
            list(APPEND local_includes ${setup_h_dir})
        endif ()

        if (WIN32)
            list(APPEND local_includes "${${pkglc}_BINARY_DIR}/lib/vc_x64_dll/mswu")
        endif ()
    else ()
        # If we already have includes from the target, still add the source/include 
        # as a safety if it's not already there.
        if (EXISTS "${${pkglc}_SOURCE_DIR}/include")
            list(APPEND local_includes "${${pkglc}_SOURCE_DIR}/include")
        endif ()
    endif ()

    list(APPEND local_libraries ${_wxLibraries})
    list(APPEND local_includes ${_wxIncludePaths})

    # Deduplicate
    if (local_compilerOptions)
        list(REMOVE_DUPLICATES local_compilerOptions)
    endif ()
    if (local_defines)
        list(REMOVE_DUPLICATES local_defines)
    endif ()
    if (local_includes)
        list(REMOVE_DUPLICATES local_includes)
    endif ()
    if (local_libraries)
        list(REMOVE_DUPLICATES local_libraries)
    endif ()

    # @formatter:off
    set(_wxCompilerOptions  "${local_compilerOptions}"  PARENT_SCOPE)
    set(_wxDefines          "${local_defines}"          PARENT_SCOPE)
    set(_wxLibraries        "${local_libraries}"        PARENT_SCOPE)
    set(_wxIncludePaths     "${local_includes}"         PARENT_SCOPE)
    set(_DependenciesList   "${_DependenciesList}"      PARENT_SCOPE)
    # @formatter:on

endfunction()
