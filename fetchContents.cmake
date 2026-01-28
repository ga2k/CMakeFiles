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
include(${CMAKE_SOURCE_DIR}/cmake/standardPackageData.cmake)

set(SystemFeatureData)
set(UserFeatureData)

########################################################################################################################
function(fetchContents)

    createStandardPackageData()

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

    foreach (line IN LISTS SystemFeatureData)
        pipelist(GET line 0 aFeature)
        list(APPEND SystemFeatures ${afeature})
        list(APPEND AllPackages    ${aFeature})
    endforeach ()

    foreach (line IN LISTS LibraryFeatureData)
        pipelist(GET line 0 aFeature)
        list(APPEND LibraryFeatures ${afeature})
        list(APPEND AllPackages     ${aFeature})
    endforeach ()

    foreach (line IN LISTS UserFeatureData)
        pipelist(GET line 0 aFeature)
        list(APPEND OptionalFeatures ${afeature})
        list(APPEND AllPackages      ${aFeature})
    endforeach ()

    list(APPEND AllPackageData ${SystemFeatureData} ${LibraryFeatureData} ${UserFeatureData})

    list(APPEND PseudoFeatures
            APPEARANCE
            PRINT
            LOGGER
    )
    list(APPEND NoLibPackages
            googletest
    )

    unset(unifiedFeatureList)

    # We don't search for pseudo packages
    foreach (use IN LISTS AUE_USE)

        # convert to a cmake list
        pipelist (GET use ${FeatureIX}        feature)
        pipelist (GET use ${FeaturePkgNameIX} pkgname)

        if (${feature} IN_LIST PseudoFeatures)
            # We don't search for plugins this way
            list(APPEND _DefinesList USING_${feature})
        elseif (${feature} IN_LIST SystemFeatures)
            # We don't search for system packages this way, but we might ADD a package variant (if one exists)
            if (NOT "${pkgname}" STREQUAL "")
                getFeaturePackageByName(SystemFeatureData ${feature} ${pkgname} actualPkg index)
                if (${index} EQUAL -1)
                    msg(ALWAYS FATAL_ERROR "FEATURE ${feature} has no package called ${pkgname}")
                elseif (${index} GREATER 0)
                    string(REPLACE ";" "|" actualPkg "${actualPkg}")
                    list(APPEND unifiedFeatureList "${feature}|${actualPkg}")
                else ()
                    msg(ALWAYS WARNING "System feature ${feature} requested, this is unnecessary")
                endif ()
            else ()
                msg(ALWAYS WARNING "System feature ${feature} requested, this is unnecessary")
            endif ()
        else ()
            set (nonSystemFeatureData "${LibraryFeatureData};${UserFeatureData}")
            if(NOT "${pkgname}" STREQUAL "")
                getFeaturePackageByName(nonSystemFeatureData ${feature} ${pkgname} actualPkg index)
            else ()
                set(index 0)
                getFeaturePackage(nonSystemFeatureData ${feature} ${index} actualPkg)
            endif ()
            if (NOT ${actualPkg} STREQUAL "${feature}-NOTFOUND")
                string(REPLACE ";" "|" actualPkg "${actualPkg}")
                list(APPEND unifiedFeatureList "${feature}|${actualPkg}")
            else ()
                msg(ALWAYS FATAL_ERROR "FEATURE ${feature} is not available")
            endif ()
        endif ()
    endforeach ()

    # ensure the caller is using the system libraries
    foreach(systemFeature IN LISTS SystemFeatureData)
        SplitAt("${systemFeature}"  "|" featureName systemPackages)
        SplitAt("${systemPackages}" "," primarySystemPackage otherSystemPackages)

        list (APPEND unifiedFeatureList "${featureName}|${primarySystemPackage}")
    endforeach ()
    ##
    ##########
    ##
    message(" ")

    if (APP_DEBUG)
        log(TITLE "After tampering" LISTS unifiedFeatureList)
    endif ()

    # Re-order unifiedFeatureList based on prerequisites (Topological Sort)
    resolveDependencies("${unifiedFeatureList}" AllPackageData reorderedList)
    set(unifiedFeatureList "${reorderedList}")

    if (APP_DEBUG)
        log(TITLE "After re-ordering by prerequisites" LISTS unifiedFeatureList)
    endif ()

    ####################################################################################################################
    ####################################################################################################################
    ################################ T H E   R E A L   W O R K   B E G I N S   H E R E #################################
    ####################################################################################################################
    ####################################################################################################################

    string(ASCII 27 ESC)
    set(RED     "${ESC}[31m")
    set(GREEN   "${ESC}[32m")
    set(YELLOW  "${ESC}[33m")
    set(BLUE    "${ESC}[34m")
    set(MAGENTA "${ESC}[35m")
    set(CYAN    "${ESC}[36m")
    set(WHITE   "${ESC}[37m")
    set(DEFAULT "${ESC}[38m")
    set(BOLD    "${ESC}[1m" )
    set(NC      "${ESC}[0m" )



    ##
    ## Nested function. How fancy
    ##

    function(processFeatures featureList)

        unset(removeFromDependencies)

        cmake_parse_arguments("apf" "IS_A_PREREQ" "" "" ${ARGN})

        # Two-Pass Strategy:
        # Pass 0: Declare all FetchContents, handle PROCESS and FIND_PACKAGE (Metadata stage)
        # Pass 1: MakeAvailable and perform post-population fixes (Build stage)

        message("\n-----------------------------------------------------------------------------------------------\n")
        string(JOIN ", " l ${packageList})

        message(CHECK_START "${YELLOW}Processing features${NC}${BOLD} ${l}${NC}")
        list(APPEND CMAKE_MESSAGE_INDENT "\t")
        message(" ")

        unset(combinedLibraryComponents)

        foreach (pass_num RANGE 1)
            foreach (this_feature_entry IN LISTS unifiedFeatureList)

                SplitAt(${this_feature_entry} "|" this_feature this_tail)

#                if(${this_pkgindex} STREQUAL "P")
#                    set(apf_IS_A_PREREQ ON)
#                    set(this_pkgindex ".0")
#                    set(this_feature_entry "${this_feature}${this_pkgindex}")
#                elseif ("${apf_IS_A_PREREQ}" STREQUAL "P")
#                    set(apf_IS_A_PREREQ ON)
#                    set(this_feature_entry "${this_feature}.${this_pkgindex}")
#                endif ()
                unset(this_tail)

                # Skip features already found/aliased, but only check this in the final pass
                # to allow declarations to overlap if necessary.
#                if (${pass_num} EQUAL 1)
                    if (TARGET ${this_feature} OR TARGET ${this_feature}::${this_feature} OR ${this_feature}_FOUND OR ${this_feature}_ALREADY_FOUND)
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(CHECK_PASS "Feature already available without re-processing: skipped")
                        list(APPEND removeFromDependencies "${this_feature_entry}" "${this_feature}")
                        continue()
                    endif ()
#                endif ()

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

                parsePackage(AllPackageData
                        BUILD_DIR this_build
                        FEATURE ${this_feature}
                        FETCH_FLAG this_fetch
                        GIT_TAG this_tag
                        INC_DIR this_inc
                        KIND this_kind
                        LIST pkg_details
                        METHOD this_method
                        PKG_INDEX ${this_pkgindex}
                        SRC_DIR this_src
                        URL this_url
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

                    string(LENGTH "${this_pkgname}" this_pkgnameLength)
                    math(EXPR paddingChars "${longestPkgName} - ${this_pkgnameLength} + 3")
                    string(REPEAT "." ${paddingChars} padding )
                    message(CHECK_START "${GREEN}${this_pkgname} ${padding} ${MAGENTA}Phase ${NC}${BOLD}1${NC}")
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
                                set(${this_pkgname}_ALREADY_FOUND ON CACHE INTERNAL "")
                                list(APPEND removeFromDependencies "${this_feature_entry}" "${this_feature}")
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

                    string(LENGTH "${this_pkgname}" this_pkgnameLength)
                    math(EXPR paddingChars "${longestPkgName} - ${this_pkgnameLength} + 3")
                    string(REPEAT "." ${paddingChars} padding )
                    message(CHECK_START "${GREEN}${this_pkgname} ${padding} ${CYAN}Phase ${NC}${BOLD}2${NC}")
                    list(APPEND CMAKE_MESSAGE_INDENT "\t")

                    if(${this_feature}_PASS_TWO_COMPLETED)
                        list(POP_BACK CMAKE_MESSAGE_INDENT)
                        message(" ")
                        message(CHECK_PASS "(already been done)")
                    else ()
                        if (apf_IS_A_PREREQ)
                            set(${this_feature}_PASS_TWO_COMPLETED ON)
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

                                if (NOT HANDLED AND NOT ${this_feature} STREQUAL TESTING)
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

            endforeach () # this_feature_entry
        endforeach () # pass_num
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        message(CHECK_PASS "${GREEN}OK${NC}\n")

        propegateUpwards("Interim" OFF)

    endfunction()

    processFeatures("${unifiedFeatureList}")
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
