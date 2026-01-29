########################################################################################################################
function(createStandardPackageData)

    # 0         1          2            3      4        5                6                       7          8                                            9                        10
    # FEATURE | PKGNAME | [NAMESPACE] | KIND | METHOD | URL or SRCDIR | [GIT_TAG] or BUILDDIR | [INCDIR] | [COMPONENT [COMPONENT [ COMPONENT ... ]]]  | [ARG [ARG [ARG ... ]]] | [PREREQ | [PREREQ | [PREREQ ... ]]]

    #   [1] FEATURE is the name of a group of package alternatives (eg BOOST)
    #   [2] PKGNAME is the individual package name (eg Boost)
    #   [3] NAMESPACE is the namespace the library lives in, if any (eg GTest)  or empty
    #   [4] KIND is one of LIBRARY / SYSTEM / USER
    #   [5] METHOD is the method of retrieving package. Can be FETCH for Fetch_Contents, FIND for find_package, or PROCESS
    #       If METHOD=PROCESS, when their turn comes, only ${CMAKE_SOURCE_DIR}/cmake/handlers/<pkgname>/process.cmake
    #       will be run and the rest of the handling skipped. No other fields are nessessary, leave them empty
    #
    #   [6] One or the other of
    #       ----------------------------------------------------------------------------------------------------
    #       GIT_REPOSITORY is the git url where the package can be found
    #       URL is the location of a .zip, .tar, or .gz file, either remote or local
    #       ----------------------------------------------------------------------------------------------------
    #   or
    #       ----------------------------------------------------------------------------------------------------
    #       SRCDIR is the source directory if you have manually downloaded the source for the
    #       package and aren't using FetchContent to get it. Format the entry like :-
    #       [SRC]/path/to/folder        [SRC] will be replaced by the directory
    #                                   ${EXTERNALS_DIR}
    #       or
    #       [BUILD]/path/to/folder      [BUILD] will be replaced by the directory
    #                                   ${BUILD_DIR}/_deps
    #       ----------------------------------------------------------------------------------------------------
    #   [7] GIT_TAG     for identifying which git branch/tag to retrieve, OR
    #       BUILDDIR    is the build directory if you have manually downloaded the source. Format as SRCDIR
    #
    #   [8] INCDIR the include folder if it can't be automatically found, or empty if not needed. Format as SRCDIR
    #
    #   [9] COMPONENT [COMPONENT [COMPONENT] [...]]] Space separated list of components, or empty if none
    #  [10] ARG [ARG [ARG [...]]] Space separated list of arguments for FIND_PACKAGE_OVERRIDE, or empty if none
    #
    #  [11] PREREQ [PREREQ [PREREQ [...]]] Space separated list of FEATURES that must be loaded first
    #
    #   [, ...] More packages in the same feature, if any
    #


    addPackageData(SYSTEM FEATURE "STACKTRACE" PKGNAME "cpptrace" NAMESPACE "cpptrace" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/jeremy-rifkin/cpptrace.git" GIT_TAG "v0.7.3"
            COMPONENT "cpptrace" ARG REQUIRED)

    addPackageData(SYSTEM FEATURE "REFLECTION" PKGNAME "magic_enum" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/Neargye/magic_enum.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(SYSTEM FEATURE "SIGNAL" PKGNAME "eventpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wqking/eventpp.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(SYSTEM FEATURE "STORAGE" PKGNAME "yaml-cpp" NAMESPACE "yaml-cpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/jbeder/yaml-cpp.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(SYSTEM FEATURE "DATABASE" PKGNAME "soci" METHOD "FETCH_CONTENTS" NAMESPACE "SOCI"
            GIT_REPOSITORY "https://github.com/SOCI/soci.git" GIT_TAG "master"
            ARGS EXCLUDE_FROM_ALL REQUIRED CONFIG COMPONENTS Core SQLite3) # GIT_SUBMODULES "")
    #
    ##
    ####
    ##
    #
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "HoffSoft" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG) # PREREQ DATABASE)

    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG PREREQ CORE)
    #
    ##
    ####
    ##
    #
    addPackageData(FEATURE "TESTING" PKGNAME "gtest" NAMESPACE "GTest" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/google/googletest.git" GIT_TAG "v1.15.2"
            INCDIR "[SRC]/googletest/include"
            ARGS REQUIRED NAMES GTest googletest)

    addPackageData(FEATURE "BOOST" PKGNAME "Boost" NAMESPACE "Boost" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/boostorg/boost.git" GIT_TAG "boost-1.85.0"
            COMPONENTS system date_time regex url algorithm
            ARGS NAMES Boost)

    addPackageData(FEATURE "COMMS" PKGNAME "mailio" NAMESPACE "mailio" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/karastojko/mailio.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(FEATURE "SSL" PKGNAME "OpenSSL" METHOD "PROCESS" # "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/OpenSSL/OpenSSL.git" GIT_TAG "master"
            ARGS REQUIRED EXCLUDE_FROM_ALL)

    addPackageData(FEATURE "WIDGETS" PKGNAME "wxWidgets" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wxWidgets/wxWidgets.git" GIT_TAG "master"
            ARG REQUIRED)

    set(SystemFeatureData  "${SystemFeatureData}"  PARENT_SCOPE)
    set(LibraryFeatureData "${LibraryFeatureData}" PARENT_SCOPE)
    set(UserFeatureData    "${UserFeatureData}"    PARENT_SCOPE)

endfunction()
########################################################################################################################
########################################################################################################################
