function(wxWidgets_process incs libs defs)
    set(GLLibs)

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
        #    find_package(PkgConfig REQUIRED)
        #    list(APPEND GLLibs PkgConfig)
    endif ()
    # Find wxWidgets dependencies

    set(wxw_compilerOptions ${_compilerOptions})
    set(wxw_defines ${_defines})
    set(wxw_includePaths ${_includePaths})
    set(wxw_libraryPaths ${_libraryPaths})
    set(wxw_libraries ${_libraries})
    set(wxw_frameworks ${_frameworks})

    if (${gui} STREQUAL "gtk3" OR ${gui} STREQUAL "qt" OR ${gui} STREQUAL "darwin")
        unset(toolkit_used)

        if ("${gui}" STREQUAL "gtk3" OR ${gui} STREQUAL "qt")
            if ("${gui}" STREQUAL "gtk3")
                set(GTK3REQUIRED "REQUIRED")
                set(QTREQUIRED "")
            else ()
                set(GTK3REQUIRED "")
                set(QTREQUIRED "REQUIRED")
            endif ()

            pkg_check_modules(GTK3 ${GTKREQUIRED} gtk+-3.0)
            if (GTK3_LINK_LIBRARIES AND NOT "${GTK3_LINK_LIBRARIES}" STREQUAL "GTK3_LINK_LIBRARIES-NOTFOUND")
                list(APPEND wxw_libraries ${GTK3_LINK_LIBRARIES})
            endif ()
            set(toolkit_used --toolkit=${gui})

            find_package(Qt6 COMPONENTS Core DBus Gui Widgets ${QTREQUIRED})
            if (QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE AND NOT "${QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE}" STREQUAL "QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE-NOTFOUND")
                list(APPEND wxw_libraries ${QT_ALL_MODULES_VERSIONED_FOUND_VIA_FIND_PACKAGE})
                list(APPEND wxw_includePaths
                        ${Qt6Core_INCLUDE_DIRS}
                        ${Qt6Gui_INCLUDE_DIRS}
                        ${Qt6Widgets_INCLUDE_DIRS}
                        ${Qt6DBus_INCLUDE_DIRS})
            endif ()
            set(toolkit_used --toolkit=${gui})
        endif ()

    endif ()
    message("Configuring wxWidgets for ${gui}")
    set(wx_config "${CMAKE_INSTALL_PREFIX}/bin/wx-config")
    if (EXISTS "${wx_config}")
        execute_process(
                COMMAND ${wx_config} ${toolkit_used} --cxxflags --libs all
                RESULT_VARIABLE oops
                OUTPUT_VARIABLE cool
                ERROR_VARIABLE what
        )
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

        # @formatter:off
        set(wxWidgets_COMPILER_OPTIONS  ${wxw_compilerOptions})
        set(wxWidgets_DEFINES           ${wxw_defines})
        set(wxWidgets_INCLUDE_DIRS      ${wxw_includePaths})
        set(wxWidgets_LIBRARY_PATHS     ${wxw_libraryPaths})
        set(wxWidgets_LIBRARIES         ${wxw_libraries};${wxw_frameworks})
        # @formatter:on

        log(TITLE "Contents of wxWidgets variables found using wx-config" LISTS wxWidgets_COMPILER_OPTIONS wxWidgets_DEFINES wxWidgets_INCLUDE_DIRS wxWidgets_LIBRARY_PATHS wxWidgets_LIBRARIES)

    else ()
        message(FATAL_ERROR "wx-config not found. Can't configure the library")
    endif ()
    #    else ()
    #        find_package(wxWidgets REQUIRED COMPONENTS aui core base)
    #        include(${wxWidgets_USE_FILE})
    #    endif ()
    #
    add_library(Widgets INTERFACE)
    target_sources(Widgets PUBLIC "${CMAKE_SOURCE_DIR}/include/Gfx/Widgets.h")

    # @formatter:off
    target_compile_options(Widgets      INTERFACE ${wxWidgets_COMPILER_OPTIONS})
    target_link_directories(Widgets     INTERFACE ${wxWidgets_LIBRARY_PATHS})
    target_link_libraries(Widgets       INTERFACE ${wxWidgets_LIBRARIES})
    target_include_directories(Widgets  INTERFACE ${wxWidgets_INCLUDE_DIRS})
    if (LINUX)
        target_link_libraries(Widgets   INTERFACE ${GLLibs} ${LinuxLibs})
    endif ()
    # @formatter:on

    target_compile_definitions(Widgets INTERFACE
            USING_WIDGETS
            USING_wxWidgets
            WXUSINGDLL
            _FILE_OFFSET_BITS=64
    )
    if (${BUILD_TYPE} STREQUAL "Debug")
        target_compile_definitions(Widgets INTERFACE DEBUG _DEBUG)
    else ()
        target_compile_definitions(Widgets INTERFACE NDEBUG)
    endif ()

    set(LiB_PRE ${CMAKE_SHARED_LIBRARY_PREFIX})
    #message("LiB_PRE=${LiB_PRE}")
    set(LiB_SUF ${CMAKE_SHARED_LIBRARY_SUFFIX})
    #message("LiB_SUF=${LiB_SUF}")
    set(LIB_ARCHIVE_DIR "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
    set(LIB_LIBRARY_DIR "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
    set(LIB_RUNTIME_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")

    #-------------------------------------------------------------------------------------------------------------------
    # @formatter:off
    set_target_properties(Widgets   PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY    "${LIB_ARCHIVE_DIR}"
        COMPILE_FEATURES            cxx_std_23
        CXX_EXTENSIONS              OFF
        LIBRARY_OUTPUT_DIRECTORY    "${LIB_LIBRARY_DIR}"
        POSITION_INDEPENDENT_CODE   ON
        PREFIX                      "${LiB_PRE}"
        RUNTIME_OUTPUT_DIRECTORY    "${LIB_RUNTIME_DIR}"
        SUFFIX                      "${LiB_SUF}"
        SOVERSION                   ${LIB_VERSION}
        VERSION                     ${LIB_VERSION}
    )

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

#    FindReplaceInFile("${wxWidgets_INCLUDE_DIRS}" "wx/image.h"  "const unsigned char wxIMAGE_ALPHA_TRANSPARENT = 0;"    "inline const unsigned char wxIMAGE_ALPHA_TRANSPARENT = 0;")
#    FindReplaceInFile("${wxWidgets_INCLUDE_DIRS}" "wx/image.h"  "const unsigned char wxIMAGE_ALPHA_THRESHOLD = 0x80;"   "inline const unsigned char wxIMAGE_ALPHA_THRESHOLD = 0x80;")
#    FindReplaceInFile("${wxWidgets_INCLUDE_DIRS}" "wx/image.h"  "const unsigned char wxIMAGE_ALPHA_OPAQUE = 0xff;"      "inline const unsigned char wxIMAGE_ALPHA_OPAQUE = 0xff;")
#
#    FindReplaceInFile("${wxWidgets_INCLUDE_DIRS}" "wx/colour.h" "const unsigned char wxALPHA_TRANSPARENT = 0;"          "inline const unsigned char wxALPHA_TRANSPARENT = 0;")
#    FindReplaceInFile("${wxWidgets_INCLUDE_DIRS}" "wx/colour.h" "const unsigned char wxALPHA_OPAQUE = 0xff;"            "inline const unsigned char wxALPHA_OPAQUE = 0xff")

    # @formatter:on
endfunction()

if (WIDGETS IN_LIST APP_FEATURES)
    if (NOT SKIP_WIDGETS)
        wxWidgets_process(_IncludePathsList _LibrariesList _DefinesList)
    endif ()
    set(HANDLED ON)

    #    set(wxWidgets_COMPILER_OPTIONS  ${wxWidgets_COMPILER_OPTIONS}   PARENT_SCOPE)
    #    set(wxWidgets_DEFINES           ${wxWidgets_DEFINES}            PARENT_SCOPE)
    #    set(wxWidgets_INCLUDE_DIRS      ${wxWidgets_INCLUDE_DIRS}       PARENT_SCOPE)
    #    set(wxWidgets_LIBRARY_PATHS     ${wxWidgets_LIBRARY_PATHS}      PARENT_SCOPE)
    #    set(wxWidgets_LIBRARIES         ${wxWidgets_LIBRARIES}          PARENT_SCOPE)
    #
    #    set(_wxCompilerOptions          ${_wxCompilerOptions}           PARENT_SCOPE)
    #    set(_wxDefines                  ${_wxDefines}                   PARENT_SCOPE)
    #    set(_wxIncludePaths             ${_wxIncludePaths}              PARENT_SCOPE)
    #    set(_wxLibraryPaths             ${_wxLibraryPaths}              PARENT_SCOPE)
    #    set(_wxLibraries                ${_wxLibraries}                 PARENT_SCOPE)
    #    set(_wxFrameworks               ${_wxFrameworks}                PARENT_SCOPE)

endif ()

