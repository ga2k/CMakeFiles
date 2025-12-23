function(wxWidgets_process incs libs defs)

    set(GLLibs)
    set(toolkit_used "")
    
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
            list(APPEND wxw_libraries ${QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE})
            list(APPEND wxw_includePaths
                    ${Qt6Core_INCLUDE_DIRS}
                    ${Qt6Gui_INCLUDE_DIRS}
                    ${Qt6Widgets_INCLUDE_DIRS}
                    ${Qt6DBus_INCLUDE_DIRS})
        endif ()
    endif ()
    
    # Find wxWidgets dependencies

    set(wxw_compilerOptions ${_compilerOptions})
    set(wxw_defines ${_defines})
    set(wxw_includePaths ${_includePaths})
    set(wxw_libraryPaths ${_libraryPaths})
    set(wxw_libraries ${_libraries})
    set(wxw_frameworks ${_frameworks})


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
                #                    list (APPEND wxw_CompileOptions "-isystem${value}")
                #                    message("added -isystem${value} to CompileOptions")
                #                else ()
                list(APPEND wxw_includePaths ${value})
                message("added ${value} to IncludePathsList")
                if (NOT EXISTS "${value}/wx/features.h")
                    include_directories(${value}/wx)
                    message("added ${value}/wx to global IncludePathsList")
                endif ()
            elseif ("${key}" STREQUAL "-D")
                list(APPEND wxw_defines ${value})
                message("added ${value} to DefinesList")
            elseif ("${key}" STREQUAL "-L")
                if (${value} STREQUAL "/usr/local/opt/llvm/c++")
                    message("skipped ${item}")
                else ()
                    list(APPEND wxw_libraryPaths ${value})
                    message("added ${value} to LibraryPathsList")
                endif ()
            elseif ("${key}" STREQUAL "-W")
                list(APPEND wxw_compilerOptions ${item})
                message("added ${item} to CompilerOptionList")
            else ()
                if ("${key}" STREQUAL "-l")
                    set(potential_lib ${value})
                elseif ("${key}" STREQUAL "-F")
                    list(APPEND wxw_frameworks "-framework ${value}")
                    message("added '-framework ${value}' to wxFrameworks")
                    continue()
                elseif ("${key}" STREQUAL "-f")
                    list(APPEND wxw_frameworks "-weak_framework ${value}")
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
                    list(APPEND wxw_libraries ${potential_lib})
                    message("added ${potential_lib} to wxLibraries")
                endif ()
            endif ()
        endforeach ()

        # Deduplicate and normalize discovered values to avoid duplicate header spellings
        if (wxw_includePaths)
            list(REMOVE_DUPLICATES wxw_includePaths)
        endif()
        if (wxw_libraryPaths)
            list(REMOVE_DUPLICATES wxw_libraryPaths)
        endif()
        if (wxw_libraries)
            list(REMOVE_DUPLICATES wxw_libraries)
        endif()
        if (wxw_frameworks)
            list(REMOVE_DUPLICATES wxw_frameworks)
        endif()
        if (wxw_defines)
            list(REMOVE_DUPLICATES wxw_defines)
        endif()
        if (wxw_compilerOptions)
            list(REMOVE_DUPLICATES wxw_compilerOptions)
        endif()

        # On Apple Silicon, prefer /opt/homebrew include roots over /usr/local to avoid mixing Intel headers.
        if (APPLE)
            set(_have_opt_homebrew FALSE)
            foreach(p IN LISTS wxw_includePaths)
                if (p MATCHES "/opt/homebrew/include")
                    set(_have_opt_homebrew TRUE)
                endif()
            endforeach()
            if (_have_opt_homebrew)
                set(_filtered_includes)
                foreach(p IN LISTS wxw_includePaths)
                    if (p MATCHES "/usr/local/include")
                        message(STATUS "Dropping duplicate/intel include root: ${p}")
                    else()
                        list(APPEND _filtered_includes ${p})
                    endif()
                endforeach()
                set(wxw_includePaths ${_filtered_includes})
            endif()
        endif()

        # @formatter:off
        set(wxWidgets_COMPILER_OPTIONS  ${wxw_compilerOptions})
        set(wxWidgets_DEFINES           ${wxw_defines})
        set(wxWidgets_INCLUDE_DIRS      ${wxw_includePaths})
        set(wxWidgets_LIBRARY_PATHS     ${wxw_libraryPaths})
        set(wxWidgets_LIBRARIES         ${wxw_libraries};${wxw_frameworks})
        # @formatter:on

        log(TITLE "Contents of wxWidgets variables found using wx-config" LISTS wxWidgets_COMPILER_OPTIONS wxWidgets_DEFINES wxWidgets_INCLUDE_DIRS wxWidgets_LIBRARY_PATHS wxWidgets_LIBRARIES)

    else () # Windows?
    
        # On Windows, use CMake's FindwxWidgets module
        set(wxWidgets_USE_STATIC ${LINK_STATIC)
        set(wxWidgets_USE_UNICODE ON)
        set(wxWidgets_USE_DEBUG ${BUILD_DEBUG})
    
        # Specify which wxWidgets libraries you need
        find_package(wxWidgets REQUIRED COMPONENTS core base gl net xml html aui ribbon richtext propgrid stc webview media)
    
        if(wxWidgets_FOUND)
            # The FindwxWidgets module provides these variables:
            # wxWidgets_INCLUDE_DIRS
            # wxWidgets_LIBRARIES
            # wxWidgets_LIBRARY_DIRS (not always set)
            # wxWidgets_DEFINITIONS
            # wxWidgets_CXX_FLAGS
        
            set(wxWidgets_COMPILER_OPTIONS ${wxWidgets_CXX_FLAGS})
            set(wxWidgets_DEFINES ${wxWidgets_DEFINITIONS})
            # wxWidgets_INCLUDE_DIRS is already set
            set(wxWidgets_LIBRARY_PATHS ${wxWidgets_LIBRARY_DIRS})
            # wxWidgets_LIBRARIES is already set
        
            log(TITLE "Contents of wxWidgets variables found using FindwxWidgets" 
                LISTS wxWidgets_COMPILER_OPTIONS wxWidgets_DEFINES 
                      wxWidgets_INCLUDE_DIRS wxWidgets_LIBRARY_PATHS 
                      wxWidgets_LIBRARIES)
        else()
            message(FATAL_ERROR "wxWidgets not found on Windows. Please install wxWidgets and set wxWidgets_ROOT_DIR if needed.")
        endif()
    endif ()
    
    # All necessary variables are exported to parent scope below
    
    set(wxWidgets_COMPILER_OPTIONS  ${wxWidgets_COMPILER_OPTIONS}   PARENT_SCOPE)
    set(wxWidgets_DEFINES           ${wxWidgets_DEFINES}            PARENT_SCOPE)
    set(wxWidgets_INCLUDE_DIRS      ${wxWidgets_INCLUDE_DIRS}       PARENT_SCOPE)
    set(wxWidgets_LIBRARY_PATHS     ${wxWidgets_LIBRARY_PATHS}      PARENT_SCOPE)
    set(wxWidgets_LIBRARIES         ${wxWidgets_LIBRARIES}          PARENT_SCOPE)

    set(_wxCompilerOptions          ${wxw_compilerOptions}          PARENT_SCOPE)
    set(_wxDefines                  ${wxw_defines}                  PARENT_SCOPE)
    set(_wxIncludePaths             ${wxw_includePaths}             PARENT_SCOPE)
    set(_wxLibraryPaths             ${wxw_libraryPaths}             PARENT_SCOPE)
    set(_wxLibraries                ${wxw_libraries}                PARENT_SCOPE)
    set(_wxFrameworks               ${wxw_frameworks}               PARENT_SCOPE)
    # @formatter:on
endfunction()

if (WIDGETS IN_LIST APP_FEATURES)
    wxWidgets_process(_IncludePathsList _LibrariesList _DefinesList)
    set(HANDLED ON)
endif ()

