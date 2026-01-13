function(wxWidgets_process incs libs defs)

    if (BUILD_WX_FROM_SOURCE)
        include(${CMAKE_SOURCE_DIR}/cmake/handlers/wxWidgets/helpers.cmake OPTIONAL RESULT_VARIABLE helper_found)
        if (helper_found)
            wxWidgets_set_build_options()
            if (NOT _wxLibraries)
                 wxWidgets_export_variables("wxWidgets")
            endif()
            
            if (_wxLibraries)
                set(wxWidgets_INCLUDE_DIRS      ${_wxIncludePaths}       PARENT_SCOPE)
                set(wxWidgets_LIBRARIES         ${_wxLibraries}          PARENT_SCOPE)
                set(_wxIncludePaths             ${_wxIncludePaths}       PARENT_SCOPE)
                set(_wxLibraries                ${_wxLibraries}          PARENT_SCOPE)
                return()
            endif()
        endif()
    endif()

    set(GLLibs)
    set(toolkit_used "")

    set(local_compilerOptions ${_wxCompilerOptions})
    set(local_defines         ${_wxDefines})
    set(local_includePaths    ${_wxIncludePaths})
    set(local_libraryPaths    ${_wxLibraryPaths})
    set(local_libraries       ${_wxLibraries})
    set(local_frameworks      ${_wxFrameworks})

    if (LINUX)
        set(OpenGL_GL_PREFERENCE GLVND)
        # Find OpenGL
        find_package(OpenGL REQUIRED)
        message(STATUS "OPENGL_FOUND: ${OPENGL_FOUND}")
        message(STATUS "OPENGL_LIBRARIES: ${OPENGL_LIBRARIES}")
        message(STATUS "OPENGL_INCLUDE_DIR: ${OPENGL_INCLUDE_DIR}")
        message(STATUS "OpenGL::GL exists: $<TARGET_EXISTS:OpenGL::GL>")
        message(STATUS "OpenGL::OpenGL exists: $<TARGET_EXISTS:OpenGL::OpenGL>")
        if (NOT TARGET OpenGL::GL)
            message(WARNING "OpenGL::GL not found. Configuring manually.")
            add_library(OpenGL::GL SHARED IMPORTED)
            set_target_properties(OpenGL::GL PROPERTIES
                    IMPORTED_LOCATION "/usr/lib64/libGL.so"
                    INTERFACE_INCLUDE_DIRECTORIES "/usr/include"
                    INTERFACE_LINK_LIBRARIES "/usr/lib64/libOpenGL.so;/usr/lib64/libGLX.so"
            )
        endif ()
        list(APPEND GLLibs OpenGL::GL)

        if (NOT TARGET OpenGL::OpenGL)
            message(WARNING "OpenGL::OpenGL not found. Configuring manually.")
            add_library(OpenGL::OpenGL SHARED IMPORTED)
            set_target_properties(OpenGL::OpenGL PROPERTIES
                    IMPORTED_LOCATION "/usr/lib64/libOpenGL.so"
                    INTERFACE_INCLUDE_DIRECTORIES "/usr/include"
                    INTERFACE_LINK_LIBRARIES "/usr/lib64/libGL.so;/usr/lib64/libGLX.so"
            )
        endif ()
        list(APPEND GLLibs OpenGL::OpenGL)

        if (NOT TARGET OpenGL::GLU)
            message(WARNING "OpenGL::GLU not found. Configuring manually.")
            add_library(OpenGL::GLU SHARED IMPORTED)
            set_target_properties(OpenGL::GLU PROPERTIES
                    IMPORTED_LOCATION "/usr/lib64/libGLU.so"
                    INTERFACE_INCLUDE_DIRECTORIES "/usr/include"
                    INTERFACE_LINK_LIBRARIES "OpenGL::GL"
            )
        endif ()
        list(APPEND GLLibs OpenGL::GLU)
        set(LinuxLibs "X11;Xext;Xtst;gspell-1;xkbcommon;curl;notify;gdk_pixbuf-2.0;gio-2.0;gobject-2.0;glib-2.0;soup-3.0;webkit2gtk-4.1;javascriptcoregtk-4.1;gstreamer-1.0;gstvideo-1.0")
        find_package(PNG REQUIRED)
        list(APPEND GLLibs PNG::PNG)
        find_package(JPEG REQUIRED)
        list(APPEND GLLibs JPEG::JPEG)
        find_package(TIFF REQUIRED)
        list(APPEND GLLibs TIFF::TIFF)
        find_package(EXPAT REQUIRED)
        list(APPEND GLLibs EXPAT::EXPAT)
        set(toolkit_used --toolkit=qt)

        find_package(Qt6 COMPONENTS Core DBus Gui Widgets REQUIRED)
        if (QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE AND NOT "${QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE}" STREQUAL "QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE-NOTFOUND")
            list(APPEND local_libraries ${QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE})
            list(APPEND local_includePaths
                    ${Qt6Core_INCLUDE_DIRS}
                    ${Qt6Gui_INCLUDE_DIRS}
                    ${Qt6Widgets_INCLUDE_DIRS}
                    ${Qt6DBus_INCLUDE_DIRS})
        endif ()
    endif ()
    
    # Find wxWidgets dependencies

    # Prefer a real wx-config on PATH, prioritizing native Homebrew on Apple Silicon
    find_program(wx_config NAMES wx-config
            HINTS
                /opt/homebrew/bin
                /usr/local/bin
                /usr/bin)
    
    if (EXISTS "${wx_config}")  # Should for Linux and macOS
        execute_process(
                COMMAND ${wx_config} ${toolkit_used} --cxxflags --libs all
                RESULT_VARIABLE oops
                OUTPUT_VARIABLE cool
                ERROR_VARIABLE what)
                
        if (NOT ${oops} EQUAL 0)
            if ("${what}" STREQUAL "")
                message(WARNING "Failed to read from wx-config: returned ${oops}")
            else ()
                message(WARNING "Failed to read from wx-config: ${what}")
            endif ()
            return()
        endif ()

        string(REGEX REPLACE "-weak_framework " "-f" phase_1 ${cool})
        string(REGEX REPLACE "-framework " "-F" phase_2 ${phase_1})
        string(REGEX REPLACE "[ \n\r]" ";" items "${phase_2}")

        foreach (item IN LISTS items)
            if ("${item}" STREQUAL "\n" OR "${item}" STREQUAL "")
                message("(Skipped blank entry)")
                continue()
            endif ()
            string(SUBSTRING "${item}" 0 2 key)
            string(SUBSTRING "${item}" 2 -1 value)

            message("${item} = ${key} + ${value}")

            if ("${key}" STREQUAL "-I")
                #                    list (APPEND local_CompileOptions "-isystem${value}")
                #                    message("added -isystem${value} to CompileOptions")
                #                else ()
                list(APPEND local_includePaths ${value})
                message("added ${value} to IncludePathsList")
                if (NOT EXISTS "${value}/wx/features.h")
                    include_directories(${value}/wx)
                    message("added ${value}/wx to global IncludePathsList")
                endif ()
            elseif ("${key}" STREQUAL "-D")
                list(APPEND local_defines ${value})
                message("added ${value} to DefinesList")
            elseif ("${key}" STREQUAL "-L")
                if (${value} STREQUAL "/usr/local/opt/llvm/c++")
                    message("skipped ${item}")
                else ()
                    list(APPEND local_libraryPaths ${value})
                    message("added ${value} to LibraryPathsList")
                endif ()
            elseif ("${key}" STREQUAL "-W")
                list(APPEND local_compilerOptions ${item})
                message("added ${item} to CompilerOptionList")
            else ()
                if ("${key}" STREQUAL "-l")
                    set(potential_lib ${value})
                elseif ("${key}" STREQUAL "-F")
                    list(APPEND local_frameworks "-framework ${value}")
                    message("added '-framework ${value}' to wxFrameworks")
                    continue()
                elseif ("${key}" STREQUAL "-f")
                    list(APPEND local_frameworks "-weak_framework ${value}")
                    message("added '-weak_framework ${value}' to wxFrameworks")
                    continue()
                else ()
                    set(potential_lib ${item})
                endif ()
                unset(matched)
                foreach (excluded_lib IN LISTS WX_EXCLUDE)
                    string(REGEX MATCH .*${excluded_lib}.* matched "${potential_lib}")
                    if (matched)
                        break ()
                    endif ()
                endforeach ()

                if (matched)
                    message("skipped ${potential_lib}")
                else ()
                    list(APPEND local_libraries ${potential_lib})
                    message("added ${potential_lib} to wxLibraries")
                endif ()
            endif ()
        endforeach ()

        # Deduplicate and normalize discovered values to avoid duplicate header spellings
        list(REMOVE_DUPLICATES local_includePaths)
        list(REMOVE_DUPLICATES local_libraryPaths)
        list(REMOVE_DUPLICATES local_libraries)
        list(REMOVE_DUPLICATES local_frameworks)
        list(REMOVE_DUPLICATES local_defines)
        list(REMOVE_DUPLICATES local_compilerOptions)
#        if (local_includePaths)
#            list(REMOVE_DUPLICATES local_includePaths)
#        endif()
#        if (local_libraryPaths)
#            list(REMOVE_DUPLICATES local_libraryPaths)
#        endif()
#        if (local_libraries)
#            list(REMOVE_DUPLICATES local_libraries)
#        endif()
#        if (local_frameworks)
#            list(REMOVE_DUPLICATES local_frameworks)
#        endif()
#        if (local_defines)
#            list(REMOVE_DUPLICATES local_defines)
#        endif()
#        if (local_compilerOptions)
#            list(REMOVE_DUPLICATES local_compilerOptions)
#        endif()

        # On Apple Silicon, prefer /opt/homebrew include roots over /usr/local to avoid mixing Intel headers.
        if (APPLE)
            set(_have_opt_homebrew FALSE)
            foreach(p IN LISTS local_includePaths)
                if (p MATCHES "/opt/homebrew/include")
                    set(_have_opt_homebrew TRUE)
                endif()
            endforeach()
            if (_have_opt_homebrew)
                set(_filtered_includes)
                foreach(p IN LISTS local_includePaths)
                    if (p MATCHES "/usr/local/include")
                        message(STATUS "Dropping duplicate/intel include root: ${p}")
                    else()
                        list(APPEND _filtered_includes ${p})
                    endif()
                endforeach()
                set(local_includePaths ${_filtered_includes})
            endif()
        endif()

        # @formatter:off
        set(wxWidgets_COMPILER_OPTIONS  ${local_compilerOptions})
        set(wxWidgets_DEFINES           ${local_defines})
        set(wxWidgets_INCLUDE_DIRS      ${local_includePaths})
        set(wxWidgets_LIBRARY_PATHS     ${local_libraryPaths})
        set(wxWidgets_LIBRARIES         ${local_libraries};${local_frameworks})
        # @formatter:on

        log(TITLE "Contents of wxWidgets variables found using wx-config" LISTS wxWidgets_COMPILER_OPTIONS wxWidgets_DEFINES wxWidgets_INCLUDE_DIRS wxWidgets_LIBRARY_PATHS wxWidgets_LIBRARIES)

    else () # Windows?
    
        # On Windows, use CMake's FindwxWidgets module
        set(wxWidgets_USE_STATIC ${LINK_STATIC})
        set(wxWidgets_USE_UNICODE ON)
        set(wxWidgets_USE_DEBUG ${BUILD_DEBUG})

        set(CMAKE_CROSSCOMPILING OFF)

        # Specify which wxWidgets libraries you need
        find_package(wxWidgets CONFIG REQUIRED COMPONENTS core base gl net xml html aui ribbon richtext propgrid stc webview media)
#        find_package(wxWidgets CONFIG REQUIRED COMPONENTS core base)

        if(wxWidgets_FOUND)
            # The FindwxWidgets module provides these variables:
            # wxWidgets_INCLUDE_DIRS
            # wxWidgets_LIBRARIES
            # wxWidgets_LIBRARY_DIRS (not always set)
            # wxWidgets_DEFINITIONS
            # wxWidgets_CXX_FLAGS

            # Extract Compiler Options
            if(NOT wxWidgets_CXX_FLAGS)
                get_target_property(_raw_options wx::core INTERFACE_COMPILE_OPTIONS)
                if(_raw_options)
                    foreach(_opt IN LISTS _raw_options)
                        # Clean up generator expressions if they exist
                        string(REGEX REPLACE "\\$<.*>" "" _clean_opt "${_opt}")
                        if(_clean_opt)
                            list(APPEND wxWidgets_CXX_FLAGS "${_clean_opt}")
                        endif()
                    endforeach()
                endif()
            endif()

            # Extract Compile Definitions (like UNICODE, __WXMSW__, etc.)
            if(NOT wxWidgets_DEFINITIONS)
                get_target_property(_raw_defs wx::core INTERFACE_COMPILE_DEFINITIONS)
                if(_raw_defs)
                    foreach(_def IN LISTS _raw_defs)
                        string(REGEX REPLACE "\\$<.*>" "" _clean_def "${_def}")
                        if(_clean_def)
                            list(APPEND wxWidgets_DEFINITIONS "${_clean_def}")
                        endif()
                    endforeach()
                endif()
            endif()
            if(NOT wxWidgets_INCLUDE_DIRS)
                get_target_property(_raw_includes wx::core INTERFACE_INCLUDE_DIRECTORIES)

                # Generator expressions like $<CONFIG:Debug> cause issues in raw variables.
                # We'll filter for the actual include directory and the base library include.
                foreach(_path IN LISTS _raw_includes)
                    if(_path MATCHES "include$")
                        list(APPEND wxWidgets_INCLUDE_DIRS "${_path}")
                    elseif(_path MATCHES "mswu")
                        # Manually resolve the common setup header path if possible
                        # or just strip the generator expression for the variable
                        string(REGEX REPLACE "\\$<.*>" "" _clean_path "${_path}")
                        list(APPEND wxWidgets_INCLUDE_DIRS "${_clean_path}")
                    endif()
                endforeach()
            endif()

            set(wxWidgets_LIBRARY_PATHS ${wxWidgets_LIBRARY_DIRS})

            set(local_compilerOptions   ${wxWidgets_COMPILER_OPTIONS})
            set(local_defines           ${wxWidgets_DEFINES})
            set(local_includePaths      ${wxWidgets_INCLUDE_DIRS})
            set(local_libraryPaths      ${wxWidgets_LIBRARY_PATHS})
            set(local_libraries         ${wxWidgets_LIBRARIES})

            log(TITLE "Contents of wxWidgets variables found using FindwxWidgets" 
                LISTS wxWidgets_CXX_FLAGS wxWidgets_DEFINITIONS
                      wxWidgets_INCLUDE_DIRS wxWidgets_LIBRARY_PATHS 
                      wxWidgets_LIBRARIES)
        else()
            message(FATAL_ERROR "wxWidgets not found on Windows. Please install wxWidgets and set wxWidgets_ROOT_DIR if needed.")
        endif()
    endif ()
    
    # All necessary variables are exported to parent scope below
    
    set(wxWidgets_COMPILER_OPTIONS  ${wxWidgets_CXX_FLAGS}          PARENT_SCOPE)
    set(wxWidgets_DEFINES           ${wxWidgets_DEFINITIONS}        PARENT_SCOPE)
    set(wxWidgets_INCLUDE_DIRS      ${wxWidgets_INCLUDE_DIRS}       PARENT_SCOPE)
    set(wxWidgets_LIBRARY_PATHS     ${wxWidgets_LIBRARY_PATHS}      PARENT_SCOPE)
    set(wxWidgets_LIBRARIES         ${wxWidgets_LIBRARIES}          PARENT_SCOPE)

    set(_wxCompilerOptions          ${local_compilerOptions}        PARENT_SCOPE)
    set(_wxDefines                  ${local_defines}                PARENT_SCOPE)
    set(_wxIncludePaths             ${local_includePaths}           PARENT_SCOPE)
    set(_wxLibraryPaths             ${local_libraryPaths}           PARENT_SCOPE)
    set(_wxLibraries                ${local_libraries}              PARENT_SCOPE)
    set(_wxFrameworks               ${local_frameworks}             PARENT_SCOPE)
    # @formatter:on
endfunction()

if (WIDGETS IN_LIST APP_FEATURES)
    wxWidgets_process(_IncludePathsList _LibrariesList _DefinesList)
    set(HANDLED ON)
endif ()

