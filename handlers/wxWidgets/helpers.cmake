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
    set(wxUSE_GRID      OFF CACHE BOOL "" FORCE)

    if (LINUX)
        set(wxBUILD_TOOLKIT "qt" CACHE STRING "" FORCE)
    elseif (APPLE)
        set(wxBUILD_TOOLKIT "osx_cocoa" CACHE STRING "" FORCE)
    elseif (WIN32)
        set(wxBUILD_TOOLKIT "msw" CACHE STRING "" FORCE)
        find_program(MSVC_RC rc.exe)
        if (MSVC_RC)
            set(CMAKE_RC_COMPILER "${MSVC_RC}" CACHE FILEPATH "" FORCE)
        endif()
message(FATAL_ERROR "FF")
        # Disable the problematic LLVM-RC preprocessing wrapper
        set(CMAKE_RC_USE_RESPONSE_FILE_FOR_INCLUDES ON CACHE BOOL "" FORCE)
        set(CMAKE_NINJA_FORCE_RESPONSE_FILE ON CACHE BOOL "" FORCE)
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
        set(_wxIncludePaths ${local_includes} PARENT_SCOPE)
    endif ()

    # Explicitly silence common external warnings for this target
    if (CMAKE_CXX_COMPILER_ID MATCHES "Clang|GNU")
        foreach(lib ${components})
            foreach(_variant wx::${lib} wx${lib} ${lib})
                if (TARGET ${_variant})
                    get_target_property(_aliasTarget "${_variant}" ALIASED_TARGET)
                    set(_actualTarget "${_variant}")
                    if (_aliasTarget)
                        set(_actualTarget "${_aliasTarget}")
                    endif()

                    target_compile_options(${_actualTarget} INTERFACE
                            "-Wno-deprecated-enum-enum-conversion"
                            "-Wno-deprecated-anon-enum-enum-conversion"
                            "-Wno-deprecated-declarations"
                            "-Wno-unused-lambda-capture"
                            "-Wno-enum-compare-switch"
                    )
                endif()
                break()
            endforeach ()
        endforeach ()
    endif ()

endfunction()
