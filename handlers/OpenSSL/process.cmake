function(OpenSSL_process incs libs defs)
    if(WIN32)
        find_library(ssl REQUIRED
                NAMES ssl
                PATHS "C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT")
        find_library(crypto REQUIRED
                NAMES crypto
                PATHS "C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT")
        list(APPEND libs  ${ssl} ${crypto})
        list(APPEND incs "C:/Program Files/OpenSSL-Win64/include")
        set (_LibrariesList    "${libs}" PARENT_SCOPE)
        set (_IncludePathsList "${incs}" PARENT_SCOPE)
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
    OpenSSL_process("${_IncludePathsList}" "${_LibrariesList}" "${_DefinesList}")
endif ()
set(HANDLED ON)

