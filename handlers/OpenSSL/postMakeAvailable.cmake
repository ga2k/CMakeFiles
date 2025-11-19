function(OpenSSL_postMakeAvailable sourceDir buildDir outDir buildType components)

    add_library(OpenSSL::SSL SHARED IMPORTED)
    set_target_properties(OpenSSL::SSL PROPERTIES
            IMPORTED_LOCATION ${outDir}/openssl_install/lib/libssl.so
            IMPORTED_SONAME ${outDir}/openssl_install/lib/libssl.so
    )

    add_library(OpenSSL::Crypto SHARED IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_LOCATION ${outDir}/openssl_install/lib/libcrypto.so
            IMPORTED_SONAME ${outDir}/openssl_install/lib/libcrypto.so
    )

    set(libr ${_LibrariesList} OpenSSL::SSL OpenSSL::Crypto)
    set(_LibrariesList ${libr} PARENT_SCOPE)

endfunction()

OpenSSL_postMakeAvailable("${this_src}" "${this_build}" "${this_out}" "${BUILD_TYPE_LC}" "${this_find_package_components}")
set(HANDLED ON)
