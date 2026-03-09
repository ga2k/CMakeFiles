########################################################################################################################
function(createStandardPackageData dryRun)

    # 0         1         2            3           4      5        6     7          8         9        10         11       12                                        13                     14                                  15
    # FEATURE | PKGNAME | IS_DEFAULT | NAMESPACE | KIND | METHOD | URL | GIT_REPO | GIT_TAG | SRCDIR | BUILDDIR | INCDIR | COMPONENT [COMPONENT [ COMPONENT ... ]] | ARG [ARG [ARG ... ]] | PREREQ | [PREREQ | [PREREQ ... ]] | FLAGS

    #   [0] FEATURE is the name of a group of package alternatives (eg BOOST)
    #   [1] PKGNAME is the individual package name (eg Boost)
    #   [2] IS_DEFAULT 0 if PKGNAME is NOT the default package for FEATURE, 1 if PKGNAME IS the default package
    #   [3] NAMESPACE is the namespace the library lives in, if any (eg GTest)  or empty
    #   [4] KIND is one of LIBRARY / SYSTEM / OPTIONAL
    #   [5] METHOD is the method of retrieving package. Can be FETCH_CONTENT for Fetch_Contents, FIND_PACKAGE for find_package, or PROCESS
    #       If METHOD=PROCESS, when their turn comes, only ${cmake_root}/handlers/<pkgname>/process.cmake
    #       will be run and the rest of the handling skipped. No other fields are nessessary, leave them empty
    #   [6] URL is the location of a .zip, .tar, or .gz file, either remote or local
    #   [7] GIT_REPO is the git url where the package can be found
    #   [8] GIT_TAG     for identifying which git branch/tag to retrieve, OR
    #   [9] SRCDIR is the source directory if you have manually downloaded the source for the
    #       package and aren't using FetchContent to get it. Format the entry like :-
    #       [SRC]/path/to/folder        [SRC] will be replaced by the directory
    #                                   ${EXTERNALS_DIR}
    #       or
    #       [BUILD]/path/to/folder      [BUILD] will be replaced by the directory
    #                                   ${BUILD_DIR}/_deps
    #  [10] BUILDDIR is the build directory if you have manually downloaded the source. Format as SRCDIR
    #  [11] INCDIR the include folder if it can't be automatically found, or empty if not needed. Format as SRCDIR
    #  [12] COMPONENT [COMPONENT [COMPONENT] [...]]] Space separated list of components, or empty if none
    #  [13] ARG [ARG [ARG [...]]] Space separated list of arguments for FIND_PACKAGE_OVERRIDE, or empty if none
    #  [14] PREREQ [PREREQ [PREREQ [...]]] Space separated list of FEATURES that must be loaded first
    #  [15] FLAGS. Available flags are  Flag                    Use
    #                                   EARLY_MAKEAVAILABLE     FetchContent_MakeAvailable() immediately after _Declare()
    #                                   ADD_TO_LIBRARY          Add non-SYSTEM package to library
    #
    #   [, ...] More packages in the same feature, if any
    #

    addPackageData(SYSTEM FEATURE "STACKTRACE" PKGNAME "cpptrace" NAMESPACE "cpptrace" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/jeremy-rifkin/cpptrace.git" GIT_TAG "v0.7.3"
            COMPONENT "cpptrace" ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "REFLECTION" PKGNAME "magic_enum" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/Neargye/magic_enum.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "SIGNAL" PKGNAME "eventpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wqking/eventpp.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "STORAGE" PKGNAME "yaml-cpp" NAMESPACE "yaml-cpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/jbeder/yaml-cpp.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "STORAGE" PKGNAME "nlohmann_json" NAMESPACE "nlohmann_json" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/nlohmann/json.git" GIT_TAG "v3.11.3"
            ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "STORAGE" PKGNAME "tomlplusplus" NAMESPACE "tomlplusplus" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/marzer/tomlplusplus.git" GIT_TAG "v3.4.0"
            ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "DATABASE" PKGNAME "soci" NAMESPACE "SOCI" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/SOCI/soci.git" GIT_TAG "master"
            ARGS EXCLUDE_FROM_ALL REQUIRED CONFIG COMPONENTS Core SQLite3 DRY_RUN ${dryRun})

    addPackageData(SYSTEM FEATURE "DATABASE" PKGNAME "sqliteOrm" NAMESPACE "sqlite_orm" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/fnc12/sqlite_orm.git" GIT_TAG "v1.8.2"
            ARG CONFIG DRY_RUN ${dryRun})

    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "FindCore" NAMESPACE "HoffSoft" METHOD "IGNORE" DRY_RUN ${dryRun} DEFAULT -1)
    addPackageData(LIBRARY FEATURE "GFX"  PKGNAME "FindGfx"  NAMESPACE "HoffSoft" METHOD "IGNORE" DRY_RUN ${dryRun} DEFAULT -1)

    #
    ##
    ####
    ##
    #
#    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core" METHOD "FIND_PACKAGE" NAMESPACE "Core"
#            ARGS REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dryRun})

#    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "Core"
#            ARGS REQUIRED CONFIG PREREQ CORE DRY_RUN ${dryRun})
    #
    ##
    ####
    ##
    #
    addPackageData(OPTIONAL FEATURE "TESTING" PKGNAME "gtest" NAMESPACE "GTest" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/google/googletest.git" GIT_TAG "v1.15.2"
            INCDIR "[SRC]/googletest/include"
            ARGS REQUIRED NAMES GTest googletest DRY_RUN ${dryRun})

    addPackageData(OPTIONAL FEATURE "BOOST" PKGNAME "Boost" NAMESPACE "Boost" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/boostorg/boost.git" GIT_TAG "boost-1.85.0"
            COMPONENTS system date_time regex url algorithm
            ARGS NAMES Boost DRY_RUN ${dryRun})

    addPackageData(OPTIONAL FEATURE "COMMS" PKGNAME "mailio" NAMESPACE "mailio" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/karastojko/mailio.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dryRun})

    addPackageData(OPTIONAL FEATURE "SSL" PKGNAME "OpenSSL" NAMESPACE "OpenSSL" METHOD "PROCESS" # "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/OpenSSL/OpenSSL.git" GIT_TAG "master"
            ARGS REQUIRED EXCLUDE_FROM_ALL COMPONENTS SSL Crypto DRY_RUN ${dryRun})

    addPackageData(OPTIONAL FEATURE "GUI"         PKGNAME "wxWidgets"     METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wxWidgets/wxWidgets.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dryRun} FLAGS ADD_TO_LIBRARY SRCDIR ${CMAKE_SOURCE_DIR}/archive/wxWidgets )

endfunction()
########################################################################################################################
########################################################################################################################
