function(OpenSSL_process incs libs defs)

    if (TARGET OpenSSLProj)
        return()
    endif ()

    # code that has to run after FetchContent_MakeAvailable
    # Create a variable to hold the OpenSSL source directory
    set(sourceDir "${EXTERNALS_DIR}")
    set(buildDir  "${BUILD_DIR}/_deps")
    set(outDir    "${OUTPUT_DIR}/${this_pkglc}")

    set(OPENSSL_SOURCE_DIR "${sourceDir}" CACHE FILEPATH "OpenSSL Source Directory")

    # Use ExternalProject to build OpenSSL manually since it doesn't use CMake
    include(ExternalProject)

    message (STATUS
            [=[
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
]=])
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

#    # Renamed from 'update' to 'checkout-tag' to avoid conflict with built-in update step
    ExternalProject_Add_Step(
            OpenSSLProj
            checkout-tag
            COMMAND git checkout openssl-3.3.2
            WORKING_DIRECTORY ${sourceDir}/OpenSSL
            DEPENDEES download  # Run after download step
            DEPENDERS configure # Run before configure step
            LOG 1
    )

    add_library(OpenSSL::SSL SHARED IMPORTED)
    set_target_properties(OpenSSL::SSL PROPERTIES
            IMPORTED_SONAME ${outDir}/openssl_install/bin/libssl${CMAKE_SHARED_LIBRARY_SUFFIX}
            IMPORTED_LOCATION ${outDir}/openssl_install/bin/libssl${CMAKE_SHARED_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${outDir}/openssl_install/lib/libssl${CMAKE_LINK_LIBRARY_SUFFIX}
    )

    add_library(OpenSSL::Crypto SHARED IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_SONAME ${outDir}/openssl_install/bin/libcrypto${CMAKE_SHARED_LIBRARY_SUFFIX}
            IMPORTED_LOCATION ${outDir}/openssl_install/bin/libcrypto${CMAKE_SHARED_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${outDir}/openssl_install/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}
    )

    set(librariesList  ${_LibrariesList} OpenSSL::SSL OpenSSL::Crypto)
    set(_LibrariesList ${librariesList}  PARENT_SCOPE)
    set(HANDLED        ON                PARENT_SCOPE)

endfunction()