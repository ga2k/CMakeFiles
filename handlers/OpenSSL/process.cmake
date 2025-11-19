function(OpenSSL_process incs libs defs)
    find_package(OpenSSL CONFIG REQUIRED HINTS ${OPENSSL_PATH})
    include(${OpenSSL_CONFIG})

    list(APPEND _LibrariesList OpenSSL::SSL OpenSSL::Crypto)
    set (_LibrariesList ${_LibrariesList} PARENT_SCOPE)
    # @formatter:on
endfunction()

if (SSL IN_LIST APP_FEATURES)
    OpenSSL_process(_IncludePathsList _LibrariesList _DefinesList)
endif ()
set(HANDLED ON)

