function(OpenSSL_process incs libs defs)
    if(NOT DEFINED OpenSSL_ROOT_DIR)
        execute_process(
                COMMAND brew --prefix openssl@3
                OUTPUT_VARIABLE HOMEBREW_OPENSSL_PREFIX
                OUTPUT_STRIP_TRAILING_WHITESPACE
                RESULT_VARIABLE BREW_RV
        )
        if(BREW_RV EQUAL 0 AND EXISTS "${HOMEBREW_OPENSSL_PREFIX}")
            # Works for both find_package and pkg-config-aware modules
            list(APPEND CMAKE_PREFIX_PATH "${HOMEBREW_OPENSSL_PREFIX}")
            set(OpenSSL_ROOT_DIR "${HOMEBREW_OPENSSL_PREFIX}" CACHE PATH "Homebrew OpenSSL prefix")
        endif()
    endif()
    find_package(OpenSSL REQUIRED)

    list(APPEND _LibrariesList OpenSSL::SSL OpenSSL:Crypto)
    set (_LibrariesList ${_LibrariesList} PARENT_SCOPE)
    # @formatter:on
endfunction()

if (SSL IN_LIST APP_FEATURES)
    OpenSSL_process(_IncludePathsList _LibrariesList _DefinesList)
endif ()
set(HANDLED ON)

