function(OpenSSL_process incs libs defs)
    if(WIN32)
        find_library(OpenSSL REQUIRED
                NAMES ssl
                PATHS "C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT")
        find_library(OpenSSL_Crypto REQUIRED
                NAMES crypto
                PATHS "C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT")
        list(APPEND _LibrariesList OpenSSL OpenSSL_Crypto)
        set (_LibrariesList ${_LibrariesList} PARENT_SCOPE)
    elseif (APPLE)
        set(ENV{OPENSSL_DIR} "${OPENSSL_PATH}")
        find_package(OpenSSL CONFIG REQUIRED)
        list(APPEND _LibrariesList OpenSSL::SSL OpenSSL::Crypto)
        set (_LibrariesList ${_LibrariesList} PARENT_SCOPE)
    else ()
        message(FATAL_ERROR "OpenSSL for Linux should not use \"process\"")
    endif ()
endfunction()

if (SSL IN_LIST APP_FEATURES)
    OpenSSL_process(_IncludePathsList _LibrariesList _DefinesList)
endif ()
set(HANDLED ON)

