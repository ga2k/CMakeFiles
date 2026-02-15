include(FetchContent)

include(${CMAKE_SOURCE_DIR}/cmake/fetchContentsFns.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/standardPackageData.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/sqlish.cmake)

set(SystemFeatureData)
set(UserFeatureData)

########################################################################################################################
function(fetchContents)

    # @formatter:off

    CREATE (MAP hSystem      AS  "tbl_SystemData"                                )
    CREATE (TABLE hSystemFeatures   AS  "tbl_SystemFeatures"   COLUMNS "Name;DfltPkg"   )
    CREATE (TABLE hSystemPackages   AS  "tbl_SystemPackages"   COLUMNS "Name"           )
    INSERT (INTO hSystem            KEY "key_SystemFeatures"   HANDLE hSystemFeatures   )
    INSERT (INTO hSystem            KEY "key_SystemPackages"   HANDLE hSystemPackages   )
    CREATE (MAP hOptional    AS  "tbl_OptionalData"                              )
    CREATE (TABLE hOptionalFeatures AS  "tbl_OptionalFeatures" COLUMNS "Name;DfltPkg"   )
    CREATE (TABLE hOptionalPackages AS  "tbl_OptionalPackages" COLUMNS "Name"           )
    INSERT (INTO hOptional          KEY "key_OptionalFeatures" HANDLE hOptionalFeatures )
    INSERT (INTO hOptional          KEY "key_OptionalPackages" HANDLE hOptionalPackages )
    CREATE (MAP hLibrary     AS  "tbl_LibraryData"                               )
    CREATE (TABLE hLibraryFeatures  AS  "tbl_LibraryFeatures"  COLUMNS "Name;DfltPkg"   )
    CREATE (TABLE hLibraryPackages  AS  "tbl_LibraryPackages"  COLUMNS "Name"           )
    INSERT (INTO hLibrary           KEY "key_LibraryFeatures"  HANDLE hLibraryFeatures  )
    INSERT (INTO hLibrary           KEY "key_LibraryPackages"  HANDLE hLibraryPackages  )
    CREATE (MAP hCustom      AS  "tbl_CustomData"                                )
    CREATE (TABLE hCustomFeatures   AS  "tbl_CustomFeatures"   COLUMNS "Name;DfltPkg"   )
    CREATE (TABLE hCustomPackages   AS  "tbl_CustomPackages"   COLUMNS "Name"           )
    INSERT (INTO hCustom            KEY "key_CustomFeatures"   HANDLE  hCustomFeatures  )
    INSERT (INTO hCustom            KEY "key_CustomPackages"   HANDLE  hCustomPackages  )
    CREATE (MAP hPlugin      AS  "tbl_PluginData"                                )
    CREATE (TABLE hPluginFeatures   AS  "tbl_PluginFeatures"   COLUMNS "Name;DfltPkg"   )
    CREATE (TABLE hPluginPackages   AS  "tbl_PluginPackages"   COLUMNS "Name"           )
    INSERT (INTO hPlugin            KEY "key_PluginFeatures"   HANDLE hPluginFeatures   )
    INSERT (INTO hPlugin            KEY "key_PluginPackages"   HANDLE hPluginPackages   )

    # @formatter:on

    set(options HELP)
    set(oneValueArgs PREFIX)
    set(multiValueArgs FEATURES)

    cmake_parse_arguments(AUE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if (AUE_HELP)
        fetchContentsHelp()
        return()
    endif ()
    if (AUE_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments passed to fetchContents() : ${AUE_UNPARSED_ARGUMENTS}")
    endif ()

    #    foreach(DRY_RUN IN ITEMS ON OFF)
    #        initialiseFeatureHandlers(${DRY_RUN} OFF)
    #        createStandardPackageData(${DRY_RUN} OFF)
    #        runPackageCallbacks(${DRY_RUN} OFF)
    #    endforeach ()
    initialiseFeatureHandlers(ON)
    createStandardPackageData(ON)
    runPackageCallbacks(ON)

    initialiseFeatureHandlers(OFF)
    createStandardPackageData(OFF)
    runPackageCallbacks(OFF)

    CREATE(VIEW BigData FROM hSystem hLibrary hOptional hPlugin hCustom INTO hGlobal)

    preProcessFeatures("${AUE_FEATURES}" hGlobal hUser)
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

    list(APPEND PseudoFeatures APPEARANCE PRINT LOGGER)
    list(APPEND NoLibPackages googletest)

    CREATE(TABLE tbl_UnifiedFeatures COLUMNS "${PkgColNames}" INTO hUnifiedFeatures)

    # We don't search for pseudo packages
    SELECT(COUNT FROM hUser INTO numPackages)
    set(aix 0)
    while (aix LESS numPackages)
        set(pkgIndex ${aix})
        inc(aix)

        SELECT(ROW FROM hUser WHERE ROWID = ${pkgIndex} into _uFeature)

        # Where we manipulate the feature to be a union of the _uFeature requirements (if any)
        # and system requirements (if any)

        list(GET _uFeature ${FIXName}    _uFeatureName)
        list(GET _uFeature ${FIXPkgName} _uPackageName)

        if ("${_uFeatureName}" IN_LIST PseudoFeatures)
            # We don't search for plugins this way, but still advise downstream users it is needed/available
            list(APPEND _DefinesList USING_${_uFeatureName})
            continue()
        endif ()

        SELECT(* FROM hGlobal WHERE KEY = "${_uFeatureName}" INTO hFeature)

        if(_uPackageName)
#            SELECT(* FROM hFeature WHERE COLUMN "FeatureName" = "${_uFeatureName}" AND COLUMN "PackageName" = "${_uPackageName}" INTO pkg)
            SELECT(ROW FROM hFeature WHERE COLUMN "FeatureName" = "${_uFeatureName}" AND COLUMN "PackageName" = "${_uPackageName}" INTO _sFeature)
        else ()
            SELECT(*     FROM hGlobal  WHERE KEY = "tbl_SystemFeatures" INTO hSysFeat)
            SELECT(VALUE FROM hSysFeat WHERE COLUMN "Name" = "${_uFeatureName}" AND COLUMN = "DflPkg" INTO dfltPkg)
            SELECT(ROW   FROM hFeature WHERE COLUMN "FeatureName" = "${uFeatureName}" AND COLUMN "PackageName" = "${dfltPkg}" INTO _sFeature)
        endif ()
#        SELECT(* FROM hGlobal WHERE KEY = "${__uFeatureName}" INTO currCat)

        # If the user has not specified a package name, it means they want the default package.
#        SELECT(ROW FROM currCat
#                WHERE COLUMN "FeatureName" = "${_uFeatureName}"
#                AND   COLUMN "PackageName" = "${_uPackageName}"
#                INTO _sFeature)
#
        list(GET _sFeature ${FIXName}    _sFeatureName)
        list(GET _sFeature ${FIXPkgName} _sPackageName)

        # If we are here, we have the users feature and options in ${_uFeature}
        # and the corresponding registered  feature and options in ${_sFeature}
        # The merged feature will be in ${wip}

        set(wip "${_sFeature}")
        unset(_uPkg)
        unset(_sPkg)
        unset(_uBits)
        unset(_sBits)
        unset(_bits)

        # Step 1. Sanity check the set pkgname
        string(TOUPPER "${_uPackageName}" _uPkg)
        string(TOUPPER "${_sPackageName}" _sPkg)

        if (NOT _uPkg STREQUAL "" AND NOT _uPkg STREQUAL _sPkg)
            DUMP(FROM hFeature)
            msg(ALWAYS FATAL_ERROR "Internal error: FC01 - Package name mismatch \"${_uPkg}\" vs \"${_sPkg}\"")
        endif ()

        # Step 2. Merge Args
        list(GET _uFeature ${FIXArgs} _uBits)
        list(GET _sFeature ${FIXArgs} _sBits)
        if (NOT "${_uBits}" STREQUAL "${_sBits}")
            string(REPLACE "&" ";" _uBits "${_uBits}")
            string(REPLACE "&" ";" _sBits "${_sBits}")
            if (REQUIRED IN_LIST _sBits AND OPTIONAL IN_LIST _uBits)
                list(REMOVE_ITEM _uBits OPTIONAL)
            elseif (REQUIRED IN_LIST _uBits AND OPTIONAL IN_LIST _rBits)
                list(REMOVE_ITEM _sBits OPTIONAL)
            endif ()
            list(APPEND _sBits ${_sBits})
            list(REMOVE_DUPLICATES _sBits)
            string(JOIN "&" _bits ${_sBits})
            string(REPLACE "&&" "&" _bits "${_bits}")
            string(REPLACE "&-" "&" _bits "${_bits}")

            list(REMOVE_AT wip ${FIXArgs})
            list(INSERT    wip ${FIXArgs} "${_bits}")
        endif ()

        # Step 3. Merge Components (FIND_PACKAGE_ARGS COMPONENTS checked later)
        list(GET _uFeature ${FIXComponents} _uBits)
        list(GET _sFeature ${FIXComponents} _sBits)
        if (NOT "${_uBits}" STREQUAL "${_sBits}")
            string(REPLACE "&" ";" _uBits "${_uBits}")
            string(REPLACE "&" ";" _sBits "${_sBits}")
            list(APPEND _sBits ${_uBits})
            list(REMOVE_DUPLICATES _sBits)
            string(JOIN "&" _bits ${_sBits})
            list(REMOVE_AT wip ${FIXComponents})
            list(INSERT    wip ${FIXComponents} "${_bits}")
        endif ()

        # Step 4. Remove prerequisites from libraries (they are not used at link time)
        list(GET wip ${FIXKind} kkk)
        if (kkk STREQUAL "LIBRARY")
            list(REMOVE_ITEM wip ${FIXPrereqs})
            list(INSERT      wip ${FIXPrereqs} "[[EMPTY_SENTINEL]]")
        endif ()

        INSERT(INTO hUnifiedFeatures VALUES ${wip})
    endwhile ()
    unset(featureName)





    # ensure the caller is using the system libraries




    SELECT(* FROM hGlobal WHERE KEY = "key_SystemFeatures" INTO hsf)
    SELECT(COUNT FROM hsf INTO numFeatureNames)

    set(featureIndex 0)
    while (featureIndex LESS numFeatureNames)
        set(haveIt OFF)

        SELECT(VALUE FROM hsf WHERE ROWID = ${featureIndex} AND COLUMN = "Name" INTO hsf_Feature)
        SELECT(VALUE FROM hsf WHERE ROWID = ${featureIndex} AND COLUMN = "DfltPkg" INTO hsf_Package)
        SELECT(* FROM hGlobal WHERE KEY = "${hsf_Feature}" INTO hsf_featureData)
        SELECT(ROW FROM hsf_featureData WHERE COLUMN "FeatureName" = "${hsf_Feature}" AND COLUMN "PackageName" = "${hsf_Package}" INTO hsf_Pkg)

        # Is this exact package already in the user's list?

        SELECT(VALUE FROM hUnifiedFeatures WHERE COLUMN = "FeatureName" AND COLUMN "FeatureName" = "${hsf_Feature}" AND COLUMN "PackageName" = "${hsf_Package}" INTO it_exists)
        if(it_exists)
            # Don't add it
        else ()
            INSERT(INTO hUnifiedFeatures VALUES ${hsf_Pkg})
        endif ()

        math(EXPR featureIndex "${featureIndex} + 1")
    endwhile ()
    ##
    ##########
    ##
    msg(" ")

    if (APP_DEBUG)
        DUMP(FROM hUnifiedFeatures VERBOSE INTO captur)
        set(captur "After tampering\n${captur}")
        msg("${captur}")
    endif ()

    # Re-order unifiedFeatureList based on prerequisites (Topological Sort)
    resolveDependencies(hUnifiedFeatures resolvedNames)

    if (APP_DEBUG)
        DUMP(FROM hUnifiedFeatures VERBOSE INTO captur)
        set(captur "After resolution\n${captur}")
        msg("${captur}")
    endif ()

    ####################################################################################################################
    ####################################################################################################################
    ################################ T H E   R E A L   W O R K   B E G I N S   H E R E #################################
    ####################################################################################################################
    ####################################################################################################################
    ##
    ## Nested function. How fancy
    ##

    function(processFeatures features featureList)

        unset(removeFromDependencies)

        cmake_parse_arguments("apf" "IS_A_PREREQ" "" "" ${ARGN})

        # Two-Pass Strategy:
        # Pass 0: Declare all FetchContents, handle PROCESS and FIND_PACKAGE (Metadata stage)
        # Pass 1: MakeAvailable and perform post-population fixes (Build stage)

        set(fix 0)
        set(lFName 0)
        set(lPName 0)
        set(prereqs)
        set(feature_names "${features}")
        record(LENGTH features numFeatures)
        while (fix LESS numFeatures)
            record(GET features ${fix} c)
            SplitAt("${c}" "/" x p)
            SplitAt("${x}" "." f g)
            set(jfp "${f}/${p}")
            longest(QUIET CURRENT ${lFName} TEXT "${f}" LONGEST lFName)
            longest(QUIET CURRENT ${lPName} TEXT "(${p})" LONGEST lPName)
            if (g)
                list(APPEND prereqs "${jfp}")
                record(REPLACE feature_names ${fix} "${jfp}")
            endif ()
            string(JOIN ", " l ${l} "${YELLOW}${f}${NC} (${GREEN}${p}${NC})")
            inc(fix)
        endwhile ()

        set(features "${feature_names}")

        message(CHECK_START "\n${BOLD}Processing ${numFeatures} features${NC} ${l}")
        list(APPEND CMAKE_MESSAGE_INDENT "\t")

        unset(combinedLibraryComponents)
        set(scannedLibraries)

        foreach (pass_num RANGE 1)
            string(REPEAT "-" 70 line)
            set(phase ${pass_num})
            inc(phase)
            message("\n ${GREEN}Phase ${phase} ${line}${NC}\n")

            set(ixloupe 0)
            while (ixloupe LESS numFeatures)
                set(ix ${ixloupe})
                inc(ixloupe)

                record(GET features ${ix} feature_package_combo)
                macro(unsetLocalVars)
                    unset(COMPONENTS_KEYWORD)
                    unset(OVERRIDE_FIND_PACKAGE_KEYWORD)
                    unset(pkg_details)
                    unset(this_build)
                    unset(this_feature_name)
                    unset(this_find_package_args)
                    unset(this_find_package_components)
                    unset(this_hint)
                    unset(this_inc)
                    unset(this_kind)
                    unset(this_method)
                    unset(this_namespace)
                    unset(this_namespace_package_components)
                    unset(this_out)
                    unset(this_pkglc)
                    unset(this_pkgname)
                    unset(this_pkgnameLength)
                    unset(this_pkguc)
                    unset(this_src)
                    unset(this_tag)
                    unset(this_url)
                endmacro()

                unsetLocalVars()

                # See if this is a prerequisite package. If it is, we do both phases together
                SplitAt(${feature_package_combo} "/" this_feature_name this_pkgname)
                if ("${feature_package_combo}" IN_LIST prereqs)
                    set(apf_IS_A_PREREQ ON)
                endif ()

                parsePackage(featureList
                        FEATURE ${this_feature_name}
                        PACKAGE ${this_pkgname}
                        ARGS this_find_package_args
                        BUILD_DIR this_build
                        COMPONENTS this_find_package_components
                        FETCH_FLAG this_fetch
                        GIT_TAG this_tag
                        INC_DIR this_inc
                        KIND this_kind
                        METHOD this_method
                        NAMESPACE this_namespace
                        OUTPUT pkg_details
                        PREREQS this_prereqs
                        SRC_DIR this_src
                        URL this_url
                )

                string(TOLOWER "${this_pkgname}" this_pkglc)
                string(TOUPPER "${this_pkgname}" this_pkguc)

                # ==========================================================================================================
                # PASS 0: DECLARATION & FIND_PACKAGE phase
                # ==========================================================================================================
                if (${pass_num} EQUAL 0)

                    longest(RIGHT CURRENT ${lFName} TEXT "${this_feature_name}" LONGEST lFName PADDED dispFeatureName)
                    longest(LEFT CURRENT ${lPName} TEXT "(${this_pkgname})" LONGEST longestPackageName PADDED dispPackageName)
                    message(CHECK_START "${YELLOW}${dispFeatureName}${NC} ${GREEN}${dispPackageName}${NC} ${MAGENTA}Phase ${NC}${BOLD}1${NC}")
                    message(" ")
                    list(APPEND CMAKE_MESSAGE_INDENT "\t")

                    if (this_pkgname IN_LIST combinedLibraryComponents)
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(CHECK_PASS "Feature already available without re-processing: skipped")
                        continue()
                    endif ()
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
                            if (${this_pkgname}_ALREADY_FOUND OR TARGET ${this_pkgname}::${this_pkgname} OR TARGET ${this_pkgname})
                                message(STATUS "${this_pkgname} already supplied by a library target. Skipping FetchContent.")
                                unset(magic_enum_ALREADY_FOUND CACHE)
                                unset(magic_enum_ALREADY_FOUND)
                                unset(magic_enum_ALREADY_FOUND CACHE)
                                #                                set(${this_pkgname}_ALREADY_FOUND ON CACHE  INTERNAL "" FORCE)
                                list(APPEND removeFromDependencies "${this_feature_name}" "${this_package}")
                                set(fn "${this_pkgname}_postDeclare")
                                if (COMMAND "${fn}")
                                    cmake_language(CALL "${fn}" "${this_pkgname}")
                                endif ()
                            else ()
                                # Try to find the package first before declaring FetchContent
                                # This allows Gfx to see what HoffSoft already fetched/built
                                message(STATUS "Checking if ${BOLD}${this_pkgname}${NC} is already available via find_package...")
                                set(temporary_args ${this_find_package_args})
                                list(REMOVE_ITEM temporary_args REQUIRED EXCLUDE_FROM_ALL FIND_PACKAGE_ARGS)
                                find_package(${this_pkgname} QUIET ${temporary_args})

                                if (${this_pkgname}_FOUND OR TARGET ${this_pkgname}::${this_pkgname} OR TARGET ${this_pkgname})
                                    message(STATUS "${this_pkgname} ${GREEN}found.${NC} Skipping FetchContent.\n")
                                    # TODO:                                    set(${this_pkgname}_ALREADY_FOUND ON CACHE  INTERNAL "" FORCE)
                                else ()
                                    message(STATUS "${MAGENTA}Nope!${NC} Doing it the hard way...")
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
                            # 1. Is the library already available? (Probe it)
                            set(temporary_args ${this_find_package_args})
                            list(REMOVE_ITEM temporary_args REQUIRED FIND_PACKAGE_ARGS CONFIG)
                            find_package(${this_pkgname} QUIET ${temporary_args})

                            if (${this_pkgname}_FOUND)
                                # Library exists! Scan it to see what 3rd-party targets it supplies
                                scanLibraryTargets("${this_pkgname}" "${features}" "${featureList}")
                                list(APPEND combinedLibraryComponents ${${this_pkgname}_COMPONENTS})
                            else ()
                                # Library not found yet. We must fulfill its metadata prerequisites
                                # so that we can eventually load it.
                                if (this_prereqs)
                                    array(CREATE needed_prereqs "${this_pkgname}Prerequisites" RECORDS)
                                    record(CREATE needed_prereqFeatureNames "${this_pkgname}PrerequisiteNames")
                                    foreach (p IN LISTS this_prereqs)
                                        SplitAt("${p}" "=" preFeatName prePkgName)
                                        if (prePkg)
                                            getFeaturePackageByName("${DATA}" "${preFeatName}" "${prePkgName}" prePkg dc)
                                        else ()
                                            getFeaturePackageBy("${DATA}" "${preFeatName}" 0 prePkg)
                                        endif ()
                                        array(APPEND needed_prereqs RECORD "${prePkg}")
                                        record(APPEND needed_prereqFeatureNames "${p}")
                                    endforeach ()

                                    message(STATUS "Library ${this_pkgname} not found. Processing metadata prerequisites: ${needed_prereqs}")
                                    processFeatures("${needed_prereqFeatureNames}" "${needed_prereqs}")
                                endif ()
                            endif ()
                            #                            endif ()
                            # 2. Now attempt the real find_package
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

                                # Now that the library is found, scan it for transitives
                                if ("${this_kind}" STREQUAL "LIBRARY")
                                    scanLibraryTargets("${this_pkgname}" "${features}" "${DATA}")
                                    list(APPEND combinedLibraryComponents ${${this_pkgname}_COMPONENTS})
                                endif ()
                            endif ()
                        endif ()
                    endif ()

                    list(POP_BACK CMAKE_MESSAGE_INDENT)
                    message(" ")
                    message(CHECK_PASS "${GREEN}Finished${NC}")

                endif ()

                # ==========================================================================================================
                # PASS 1: POPULATION & FIX phase
                # ==========================================================================================================

                if (${pass_num} EQUAL 1 OR apf_IS_A_PREREQ)

                    longest(RIGHT CURRENT ${lFName} TEXT "${this_feature_name}" LONGEST lFName PADDED dispFeatureName)
                    longest(LEFT CURRENT ${lPName} TEXT "(${this_pkgname})" LONGEST longestPackageName PADDED dispPackageName)
                    message(CHECK_START "${YELLOW}${dispFeatureName}${NC} ${GREEN}${dispPackageName}${NC} ${BLUE}Phase ${NC}${BOLD}2${NC}")
                    message(" ")

                    list(APPEND CMAKE_MESSAGE_INDENT "\t")

                    if (${this_package}_PASS_TWO_COMPLETED)
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(" ")
                        message(CHECK_PASS "(already been done)")
                    else ()
                        if (apf_IS_A_PREREQ)
                            set(${this_package}_PASS_TWO_COMPLETED ON)
                        endif ()

                        if (this_pkgname IN_LIST combinedLibraryComponents)
                            list(POP_BACK CMAKE_MESSAGE_INDENT)
                            message(CHECK_PASS "Feature already available without re-processing: skipped")
                            continue()
                        endif ()

                        if ("${this_method}" STREQUAL "FIND_PACKAGE")
                            if (NOT TARGET ${this_namespace}::${this_pkgname})
                                handleTarget(${this_pkgname})
                            endif ()
                        elseif ("${this_method}" STREQUAL "FETCH_CONTENTS" AND this_fetch)

                            if (NOT this_src)
                                if (EXISTS "${EXTERNALS_DIR}/${this_pkgname}")
                                    set(this_src "${EXTERNALS_DIR}/${this_pkgname}")
                                endif ()
                            endif ()
                            if (NOT this_build)
                                if (EXISTS "${BUILD_DIR}/${this_pkglc}-build")
                                    set(this_build "${BUILD_DIR}/${this_pkglc}-build")
                                endif ()
                            endif ()

                            if (NOT ${this_pkgname}_ALREADY_FOUND)
                                set(fn "${this_pkgname}_preMakeAvailable")
                                set(HANDLED OFF)
                                if (COMMAND "${fn}")
                                    cmake_language(CALL "${fn}" "${this_pkgname}")
                                endif ()

                                if (NOT HANDLED AND NOT ${this_feature_name} STREQUAL TESTING)
                                    message(STATUS "\nFetchContent_MakeAvailable(${this_pkgname})")
                                    FetchContent_MakeAvailable(${this_pkgname})
                                    handleTarget(${this_pkgname})
                                endif ()
                            else ()
                                message(" ")
                                message(STATUS "${this_pkgname} already found, skipping population.")
                                #                                handleTarget(${this_pkgname})
                            endif ()

                            set(fn "${this_pkgname}_postMakeAvailable")
                            if (COMMAND "${fn}")
                                cmake_language(CALL "${fn}" "${this_src}" "${this_build}" "${OUTPUT_DIR}" "${BUILD_TYPE_LC}")
                            endif ()

                            # Auto-include the standard 'include' folder if it exists and wasn't handled
                            if (EXISTS "${this_src}/include")
                                list(APPEND _IncludePathsList "${this_src}/include")
                            endif ()
                        else ()
                            message(" ")
                            message("No Phase 2 step")
                        endif ()

                        # Final patching/fixing phase
                        set(fn "${this_pkgname}_fix")
                        if (COMMAND "${fn}")
                            cmake_language(CALL "${fn}" "${this_pkgname}" "${this_tag}" "${EXTERNALS_DIR}/${this_pkgname}")
                        elseif (NOT ${this_pkgname}_PATCHED AND EXISTS "${CMAKE_SOURCE_DIR}/cmake/patches/${this_pkgname}")
                            unset(patches)
                            list(APPEND patches "${this_pkgname}|${EXTERNALS_DIR}/${this_pkgname}")
                            replaceFile("${this_pkgname}" ${patches})
                        endif ()

                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(" ")
                        message(CHECK_PASS "${GREEN}Finished${NC}")

                    endif ()
                endif ()

                inc(ix)

            endwhile () # this_feature_name
        endforeach () # pass_num
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "${GREEN}OK${NC}\n")

        propegateUpwards("Interim" OFF)

    endfunction()

    processFeatures("${resolvedNames}" "${unifiedFeatureList}")
    propegateUpwards("Finally" ON)
endfunction()

macro(propegateUpwards whereWeAre REPORT)

    # @formatter:off
    list(APPEND ${AUE_PREFIX}_CompileOptionsList ${_CompileOptionsList} ${${AUE_PREFIX}_CompileOptionsList})
    list(APPEND ${AUE_PREFIX}_DefinesList        ${_DefinesList}        ${${AUE_PREFIX}_DefinesList})
    list(APPEND ${AUE_PREFIX}_DependenciesList   ${_DependenciesList}   ${${AUE_PREFIX}_DependenciesList})

    list(REMOVE_ITEM ${AUE_PREFIX}_DependenciesList ${removeFromDependencies})

    list(APPEND ${AUE_PREFIX}_IncludePathsList   ${_IncludePathsList}   ${${AUE_PREFIX}_IncludePathsList})
    list(APPEND ${AUE_PREFIX}_LibrariesList      ${_LibrariesList}      ${${AUE_PREFIX}_LibrariesList})
    list(APPEND ${AUE_PREFIX}_LibraryPathsList   ${_LibraryPathsList}   ${${AUE_PREFIX}_LibraryPathsList})
    list(APPEND ${AUE_PREFIX}_LinkOptionsList    ${_LinkOptionsList}    ${${AUE_PREFIX}_LinkOptionsList})
    list(APPEND ${AUE_PREFIX}_PrefixPathsList    ${_PrefixPathsList}    ${${AUE_PREFIX}_PrefixPathsList})

    list(APPEND ${AUE_PREFIX}_wxCompilerOptions  ${_wxCompilerOptions}  ${${AUE_PREFIX}_wxCompilerOptions})
    list(APPEND ${AUE_PREFIX}_wxDefines          ${_wxDefines}          ${${AUE_PREFIX}_wxDefines})
    list(APPEND ${AUE_PREFIX}_wxIncludePaths     ${_wxIncludePaths}     ${${AUE_PREFIX}_wxIncludePaths})
    list(APPEND ${AUE_PREFIX}_wxLibraryPaths     ${_wxLibraryPaths}     ${${AUE_PREFIX}_wxLibraryPaths})
    list(APPEND ${AUE_PREFIX}_wxLibraries        ${_wxLibraries}        ${${AUE_PREFIX}_wxLibraries})
    list(APPEND ${AUE_PREFIX}_wxFrameworks       ${_wxFrameworks}       ${${AUE_PREFIX}_wxFrameworks})

    list(REMOVE_DUPLICATES ${AUE_PREFIX}_CompileOptionsList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_DefinesList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_DependenciesList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_IncludePathsList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_LibrariesList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_LibraryPathsList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_LinkOptionsList)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_PrefixPathsList)

    list(REMOVE_DUPLICATES ${AUE_PREFIX}_wxCompilerOptions)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_wxDefines)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_wxIncludePaths)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_wxLibraryPaths)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_wxLibraries)
    list(REMOVE_DUPLICATES ${AUE_PREFIX}_wxFrameworks)

    set(${AUE_PREFIX}_CompileOptionsList ${${AUE_PREFIX}_CompileOptionsList} PARENT_SCOPE)
    set(${AUE_PREFIX}_DefinesList        ${${AUE_PREFIX}_DefinesList}        PARENT_SCOPE)
    set(${AUE_PREFIX}_DependenciesList   ${${AUE_PREFIX}_DependenciesList}   PARENT_SCOPE)
    set(${AUE_PREFIX}_IncludePathsList   ${${AUE_PREFIX}_IncludePathsList}   PARENT_SCOPE)
    set(${AUE_PREFIX}_LibrariesList      ${${AUE_PREFIX}_LibrariesList}      PARENT_SCOPE)
    set(${AUE_PREFIX}_LibraryPathsList   ${${AUE_PREFIX}_LibraryPathsList}   PARENT_SCOPE)
    set(${AUE_PREFIX}_LinkOptionsList    ${${AUE_PREFIX}_LinkOptionsList}    PARENT_SCOPE)
    set(${AUE_PREFIX}_PrefixPathsList    ${${AUE_PREFIX}_PrefixPathsList}    PARENT_SCOPE)

    set(${AUE_PREFIX}_wxCompilerOptions  ${${AUE_PREFIX}_wxCompilerOptions}  PARENT_SCOPE)
    set(${AUE_PREFIX}_wxDefines          ${${AUE_PREFIX}_wxDefines}          PARENT_SCOPE)
    set(${AUE_PREFIX}_wxIncludePaths     ${${AUE_PREFIX}_wxIncludePaths}     PARENT_SCOPE)
    set(${AUE_PREFIX}_wxLibraryPaths     ${${AUE_PREFIX}_wxLibraryPaths}     PARENT_SCOPE)
    set(${AUE_PREFIX}_wxLibraries        ${${AUE_PREFIX}_wxLibraries}        PARENT_SCOPE)
    set(${AUE_PREFIX}_wxFrameworks       ${${AUE_PREFIX}_wxFrameworks}       PARENT_SCOPE)
    # @formatter:on

    if (REPORT)
        log(TITLE "${whereWeAre}" LISTS

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
    endif ()
endmacro()
