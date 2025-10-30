
if (APPLE)
    message(STATUS "Building on an Apple machine.")

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
    if (NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        # If no deployment target has been set default to the minimum supported
        # OS version (this has to be set before the first project() call)
        set(CMAKE_OSX_DEPLOYMENT_TARGET 14.0 CACHE STRING "macOS Deployment Target")
    endif ()
    list(APPEND extra_Definitions BOOST_STACKTRACE_GNU_SOURCE_NOT_REQUIRED)
    list(APPEND extra_CompileOptions "-fPIC")
    set(DYN_FLAG dl)

    if ("${LINK_TYPE_UC}" STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui "darwin")

    list(APPEND extra_Definitions __WXOSX_COCOA__)

    #    if (${CMAKE_OSX_ARCHITECTURES} STREQUAL "x86_64")
    #        list(APPEND extra_CompileOptions "-stdlib=libc++")
    #        list(APPEND extra_LinkOptions "-stdlib=libc++")
    #    endif ()

elseif(LINUX)

    list(APPEND extra_CompileOptions -fPIC)

    if("${GUI}" STREQUAL "GUI_GTK")
        set(LINUX_GUI "gtk3")
        list(APPEND extra_Definitions __WXGTK__)
        list(APPEND extrawxLibraries wxwebview)
        list(APPEND extra_IncludePaths "/usr/include/gtk-3.0")
        list(APPEND extra_IncludePaths "/usr/include/pango-1.0")
        list(APPEND extra_IncludePaths "/usr/include/harfbuzz")
        list(APPEND extra_IncludePaths "/usr/include/gdk-pixbuf-2.0")
        list(APPEND extra_IncludePaths "/usr/include/glib-2.0")
        list(APPEND extra_IncludePaths "/usr/lib64/glib-2.0/include")

    elseif ("${GUI}" STREQUAL "GUI_QT")
        set(LINUX_GUI "qt")
        list(APPEND extra_Definitions __WXQT__)
    else ()
        message(FATAL_ERROR "Unknown Linux GUI (${GUI}): GUI must be set to one of (GUI_GTK;GUI_QT)")
    endif ()

    set(wxBUILD_TOOLKIT ${LINUX_GUI} CACHE STRING "" FORCE)

    list(APPEND extra_CompileOptions -fvisibility=default)

    set(DYN_FLAG dl)

    if (${LINK_TYPE_UC} STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui ${LINUX_GUI})

elseif (WIN32)

    set(GSASL_ROOT          ${CMAKE_CURRENT_SOURCE_DIR}/windows/GSASL)
    set(GSASL_INCLUDE_DIR   ${GSASL_ROOT}/include)
    set(GSASL_LIBRARIES     ${GSASL_ROOT}/bin;${GSASL_ROOT}/lib)
    set(GNUTLS_ROOT         ${CMAKE_CURRENT_SOURCE_DIR}/windows/GnuTLS)
    set(GNUTLS_INCLUDE_DIR  ${GNUTLS_ROOT}include)
    set(GNUTLS_LIBRARIES    ${GNUTLS_ROOT}bin;${GNUTLS_ROOT}lib)
    set(ICU_ROOT            ${CMAKE_CURRENT_SOURCE_DIR}/windows/ICU)
    set(ICU_LIBRARIES       ${ICU_ROOT}/bin64;${ICU_ROOT}/lib64)
    set(OPENSSL_CRYPTO_LIBRARY C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT/libcrypto.lib)

    if (LINK_SHARED)
        set(GSASL_LIBRARY   ${GSASL_ROOT}/lib/libgsasl.dll.a)
        set(GNUTLS_LIBRARY  ${GNUTLS_ROOT}/lib/libgnutls.dll.a)
        set(ICU_LIBRARY     ${ICU_ROOT}/bin64/icuuc75.dll)
    else ()
        set(GSASL_LIBRARY   ${GSASL_ROOT}/lib/libgsasl.a)
        set(GNUTLS_LIBRARY  ${GNUTLS_ROOT}/lib/libgnutls.a)
        set(ICU_LIBRARY     ${ICU_ROOT}/bin64/icuuc.lib)
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

    # Suppress nologo for the compiler
    list(APPEND extra_CompileOptions "/nologo")
    list(APPEND extra_CompileOptions "/MP")
    list(APPEND extra_CompileOptions "/Wv:19.34")

    # Suppress nologo for the linker (for executables and shared libraries)
    set(CMAKE_EXE_LINKER_FLAGS    "${CMAKE_EXE_LINKER_FLAGS}    /nologo")
    set(CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} /nologo")
    set(CMAKE_STATIC_LINKER_FLAGS "${CMAKE_STATIC_LINKER_FLAGS} /nologo")

    string(SUBSTRING "${CMAKE_GENERATOR}" 0 13 Visual_Studio)
    if ("${Visual_Studio}" STREQUAL "Visual Studio")
        set(CMAKE_GENERATOR_TOOLSET "host=x64")
    endif ()
    set(CMAKE_WINDOWS_EXPORT_ALL_SYMBOLS OFF)

endif ()
