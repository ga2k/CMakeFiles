function(wxWidgets_set_build_options)
    message(NOTICE "Configuring wxWidgets build options")

    # Common wxWidgets build options
    set(wxBUILD_MONOLITHIC   ON CACHE BOOL "" FORCE)
    set(wxBUILD_SHARE        ON CACHE BOOL "" FORCE)
    set(wxBUILD_SAMPLES     OFF CACHE BOOL "" FORCE)
    set(wxBUILD_TESTS       OFF CACHE BOOL "" FORCE)
    set(wxBUILD_DEMOS       OFF CACHE BOOL "" FORCE)
    set(wxBUILD_INSTALL      ON CACHE BOOL "" FORCE)
    set(wxUSE_SCINTILLA     OFF CACHE BOOL "" FORCE)
    set(wxUSE_LEXILLA       OFF CACHE BOOL "" FORCE)
    set(wxUSE_STC           OFF CACHE BOOL "" FORCE)
    set(wxUSE_GRID          OFF CACHE BOOL "" FORCE)

    if (LINUX)
        set(wxBUILD_TOOLKIT "qt" CACHE STRING "" FORCE)
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
    message(NOTICE "wxWidgets: exporting variables for project")

    if(wxBUILD_MONOLITHIC)
        set(components mono)
        set(_wx_main_target wx::mono)
    else ()
        set(components core base aui gl html media net propgrid ribbon richtext webview xml)
        set(_wx_main_target wx::core)
    endif ()
    
    # Check both the CACHE variable and the local variable
    set(stc_enabled OFF)
    if (wxUSE_STC)
        set(stc_enabled ON)
    endif()
    
    if (stc_enabled)
        list(APPEND components stc)
    endif()

    set(local_libraries)
    foreach(comp IN LISTS components)
        if (TARGET wx::${comp})
            list(APPEND local_libraries wx::${comp})
        endif()
        if (TARGET wx${comp})
            list(APPEND local_libraries wx${comp})
        endif()
    endforeach()

    # If targets exist, extract metadata like process.cmake does
    if (TARGET ${_wx_main_target})
        # Extract Compiler Options
        get_target_property(_raw_options ${_wx_main_target} INTERFACE_COMPILE_OPTIONS)
        if(_raw_options)
            foreach(_opt IN LISTS _raw_options)
                # Filter out anything that looks like a generator expression if we are in a context 
                # where we need raw strings, but for _wxCompilerOptions we generally want them 
                # unless they cause issues. process.cmake strips them.
                string(REGEX REPLACE "\\$<.*>" "" _clean_opt "${_opt}")
                if(_clean_opt)
                    list(APPEND local_compilerOptions "${_clean_opt}")
                endif()
            endforeach()
        endif()

        # Extract Compile Definitions
        get_target_property(_raw_defs ${_wx_main_target} INTERFACE_COMPILE_DEFINITIONS)
        if(_raw_defs)
            foreach(_def IN LISTS _raw_defs)
                string(REGEX REPLACE "\\$<.*>" "" _clean_def "${_def}")
                if(_clean_def)
                    list(APPEND local_defines "${_clean_def}")
                endif()
            endforeach()
        endif()

        # Extract Include Directories
        get_target_property(_raw_includes ${_wx_main_target} INTERFACE_INCLUDE_DIRECTORIES)
        if (_raw_includes)
            foreach(_path IN LISTS _raw_includes)
                if(_path MATCHES "include$")
                    list(APPEND local_includes "${_path}")
                elseif(_path MATCHES "mswu")
                    string(REGEX REPLACE "\\$<.*>" "" _clean_path "${_path}")
                    if (_clean_path)
                        list(APPEND local_includes "${_clean_path}")
                    endif()
                endif()
            endforeach()
        endif()
        
        # Also extract link libraries for completeness if needed, 
        # though we already populated local_libraries with wx::comp
    else()
        message(STATUS "wxWidgets: main target ${_wx_main_target} not found yet.")
    endif()

    # Include directories (fallback/manual)
    string(TOLOWER "${pkgname}" pkglc)
    # FetchContent sets <lowercaseName>_SOURCE_DIR and <lowercaseName>_BINARY_DIR
    if (NOT ${pkglc}_SOURCE_DIR)
        # Fallback if not set (though FetchContent should set it)
        set(${pkglc}_SOURCE_DIR "${EXTERNALS_DIR}/${pkgname}")
    endif()
    if (NOT ${pkglc}_BINARY_DIR)
        set(${pkglc}_BINARY_DIR "${CMAKE_BINARY_DIR}/_deps/${pkglc}-build")
    endif()

    if (NOT local_includes)
        set(local_includes "${${pkglc}_SOURCE_DIR}/include")

        # Path to setup.h varies. In CMake builds it's usually in the build tree's lib/wx/include/...
        file(GLOB setup_h_dir LIST_DIRECTORIES true "${${pkglc}_BINARY_DIR}/lib/wx/include/*")
        if (setup_h_dir)
            list(APPEND local_includes ${setup_h_dir})
        endif()

        if (WIN32)
            list(APPEND local_includes "${${pkglc}_BINARY_DIR}/lib/vc_x64_dll/mswu")
        endif()
    else()
        # If we already have includes from the target, still add the source/include 
        # as a safety if it's not already there.
        if (EXISTS "${${pkglc}_SOURCE_DIR}/include")
            list(APPEND local_includes "${${pkglc}_SOURCE_DIR}/include")
        endif()
    endif()

    set(WX_OVERRIDE_PATH "${CMAKE_SOURCE_DIR}/include/overrides/wxWidgets/include")
    if (EXISTS ${WX_OVERRIDE_PATH})
        message(STATUS "wxWidgets: Patching system headers with local overrides...")

        # 1. Find all files in your override folder
        file(GLOB_RECURSE override_files RELATIVE "${WX_OVERRIDE_PATH}" "${WX_OVERRIDE_PATH}/*")

        foreach(file_rel_path IN LISTS override_files)
            set(system_file_path "${${pkglc}_SOURCE_DIR}/include/${file_rel_path}")
            set(override_file_path "${WX_OVERRIDE_PATH}/${file_rel_path}")

            if (EXISTS "${system_file_path}")
                # Overwrite the system file instead of deleting it
                # This keeps the CMake file list valid while giving us the fixed code
                message(STATUS "  Patching: ${file_rel_path}")
                file(COPY_FILE "${override_file_path}" "${system_file_path}")
            endif()
        endforeach()

        # 2. We no longer need to mess with PREPEND or target_include_directories
        # because we have physically patched the files in the wxWidgets source tree.
        message(STATUS "wxWidgets: Source tree patched successfully.")
    endif ()

    # Explicitly silence common external warnings for this target
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
        # Check all components, including 'mono'
        set(_targets_to_patch ${components})
        list(APPEND _targets_to_patch wxwidgets wxWidgets)
        
        foreach(lib IN LISTS _targets_to_patch)
            foreach(_variant wx::${lib} wx${lib} ${lib})
                if (TARGET ${_variant})
                    get_target_property(_aliasTarget "${_variant}" ALIASED_TARGET)
                    set(_actualTarget "${_variant}")
                    if (_aliasTarget)
                        set(_actualTarget "${_aliasTarget}")
                    endif()

                    target_compile_options(${_actualTarget} INTERFACE
                            "-Wno-deprecated-anon-enum-enum-conversion"
                            "-Wno-deprecated-declarations"
                            "-Wno-deprecated-enum-enum-conversion"
                            "-Wno-deprecated-this-capture"
                            "-Wno-enum-compare-switch"
                            "-Wno-extern-initializer"
                            "-Wno-ignored-attributes"
                            "-Wno-microsoft-exception-spec"
                            "-Wno-unknown-pragmas"
                            "-Wno-unused-command-line-argument"
                            "-Wno-unused-lambda-capture"
                            "-Wno-unused-local-typedef"
                    )
                    break()
                endif()
            endforeach ()
        endforeach ()
    endif ()

    list(APPEND local_libraries _wxLibraries)
    list(APPEND local_includes  _wxIncludePaths)

    # Deduplicate
    if (local_compilerOptions)
        list(REMOVE_DUPLICATES local_compilerOptions)
    endif()
    if (local_defines)
        list(REMOVE_DUPLICATES local_defines)
    endif()
    if (local_includes)
        list(REMOVE_DUPLICATES local_includes)
    endif()
    if (local_libraries)
        list(REMOVE_DUPLICATES local_libraries)
    endif()

    set (_wxCompilerOptions "${local_compilerOptions}" PARENT_SCOPE)
    set (_wxDefines         "${local_defines}"         PARENT_SCOPE)
    set (_wxLibraries       "${local_libraries}"       PARENT_SCOPE)
    set (_wxIncludePaths    "${local_includes}"        PARENT_SCOPE)

endfunction()
