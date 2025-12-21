
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
    #    if (NOT CMAKE_OSX_DEPLOYMENT_TARGET)
    #    # If no deployment target has been set default to the minimum supported
    #    # OS version (this has to be set before the first project() call)
    #    set(CMAKE_OSX_DEPLOYMENT_TARGET 15.0 CACHE STRING "macOS Deployment Target" FORCE)
    #endif ()
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

    # Link Objective-C runtime for macOS-specific code
    find_library(OBJC_LIBRARY objc)
    if(OBJC_LIBRARY)
        list(APPEND extra_LibrariesList ${OBJC_LIBRARY})
    endif()

    # Shared CMake module paths (stage + repo cmake directory)
    list(APPEND CMAKE_PREFIX_PATH ${OUTPUT_DIR}/bin)
    list(APPEND CMAKE_PREFIX_PATH ${CMAKE_INSTALL_PREFIX}/lib/cmake)
    list(APPEND CMAKE_PREFIX_PATH "$ENV{HOME}/dev/stage${CMAKE_INSTALL_PREFIX}/lib/cmake")
    if(NOT "$ENV{DESTDIR}" AND NOT "$ENV{HOME}/dev/stage" STREQUAL "$ENV{DESTDIR}")
        list(APPEND CMAKE_PREFIX_PATH "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake")
    endif ()
    
    add_compile_options(-gline-tables-only)

elseif(LINUX)

    list(APPEND extra_Definitions __WXQT__)
    set(wxBUILD_TOOLKIT qt CACHE STRING "" FORCE)
    list(APPEND extra_CompileOptions -fvisibility=default)

    set(DYN_FLAG dl)

    if (${LINK_TYPE_UC} STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui ${CURRENT_GFX_LIB})

    # Shared CMake module paths (stage + repo cmake directory)
    list(APPEND CMAKE_PREFIX_PATH ${OUTPUT_DIR}/bin)
    list(APPEND CMAKE_PREFIX_PATH ${CMAKE_INSTALL_PREFIX}/lib/cmake)
    list(APPEND CMAKE_PREFIX_PATH "$ENV{HOME}/dev/stage${CMAKE_INSTALL_PREFIX}/lib/cmake")
    if(NOT "$ENV{DESTDIR}" AND NOT "$ENV{HOME}/dev/stage" STREQUAL "$ENV{DESTDIR}")
        list(APPEND CMAKE_PREFIX_PATH "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake")
    endif ()

elseif (WIN32)

    set(GSASL_ROOT          ${CMAKE_CURRENT_SOURCE_DIR}/windows/GSASL)
    set(GSASL_INCLUDE_DIR   ${GSASL_ROOT}/include)
    set(GSASL_LIBRARIES     ${GSASL_ROOT}/bin;${GSASL_ROOT}/lib)
    set(GNUTLS_ROOT         ${CMAKE_CURRENT_SOURCE_DIR}/windows/GnuTLS)
    set(GNUTLS_INCLUDE_DIR  ${GNUTLS_ROOT}include)
    set(GNUTLS_LIBRARIES    ${GNUTLS_ROOT}bin;${GNUTLS_ROOT}lib)
    set(ICU_ROOT            ${CMAKE_CURRENT_SOURCE_DIR}/windows/ICU)
    set(ICU_LIBRARIES       ${ICU_ROOT}/bin64;${ICU_ROOT}/lib64)
    set(SQLite3_ROOT        ${CMAKE_CURRENT_SOURCE_DIR}/windows/SQLite3)
    set(SQLite3_LIBRARY     ${SQLite3_ROOT})
    set(SQLite3_INCLUDE_DIR ${SQLite3_ROOT})

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

    message(NOTICE "SQLite3_ROOT=${SQLite3_ROOT}")
    message(NOTICE "SQLite3_LIBRARY=${SQLite3_LIBRARY}")
    message(NOTICE "SQLite3_INCLUDE_DIR=${SQLite3_INCLUDE_DIR}")

    set(PlatformFlag "WIN32")
    set(DYN_FLAG ws2_32)

    if (${LINK_TYPE_UC} STREQUAL "SHARED")
        set(APP_DYN_FLAG ${DYN_FLAG})
    else ()
        set(APP_DYN_FLAG)
    endif ()

    set(gui "win")

    # Shared CMake module paths (stage + repo cmake directory)
    list(APPEND CMAKE_PREFIX_PATH ${OUTPUT_DIR}/bin)
    list(APPEND CMAKE_PREFIX_PATH ${CMAKE_INSTALL_PREFIX}/lib/cmake)
    list(APPEND CMAKE_PREFIX_PATH "$ENV{HOME}/dev/stage${CMAKE_INSTALL_PREFIX}/lib/cmake")
    if(NOT "$ENV{DESTDIR}" AND NOT "$ENV{HOME}/dev/stage" STREQUAL "$ENV{DESTDIR}")
        list(APPEND CMAKE_PREFIX_PATH "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake")
    endif ()

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
