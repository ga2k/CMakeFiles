function(OpenSSL_process incs libs defs)

    if (TARGET OpenSSLProj)
        return()
    endif ()

    set(sourceDir   "${EXTERNALS_DIR}")
    set(buildDir    "${BUILD_DIR}/_deps")
    set(outDir      "${OUTPUT_DIR}/${this_pkglc}")
    set(installDir  "${outDir}/openssl_install")
    set(paths       "${_LibraryPathsList}")

    if(WIN32)
        find_library(ssl
                NAMES ssl
                PATHS   "C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT")
        find_library(crypto
                NAMES crypto
                PATHS   "C:/Program Files/OpenSSL-Win64/lib/VC/x64/MT")

        if (ssl AND crypto)
            get_filename_component(ssl_lib      "${ssl}"    NAME)
            get_filename_component(crypto_lib   "${crypto}" NAME)
            get_filename_component(lib_dir      "${crypto}" PATH)

            message("\nUsing installed system OpenSSL libraries")
            list(APPEND libs    ${ssl_lib} ${crypto_lib})
            list(APPEND incs    "C:/Program Files/OpenSSL-Win64/include")
            list(APPEND paths   "${lib_dir}")

            set (_LibrariesList    "${libs}"    PARENT_SCOPE)
            set (_LibraryPathsList "${paths}"   PARENT_SCOPE)
            set (_IncludePathsList "${incs}"    PARENT_SCOPE)
            set(HANDLED ON PARENT_SCOPE)
            return()
        endif ()
    elseif (APPLE OR LINUX)
        set(ENV{OPENSSL_DIR} "${OPENSSL_PATH}")
        find_package(OpenSSL CONFIG)
        if(OpenSSL_FOUND)
            message("\nUsing installed system OpenSSL libraries")
            list(APPEND libs OpenSSL::SSL OpenSSL::Crypto)
            set (_LibrariesList "${libs}" PARENT_SCOPE)
            set(HANDLED ON PARENT_SCOPE)
            return()
        endif ()
    endif ()

    set(OPENSSL_SOURCE_DIR "${sourceDir}" CACHE FILEPATH "OpenSSL Source Directory")
    file(MAKE_DIRECTORY ${outDir}/openssl_install/include)
    include(ExternalProject)

    if(WIN32)

        # Force CMake to find Strawberry Perl specifically if it exists
        find_program(PERL_EXECUTABLE
                NAMES perl
                PATHS "C:/Strawberry/perl/bin"
                NO_DEFAULT_PATH
        )
        if ("${PERL_EXECUTABLE}" STREQUAL "PERL_EXECUTABLE-NOTFOUND")
            # If not in the specific path, find any perl
            find_package(Perl REQUIRED)
        endif ()

        find_program(MAKE_EXECUTABLE NAMES nmake REQUIRED)

        # Use the absolute path found by CMake instead of just 'perl'
        set(OPENSSL_CONFIGURE ${PERL_EXECUTABLE} ${sourceDir}/OpenSSL/Configure VC-WIN64A --prefix=${installDir} --openssldir=${installDir} shared no-asm)
        set(OPENSSL_BUILD ${MAKE_EXECUTABLE})
        set(OPENSSL_INSTALL ${MAKE_EXECUTABLE} install)
    else()
        set(OPENSSL_CONFIGURE ${sourceDir}/OpenSSL/config --prefix=${installDir} --openssldir=${installDir} shared)
        set(OPENSSL_BUILD make -j)
        set(OPENSSL_INSTALL make install)
    endif()

    message([=[)
ExternalProject_Add(OpenSSLProj
        GIT_REPOSITORY      https://github.com/openssl/openssl.git
        GIT_TAG             openssl-3.3.2
        SOURCE_DIR          ${sourceDir}/OpenSSL
        BINARY_DIR          ${buildDir}/OpenSSL
        INSTALL_DIR         ${installDir}/
        CONFIGURE_COMMAND   ${OPENSSL_CONFIGURE}
        BUILD_COMMAND       ${OPENSSL_BUILD}
        INSTALL_COMMAND     ${OPENSSL_INSTALL}
        BUILD_BYPRODUCTS    ${installDir}/lib/libssl.lib
        ${installDir}/lib/libcrypto.lib
        USES_TERMINAL_DOWNLOAD  ON
        USES_TERMINAL_CONFIGURE ON
        USES_TERMINAL_BUILD     ON
        USES_TERMINAL_INSTALL   ON
)
    ]=])
    ExternalProject_Add(OpenSSLProj
            GIT_REPOSITORY      https://github.com/openssl/openssl.git
            GIT_TAG             openssl-3.3.2
            SOURCE_DIR          ${sourceDir}/OpenSSL
            BINARY_DIR          ${buildDir}/OpenSSL
            INSTALL_DIR         ${installDir}/
            CONFIGURE_COMMAND   ${OPENSSL_CONFIGURE}
            BUILD_COMMAND       ${OPENSSL_BUILD}
            INSTALL_COMMAND     ${OPENSSL_INSTALL}
            BUILD_BYPRODUCTS    ${installDir}/lib/libssl.lib
                                ${installDir}/lib/libcrypto.lib
            USES_TERMINAL_DOWNLOAD  ON
            USES_TERMINAL_CONFIGURE ON
            USES_TERMINAL_BUILD     ON
            USES_TERMINAL_INSTALL   ON
    )

    add_library(OpenSSL::SSL SHARED IMPORTED)
    set_target_properties(OpenSSL::SSL PROPERTIES
            IMPORTED_LOCATION ${installDir}/lib/libssl${CMAKE_LINK_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${installDir}/lib/libssl${CMAKE_LINK_LIBRARY_SUFFIX}
            INTERFACE_INCLUDE_DIRECTORIES ${installDir}/include
    )
    add_dependencies(OpenSSL::SSL OpenSSLProj)

    add_library(OpenSSL::Crypto SHARED IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_LOCATION ${installDir}/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${installDir}/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}
            INTERFACE_INCLUDE_DIRECTORIES ${installDir}/include
    )
    add_dependencies(OpenSSL::Crypto OpenSSLProj)

    set(librariesList  ${_LibrariesList} OpenSSL::SSL OpenSSL::Crypto)
    set(_LibrariesList ${librariesList}  PARENT_SCOPE)
    set(HANDLED        ON                PARENT_SCOPE)

endfunction()
