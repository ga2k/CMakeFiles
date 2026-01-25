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

                SplitAt(${this_feature_entry} "." this_feature this_tail)
                SplitAt(${this_tail} "." this_pkgindex apf_IS_A_PREREQ)

                if(${this_pkgindex} STREQUAL "P")
                    set(apf_IS_A_PREREQ ON)
                    set(this_pkgindex ".0")
                    set(this_feature_entry "${this_feature}${this_pkgindex}")
                elseif ("${apf_IS_A_PREREQ}" STREQUAL "P")
                    set(apf_IS_A_PREREQ ON)
                    set(this_feature_entry "${this_feature}.${this_pkgindex}")
                endif ()
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
                            patchExternals("${this_pkgname}" ${patches})
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

        propegateUpwards("Interim" ON)

    endfunction()

    processFeatures("${unifiedFeatureList}")
    propegateUpwards("Finally" ON)

endfunction()

macro (propegateUpwards whereWeAre QUIET)

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

    if(NOT QUIET)
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
