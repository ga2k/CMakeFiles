include(FetchContent)

set(FeatureIX 0)
set(FeaturePkgNameIX 1)
set(FeatureNamespaceIX 2)
set(FeatureMethodIX 3)
set(FeatureMethodIX 4)
set(FeatureUrlIX 5)
set(FeatureGitTagIX 6)
set(FeatureSrcDirIX 5)
set(FeatureBuildDirIX 6)
set(FeatureIncDirIX 7)
set(FeatureComponentsIX 8)
set(FeatureArgsIX 9)
set(FeaturePrereqsIX 10)

set(PkgNameIX 0)
set(PkgNamespaceIX 1)
set(PkgKindIX 2)
set(PkgMethodIX 3)
set(PkgUrlIX 4)
set(PkgGitTagIX 5)
set(PkgSrcDirIX 4)
set(PkgBuildDirIX 5)
set(PkgIncDirIX 6)
set(PkgComponentsIX 7)
set(PkgArgsIX 8)
set(PkgPrereqsIX 9)

include(${CMAKE_SOURCE_DIR}/cmake/fetchContentsFns.cmake)

set(SystemFeatureData)
set(UserFeatureData)
########################################################################################################################
function(createStandardPackageData)

    # 0          1          2            3      4        5                6                     7          8                                            9                        10
    # FEATURE | PKGNAME | [NAMESPACE] | KIND | METHOD | URL or SRCDIR | [GIT_TAG] or BINDIR | [INCDIR] | [COMPONENT [COMPONENT [ COMPONENT ... ]]]  | [ARG [ARG [ARG ... ]]] | [PREREQ | [PREREQ | [PREREQ ... ]]]

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
    #       BINDIR      is the build directory if you have manually downloaded the source. Format as SRCDIR
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

    addPackageData(SYSTEM FEATURE "YAML" PKGNAME "yaml-cpp" NAMESPACE "yaml-cpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/jbeder/yaml-cpp.git" GIT_TAG "master"
            ARG REQUIRED)
    #
    ##
    ####
    ##
    #
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "HoffSoft" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG PREREQS STACKTRACE REFLECTION SIGNAL DATABASE)

    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG PREREQ CORE STACKTRACE REFLECTION SIGNAL DATABASE)
    #
    ##
    ####
    ##
    #
    addPackageData(FEATURE "DATABASE" PKGNAME "soci" METHOD "FETCH_CONTENTS" NAMESPACE "SOCI"
            GIT_REPOSITORY "https://github.com/SOCI/soci.git" GIT_TAG "master"
            ARGS EXCLUDE_FROM_ALL REQUIRED) # GIT_SUBMODULES "")

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

#    if (WIN32 OR APPLE OR LINUX)
        addPackageData(FEATURE "SSL" PKGNAME "OpenSSL" METHOD "PROCESS")
#    else ()
#        addPackageData(FEATURE "SSL" PKGNAME "OpenSSL" METHOD "FETCH_CONTENTS"
#                GIT_REPOSITORY "https://github.com/OpenSSL/OpenSSL.git" GIT_TAG "master"
#                ARGS REQUIRED EXCLUDE_FROM_ALL)
#    endif ()

    if (BUILD_WX_FROM_SOURCE)
        addPackageData(FEATURE "WIDGETS" PKGNAME "wxWidgets" METHOD "FETCH_CONTENTS"
                GIT_REPOSITORY "https://github.com/wxWidgets/wxWidgets.git" GIT_TAG "master" # "v3.2.6"
                ARG REQUIRED)
    else ()
        addPackageData(FEATURE "WIDGETS" PKGNAME "wxWidgets" METHOD "PROCESS")
    endif ()

    set(SystemFeatureData  "${SystemFeatureData}"  PARENT_SCOPE)
    set(LibraryFeatureData "${LibraryFeatureData}" PARENT_SCOPE)
    set(UserFeatureData    "${UserFeatureData}"    PARENT_SCOPE)

endfunction()
########################################################################################################################
########################################################################################################################
########################################################################################################################
function(fetchContents)

    createStandardPackageData()

    set(options HELP DEBUG)
    set(oneValueArgs PREFIX)
    set(multiValueArgs USE;NOT;OVERRIDE_FIND_PACKAGE;FIND_PACKAGE_ARGS;FIND_PACKAGE_COMPONENTS;PREREQS)
    # NOT has precedence over USE

    cmake_parse_arguments(AUE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if (AUE_HELP)
        fetchContentsHelp()
        return()
    endif ()
    if (AUE_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments passed to fetchContents() : ${AUE_UNPARSED_ARGUMENTS}")
    endif ()

set(AUE_DEBUG ON)
    if (AUE_DEBUG)
        log(TITLE "Before tampering "
            LISTS
                AUE_USE
                AUE_NOT
                AUE_OVERRIDE_FIND_PACKAGE
                AUE_FIND_PACKAGE_ARGS
                AUE_FIND_PACKAGE_COMPONENTS
                AUE_PREREQS)
    endif ()

    set(FETCHCONTENT_QUIET OFF)

    set(_CompileOptionsList ${${AUE_PREFIX}_CompileOptionsList})
    set(_DefinesList ${${AUE_PREFIX}_DefinesList})
    set(_DependenciesList ${${AUE_PREFIX}_DependenciesList})

    set(_IncludePathsList ${${AUE_PREFIX}_IncludePathsList})
    set(_LibrariesList ${${AUE_PREFIX}_LibrariesList})
    set(_LibraryPathsList ${${AUE_PREFIX}_LibraryPathsList})
    set(_LinkOptionsList ${${AUE_PREFIX}_LinkOptionsList})
    set(_PrefixPathsList ${${AUE_PREFIX}_PrefixPathsList})

    set(_wxCompilerOptions ${${AUE_PREFIX}_wxCompilerOptions})
    set(_wxDefines ${${AUE_PREFIX}_wxDefines})
    set(_wxFrameworks ${${AUE_PREFIX}_wxFrameworks})
    set(_wxIncludePaths ${${AUE_PREFIX}_wxIncludePaths})
    set(_wxLibraryPaths ${${AUE_PREFIX}_wxLibraryPaths})
    set(_wxLibraries ${${AUE_PREFIX}_wxLibraries})

    foreach (line IN LISTS SystemFeatureData)
        SplitAt(${line} "|" afeature dc)
        list(APPEND SystemFeatures ${afeature})
    endforeach ()

    foreach (line IN LISTS LibraryFeatureData)
        SplitAt(${line} "|" afeature dc)
        list(APPEND LibraryFeatures ${afeature})
    endforeach ()

    foreach (line IN LISTS UserFeatureData)
        SplitAt(${line} "|" afeature dc)
        list(APPEND OptionalFeatures ${afeature})
    endforeach ()

    list(APPEND AllPackageData ${SystemFeatureData} ${LibraryFeatureData} ${UserFeatureData})

    list(APPEND PseudoFeatureagories
            APPEARANCE
            PRINT
            LOGGER
    )
    list(APPEND NoLibPackages
            googletest
            soci
    )

    unset(USE_ALL)
    if ("ALL" IN_LIST AUE_USE)
        set(USE_ALL ON)
        list(REMOVE_ITEM AUE_USE ALL)
    endif ()

    # We don't search for pseudo packages
    foreach (pseudoLibrary IN LISTS PseudoFeatureagories)
        if (${pseudoLibrary} IN_LIST AUE_USE)
            list(REMOVE_ITEM AUE_USE ${pseudoLibrary})
            list(APPEND _DefinesList USING_${pseudoLibrary})
        endif ()
    endforeach ()

    # We don't search for system packages this way
    list(REMOVE_ITEM AUE_USE ${SystemFeatures})

    set(unifiedComponentList)
    set(unifiedArgumentList)
    set(unifiedFeatureList)

    # ensure the caller is using the system libraries
    foreach (sys_feature IN LISTS SystemFeatures)
        string(APPEND sys_feature ".0")
        list(APPEND unifiedFeatureList "${sys_feature}")
    endforeach ()

    ## combine the caller's and the system's components and arguments into unified lists
    ##
    foreach (feature IN LISTS SystemFeatures)
        ##
        unset(callerArguments)
        unset(callerComponents)
        unset(combinedArguments)
        unset(combinedComponents)
        unset(index)
        unset(pkg)
        unset(sysArguments)
        unset(sysComponents)
        unset(temp)

        ###########################################################
        ## get the component and argument details for this feature
        ##
        ##
        parsePackage(SystemFeatureData
                FEATURE ${feature}
                LIST pkgs
                COMPONENTS sysComponents
                ARGS sysArguments)
        ##
        ## All system packages are REQUIRED
        list(APPEND combinedArguments "REQUIRED")
        ##
        findInList("${AUE_FIND_PACKAGE_COMPONENTS}" ${feature} " " callerComponents index)
        combine("${sysComponents}" "${callerComponents}" combinedComponents)
        if (index GREATER_EQUAL 0)
            list(REMOVE_AT AUE_FIND_PACKAGE_COMPONENTS ${index})
        endif ()
        string(JOIN " " temp ${feature} ${combinedComponents})
        if (NOT "${temp}" STREQUAL ${feature})
            list(APPEND unifiedComponentList "${temp}")
        endif ()
        ##
        findInList("${AUE_FIND_PACKAGE_ARGS}" ${feature} " " callerArguments index)
        # Caller cannot tell us to make a system package optional
        list(REMOVE_ITEM callerArguments "OPTIONAL")
        combine("${sysArguments}" "${callerArguments}" combinedArguments OFF)
        if (index GREATER_EQUAL 0)
            list(REMOVE_AT AUE_FIND_PACKAGE_ARGS ${index})
        endif ()
        string(JOIN " " temp ${feature} ${combinedArguments})
        if (NOT "${temp}" STREQUAL ${feature})
            list(APPEND unifiedArgumentList "${temp}")
        endif ()
    endforeach ()

    ##
    ##########
    ##

    # If the user wants some find_package_args added to ALL, we take care if
    # that here, after the system packages have been added. This is because
    # anything the callers wants done to the find_package_args don't have
    # any effect on the system libraries, only the optional libraries, which
    # we will deal with next

    # UPDATE: Why not allow changes to the system libraries? If they break it,
    # they own it...


    unset(FIND_PACKAGE_ARGS_ALL)
    unset(TARGET_LINE)
    foreach (package_line IN LISTS AUE_FIND_PACKAGE_ARGS)
        SplitAt("${package_line}" " " this_feature pkg_args)
        if ("${this_feature}" STREQUAL "ALL")
            set(FIND_PACKAGE_ARGS_ALL "${pkg_args}")
            set(TARGET_LINE "${package_line}")
            break()
        endif ()
    endforeach ()
    if (TARGET_LINE)
        list(REMOVE_ITEM AUE_FIND_PACKAGE_ARGS "${TARGET_LINE}")
    endif ()

    if (USE_ALL)
        list(APPEND AUE_USE ${OptionalFeatures})
    endif ()

    list(REMOVE_DUPLICATES AUE_USE)

    foreach (feature IN LISTS AUE_NOT)
        # remove any features excluded by the AUE_NOT list
        if (NOT ${feature} IN_LIST SystemFeatures)
            list(REMOVE_ITEM AUE_USE ${feature})
            list(FILTER AUE_FIND_PACKAGE_ARGS EXCLUDE REGEX "${feature}.*")
            list(FILTER AUE_FIND_PACKAGE_COMPONENTS EXCLUDE REGEX "${feature}.*")
        endif ()
    endforeach ()
    set(AUE_NOT "")
    ##
    ####################################################################################
    ## combine the caller's and the optional components and arguments into unified lists
    ##
    unset(deadFeatures)

    foreach (feature IN LISTS AUE_USE)

        SplitAt(${feature} "=" kat pkg)
        if (pkg)
            getFeaturePkgList("${UserFeatureData}" ${kat} pkg_list)
            list(FIND pkg_list ${pkg} this_pkgindex)
            if (${this_pkgindex} EQUAL -1)
                message(FATAL_ERROR "No pkg named '${pkg}' in feature '${feature}'")
                continue()
            endif ()
            list(APPEND deadFeatures ${feature})
            set(feature ${kat})
        else ()
            set(this_pkgindex 0)
        endif ()

        ##
        ###########################################################
        ## get the component and argument details for this feature
        ##
        unset(callerArguments)
        unset(callerComponents)
        unset(combinedArguments)
        unset(combinedComponents)
        unset(index)
        unset(pkg)
        unset(optArguments)
        unset(optComponents)
        unset(temp)
        ##
        set(bothLibAndUser "${LibraryFeatureData};${UserFeatureData}")
        parsePackage(bothLibAndUser
                FEATURE ${feature}
                PKG_INDEX ${this_pkgindex}
                LIST pkg
                COMPONENTS optComponents
                ARGS optArguments)

        ##
        if (NOT "${pkg}" STREQUAL "")
            findInList("${AUE_FIND_PACKAGE_COMPONENTS}" ${feature} " " callerComponents index)
            combine("${callerComponents}" "${optComponents}" combinedComponents)
            if (DEFINED index)
                if ("${index}" GREATER_EQUAL 0)
                    list(REMOVE_AT AUE_FIND_PACKAGE_COMPONENTS ${index})
                endif ()
            endif ()
            string(JOIN " " temp ${feature} ${combinedComponents})
            if (NOT "${temp}" STREQUAL ${feature})
                list(APPEND unifiedComponentList "${temp}")
            endif ()
            ##
            findInList("${AUE_FIND_PACKAGE_ARGS}" ${feature} " " callerArguments index)
            if (FIND_PACKAGE_ARGS_ALL)
                list(APPEND callerArguments "${FIND_PACKAGE_ARGS_ALL}")
            endif ()
            if ("OPTIONAL" IN_LIST callerArguments)
                list(REMOVE_ITEM callerArguments "REQUIRED")
                list(REMOVE_ITEM optionalArguments "REQUIRED")
            endif ()
            combine("${callerArguments}" "${optArguments}" combinedArguments OFF)
            if (DEFINED index)
                if ("${index}" GREATER_EQUAL 0)
                    list(REMOVE_AT AUE_FIND_PACKAGE_ARGS ${index})
                endif ()
            endif ()
            string(JOIN " " temp ${feature} ${combinedArguments})
            if (NOT "${temp}" STREQUAL ${feature})
                list(APPEND unifiedArgumentList "${temp}")
            endif ()
            ##
            list(APPEND unifiedFeatureList ${feature}.${this_pkgindex})
            list(APPEND deadFeatures ${feature})
        endif ()
    endforeach ()

    list(REMOVE_ITEM AUE_USE ${deadFeatures})

    foreach (item IN LISTS AUE_USE)
        if (NOT ${item} STREQUAL ${kat})
            message("Unknown feature: ${item}")
        endif ()
    endforeach ()

    foreach (item IN LISTS AUE_FIND_PACKAGE_COMPONENTS)
        message("Unknown find_package_components: ${item}")
    endforeach ()

    foreach (item IN LISTS AUE_FIND_PACKAGE_ARGS)
        message("Unknown find_package_args: ${item}")
    endforeach ()
    message(" ")

    if (AUE_DEBUG)
        log(TITLE "After tampering" LISTS unifiedFeatureList unifiedArgumentList unifiedComponentList)
    endif ()

    # Re-order unifiedFeatureList based on prerequisites (Topological Sort)
    resolveDependencies("${unifiedFeatureList}" AllPackageData reorderedList)
    set(unifiedFeatureList "${reorderedList}")

    if (AUE_DEBUG)
        log(TITLE "After re-ordering by prerequisites" LISTS unifiedFeatureList)
    endif ()

    ####################################################################################################################
    ####################################################################################################################
    ################################ T H E   R E A L   W O R K   B E G I N S   H E R E #################################
    ####################################################################################################################
    ####################################################################################################################

    # ==========================================================================================================
    # PRE-SCAN phase: Identify targets already supplied by LIBRARY features
    # ==========================================================================================================
    message(STATUS "Pre-scanning libraries for supplied targets...")
    foreach (this_feature_entry IN LISTS unifiedFeatureList)
        SplitAt(${this_feature_entry} "." _feat _idx)
        parsePackage(AllPackageData FEATURE ${_feat} PKG_INDEX ${_idx} KIND _kind METHOD _method ARGS _args LIST _pkg)

        if ("${_kind}" STREQUAL "LIBRARY" AND "${_method}" STREQUAL "FIND_PACKAGE")
            # Try to locate the library now to see its exported targets
            SplitAt("${_pkg}" ";" _name _dc)
            set(_temp_args ${_args})
            list(REMOVE_ITEM _temp_args REQUIRED EXCLUDE_FROM_ALL)
            find_package(${_name} ${_temp_args})

            if (${_name}_FOUND)
                scanLibraryTargets("${_name}")
            endif()
        endif()
    endforeach()

    list(LENGTH unifiedFeatureList numWanted)
    set(numFailed 0)
    if (${numWanted} EQUAL 1)
        message(CHECK_START "Fetching library")
    else ()
        message(CHECK_START "Fetching ${numWanted} Libraries")
    endif ()
    list(APPEND CMAKE_MESSAGE_INDENT "\t")

    string(ASCII 27 ESC)

    # Two-Pass Strategy:
    # Pass 0: Declare all FetchContents, handle PROCESS and FIND_PACKAGE (Metadata stage)
    # Pass 1: MakeAvailable and perform post-population fixes (Build stage)

    foreach (pass_num RANGE 1)
        foreach (this_feature_entry IN LISTS unifiedFeatureList)

            SplitAt(${this_feature_entry} "." this_feature this_pkgindex)

            message(CHECK_START "${ESC}[32m${this_feature}${ESC}[0m")
            list(APPEND CMAKE_MESSAGE_INDENT "\t")

            # Skip features already found/aliased, but only check this in the final pass
            # to allow declarations to overlap if necessary.
            if (${pass_num} EQUAL 1)
                if (TARGET ${this_feature} OR TARGET ${this_feature}::${this_feature} OR ${this_feature}_FOUND)
                    list(POP_BACK CMAKE_MESSAGE_INDENT)
                    message(CHECK_PASS "Feature already available without re-processing: skipped")
                    continue()
                endif ()
            endif ()

            unset(pkg_details)
            unset(this_pkgname)
            unset(this_pkglc)
            unset(this_pkguc)
            unset(this_namespace)
            unset(this_method)
            unset(this_url)
            unset(this_tag)
            unset(this_src)
            unset(this_build)
            unset(this_inc)
            unset(this_out)
            unset(this_find_package_components)
            unset(this_namespace_package_components)
            unset(this_find_package_args)
            unset(this_hint)
            unset(OVERRIDE_FIND_PACKAGE_KEYWORD)
            unset(COMPONENTS_KEYWORD)

            parsePackage(AllPackageData
                    FEATURE ${this_feature}
                    PKG_INDEX ${this_pkgindex}
                    METHOD this_method
                    LIST pkg_details
                    URL this_url
                    GIT_TAG this_tag
                    SRC_DIR this_src
                    BUILD_DIR this_build
                    FETCH_FLAG this_fetch
                    INC_DIR this_inc
            )

            findInList("${unifiedComponentList}" ${this_feature} " " this_find_package_components)
            findInList("${unifiedArgumentList}" ${this_feature} " " this_find_package_args)

            list(POP_FRONT pkg_details this_pkgname this_namespace)
            string(TOLOWER "${this_pkgname}" this_pkglc)
            string(TOUPPER "${this_pkgname}" this_pkguc)

            # ==========================================================================================================
            # PASS 0: DECLARATION & FIND_PACKAGE phase
            # ==========================================================================================================
            if (${pass_num} EQUAL 0)

                if ("${this_method}" STREQUAL "PROCESS")
                    set(fn "${this_pkgname}_process")
                    if (COMMAND "${fn}")
                        cmake_language(CALL "${fn}" "${_IncludePathsList}" "${_LibrariesList}" "${_DefinesList}")
                    endif ()
                endif ()

                # Pre-download hooks (mostly for setting variables/policies)
                set(fn "${this_pkgname}_preDownload")
                if (COMMAND "${fn}")
                    cmake_language(CALL "${fn}" "${this_pkgname}" "${this_url}" "${this_tag}" "${this_src}")
                endif ()

                if ("${this_method}" STREQUAL "FETCH_CONTENTS")
                    if (this_fetch)

                        # Check if a previously loaded LIBRARY already claimed this package
                        if (${this_pkgname}_ALREADY_FOUND)
                            message(STATUS "${this_pkgname} was discovered as a transitive dependency. Skipping FetchContent.")
                        else()
                            # Try to find the package first before declaring FetchContent
                            # This allows Gfx to see what HoffSoft already fetched/built
                            message(STATUS "Checking if ${this_pkgname} is already available via find_package...")
                            set(temporary_args ${this_find_package_args})
                            list(REMOVE_ITEM temporary_args REQUIRED EXCLUDE_FROM_ALL)
                            find_package(${this_pkgname} QUIET ${temporary_args})

                            if(${this_pkgname}_FOUND OR TARGET ${this_pkgname}::${this_pkgname} OR TARGET ${this_pkgname})
                                message(STATUS "${this_pkgname} found (likely via prerequisite). Skipping FetchContent.")
                                set(${this_pkgname}_ALREADY_FOUND ON CACHE INTERNAL "")
                            else()
                                message(STATUS "Nope! Doing it the hard way...")
                                # Normalise source/URL keywords
                                string(FIND "${this_url}" ".zip" azip)
                                string(FIND "${this_url}" ".tar" atar)
                                string(FIND "${this_url}" ".gz" agz)
                                if (${azip} GREATER 0 OR ${atar} GREATER 0 OR ${agz} GREATER 0)
                                    set(SOURCE_KEYWORD "URL")
                                    unset(GIT_TAG_KEYWORD)
                                    unset(this_tag)
                                else ()
                                    set(SOURCE_KEYWORD "GIT_REPOSITORY")
                                    set(GIT_TAG_KEYWORD "GIT_TAG")
                                endif ()

                                # Setup Override keywords
                                list(LENGTH this_find_package_components num_components)
                                list(LENGTH this_find_package_args num_args)
                                if (num_args OR num_components)
                                    set(OVERRIDE_FIND_PACKAGE_KEYWORD "OVERRIDE_FIND_PACKAGE")
                                endif ()
                                if (num_components)
                                    set(COMPONENTS_KEYWORD "COMPONENTS")
                                endif ()

                                message(STATUS "\nFetchContent_Declare(${this_pkgname} ${SOURCE_KEYWORD} ${this_url} SOURCE_DIR ${EXTERNALS_DIR}/${this_pkgname} ${OVERRIDE_FIND_PACKAGE_KEYWORD} ${this_find_package_args} ${COMPONENTS_KEYWORD} ${this_find_package_components} ${GIT_TAG_KEYWORD} ${this_tag})")

                                FetchContent_Declare(${this_pkgname}
                                        ${SOURCE_KEYWORD} ${this_url}
                                        SOURCE_DIR ${EXTERNALS_DIR}/${this_pkgname}
                                        ${OVERRIDE_FIND_PACKAGE_KEYWORD} ${this_find_package_args}
                                        ${COMPONENTS_KEYWORD} ${this_find_package_components}
                                        ${GIT_TAG_KEYWORD} ${this_tag})

                                set(fn "${this_pkgname}_postDeclare")
                                if (COMMAND "${fn}")
                                    cmake_language(CALL "${fn}" "${this_pkgname}")
                                endif ()
                            endif ()
                        endif ()
                    endif ()
                elseif ("${this_method}" STREQUAL "FIND_PACKAGE")
                    if (NOT TARGET ${this_namespace}::${this_pkgname})
                        message(STATUS "\nfind_package(${this_pkgname} ${this_find_package_args})")

                        find_package(${this_pkgname} ${this_find_package_args})

                        set(HANDLED OFF)
                        set(fn "${this_pkgname}_postMakeAvailable")
                        if (COMMAND "${fn}")
                            cmake_language(CALL "${fn}" "${this_src}" "${this_build}" "${OUTPUT_DIR}" "${BUILD_TYPE_LC}")
                        endif ()

                        if (NOT HANDLED AND ${this_pkgname}_FOUND)
                            if (${this_pkgname}_LIBRARIES)
                                list(APPEND _LibrariesList ${${this_pkgname}_LIBRARIES})
                            endif ()
                            if (${this_pkgname}_INCLUDE_DIR)
                                list(APPEND _IncludePathsList ${${this_pkgname}_INCLUDE_DIR})
                            endif ()

                            # If this was a LIBRARY (like CORE), scan it for 3rd-party targets it might supply
                            parsePackage(AllPackageData FEATURE ${this_feature} PKG_INDEX ${this_pkgindex} KIND this_kind)
                            if ("${this_kind}" STREQUAL "LIBRARY")
                                scanLibraryTargets("${this_pkgname}")
                            endif()
                        endif ()
                    endif ()

                endif ()

                # ==========================================================================================================
                # PASS 1: POPULATION & FIX phase
                # ==========================================================================================================

            else ()
                if ("${this_method}" STREQUAL "FIND_PACKAGE")
                    if (NOT TARGET ${this_namespace}::${this_pkgname})
                       handleTarget()
                    endif ()
                elseif ("${this_method}" STREQUAL "FETCH_CONTENTS" AND this_fetch)

                    if (NOT ${this_pkgname}_ALREADY_FOUND)
                        set(fn "${this_pkgname}_preMakeAvailable")
                        set(HANDLED OFF)
                        if (COMMAND "${fn}")
                            cmake_language(CALL "${fn}" "${this_pkgname}")
                        endif ()

                        if (NOT HANDLED AND NOT ${this_feature} STREQUAL TESTING)
                            message(STATUS "\nFetchContent_MakeAvailable(${this_pkgname})")

                            FetchContent_MakeAvailable(${this_pkgname})
                            handleTarget()
                        endif ()

                        set(fn "${this_pkgname}_postMakeAvailable")
                        if (COMMAND "${fn}")
                            cmake_language(CALL "${fn}" "${this_src}" "${this_build}" "${OUTPUT_DIR}" "${BUILD_TYPE_LC}")
                        endif ()
                    else()
                        message(STATUS "${this_pkgname} already found, skipping population.")
                        handleTarget()
                    endif()

                    # Auto-include the standard 'include' folder if it exists and wasn't handled
                    if (EXISTS "${this_src}/include")
                        list(APPEND _IncludePathsList "${this_src}/include")
                    endif ()
                else ()
                    message("\nNo Phase 2 step")
                endif ()

                # Final patching/fixing phase
                set(fn "${this_pkgname}_fix")
                if (COMMAND "${fn}")
                    cmake_language(CALL "${fn}" "${this_pkgname}" "${this_tag}" "${EXTERNALS_DIR}/${this_pkgname}")
                endif ()

            endif ()
            message("")
            list(POP_BACK CMAKE_MESSAGE_INDENT)
            message(CHECK_PASS "${ESC}[32mOK${ESC}[0m\n")

        endforeach () # this_feature_entry
    endforeach () # pass_num


    set(ies "ies")
    if (numWanted EQUAL 1)
        set(ies "y")
    endif ()
    list(POP_BACK CMAKE_MESSAGE_INDENT)

    if (numFailed)
        if (${numFailed} EQUAL 1)
            if (${numWanted} EQUAL 1)
                message(CHECK_FAIL "finished. Library could not be loaded.")
            else ()
                message(CHECK_FAIL "finished. One out of ${numWanted} libraries could not be loaded.")
            endif ()
        elseif ()
            message(CHECK_FAIL "finished. ${numFailed} out of ${numWanted} libraries could not be loaded.")
        endif ()
    else ()
        if (${numWanted} EQUAL 1)
            message(CHECK_PASS "finished. Library loaded.")
        else ()
            message(CHECK_PASS "finished. All ${numWanted} librar${ies} loaded.")
        endif ()
    endif ()
    #
    # ##########################################################################################################
    #
    #
    # ###################################################################################################
    #
    list(REMOVE_DUPLICATES _CompileOptionsList)
    list(REMOVE_DUPLICATES _DefinesList)
    list(REMOVE_DUPLICATES _DependenciesList)
    list(REMOVE_DUPLICATES _ExportedDependencies)
    list(REMOVE_DUPLICATES _IncludePathsList)
    list(REMOVE_DUPLICATES _LibrariesList)
    list(REMOVE_DUPLICATES _LibraryPathsList)
    list(REMOVE_DUPLICATES _LinkOptionsList)
    list(REMOVE_DUPLICATES _PrefixPathsList)

    list(REMOVE_DUPLICATES _wxCompilerOptions)
    list(REMOVE_DUPLICATES _wxDefines)
    list(REMOVE_DUPLICATES _wxIncludePaths)
    list(REMOVE_DUPLICATES _wxLibraryPaths)
    list(REMOVE_DUPLICATES _wxLibraries)
    list(REMOVE_DUPLICATES _wxFrameworks)
    #
    # ###################################################################################################
    #
    # @formatter:off
    set(${AUE_PREFIX}_CompileOptionsList        ${_CompileOptionsList}                      )
    set(${AUE_PREFIX}_CompileOptionsList        ${_CompileOptionsList}          PARENT_SCOPE)
    set(${AUE_PREFIX}_DefinesList               ${_DefinesList}                             )
    set(${AUE_PREFIX}_DefinesList               ${_DefinesList}                 PARENT_SCOPE)
    set(${AUE_PREFIX}_DependenciesList          ${_DependenciesList}                        )
    set(${AUE_PREFIX}_DependenciesList          ${_DependenciesList}            PARENT_SCOPE)
    set(${AUE_PREFIX}_IncludePathsList          ${_IncludePathsList}                        )
    set(${AUE_PREFIX}_IncludePathsList          ${_IncludePathsList}            PARENT_SCOPE)
    set(${AUE_PREFIX}_LibrariesList             ${_LibrariesList}                           )
    set(${AUE_PREFIX}_LibrariesList             ${_LibrariesList}               PARENT_SCOPE)
    set(${AUE_PREFIX}_LibraryPathsList          ${_LibraryPathsList}                        )
    set(${AUE_PREFIX}_LibraryPathsList          ${_LibraryPathsList}            PARENT_SCOPE)
    set(${AUE_PREFIX}_LinkOptionsList           ${_LinkOptionsList}                         )
    set(${AUE_PREFIX}_LinkOptionsList           ${_LinkOptionsList}             PARENT_SCOPE)
    set(${AUE_PREFIX}_PrefixPathsList           ${_PrefixPathsList}                         )
    set(${AUE_PREFIX}_PrefixPathsList           ${_PrefixPathsList}             PARENT_SCOPE)

    set(${AUE_PREFIX}_wxCompilerOptions         ${_wxCompilerOptions}               )
    set(${AUE_PREFIX}_wxCompilerOptions         ${_wxCompilerOptions}           PARENT_SCOPE)
    set(${AUE_PREFIX}_wxDefines                 ${_wxDefines}                               )
    set(${AUE_PREFIX}_wxDefines                 ${_wxDefines}                   PARENT_SCOPE)
    set(${AUE_PREFIX}_wxIncludePaths            ${_wxIncludePaths}                          )
    set(${AUE_PREFIX}_wxIncludePaths            ${_wxIncludePaths}              PARENT_SCOPE)
    set(${AUE_PREFIX}_wxLibraryPaths            ${_wxLibraryPaths}                          )
    set(${AUE_PREFIX}_wxLibraryPaths            ${_wxLibraryPaths}              PARENT_SCOPE)
    set(${AUE_PREFIX}_wxLibraries               ${_wxLibraries}                             )
    set(${AUE_PREFIX}_wxLibraries               ${_wxLibraries}                 PARENT_SCOPE)
    set(${AUE_PREFIX}_wxFrameworks              ${_wxFrameworks}                            )
    set(${AUE_PREFIX}_wxFrameworks              ${_wxFrameworks}                PARENT_SCOPE)

    # @formatter:on

    log(TITLE "Leaving Las Vegas" LISTS
            ${AUE_PREFIX}_CompileOptionsList
            ${AUE_PREFIX}_DefinesList
            ${AUE_PREFIX}_DependenciesList
            ${AUE_PREFIX}_IncludePathsList
            ${AUE_PREFIX}_LibrariesList
            ${AUE_PREFIX}_LibraryPathsList
            ${AUE_PREFIX}_LinkOptionsList
            ${AUE_PREFIX}_PrefixPathsList

            ${AUE_PREFIX}_wxCompilerOptions
            ${AUE_PREFIX}_wxDefines
            ${AUE_PREFIX}_wxIncludePaths
            ${AUE_PREFIX}_wxLibraryPaths
            ${AUE_PREFIX}_wxLibraries
            ${AUE_PREFIX}_wxFrameworks
    )
endfunction()
