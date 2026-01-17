function(OpenSSL_process incs libs defs)

    if (TARGET OpenSSLProj)
        return()
    endif ()

    set(sourceDir "${EXTERNALS_DIR}")
    set(buildDir  "${BUILD_DIR}/_deps")
    set(outDir    "${OUTPUT_DIR}/${this_pkglc}")

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

#        # Use Strawberry Perl's gmake if available, as it's best for OpenSSL
#        find_program(MAKE_EXECUTABLE
#                NAMES gmake gmake.exe make make.exe
#                PATHS
#                    "C:/Strawberry/c/bin"
#                    "C:/Program Files (x86)/GnuWin32/bin"
#                    "C:/Users/geoff/AppData/Local/Microsoft/WinGet/Links"
#                NO_DEFAULT_PATH
#        )
#        if ("${MAKE_EXECUTABLE}" STREQUAL "MAKE_EXECUTABLE-NOTFOUND")
            find_program(MAKE_EXECUTABLE NAMES nmake REQUIRED)
#        endif ()

        # Use the absolute path found by CMake instead of just 'perl'
        set(OPENSSL_CONFIGURE ${PERL_EXECUTABLE} ${sourceDir}/OpenSSL/Configure VC-WIN64A --prefix=${outDir}/openssl_install --openssldir=${outDir}/openssl_install shared no-asm)
        set(OPENSSL_BUILD ${MAKE_EXECUTABLE})
        set(OPENSSL_INSTALL ${MAKE_EXECUTABLE} install)
    else()
        set(OPENSSL_CONFIGURE ${sourceDir}/OpenSSL/config --prefix=${outDir}/openssl_install --openssldir=${outDir}/openssl_install shared)
        set(OPENSSL_BUILD make -j)
        set(OPENSSL_INSTALL make install)
    endif()

    include(ExternalProject)
    ExternalProject_Add(OpenSSLProj
            GIT_REPOSITORY      https://github.com/openssl/openssl.git
            GIT_TAG             openssl-3.3.2
            SOURCE_DIR          ${sourceDir}/OpenSSL
            BINARY_DIR          ${buildDir}/OpenSSL
            INSTALL_DIR         ${outDir}/openssl_install
            CONFIGURE_COMMAND   ${OPENSSL_CONFIGURE}
            BUILD_COMMAND       ${OPENSSL_BUILD}
            INSTALL_COMMAND     ${OPENSSL_INSTALL}
            BUILD_BYPRODUCTS    ${outDir}/openssl_install/lib/libssl.lib
                                ${outDir}/openssl_install/lib/libcrypto.lib
            LOG_DOWNLOAD        ON
            LOG_CONFIGURE       ON
            LOG_BUILD           ON
            LOG_INSTALL         ON
    )

    add_library(OpenSSL::SSL SHARED IMPORTED)
    set_target_properties(OpenSSL::SSL PROPERTIES
            IMPORTED_LOCATION ${outDir}/openssl_install/lib/libssl${CMAKE_LINK_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${outDir}/openssl_install/lib/libssl${CMAKE_LINK_LIBRARY_SUFFIX}
            INTERFACE_INCLUDE_DIRECTORIES ${outDir}/openssl_install/include
    )
    add_dependencies(OpenSSL::SSL OpenSSLProj)  # Add this dependency

    add_library(OpenSSL::Crypto SHARED IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_LOCATION ${outDir}/openssl_install/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${outDir}/openssl_install/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}
            INTERFACE_INCLUDE_DIRECTORIES ${outDir}/openssl_install/include
    )
    add_dependencies(OpenSSL::Crypto OpenSSLProj)  # Add this dependency

    set(librariesList  ${_LibrariesList} OpenSSL::SSL OpenSSL::Crypto)
    set(_LibrariesList ${librariesList}  PARENT_SCOPE)
    set(HANDLED        ON                PARENT_SCOPE)

endfunction()






function(OpenSSL_process_ incs libs defs)

    if (TARGET OpenSSLProj)
        return()
    endif ()

    set(sourceDir "${EXTERNALS_DIR}")
    set(buildDir  "${BUILD_DIR}/_deps")
    set(outDir    "${OUTPUT_DIR}/${this_pkglc}")

    set(OPENSSL_SOURCE_DIR "${sourceDir}" CACHE FILEPATH "OpenSSL Source Directory")
    file(MAKE_DIRECTORY ${outDir}/openssl_install/include)

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
            BUILD_BYPRODUCTS ${outDir}/openssl_install/lib/libssl${CMAKE_LINK_LIBRARY_SUFFIX}
                             ${outDir}/openssl_install/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}  # Add this
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
            INTERFACE_INCLUDE_DIRECTORIES ${outDir}/openssl_install/include
    )
    add_dependencies(OpenSSL::SSL OpenSSLProj)

    add_library(OpenSSL::Crypto SHARED IMPORTED)
    set_target_properties(OpenSSL::Crypto PROPERTIES
            IMPORTED_SONAME ${outDir}/openssl_install/bin/libcrypto${CMAKE_SHARED_LIBRARY_SUFFIX}
            IMPORTED_LOCATION ${outDir}/openssl_install/bin/libcrypto${CMAKE_SHARED_LIBRARY_SUFFIX}
            IMPORTED_IMPLIB ${outDir}/openssl_install/lib/libcrypto${CMAKE_LINK_LIBRARY_SUFFIX}
            INTERFACE_INCLUDE_DIRECTORIES ${outDir}/openssl_install/include
    )
    add_dependencies(OpenSSL::Crypto     OpenSSLProj)

    set(librariesList       ${_LibrariesList}       OpenSSL::SSL OpenSSL::Crypto)
#    set(dependenciesList    ${_dependenciesList}    OpenSSL::SSL OpenSSLProj)

    set(_LibrariesList      ${librariesList}        PARENT_SCOPE)
#    set(_dependenciesList   ${dependenciesList}     PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)

endfunction()