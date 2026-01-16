function(OpenSSL_postMakeAvailable sourceDir buildDir outDir buildType components)

    if (TARGET OpenSSLProj)
        return()
    endif ()

    set(OPENSSL_SOURCE_DIR "${sourceDir}" CACHE FILEPATH "OpenSSL Source Directory")

    # Use ExternalProject to build OpenSSL manually since it doesn't use CMake
    include(ExternalProject)

    ExternalProject_Add(
            OpenSSLProj
            GIT_REPOSITORY https://github.com/openssl/openssl.git
            GIT_TAG openssl-3.3.2
            SOURCE_DIR ${sourceDir}/OpenSSL
            BINARY_DIR ${buildDir}/OpenSSL
            INSTALL_DIR ${outDir}/openssl_install
            CONFIGURE_COMMAND ${sourceDir}/OpenSSL/config --prefix=${outDir}/openssl_install --openssldir=${outDir}/openssl_install shared
            BUILD_COMMAND ${sourceDir}/OpenSSL/config --prefix=${outDir}/openssl_install --openssldir=${outDir}/openssl_install shared && make -j
            INSTALL_COMMAND make install
            LOG_DOWNLOAD ON
            LOG_CONFIGURE ON
            LOG_BUILD ON
            LOG_INSTALL ON
    )

    ExternalProject_Add_Step(
            OpenSSLProj
            update
            COMMAND git checkout openssl-3.3.2
            WORKING_DIRECTORY ${OUTPUT_DIR}/OpenSSL
            LOG_FILE ${OUTPUT_DIR}/OpenSSLProj-update.log
    )


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

    set(librariesList  ${_LibrariesList} OpenSSL::SSL OpenSSL::Crypto)
    set(_LibrariesList ${librariesList}  PARENT_SCOPE)
    set(HANDLED        ON                PARENT_SCOPE)

endfunction()
