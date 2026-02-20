include(FetchContent)

include(${CMAKE_SOURCE_DIR}/cmake/fetchContentsFns.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/standardPackageData.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/sqlish.cmake)

macro(_initializeVars)

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

    list(APPEND pseudoFeatures APPEARANCE PRINT LOGGER)
    list(APPEND noLibPackages googletest)

endmacro()

########################################################################################################################
function(fetchContents)

    _initializeVars()

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

    CREATE(TABLE allFeatures     COLUMNS ( ${PkgColNames} ))
    CREATE(TABLE initialFeatures COLUMNS ( ${PkgColNames} ))
    CREATE(TABLE unifiedFeatures COLUMNS ( ${PkgColNames} ))
    CREATE(TABLE resolvedNames   COLUMNS (     FslashP    ))

    foreach(DRY_RUN IN ITEMS ON OFF)
        initialiseFeatureHandlers(${DRY_RUN})
        createStandardPackageData(${DRY_RUN})
        runPackageCallbacks(${DRY_RUN})
    endforeach ()

    preProcessFeatures("${AUE_FEATURES}" allFeatures userPackages)

    SELECT(COUNT AS numPackages FROM userPackages)

    set(aix 0)
    while (aix LESS numPackages)
        inc(aix)
        set(pkgIndex ${aix})

        DROP(HANDLE _uPackage)
        DROP(HANDLE _sPackage)

        # Get user's selected package
        SELECT(ROW AS _uPackage FROM userPackages WHERE ROWID = ${pkgIndex})

        list(GET _uPackage ${FIXName}    _uFeatureName)
        list(GET _uPackage ${FIXPkgName} _uPackageName)

        # Get corresponding system package
        SELECT(ROW AS _sPackage FROM allFeatures WHERE "FeatureName" = "${_uFeatureName}" AND "PackageName" = "${_uPackageName}")

        list(GET _sPackage ${FIXName}    _sFeatureName)
        list(GET _sPackage ${FIXPkgName} _sPackageName)
        list(GET _sPackage ${FIXKind}    _sKind)

        # Integrity check
        if (NOT _uFeatureName STREQUAL "${_sFeatureName}")
            msg(ALWAYS FATAL_ERROR "Internal error: FC01 - Feature name mismatch \"${_uFeatureName}\" vs \"${_sFeatureName}\"")
        endif ()
        if (NOT _uPackageName STREQUAL "${_sPackageName}")
            msg(ALWAYS FATAL_ERROR "Internal error: FC02 - Package name mismatch \"${_uPackageName}\" vs \"${_sPackageName}\"")
        endif ()

        if (_sKind STREQUAL "PLUGIN")
            # We don't search for plugins this way, but still advise downstream users it is needed/available
            list(APPEND _DefinesList USING_${_uPackageName})
            continue()
        endif ()

        # Where we manipulate the feature to be a union of the _uPackage requirements (if any)
        # and system requirements (if any)

        # If we are here, we have the users    feature and options in ${_uPackage}
        # and we have the corresponding system feature and options in ${_sPackage}
        # The merged feature will be in ${wip}

        set(wip "${_sPackage}")
        unset(_uPkg)
        unset(_sPkg)
        unset(_uBits)
        unset(_sBits)
        unset(_bits)

        # Step 1. Merge Args
        list(GET _uPackage ${FIXArgs} _uBits)
        list(GET _sPackage ${FIXArgs} _sBits)
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

        # Step 2. Merge Components (FIND_PACKAGE_ARGS COMPONENTS checked later)
        list(GET _uPackage ${FIXComponents} _uBits)
        list(GET _sPackage ${FIXComponents} _sBits)
        if (NOT "${_uBits}" STREQUAL "${_sBits}")
            string(REPLACE "&" ";" _uBits "${_uBits}")
            string(REPLACE "&" ";" _sBits "${_sBits}")
            list(APPEND _sBits ${_uBits})
            list(REMOVE_DUPLICATES _sBits)
            string(JOIN "&" _bits ${_sBits})
            list(REMOVE_AT wip ${FIXComponents})
            list(INSERT    wip ${FIXComponents} "${_bits}")
        endif ()

        # Step 3. Remove prerequisites from libraries (they are not used at link time)
        list(GET wip ${FIXKind} kkk)
        if (kkk STREQUAL "LIBRARY")
            list(REMOVE_ITEM wip ${FIXPrereqs})
            list(INSERT      wip ${FIXPrereqs} "[[EMPTY_SENTINEL]]")
        endif ()

        _hs_sql_fields_to_storage(wip whip)
        INSERT(INTO initialFeatures VALUES (${whip}))

    endwhile ()
    unset(featureName)

    # ensure the caller is using the system libraries

    ####################################################################################################################
    function(_addPackages _rowID)
        set(haveIt OFF)

        SELECT(ROW AS hsf_SysPkg FROM systemPackagesOnly WHERE ROWID = ${_rowID})
        list(GET hsf_SysPkg ${FIXName}    sys_Feature)
        list(GET hsf_SysPkg ${FIXPkgName} sys_Package)

        SELECT(COUNT AS numUserPackages FROM userPackages)

        set(featureIndex 0)
        while (featureIndex LESS numUserPackages)
            math(EXPR featureIndex "${featureIndex} + 1")
            set(thisIndex ${featureIndex})
            set(haveIt OFF)

            SELECT(ROW AS hsf_UsrPkg FROM userPackages WHERE ROWID = ${thisIndex})
            if(hsf_UsrPkg)
                list(GET hsf_UsrPkg ${FIXName}    usr_Feature)
                list(GET hsf_UsrPkg ${FIXPkgName} usr_Package)

                # Is this exact package already in the user's list?

                if (usr_Feature STREQUAL ${sys_Feature} AND usr_Package STREQUAL ${sys_Package})
                    set(haveIt ON)
                endif ()
            endif ()

            if(NOT haveIt)
                _hs_sql_fields_to_storage(hsf_SysPkg _encodedPkg)
                INSERT(INTO initialFeatures VALUES (${_encodedPkg}))
            endif ()
        endwhile ()
    endfunction()
    ####################################################################################################################
    SELECT(* AS systemPackagesOnly FROM allFeatures WHERE "Kind" = "SYSTEM" AND "IsDefault" = 1)
    SQL_FOREACH(ROW IN systemPackagesOnly CALL _addPackages)

    # Re-order unifiedFeatureList based on prerequisites (Topological Sort)
    resolveDependencies(allFeatures initialFeatures unifiedFeatures resolvedNames)

    ####################################################################################################################
    ####################################################################################################################
    ################################ T H E   R E A L   W O R K   B E G I N S   H E R E #################################
    ####################################################################################################################
    ####################################################################################################################
    ##
    ## Nested function. How fancy
    ##

    function(processFeatures features feature_names)

        unset(removeFromDependencies)

        cmake_parse_arguments("apf" "IS_A_PREREQ" "" "" ${ARGN})

        # Two-Pass Strategy:
        # Pass 0: Declare all FetchContents, handle PROCESS and FIND_PACKAGE (Metadata stage)
        # Pass 1: MakeAvailable and perform post-population fixes (Build stage)

        set(fix 0)
        set(lFName 0)
        set(lPName 0)
        set(prereqs)
        SELECT(COUNT AS numFeatures FROM ${feature_names} )

        while (fix LESS numFeatures)
            inc(fix)
            set(row_id ${fix})

            SELECT(ROW AS c FROM ${feature_names} WHERE ROWID = ${row_id})
            SplitAt("${c}" "/" x p)
            SplitAt("${x}" "." f g)
            set(jfp "${f}/${p}")
            longest(QUIET CURRENT ${lFName} TEXT  "${f}"  LONGEST lFName)
            longest(QUIET CURRENT ${lPName} TEXT "(${p})" LONGEST lPName)

            if (g)
                list(APPEND prereqs "${jfp}")
                UPDATE(${feature_names} SET FslashP = "${f}/${p}" WHERE ROWID = ${row_id})
            endif ()
            string(JOIN ", " l ${l} "${YELLOW}${f}${NC} (${GREEN}${p}${NC})")
        endwhile ()

        msg(CHECK_START "\n${BOLD}Processing ${numFeatures} features${NC} ${l}")
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
                inc(ixloupe)
                set(ix ${ixloupe})

                SELECT(FslashP AS pair FROM ${feature_names} WHERE ROWID = ${ix})

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
                SplitAt(${pair} "/" this_feature_name this_pkgname)
                if ("${pair}" IN_LIST prereqs)
                    set(apf_IS_A_PREREQ ON)
                endif ()

                parsePackage(features
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

                    longest(RIGHT CURRENT ${lFName} TEXT "${this_feature_name}" LONGEST lFName              PADDED dispFeatureName)
                    longest(LEFT  CURRENT ${lPName} TEXT "(${this_pkgname})"    LONGEST longestPackageName  PADDED dispPackageName)
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
                                scanLibraryTargets("${features}" "${this_pkgname}" "${feature_names}")
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
                                    scanLibraryTargets("${DATA}" "${this_pkgname}" "${feature_names}")
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

    processFeatures(unifiedFeatures resolvedNames )
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
