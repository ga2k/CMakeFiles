function(OpenSSL_postMakeAvailable sourceDir buildDir outDir buildType components)

    set(definesList         ${_DefinesList})
    set(includePathsList    ${_IncludePathsList})
    set(librariesList       ${_LibrariesList})

    # code that has to run after FetchContent_MakeAvailable
    # Create a variable to hold the OpenSSL source directory
    forceSet(OPENSSL_SOURCE_DIR "" ${sourceDir} FILEPATH)

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

#    ExternalProject_Add_Step(
#            OpenSSLProj
#            update
#            COMMAND git checkout openssl-3.3.2
#            WORKING_DIRECTORY ${OUTPUT_DIR}/OpenSSL
#            LOG_FILE ${OUTPUT_DIR}/OpenSSLProj-update.log
#    )

    add_library(OpenSSLShared SHARED IMPORTED)
    set_target_properties(OpenSSLShared PROPERTIES
            IMPORTED_LOCATION ${outDir}/openssl_install/lib/libssl.so
            IMPORTED_SONAME ${outDir}/openssl_install/lib/libssl.so
            IMPORTED_LOCATION_CRYPTO ${outDir}/openssl_install/lib/libcrypto.so
            IMPORTED_SONAME_CRYPTO ${outDir}/openssl_install/lib/libcrypto.so
    )

    add_dependencies(OpenSSLShared OpenSSLProj)

#    addTarget(OpenSSLShared ON "")

    list(APPEND librariesList OpenSSLShared)
    list(APPEND dependenciesList OpenSSLShared)

    set(_DependenciesList   ${dependenciesList} PARENT_SCOPE)
    set(_IncludeFoldersList ${includeFoldersList} PARENT_SCOPE)
    set(_LibrariesList      ${librariesList} PARENT_SCOPE)
endfunction()

OpenSSL_postMakeAvailable("${this_src}" "${this_build}" "${this_out}" "${BUILD_TYPE_LC}" "${this_find_package_components}")
set(HANDLED ON)

set(_DependenciesList   ${_DependenciesList} PARENT_SCOPE)
set(_IncludeFoldersList ${_IncludeFoldersList} PARENT_SCOPE)
set(_LibrariesList      ${_LibrariesList} PARENT_SCOPE)
