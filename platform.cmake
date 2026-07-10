include(GNUInstallDirs)

if (APPLE)
    message(STATUS "Building on an Apple machine.")

    if (NOT CMAKE_INSTALL_LIBDIR)
        set(CMAKE_INSTALL_LIBDIR "lib")
    endif ()

    # Run uname -m to determine the architecture
    execute_process(COMMAND uname -m OUTPUT_VARIABLE CMAKE_SYSTEM_PROCESSOR OUTPUT_STRIP_TRAILING_WHITESPACE)

    if (CMAKE_SYSTEM_PROCESSOR STREQUAL "arm64")
        message(STATUS "Detected Apple Silicon (arm64).")
        set(CMAKE_OSX_ARCHITECTURES "arm64")
    elseif (CMAKE_SYSTEM_PROCESSOR STREQUAL "x86_64")
        message(STATUS "Detected Intel (x86_64).")
        set(CMAKE_OSX_ARCHITECTURES "x86_64")
    else ()
        message(WARNING "Unknown architecture: ${CMAKE_SYSTEM_PROCESSOR}")
    endif ()
    add_definitions("-DPCRE2_CODE_UNIT_WIDTH=32")
    add_definitions("-DMAGIC_ENUM_ENABLE_HASH")

    list(APPEND extra_Definitions BOOST_STACKTRACE_GNU_SOURCE_NOT_REQUIRED)
    list(APPEND extra_CompileOptions "-fPIC")
    set(DYN_FLAG dl)

    set(PlatformFlag "MACOSX_BUNDLE")
    if ("${LINK_TYPE_UC}" STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui "darwin")

    list(APPEND extra_Definitions __WXOSX_COCOA__)

    # Link Objective-C runtime for macOS-specific code
    find_library(OBJC_LIBRARY objc)
    if (OBJC_LIBRARY)
        list(APPEND extra_LibrariesList ${OBJC_LIBRARY})
    endif ()

    add_compile_options($<$<NOT:$<CONFIG:Debug>>:-gline-tables-only>)

elseif (LINUX)

    list(APPEND extra_IncludePaths
            /usr/include/bullshit
            /usr/include/gtk-4.0
            /usr/include/glib-2.0
            /usr/lib64/glib-2.0/include
            /usr/include/cairo
            /usr/include/pango-1.0
            /usr/include/harfbuzz
            /usr/include/gdk-pixbuf-2.0
            /usr/include/graphene-1.0
            /usr/lib64/graphene-1.0/include
    )

    if (NOT CMAKE_INSTALL_LIBDIR)
        set(CMAKE_INSTALL_LIBDIR "lib64")
    endif ()

    list(APPEND extra_Definitions __WXGTK__ __WXGTK3__)
    set(wxBUILD_TOOLKIT gtk3 CACHE STRING "" FORCE)
    list(APPEND extra_CompileOptions -fvisibility=default)

    set(DYN_FLAG dl)

    if (${LINK_TYPE_UC} STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui ${CURRENT_GFX_LIB})

elseif (WIN32)

    if (NOT CMAKE_INSTALL_LIBDIR)
        set(CMAKE_INSTALL_LIBDIR "lib")
    endif ()

    set(PlatformFlag "WIN32")
    set(DYN_FLAG ws2_32)

    if (${LINK_TYPE_UC} STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui "win")

    list(APPEND extra_Definitions __WXMSW__ UNICODE _UNICODE)

    list(APPEND extra_IncludePaths
            "C:/Program Files/OpenSSL-Win64/include"
            ${SQLITE3_INCLUDE_DIR}
            ${GSASL_INCLUDE_DIR}
            ${GNUTLS_INCLUDE_DIR}
            ${ICU_INCLUDE_DIR}
    )

    if ("${CMAKE_CXX_COMPILER_ID}" MATCHES "Visual Studio")
        list(APPEND extra_CompileOptions "/nologo")
        list(APPEND extra_CompileOptions "/MP")
        list(APPEND extra_CompileOptions "/Wv:19.34")

        # Suppress nologo for the linker (for executables and shared libraries)
        set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS}    /nologo")
        set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /nologo")
        set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /nologo")
    elseif (CMAKE_CXX_SIMULATE_ID STREQUAL "MSVC" AND CMAKE_LINKER MATCHES "lld-link")
        # clang++ emits CodeView debug info into .obj files when -g is passed, but
        # lld-link discards it unless told to produce a PDB (/debug).
        add_link_options("$<$<CONFIG:Debug>:-Wl,/debug>")
    endif ()
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS OFF)

    # windres and llvm-rc don't support GCC-style dep tracking (-MD -MF);
    # clear the flags so CMake/Ninja doesn't append them to the RC compile rule.
    set(CMAKE_DEPFILE_FLAGS_RC "")

    # CMake 4.x Platform/Windows-Clang.cmake hardcodes -fuse-ld=lld-link and
    # MSVC-PE link rule templates for the clang++-simulate-MSVC configuration.
    # When CMAKE_LINKER is ld.lld, replace them with GNU-PE equivalents so that
    # --subsystem/--entry flags (and windres COFF objects) reach ld.lld correctly.
    if(CMAKE_LINKER MATCHES "ld[.]lld")
        set(CMAKE_CXX_USING_LINKER_DEFAULT "-fuse-ld=ld.lld")
        set(CMAKE_C_USING_LINKER_DEFAULT   "-fuse-ld=ld.lld")

        set(CMAKE_CXX_CREATE_SHARED_LIBRARY
            "<CMAKE_CXX_COMPILER> -nostartfiles -nostdlib <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> -o <TARGET> -Wl,--out-implib,<TARGET_IMPLIB> <OBJECTS> <LINK_LIBRARIES>")
        set(CMAKE_C_CREATE_SHARED_LIBRARY
            "<CMAKE_C_COMPILER> -nostartfiles -nostdlib <CMAKE_SHARED_LIBRARY_C_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> -o <TARGET> -Wl,--out-implib,<TARGET_IMPLIB> <OBJECTS> <LINK_LIBRARIES>")
        set(CMAKE_CXX_CREATE_SHARED_MODULE
            "<CMAKE_CXX_COMPILER> -nostartfiles -nostdlib <CMAKE_SHARED_LIBRARY_CXX_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> -o <TARGET> -Wl,--out-implib,<TARGET_IMPLIB> <OBJECTS> <LINK_LIBRARIES>")
        set(CMAKE_C_CREATE_SHARED_MODULE
            "<CMAKE_C_COMPILER> -nostartfiles -nostdlib <CMAKE_SHARED_LIBRARY_C_FLAGS> <LANGUAGE_COMPILE_FLAGS> <LINK_FLAGS> -o <TARGET> -Wl,--out-implib,<TARGET_IMPLIB> <OBJECTS> <LINK_LIBRARIES>")
        set(CMAKE_CXX_LINK_EXECUTABLE
            "<CMAKE_CXX_COMPILER> -nostartfiles -nostdlib <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")
        set(CMAKE_C_LINK_EXECUTABLE
            "<CMAKE_C_COMPILER> -nostartfiles -nostdlib <FLAGS> <LINK_FLAGS> <OBJECTS> -o <TARGET> <LINK_LIBRARIES>")

        set(CMAKE_CXX_CREATE_WIN32_EXE   "-Wl,--subsystem,windows")
        set(CMAKE_C_CREATE_WIN32_EXE     "-Wl,--subsystem,windows")
        set(CMAKE_CXX_CREATE_CONSOLE_EXE "-Wl,--subsystem,console")
        set(CMAKE_C_CREATE_CONSOLE_EXE   "-Wl,--subsystem,console")
    endif()

endif ()
