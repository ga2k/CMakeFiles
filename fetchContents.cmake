include(FetchContent)

include(${CMAKE_SOURCE_DIR}/cmake/fetchContentsFns.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/standardPackageData.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/array_enhanced.cmake)

set(SystemFeatureData)
set(UserFeatureData)

########################################################################################################################
function(fetchContents)

    record(CREATE featureNames NAMES)
    collection(CREATE FEATURES)
    collection(SET FEATURES NAMES    "${featureNames}")
    record(CREATE featurePackages PACKAGES)
    collection(SET FEATURES PACKAGES "${featurePackages}")

    record(CREATE systemNames NAMES)
    collection(CREATE SYSTEM_FEATURES)
    collection(SET SYSTEM_FEATURES NAMES    "${systemNames}")
    record(CREATE systemPackages PACKAGES)
    collection(SET SYSTEM_FEATURES PACKAGES "${systemPackages}")

    record(CREATE libraryNames NAMES)
    collection(CREATE LIBRARY_FEATURES)
    collection(SET LIBRARY_FEATURES NAMES    "${libraryNames}")
    record(CREATE libraryPackages PACKAGES)
    collection(SET LIBRARY_FEATURES PACKAGES "${libraryPackages}")

    record(CREATE optionalNames NAMES)
    collection(CREATE OPTIONAL_FEATURES)
    collection(SET OPTIONAL_FEATURES NAMES    "${optionalNames}")
    record(CREATE optionalPackages PACKAGES)
    collection(SET OPTIONAL_FEATURES PACKAGES "${optionalPackages}")

    collection(DUMP FEATURES VERBOSE)
    createStandardPackageData()
    collection(DUMP FEATURES VERBOSE)

    set(options HELP)
    set(oneValueArgs PREFIX)
    set(multiValueArgs FEATURES)
    # NOT has precedence over USE

    cmake_parse_arguments(AUE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if (AUE_HELP)
        fetchContentsHelp()
        return()
    endif ()
    if (AUE_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments passed to fetchContents() : ${AUE_UNPARSED_ARGUMENTS}")
    endif ()

    log(TITLE "Before tampering " LISTS AUE_FEATURES)

    processFeatures("${AUE_FEATURES}" AUE_USE)

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

    unset(unifiedFeatureList)
    array(CREATE unifiedFeatureList unifiedFeatureList RECORDS)
    # We don't search for pseudo packages
    array(LENGTH AUE_USE numPackages)
    array(DUMP AUE_USE VERBOSE)
    if(numPackages)
        foreach(pkgIndex RANGE ${numPackages})
            if(pkgIndex EQUAL numPackages)
                break()
            endif ()
            array(GET AUE_USE ${pkgIndex} requestedFeature)
            record(DUMP requestedFeature)
            # Where we manipulate the feature to be a union of the requestedFeature requirements (if any)
            # and system requirements (if any)
            set(potentialFeature)
            record(GET requestedFeature ${FIXName} featureName packageName)
            if ("${featureName}" IN_LIST PseudoFeatures)
                # We don't search for plugins this way
                list(APPEND _DefinesList USING_${featureName})
                continue()
            elseif (${featureName} IN_LIST SYSTEM_NAMES) # OR ${featureName} IN_LIST LIBRARY_NAMES)
                # We don't search for system packages this way, but we might ADD a package variant (if one exists)
                if (packageName)
                    getFeaturePackageByName(FEATURES ${featureName} ${packageName} potentialFeature index)
                    if (index)
                        if (index STREQUAL "SYSTEM")
                            msg(ALWAYS "Redundant addition of System feature ${featureName} ignored")
                            continue()
                        endif ()
                        set(potentialFeature "${featureName}|${potentialFeature}")
                    else ()
                        msg(ALWAYS FATAL_ERROR "FEATURE ${featureName} has no package called ${packageName}")
                        continue()
                    endif ()
                else ()
                    msg(ALWAYS "Redundant addition of System feature ${featureName} ignored")
                    continue()
                endif ()
            else ()
                if(NOT "${packageName}" STREQUAL "")
                    getFeaturePackageByName(FEATURES ${featureName} ${packageName} potentialFeature index)
                    if (NOT potentialFeature)
                        msg(ALWAYS FATAL_ERROR "FEATURE ${featureName} has no package called ${packageName}")
                        continue()
                    elseif (DEFINED index AND index EQUAL "SYSTEM")
                        msg(ALWAYS "Redundant addition of System feature ${featureName} ignored")
                        continue()
                    endif ()
                else ()
                    set(index 0)
                    getFeaturePackage(FEATURES ${featureName} ${index} potentialFeature)
                    if(potentialFeature)
                        record(GET potentialFeature ${FIXPkgName} packageName)
                    endif ()
                endif ()
                if (NOT potentialFeature)
                    msg(ALWAYS FATAL_ERROR "FEATURE ${featureName} is not available")
                endif ()
            endif ()

            # If we are here, we have the users feature and options in ${requestedFeature}
            # and the corresponding registered  feature and options in ${potentialFeature}
            # The merged feature will be in ${wip}

            set (wip "${potentialFeature}")
            unset(_uPkg)
            unset(_rPkg)
            unset(_userBits)
            unset(_regdBits)
            unset(_bits)

            # Step 1. Sanity check the set pkgname
            record(GET requestedFeature ${FIXName} _uPkg TOUPPER)
            record(GET potentialFeature ${FIXName} _rPkg TOUPPER)

            if (NOT "${_uPkg}" STREQUAL "" AND NOT "${_uPkg}" STREQUAL "${_rPkg}")
                msg(ALWAYS FATAL_ERROR "Internal error: FC01 - Package name mismatch")
            endif ()

            # Step 2. Merge Args
            record(GET requestedFeature ${FIXArgs} _userBits)
            record(GET potentialFeature ${FIXArgs} _regdBits)
            if("${_userBits}" STREQUAL "${_regdBits}")
                continue()
            endif ()
            string(REPLACE ":" ";" _userBits "${_userBits}")
            string(REPLACE ":" ";" _regdBits "${_regdBits}")
            if (REQUIRED IN_LIST _regdBits AND OPTIONAL IN_LIST _userBits)
                list(REMOVE_ITEM _userBits OPTIONAL)
            elseif (REQUIRED IN_LIST _userBits AND OPTIONAL IN_LIST _regdBits)
                list(REMOVE_ITEM _regdBits OPTIONAL)
            endif ()
            list(APPEND _regdBits ${_userBits})
            list(REMOVE_DUPLICATES _regdBits)
            string(JOIN ":" _bits ${_regdBits})
            string(REPLACE "::" ":" _bits "${_bits}")
            string(REPLACE ":-" ":" _bits "${_bits}")
            record(CONVERT wip)
            math(EXPR adjusted "${FIXArgs} + 2")
            list(REMOVE_AT wip ${adjusted})
            list(INSERT wip ${adjusted} "${_bits}")
            record(CONVERT wip)

            # Step 3. Merge Components (FIND_PACKAGE_ARGS COMPONENTS checked later)
            record(GET requestedFeature ${FIXComponents} _userBits)
            record(GET potentialFeature ${FIXComponents} _regdBits)
            if(NOT "${_userBits}" STREQUAL "${_regdBits}")
                string(REPLACE ":" ";" _userBits "${_userBits}")
                string(REPLACE ":" ";" _regdBits "${_regdBits}")
                list(APPEND _regdBits ${_userBits})
                list(REMOVE_DUPLICATES _regdBits)
                string(JOIN ":" _bits ${_regdBits})
                record(REPLACE wip ${FIXComponents} "${_bits}")
            endif ()

            array(APPEND unifiedFeatureList RECORD "${wip}")

        endforeach ()
    endif ()
    unset(featureName)

    # ensure the caller is using the system libraries
    collection(GET SYSTEM_FEATURES "NAMES" featureNames)
    record(LENGTH featureNames numFeatureNames)
    set(featureIndex 0)
    while(featureIndex LESS numFeatureNames)
        array(DUMP unifiedFeatureList)
        set(haveIt OFF)
        record(GET featureNames ${featureIndex} thisFeatureName)
        collection(GET SYSTEM_FEATURES "EQUAL" "${thisFeatureName}" thisFeature)
        array(GET thisFeature 0 defaultPackage)
        record(GET defaultPackage 0 defFeature defPkg)
        # Is this exact package already in the user's list?
        array(GET unifiedFeatureList EQUAL "${defPkg}" maybePackage)
        if(maybePackage)
            record(GET maybePackage 0 maybeFeature maybePkg)
            if(NOT (maybeFeature STREQUAL defFeature AND maybePkg STREQUAL defPkg))
                array(PREPEND unifiedFeatureList RECORD "${defaultPackage}")
            endif ()
        else ()
            array(PREPEND unifiedFeatureList RECORD "${defaultPackage}")
        endif ()
        math(EXPR featureIndex "${featureIndex} + 1")
    endwhile ()
    ##
    ##########
    ##
    msg(" ")

    if (APP_DEBUG)
        array(DUMP unifiedFeatureList captur)
        set(captur "After tampering\n${captur}")
        msg("${captur}")
    endif ()

    # Re-order unifiedFeatureList based on prerequisites (Topological Sort)
    resolveDependencies(unifiedFeatureList FEATURES resolvedFeatures resolvedNames)

    if (APP_DEBUG)
        array(DUMP unifiedFeatureList captur)
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
        list(LENGTH features numFeatures)
        while(fix LESS numFeatures)
            list(GET features ${fix} c)
            SplitAt("${c}" "." x g)
#            if ("${g}" STREQUAL "*")
#                set(apf_IS_A_PREREQ ON)
#            endif ()

            array(GET featureList ${fix} k)
            record(GET k ${FIXName} f n)
            string(JOIN ", " l ${l} "${YELLOW}${f}${NC} (${GREEN}${n}${NC})")
            inc(fix)
        endwhile ()

        message(CHECK_START "\n${BOLD}Processing features${NC} ${l}")
        list(APPEND CMAKE_MESSAGE_INDENT "\t")

        unset(combinedLibraryComponents)

        foreach (pass_num RANGE 1)
            message("${GREEN}\n-------------------------------------------------------------------------------\n${NC}")
            foreach (featureName IN LISTS features)
#                getFeaturePackage(featureList ${featureName} 0 package)
#                record(GET package ${FeatureNameIX} this_package)
#                # Skip features already found/aliased, but only check this in the final pass
#                # to allow declarations to overlap if necessary.
##                if (${pass_num} EQUAL 1)
#                    if (TARGET ${this_package} OR TARGET ${this_package}::${this_package} OR ${this_package}_FOUND OR ${this_package}_ALREADY_FOUND)
#                        list(POP_BACK CMAKE_MESSAGE_INDENT)
#                        message(CHECK_PASS "Feature already available without re-processing: skipped")
#                        list(APPEND removeFromDependencies "${featureName}" "${this_package}")
#                        continue()
#                    endif ()
##                endif ()

                macro(unsetLocalVars)
                    unset(COMPONENTS_KEYWORD)
                    unset(OVERRIDE_FIND_PACKAGE_KEYWORD)
                    unset(pkg_details)
                    unset(this_build)
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

                # See if this is a prereqisuite package. If it is, we do both phases together
                SplitAt(${featureName} "." featureName flagChar)
                if ("${flagChar}" STREQUAL "*")
                    set(apf_IS_A_PREREQ ON)
                endif ()

                parsePackage(featureList
                        FEATURE     ${featureName}
                        PKG_INDEX   0
                        ARGS        this_find_package_args
                        BUILD_DIR   this_build
                        COMPONENTS  this_find_package_components
                        FETCH_FLAG  this_fetch
                        GIT_TAG     this_tag
                        INC_DIR     this_inc
                        KIND        this_kind
                        METHOD      this_method
                        NAME        this_pkgname
                        NAMESPACE   this_namespace
                        OUTPUT      pkg_details
                        PREREQS     this_prereqs
                        SRC_DIR     this_src
                        URL         this_url
                )

                string(TOLOWER "${this_pkgname}" this_pkglc)
                string(TOUPPER "${this_pkgname}" this_pkguc)

                # ==========================================================================================================
                # PASS 0: DECLARATION & FIND_PACKAGE phase
                # ==========================================================================================================
                if (${pass_num} EQUAL 0)

                    string(LENGTH "${featureName}" this_featurenameLength)
                    math(EXPR paddingChars "${longestFeatureName} - ${this_featurenameLength}")
                    string(REPEAT " " ${paddingChars} fpadding )

                    string(LENGTH "${this_pkgname}" this_pkgnameLength)
                    math(EXPR paddingChars "${longestPkgName} - ${this_pkgnameLength} + 3")
                    string(REPEAT "." ${paddingChars} ppadding )
                    message(CHECK_START "${YELLOW}${fpadding}${featureName}${NC} (${GREEN}${this_pkgname}${NC}) ${ppadding} ${MAGENTA}Phase ${NC}${BOLD}1${NC}")
                    message(" ")
                    list(APPEND CMAKE_MESSAGE_INDENT "\t")

                    if(${this_pkgname} IN_LIST combinedLibraryComponents)
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(CHECK_PASS "Feature already available without re-processing: skipped")
                        # Pre-download hooks (mostly for setting variables/policies)
                        set(fn "${this_pkgname}_preDownload")
                        if (COMMAND "${fn}")
                            cmake_language(CALL "${fn}" "${this_pkgname}" "${this_url}" "${this_tag}" "${this_src}")
                        endif ()
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
#                                set(${this_pkgname}_ALREADY_FOUND ON CACHE INTERNAL "")
                                list(APPEND removeFromDependencies "${featureName}" "${this_package}")
                                set(fn "${this_pkgname}_postDeclare")
                                if (COMMAND "${fn}")
                                    cmake_language(CALL "${fn}" "${this_pkgname}")
                                endif ()
                            else()
                                # Try to find the package first before declaring FetchContent
                                # This allows Gfx to see what HoffSoft already fetched/built
                                message(STATUS "Checking if ${this_pkgname} is already available via find_package...")
                                set(temporary_args ${this_find_package_args})
                                list(REMOVE_ITEM temporary_args REQUIRED EXCLUDE_FROM_ALL)
                                find_package(${this_pkgname} QUIET ${temporary_args})

                                if(${this_pkgname}_FOUND OR TARGET ${this_pkgname}::${this_pkgname} OR TARGET ${this_pkgname})
                                    message(STATUS "${this_pkgname} found. Skipping FetchContent.\n")
# TODO:                                    set(${this_pkgname}_ALREADY_FOUND ON CACHE INTERNAL "")
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
                            # 1. Is the library already available? (Probe it)
                            set(temporary_args ${this_find_package_args})
                            list(REMOVE_ITEM temporary_args REQUIRED CONFIG)
                            find_package(${this_pkgname} QUIET ${temporary_args})

                            if (${this_pkgname}_FOUND)
                                # Library exists! Scan it to see what 3rd-party targets it supplies
                                scanLibraryTargets("${this_pkgname}" "${AllPackageData}")
                                list(APPEND combinedLibraryComponents ${${this_pkgname}_COMPONENTS})
                            else()
                                # Library not found yet. We must fulfill its metadata prerequisites
                                # so that we can eventually load it.
                                if (this_prereqs)
                                    set(needed_prereqs)
                                    foreach(p IN LISTS this_prereqs)
                                        foreach(e IN LISTS unifiedFeatureList)
                                            if(e MATCHES "^${p}\\.")
                                                list(APPEND needed_prereqs "${e}")
                                                break()
                                            endif()
                                        endforeach()
                                    endforeach()

                                    if (needed_prereqs)
                                        message(STATUS "Library ${this_pkgname} not found. Processing metadata prerequisites: ${needed_prereqs}")
                                        processFeatures("${needed_prereqs}")
                                    endif()
                                endif()
                            endif()

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
                                    scanLibraryTargets("${this_pkgname}" "${AllPackageData}")
                                    list(APPEND combinedLibraryComponents ${${this_pkgname}_COMPONENTS})
                                endif()
                            endif ()
                        endif ()
                    endif ()

                    list(POP_BACK CMAKE_MESSAGE_INDENT)
                    message( " " )
                    message(CHECK_PASS "${GREEN}Finished${NC}")

                endif ()

                    # ==========================================================================================================
                    # PASS 1: POPULATION & FIX phase
                    # ==========================================================================================================

                if (${pass_num} EQUAL 1 OR apf_IS_A_PREREQ)

                    string(LENGTH "${featureName}" this_featurenameLength)
                    math(EXPR paddingChars "${longestFeatureName} - ${this_featurenameLength}")
                    string(REPEAT " " ${paddingChars} fpadding )

                    string(LENGTH "${this_pkgname}" this_pkgnameLength)
                    math(EXPR paddingChars "${longestPkgName} - ${this_pkgnameLength} + 3")
                    string(REPEAT "." ${paddingChars} ppadding )
                    message(CHECK_START "${YELLOW}${fpadding}${featureName}${NC} (${GREEN}${this_pkgname}${NC}) ${ppadding} ${CYAN}Phase ${NC}${BOLD}2${NC}")
                    message(" ")
                    list(APPEND CMAKE_MESSAGE_INDENT "\t")

                    if(${this_package}_PASS_TWO_COMPLETED)
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(" ")
                        message(CHECK_PASS "(already been done)")
                    else ()
                        if (apf_IS_A_PREREQ)
                            set(${this_package}_PASS_TWO_COMPLETED ON)
                        endif ()

                        if ("${this_method}" STREQUAL "FIND_PACKAGE")
                            if (NOT TARGET ${this_namespace}::${this_pkgname})
                               handleTarget(${this_pkgname})
                            endif ()
                        elseif ("${this_method}" STREQUAL "FETCH_CONTENTS" AND this_fetch)

                            if(NOT this_src)
                                if(EXISTS "${EXTERNALS_DIR}/${this_pkgname}")
                                    set(this_src "${EXTERNALS_DIR}/${this_pkgname}")
                                endif ()
                            endif ()
                            if(NOT this_build)
                                if(EXISTS "${BUILD_DIR}/${this_pkglc}-build")
                                    set(this_build "${BUILD_DIR}/${this_pkglc}-build")
                                endif ()
                            endif ()

                            if (NOT ${this_pkgname}_ALREADY_FOUND)
                                set(fn "${this_pkgname}_preMakeAvailable")
                                set(HANDLED OFF)
                                if (COMMAND "${fn}")
                                    cmake_language(CALL "${fn}" "${this_pkgname}")
                                endif ()

                                if (NOT HANDLED AND NOT ${featureName} STREQUAL TESTING)
                                    message(STATUS "\nFetchContent_MakeAvailable(${this_pkgname})")
                                    FetchContent_MakeAvailable(${this_pkgname})
                                    handleTarget(${this_pkgname})
                                endif ()
                            else()
                                message(" ")
                                message(STATUS "${this_pkgname} already found, skipping population.")
#                                handleTarget(${this_pkgname})
                            endif()

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

            endforeach () # featureName
        endforeach () # pass_num
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "${GREEN}OK${NC}\n")

        propegateUpwards("Interim" OFF)

    endfunction()

    processFeatures("${resolvedNames}" "${resolvedFeatures}")
    propegateUpwards("Finally" ON)
endfunction()

macro (propegateUpwards whereWeAre REPORT)

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

    if(REPORT)
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
