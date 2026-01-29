cmake_minimum_required(VERSION 3.28)

set(FeatureIX 0)
set(FeaturePkgNameIX 1)
set(FeatureNamespaceIX 2)
set(FeatureKindIX 3)
set(FeatureMethodIX 4)
set(FeatureUrlIX 5)
set(FeatureGitTagIX 6)
set(FeatureSrcDirIX 5)
set(FeatureBuildDirIX 6)
set(FeatureIncDirIX 7)
set(FeatureComponentsIX 8)
set(FeatureArgsIX 9)
set(FeaturePrereqsIX 10)
math(EXPR FeatureIXCount "${FeaturePrereqsIX} + 1")

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
math(EXPR PkgIXCount "${PkgPrereqsIX} + 1")

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

macro(fetchContentsHelp)

    set(help_msg "[=[
Valid options for fetchContents()

USE <ALL | FEATURE[:ALT] [FEATURE[:ALT] [...]]>
        FetchContent() the named package features

NOT <FEATURE [FEATURE [...]]>
        Don't Fetch_Content() these package features

OVERRIDE_FIND_PACKAGE ALL | FEATURE [FEATURE [...]]
        Redirect calls to find_package() to this local cache

FIND_PACKAGE_ARGS ALL [args]
FIND_PACKAGE_ARGS FEATURE [args] [FEATURE [args] [...]]
        These args to find_package will take precedence over or supplement the user's args.
        If ALL [args] supplied, [args] will be prepended to each FEATURE's args.

FIND_PACKAGE_COMPONENTS FEATURE=component[,component[,... ]] [FEATURE=component[,component[,... ]] [ ... ]]
        COMPONENTS parameter to pass to find_package.

HELP
        Print this help and exit

    Currently available package features are
]=]")

    list(LENGTH PKG_FEATURES items)
    math(EXPR last_item "${items} - 1")

    # Find longest package feature
    string(LENGTH "Package Feature" TITLE_LENGTH)
    set(LONGEST_PKG_LENGTH ${TITLE_LENGTH})

    foreach (x IN LISTS ${PKG_FEATURES})
        unset(THS_PKG_FEATURE)
        getPkgFeature("${x}" THIS_PKG_FEATURE)
        string(LENGTH ${THS_PKG_FEATURE} THS_PKG_LENGTH)
        if (${THS_PKG_LENGTH} GREATER ${LONGEST_PKG_LENGTH})
            set(LONGEST_PKG_LENGTH ${THS_PKG_LENGTH})
        endif ()
    endforeach ()

    set(NAME "Package Feature")
    math(EXPR PADDING "${LONGEST_PKG_LENGTH} - ${TITLE_LENGTH} + 3")
    string(REPEAT "." ${PADDING} PAD)
    list(APPEND help_msg "\t${NAME} ${PAD} Package Options")
    list(APPEND help_msg "\t---------------- ${PAD} ---------------")

    foreach (x IN LISTS PKG_FEATURES)
        unset(THS_PKG_FEATURE)
        unset(THS_PKG_NAME_LIST)
        getPkgFeature("${x}" THIS_PKG_FEATURE)
        getPkgNameList("${x}" THS_PKG_NAME_LIST)
        string(REPLACE ";" ", " THS_PKG_LIST "${THS_PKG_NAME_LIST}")
        string(LENGTH ${THIS_PKG_FEATURE} THS_PKG_LENGTH)
        math(EXPR PADDING "${LONGEST_PKG_LENGTH} - ${THS_PKG_LENGTH} + 3")
        string(REPEAT "." ${PADDING} PAD)
        list(APPEND help_msg "\t${THIS_PKG_FEATURE} ${PAD} ${THS_PKG_LIST}")
    endforeach ()
    list(APPEND help_msg " ")

    log(LIST help_msg)
    message(FATAL_ERROR ${msg})

endmacro()

include(FetchContent)


function(addTargetProperties target pkgname addToLists)

    unset(at_LibrariesList)
    unset(at_DependenciesList)
    unset(at_LibraryPathsList)

    message(" ")
    message("addTargetProperties called for '${target}'")
    get_target_property(_aliasTarget ${target} ALIASED_TARGET)

    if (NOT ${_aliasTarget} STREQUAL "_aliasTarget-NOTFOUND")
        message("Target ${target} is an alias. Retargeting target to target target ${_aliasTarget}")
        addTargetProperties(${_aliasTarget} "${pkgname}" ${addToLists})
        if(addToLists)
            set(_LibrariesList      ${_LibrariesList}       PARENT_SCOPE)
            set(_DependenciesList   ${_DependenciesList}    PARENT_SCOPE)
            set(at_LibraryPathsList ${_LibraryPathsList}    PARENT_SCOPE)
        endif ()
        return()
    endif ()

    get_target_property(_targetType ${target} TYPE)

    if (${_targetType} STREQUAL "INTERFACE_LIBRARY")
        set(LIB_TYPE "INTERFACE")
    else ()
        get_property(is_imported TARGET ${target} PROPERTY IMPORTED)
        if (is_imported)
            set(LIB_TYPE "INTERFACE")
        else ()
            set(LIB_TYPE "PUBLIC")
        endif ()
    endif ()

    target_compile_options(     "${target}" ${LIB_TYPE} "${_CompileOptionsList}")
    target_compile_definitions( "${target}" ${LIB_TYPE} "${_DefinesList}")
    target_link_options(        "${target}" ${LIB_TYPE} "${_LinkOptionsList}")

    if(WIN32)
        set_target_properties("${target}" PROPERTIES DEBUG_POSTFIX "")
    endif ()

    if (addToLists)
        list(APPEND at_LibrariesList ${target})
        list(APPEND at_DependenciesList ${target})
        list(APPEND at_LibraryPathsList ${OUTPUT_DIR}/lib)
    endif ()

    set_target_properties("${target}" PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_DIR}/bin
            LIBRARY_OUTPUT_DIRECTORY ${OUTPUT_DIR}/lib
            ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_DIR}/lib
    )

    ####################################################################################################################
    ####################################################################################################################
    set(fn "${pkgname}_postAddTarget") ################################################################################
    if (COMMAND "${fn}") ################################################################################################
        cmake_language(CALL "${fn}" "${target}") #######################################################################
    endif () ###########################################################################################################
    ####################################################################################################################
    ####################################################################################################################

    list(APPEND at_LibrariesList    ${_LibrariesList})
    list(APPEND at_LibraryPathsList ${_LibraryPathsList})
    list(APPEND at_DependenciesList ${_DependenciesList})

    set(_LibrariesList    ${at_LibrariesList}    PARENT_SCOPE)
    set(_LibraryPathsList ${at_LibraryPathsList} PARENT_SCOPE)
    set(_DependenciesList ${at_DependenciesList} PARENT_SCOPE)

endfunction()

#######################################################################################################################
#######################################################################################################################
#######################################################################################################################
function(initialiseFeatureHandlers)
    if (MONOREPO)
        file(GLOB_RECURSE handlers "${CMAKE_SOURCE_DIR}/${APP_VENDOR}/cmake/handlers/*.cmake")
    else ()
        file(GLOB_RECURSE handlers "${CMAKE_SOURCE_DIR}/cmake/handlers/*.cmake")
    endif ()

    string(LENGTH "postMakeAvailable" longest)
    set(spaces "                         ")

    foreach (handler IN LISTS handlers)
        get_filename_component(handlerName "${handler}" NAME_WE)
        get_filename_component(_path "${handler}" DIRECTORY)
        get_filename_component(packageName "${_path}" NAME_WE)

        string(LENGTH ${handlerName} length)
        math(EXPR num_spaces "${longest} - ${length}")
        string(SUBSTRING "${spaces}" 0 ${num_spaces} padding)

        set(msg "Adding handler ${padding}${handlerName} for ${packageName}")
        if (${handlerName} STREQUAL "init")
            string(APPEND msg " and calling it ...")
        endif ()
        message("${msg}")
        include("${handler}")
        if ("${handlerName}" STREQUAL "init")
            ############################################################################################################
            ############################################################################################################
            set(fn "${packageName}_init") #############################################################################
            if (COMMAND "${fn}") ########################################################################################
                cmake_language(CALL "${fn}") ###########################################################################
            endif () ###################################################################################################
            ############################################################################################################
            ############################################################################################################
        endif ()
    endforeach ()
endfunction()
########################################################################################################################
########################################################################################################################
########################################################################################################################
function(initialiseFunctionHandlers)
endfunction()
########################################################################################################################
########################################################################################################################
########################################################################################################################
function(addPackageData)
    set(switches SYSTEM;USER;LIBRARY)
    set(args METHOD;FEATURE;PKGNAME;NAMESPACE;URL;GIT_REPOSITORY;SRCDIR;GIT_TAG;BINDIR;INCDIR;COMPONENT;ARG;PREREQ)
    set(arrays COMPONENTS;ARGS;PREREQS)

    cmake_parse_arguments("apd" "${switches}" "${args}" "${arrays}" ${ARGN})

    if (NOT apd_METHOD OR (NOT ${apd_METHOD} STREQUAL "PROCESS" AND NOT ${apd_METHOD} STREQUAL "FETCH_CONTENTS" AND NOT ${apd_METHOD} STREQUAL "FIND_PACKAGE"))
        message(FATAL_ERROR "addPackageData: One of METHOD FIND_PACKAGE/FETCH_CONTENTS/PROCESS required for ${apd_FEATURE}")
    endif ()

    if (NOT apd_SYSTEM AND NOT apd_USER AND NOT apd_LIBRARY)
        set(apd_USER ON)
    endif ()

    if ((apd_SYSTEM AND apd_USER) OR (apd_SYSTEM AND apd_LIBRARY) OR (apd_USER AND apd_LIBRARY))
        message(FATAL_ERROR "addPackageData: Zero or one of SYSTEM/USER/LIBRARY allowed")
    else ()
        if(apd_SYSTEM)
            set(apd_KIND "SYSTEM")
        elseif(apd_LIBRARY)
            set(apd_KIND "LIBRARY")
        else ()
            set(apd_KIND "USER")
        endif ()
    endif ()

    if (NOT apd_PKGNAME)
        message(FATAL_ERROR "addPackageData: PKGNAME required")
    endif ()
    if (
    (apd_URL AND apd_GIT_REPOSITORY) OR
    (apd_URL AND apd_SRCDIR) OR
    (apd_GIT_REPOSITORY AND apd_SRCDIR)
    )
        message(FATAL_ERROR "addPackageData: Only one of URL/GIT_REPOSITORY/SRCDIR allowed")
    endif ()
    if (NOT apd_URL AND NOT apd_GIT_REPOSITORY AND NOT apd_SRCDIR AND apd_METHOD STREQUAL "FETCH_CONTENTS")
        message(FATAL_ERROR "addPackageData: One of URL/GIT_REPOSITORY/SRCDIR required")
    endif ()
    if ((apd_GIT_REPOSITORY AND NOT apd_GIT_TAG) OR
    (NOT apd_GIT_REPOSITORY AND apd_GIT_TAG))
        message(FATAL_ERROR "addPackageData: Neither or both GIT_REPOSITORY/GIT_TAG allowed")
    endif ()
    if ((apd_URL AND apd_GIT_TAG) OR
    (apd_SRCDIR AND apd_GIT_TAG))
        message(FATAL_ERROR "addPackageData: GIT_TAG only allowed with GIT_REPOSITIORY")
    endif ()
    if (apd_GIT_TAG AND apd_BINDIR)
        message(FATAL_ERROR "addPackageData: Only one of GIT_TAG or BINDIR allowed")
    endif ()

    if (apd_COMPONENT)
        list(APPEND apd_COMPONENTS ${apd_COMPONENT})
    endif ()

    if (apd_ARG)
        list(APPEND apd_ARGS ${apd_ARG})
    endif ()

    if (apd_PREREQ)
        list(APPEND apd_PREREQS ${apd_PREREQ})
    endif ()

    set(entry "${apd_PKGNAME}")

#    if (${apd_METHOD} STREQUAL "PROCESS")
#        unset(apd_NAMESPACE)
#        unset(apd_URL)
#        unset(apd_GIT_REPOSITORY)
#        unset(apd_SRCDIR)
#        unset(apd_GIT_TAG)
#        unset(apd_BINDIR)
#        unset(apd_INCDIR)
#        unset(apd_COMPONENT)
#        unset(apd_ARG)
#        unset(apd_COMPONENTS)
#        unset(apd_ARGS)
#    endif ()

    if (apd_NAMESPACE)
        string(JOIN "|" entry "${entry}" "${apd_NAMESPACE}")
    else ()
        string(APPEND entry "|")
    endif ()

    string(JOIN "|" entry "${entry}" ${apd_KIND})
    string(JOIN "|" entry "${entry}" ${apd_METHOD})

    if (apd_GIT_REPOSITORY)
        string(JOIN "|" entry "${entry}" "${apd_GIT_REPOSITORY}")
    elseif (apd_SRCDIR)
        string(JOIN "|" entry "${entry}" "${apd_SRCDIR}")
    elseif (apd_URL)
        string(JOIN "|" entry "${entry}" "${apd_URL}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (apd_GIT_TAG)
        string(JOIN "|" entry "${entry}" "${apd_GIT_TAG}")
    elseif (apd_BINDIR)
        string(JOIN "|" entry "${entry}" "${apd_BINDIR}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (apd_INCDIR)
        string(JOIN "|" entry "${entry}" "${apd_INCDIR}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (apd_COMPONENTS)
        set(components)
#        foreach (component IN LISTS apd_COMPONENTS)
        string(REPLACE ";" ":" components "${apd_COMPONENTS}")
#        endforeach ()
        string(STRIP "${components}" components)
        string(JOIN "|" entry "${entry}" "${components}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (apd_ARGS)
        set(args)
        foreach (arg IN LISTS apd_ARGS)
            string(JOIN " " args "${args}" "${arg}")
        endforeach ()
        string(STRIP "${args}" args)
        string(JOIN "|" entry "${entry}" "${args}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (apd_PREREQS)
        set(prereqs)
        foreach (prereq IN LISTS apd_PREREQS)
            string(JOIN " " prereqs "${prereqs}" "${prereq}")
        endforeach ()
        string(STRIP "${prereqs}" prereqs)
        string(JOIN "|" entry "${entry}" "${prereqs}")
    else ()
        string(APPEND entry "|")
    endif ()

    set(pkgIndex)

    if (apd_USER)
        set(activeArray UserFeatureData)
    elseif (apd_SYSTEM)
        set(activeArray SystemFeatureData)
    elseif (apd_LIBRARY)
        set(activeArray LibraryFeatureData)
    endif ()

    getFeatureIndex(${activeArray} ${apd_FEATURE} pkgIndex)

    if (${pkgIndex} EQUAL -1)
        set(newEntry "${apd_FEATURE}|${entry}")
        list(APPEND ${activeArray} "${newEntry}")
        set(${activeArray} "${${activeArray}}" PARENT_SCOPE)
    else ()
        list(GET ${activeArray} ${pkgIndex} featureLine)
        string(JOIN "," feature_line "${featureLine}" "${entry}")
        list(REMOVE_AT ${activeArray} ${pkgIndex})
        list(INSERT ${activeArray} ${pkgIndex} "${feature_line}")
        set(${activeArray} "${${activeArray}}" PARENT_SCOPE)
    endif ()

    set(SystemFeatureData "${SystemFeatureData}" PARENT_SCOPE)
    set(LibraryFeatureData "${LibraryFeatureData}" PARENT_SCOPE)
    set(UserFeatureData "${UserFeatureData}" PARENT_SCOPE)

endfunction()
##
######################################################################################
##
function(getFeaturePkgList arrayName feature receivingVarName)
    # iterate over array to find line with feature
    foreach (line IN LISTS ${arrayName})
        SplitAt("${line}" "|" this_feature packages)
        if ("${this_feature}" STREQUAL "${feature}")

            # break line into packages at the comma
            string(REPLACE "," ";" pkglist ${packages})

            set(local)
            # Grab the package name from each package
            foreach (package IN LISTS pkglist)
                SplitAt("${package}" "|" this_pkg unused)
                list(APPEND local ${this_pkg})
            endforeach ()

            set(${receivingVarName} ${local} PARENT_SCOPE)
            return()
        endif ()
    endforeach ()
endfunction()
##
######################################################################################
##
function(getFeatureIndex arrayName feature receivingVarName)
    # iterate over array to find line with feature
    set(ix -1)
    foreach (line IN LISTS "${arrayName}")
        math(EXPR ix "${ix} + 1")
        SplitAt("${line}" "|" this_feature packages)
        if ("${this_feature}" STREQUAL "${feature}")
            set(${receivingVarName} ${ix} PARENT_SCOPE)
            return()
        endif ()
    endforeach ()
    set(${receivingVarName} -1 PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeaturePackage arrayName feature index receivingVarName)
    foreach (item IN LISTS ${arrayName})
#    foreach (item IN LISTS arrayName)
        SplitAt("${item}" "|" this_feature packages)
        if ("${this_feature}" STREQUAL "${feature}")
            string(REPLACE "," ";" list "${packages}")
            list(GET list ${index} package)
            set(${receivingVarName} "${package}" PARENT_SCOPE)
            break()
        endif ()
    endforeach ()
    set (${receivingVarName} "${name}-NOTFOUND")
endfunction()
##
######################################################################################
##
function(getFeaturePackageByName arrayName feature name receivingVarName indexVarName)
    foreach (item IN LISTS ${array})
        set(ix -1)
        SplitAt("${item}" "|" this_feature packages)
        if ("${this_feature}" STREQUAL "${feature}")
            string(REPLACE "," ";" list "${packages}")
            foreach (pkg IN LISTS list)
                math(EXPR ix "${ix} + 1")
                SplitAt("${pkg}" "|" pkgName pkgData)
                if ("${pkgName}" STREQUAL "${name}")
                    set(${receivingVarName} "${pkg}" PARENT_SCOPE)
                    set(${indexVarName} ${ix} PARENT_SCOPE)
                    break()
                endif ()
            endforeach ()
            set (${receivingVarName} "${name}-NOTFOUND")
            set(${indexVarName} -1 PARENT_SCOPE)
        endif ()
    endforeach ()
    set (${receivingVarName} "${name}-NOTFOUND")
    set(${indexVarName} -2 PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getPkgFeature line var)
    unset(${var} PARENT_SCOPE)
    set(feature "")
    set(dc "")
    SplitAt("${line}" "|" feature unused)
    string(STRIP "${feature}" feature)
    set(${var} "${feature}" PARENT_SCOPE)
endfunction()
##
########################################################################################################################
##
function(popFront lineVarName frontVarName)
    unset(${frontVarName} PARENT_SCOPE)
    set(front "")
    SplitAt("${${lineVarName}}" "|" front balance)
    string(STRIP "${front}" front)
    string(STRIP "${balance}" balance)
    set(${frontVarName} "${front}" PARENT_SCOPE)
    set(${lineVarName} "${lineVarName}" PARENT_SCOPE)
endfunction()
##
########################################################################################################################
##
## parsePackage can be called with a    * A list of features like "SystemFeatureList" which is a list of features
##                                      * A single feature, which is a list of packages
##                                      * A single package, which is a list of attributes.
##
## If INPUT_TYPE is provided, we'll verify that
## If INPUT_TYPE is not provided, we'll work it out
##
function(parsePackage)
    set(options)
    set(one_value_args
#           Keyword         Type        Direction   Description
            INPUT_TYPE  #   STRING      IN          Type of list supplied in inputListName
                        #                           One of (SET,FEATURE,PACKAGE).
                        #                           If omitted, an attempt to determine it will be made
            FEATURE     #   STRING      IN          Feature to select from inputList
                        #                           If INPUT_TYPE is FEATURE or PACKAGE, FEATURE is ignored
            PACKAGE     #   STRING      IN          Package to select by name from Feature
                        #                           If INPUT_TYPE is PACKAGE, PKG_NAME is ignored
            PKG_INDEX   #   INTEGER     IN          Package to select by index from Feature
                        #                           If INPUT_TYPE is PACKAGE, PKG_INDEX is ignored
            OUTPUT      #   VARNAME     OUT         Receive a copy of the entire PACKAGE
            INDEX       #   VARNAME     OUT         Receive a copy of the package index
            NAME        #   VARNAME     OUT         Receive a copy of the package name
            URL         #   VARNAME     OUT         Receive a copy of the URL attribute (if applicable)
            GIT_TAG     #   VARNAME     OUT         Receive a copy of the GIT_TAG attribute (if applicable)
            SRC_DIR     #   VARNAME     OUT         Receive a copy of the SRCDIR attribute (if applicable)
            BUILD_DIR   #   VARNAME     OUT         Receive a copy of the BUILDDIR attribute (if applicable)
            INC_DIR     #   VARNAME     OUT         Receive a copy of the INCDIR attribute (if applicable)
            FETCH_FLAG  #   VARNAME     OUT         Indication that this PACKAGE needs to be downloaded somehow
            KIND        #   VARNAME     OUT         Receive a copy of the KIND attribute (SYSTEM/LIBRARY/USER)
            METHOD      #   VARNAME     OUT         Receive a copy of the METHOD attribute (FETCH_CONTENT/FIND_PACKAGE/PROCESS)
            COMPONENTS  #   VARNAME     OUT         Receive a copy of the COMPONENT attribute in CMake LIST format
            PREREQS     #   VARNAME     OUT         Receive a copy of the PREREQ attribute in CMake LIST format
            ARGS        #   VARNAME     OUT         Receive a copy of the ARG attribute in CMake LIST format
    )
    set(multi_value_args)
    unset(A_PP_UNDEFINED_ARGUMENTS)

    # Parse the arguments
    cmake_parse_arguments(A_PP "${options}" "${one_value_args}" "${multi_value_args}" ${ARGN})

    if (NOT DEFINED A_PP_UNPARSED_ARGUMENTS)
        msg(ALWAYS FATAL_ERROR "NO inputListName found in call to parsePackage()")
    endif ()

    list(POP_FRONT A_PP_UNPARSED_ARGUMENTS inputListName)

    if (NOT DEFINED ${inputListName})
        msg(ALWAYS FATAL_ERROR "NO input list called \"${inputListName}\" exists in call to parsePackage()")
    endif ()

    unset(inputListVerifyFailed)

    if (NOT DEFINED A_PP_INPUT_TYPE)
        # How we know what we have;
        # Definitions
        # PIPELIST      Like a CMAKE LIST, except each record separator ";" is replaced by a PIPE ("|") symbol.
        #               The list(LENGTH...)    of a PIPELIST will be 1.
        #               The piplist(LENGTH...) of a PIPELIST will be from ${PkgIXCount} to ${FeatureIXCount} + n * ${PkgIXCount}
        # PACKAGE       A PIPELIST. pipelist(LENGTH...) will be ${PkgIXCount}
        # FEATURE       A PIPELIST that Looks like this <FEATURE_NAME><PACKAGE>[,<PACKAGE>[...]]
        #               so a FEATURE has the length of ${FeatureIXCount} + n * ${PkgIXCount}
        # SET           A CMake LIST of FEATURES. Each FEATURE will be one PIPELIST

        # See if this is a PIPELIST
        list(LENGTH ${inputListName} listLength)
        pipelist(LENGTH ${inputListName} pipeLength)

        if (${listLength} EQUAL 1 AND ${pipeLength} EQUAL 1)
            set(inputListVerifyFailed "INPUT_TYPE needed - analysis failed")
        elseif (${listLength} GREATER_EQUAL 1)
            # Can ONLY be a set. We'll check if it is later
            set(A_PP_INPUT_TYPE "SET")
        elseif (${listLength} EQUAL 1 AND ${pipeLength} EQUAL ${PkgIXCount})
            # Can ONLY be a PACKAGE. We'll check if it is later
            set(A_PP_INPUT_TYPE "PACKAGE")
        elseif (${listLength} EQUAL 1 AND ${pipeLength} GREATER_EQUAL ${FeatureIXCount})
            # Can ONLY be a FEATURE. We'll check if it is later
            set(A_PP_INPUT_TYPE "FEATURE")
        else ()
            set(inputListVerifyFailed "INPUT_TYPE needed - analysis failed")
        endif ()
    endif ()

    unset(A_SET)
    unset(A_FEATURE)
    unset(A_PACKAGE)

    if (NOT inputListVerifyFailed)
        # Ok, we know what inputListName is SUPPOSED to be, let's verify it

        if (${A_PP_INPUT_TYPE} MATCHES "PACKAGE")
            set(A_PACKAGE ON)

            pipelist(LENGTH ${inputListName} len)
            if (NOT ${len} EQUAL "${PkgIXCount}")
                set(inputListVerifyFailed "Input PACKAGE length of ${len} should be ${PkgIXCount}")
            endif ()
        elseif (${A_PP_INPUT_TYPE} MATCHES "FEATURE")
            set(A_FEATURE ON)

            pipelist(LENGTH ${inputListName} len)
            if (NOT ${len} GREATER_EQUAL "${FeatureIXCount}")
                set(inputListVerifyFailed "Input FEATURE length of ${len} should be 1 + n * ${PkgIXCount}")
            else ()
                math(EXPR featurePackages "(${len} - 1) % ${PkgIXCount})")
                math(EXPR expectedFields "1 + ${featurePackages} * ${PkgIXCount}")
                if (NOT ${len} EQUAL "${expectedFields}")
                    list(APPEND inputListVerifyFailed "Input FEATURE length of ${len} should be 1 + n * ${PkgIXCount}")
                endif ()
            endif ()
        elseif (${A_PP_INPUT_TYPE} MATCHES "SET")
            set(A_SET ON)
            set (whichElement 0)
            list(LENGTH ${inputListName} numElements)
            foreach(sample IN LISTS ${inputListName})
                math(EXPR whichElement "${whichElement} + 1")
                pipelist(LENGTH sample len)
                math(EXPR featurePackages "(${len} - 1) / ${PkgIXCount}")
                math(EXPR expectedFields "1 + ${featurePackages} * ${PkgIXCount}")
                if (NOT (${len} EQUAL ${PkgIXCount} OR ${len} EQUAL "${expectedFields}"))
                    set(inputListVerifyFailed "FEATURE #${whichElement} of ${numElements} in input list is invalid")
                endif ()
            endforeach ()
        else ()
            set(inputListVerifyFailed "INPUT_TYPE must be one of (SET FEATURE PACKAGE), not ${A_PP_INPUT_TYPE}")
        endif ()
    endif ()

    if(inputListVerifyFailed)
        msg(ALWAYS FATAL_ERROR "${RED}${BOLD}parsePackage() FAIL:${NC} ${inputListVerifyFailed}")
    endif()

    if (A_SET AND NOT A_PP_FEATURE)
        msg (ALWAYS FATAL_ERROR "parsePackage() needs FEATURE parameter")
    endif ()

    if (NOT ((A_SET OR A_FEATURE) AND (A_PP_PACKAGE OR DEFINED A_PP_PKG_INDEX)))
        msg (ALWAYS FATAL_ERROR "parsePackage() needs PACKAGE or PKG_INDEX parameter")
    endif ()

    if (DEFINED A_PP_PKG_INDEX AND A_PP_PACKAGE)
        msg(ALWAYS WARNING "parsePackage() both PACKAGE and PKG_FEATURE supplied. Need one or the other")
    endif ()

    if(A_SET OR A_FEATURE)
        if(DEFINED A_PP_PKG_INDEX)
            getFeaturePackage(${inputListName} "${A_PP_FEATURE}" "${A_PP_PKG_INDEX}" local)
            SplitAt("${local}" "|" name dc)
            set(index ${A_PP_PKG_INDEX})
        else ()
            getFeaturePackageByName(inputListName "${A_PP_FEATURE}" "${A_PP_PACKAGE}" local index)
            set(name "${A_PP_PACKAGE}")
        endif ()
        if(DEFINED A_PP_INDEX)
            set(${A_PP_INDEX} ${index} PARENT_SCOPE)
        endif ()
        if(DEFINED A_PP_NAME)
            set(${A_PP_NAME} ${name} PARENT_SCOPE)
        endif ()
    else()
        set(local ${${inputListName}})
        if(DEFINED A_PP_INDEX)
            set(${A_PP_INDEX} "UNKNOWN" PARENT_SCOPE)
        endif ()
        if(DEFINED A_PP_NAME)
            SplitAt("${local}" "|" name dc)
            set(${A_PP_NAME} ${name} PARENT_SCOPE)
        endif ()
    endif ()

    # Initialize output variables
    if(DEFINED ${A_PP_OUTPUT})
        set(${A_PP_OUTPUT}      "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_KIND})
        set(${A_PP_KIND}        "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_METHOD})
        set(${A_PP_METHOD}      "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_URL})
        set(${A_PP_URL}         "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_GIT_TAG})
        set(${A_PP_GIT_TAG}     "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_SRC_DIR})
        set(${A_PP_SRC_DIR}     "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_BUILD_DIR})
        set(${A_PP_BUILD_DIR}   "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_FETCH_FLAG})
        set(${A_PP_FETCH_FLAG}  ON PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_INC_DIR})
        set(${A_PP_INC_DIR}     "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_COMPONENTS})
        set(${A_PP_COMPONENTS}  "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_ARGS})
        set(${A_PP_ARGS}        "" PARENT_SCOPE)
    endif ()
    if(DEFINED ${A_PP_PREREQS})
        set(${A_PP_PREREQS}     "" PARENT_SCOPE)
    endif ()

    string(REPLACE "|" ";" pkg "${local}")
    list(LENGTH pkg length)

    list(GET pkg ${PkgNamespaceIX} localNS)
    list(GET pkg ${PkgKindIX}      localKind)
    list(GET pkg ${PkgMethodIX}    localMethod)

    set(${A_PP_KIND}   ${localKind}   PARENT_SCOPE)
    set(${A_PP_METHOD} ${localMethod} PARENT_SCOPE)

    set(is_git_repo OFF)
    set(is_zip_file OFF)
    set(is_src_dir OFF)

    set(is_git_tag OFF)
    set(is_build_dir OFF)

    if (A_PP_URL AND ${PkgUrlIX} LESS ${length})
        list(GET pkg ${PkgUrlIX} temp)
        if (${temp} MATCHES "^http.*")
            if (${temp} MATCHES ".*\.zip$" OR ${temp} MATCHES ".*\.tar$" OR ${temp} MATCHES ".*\.gz$")
                set(is_zip_file ON)
                set(is_git_tag OFF)
                set(is_build_dir ON)
            else ()
                set(is_git_repo ON)
                set(is_git_tag ON)
                set(is_build_dir OFF)
            endif ()
            set(${A_PP_URL} ${temp} PARENT_SCOPE)
            set(${A_PP_FETCH_FLAG} ON PARENT_SCOPE)
        else ()
            set(is_src_dir ON)
            set(is_git_tag OFF)
            set(is_build_dir ON)
        endif ()
    endif ()

    if (A_PP_GIT_TAG AND is_git_tag AND ${PkgGitTagIX} LESS ${length})
        list(GET pkg ${PkgGitTagIX} temp)
        set(${A_PP_GIT_TAG} ${temp} PARENT_SCOPE)
    endif ()

    if (A_PP_SRC_DIR AND is_src_dir AND ${PkgSrcDirIX} LESS ${length})
        list(GET pkg ${PkgSrcDirIX} temp)
        if (temp)
            string(FIND "${temp}" "[" open_bracket)
            string(FIND "${temp}" "]" close_bracket)
            if (${open_bracket} GREATER_EQUAL 0 AND ${close_bracket} GREATER_EQUAL 1)
                math(EXPR one_past_open_bracket "${open_bracket} + 1")
                math(EXPR one_before_close_bracket "${close_bracket} - 1")
                math(EXPR one_past_close_bracket "${close_bracket} + 1")
                math(EXPR dirroot_length "${one_before_close_bracket} - ${one_past_open_bracket} + 1")
                string(SUBSTRING "${temp}" ${one_past_open_bracket} ${dirroot_length} dirroot)
                string(SUBSTRING "${temp}" ${one_past_close_bracket} -1 src_folder)

                if (${dirroot} STREQUAL "SRC")
                    set(${A_PP_SRC_DIR} ${EXTERNALS_DIR}/${src_folder} PARENT_SCOPE)
                    set(src_ok ON)
                elseif (${dirroot} STREQUAL "BUILD")
                    set(${A_PP_SRC_DIR} ${BUILD_DIR}/_deps/${src_folder} PARENT_SCOPE)
                    set(src_ok ON)
                else ()
                    message(FATAL_ERROR "Bad SRCDIR for ${this_pkgname} (${temp}): Must start with \"[SRC]\" or \"[BUILD]\"")
                endif ()
            else ()
                set(src_ok ON)
            endif ()
        else ()
            set(src_ok OFF)
        endif ()
    endif ()

    if (A_PP_BUILD_DIR AND is_build_dir AND ${PkgBuildDirIX} LESS ${length})
        list(GET pkg ${PkgBuildDirIX} temp)
        if (temp)
            string(FIND "${temp}" "[" open_bracket)
            string(FIND "${temp}" "]" close_bracket)
            if (${open_bracket} GREATER_EQUAL 0 AND ${close_bracket} GREATER_EQUAL 1)
                math(EXPR one_past_open_bracket "${open_bracket} + 1")
                math(EXPR one_before_close_bracket "${close_bracket} - 1")
                math(EXPR one_past_close_bracket "${close_bracket} + 1")
                math(EXPR dirroot_length "${one_before_close_bracket} - ${one_past_open_bracket} + 1")
                string(SUBSTRING "${temp}" ${one_past_open_bracket} ${dirroot_length} dirroot)
                string(SUBSTRING "${temp}" ${one_past_close_bracket} -1 src_folder)

                if (${dirroot} STREQUAL "SRC")
                    set(${A_PP_BUILD_DIR} ${EXTERNALS_DIR}/${build_folder} PARENT_SCOPE)
                    set(build_ok ON)
                elseif (${dirroot} STREQUAL "BUILD")
                    set(${A_PP_BUILD_DIR} ${BUILD_DIR}/_deps/${build_folder} PARENT_SCOPE)
                    set(build_ok ON)
                else ()
                    message(FATAL_ERROR "Bad BINDIR for ${this_pkgname} (${temp}): Must start with \"[SRC]\" or \"[BUILD]\"")
                endif ()
            else ()
                set(build_ok ON)
            endif ()
        else ()
            set(build_ok OFF)
        endif ()
    endif ()

    if (src_ok) # Was AND build_ok) # But I think the existence of the build folder shouldn't have any effect here
        set(${A_PP_FETCH_FLAG} OFF PARENT_SCOPE)
    endif ()

    if (A_PP_INC_DIR AND ${PkgIncDirIX} LESS ${length})
        list(GET pkg ${PkgIncDirIX} temp)
        string(FIND "${temp}" "[" open_bracket)
        string(FIND "${temp}" "]" close_bracket)
        if (${open_bracket} GREATER_EQUAL 0 AND ${close_bracket} GREATER_EQUAL 1)
            math(EXPR one_past_open_bracket "${open_bracket} + 1")
            math(EXPR one_before_close_bracket "${close_bracket} - 1")
            math(EXPR one_past_close_bracket "${close_bracket} + 1")
            math(EXPR dirroot_length "${one_before_close_bracket} - ${one_past_open_bracket} + 1")
            string(SUBSTRING "${temp}" ${one_past_open_bracket} ${dirroot_length} dirroot)
            string(SUBSTRING "${temp}" ${one_past_close_bracket} -1 src_folder)

            if (${dirroot} STREQUAL "SRC")
                set(${A_PP_INC_DIR} ${EXTERNALS_DIR}/${folder} PARENT_SCOPE)
                set(inc_ok ON)
            elseif (${dirroot} STREQUAL "BUILD")
                set(${A_PP_INC_DIR} ${BUILD_DIR}/_deps/${folder} PARENT_SCOPE)
                set(inc_ok ON)
            else ()
                message(FATAL_ERROR "Bad INCDIR for ${this_pkgname} (${temp}): Must start with \"[SRC]\" or \"[BUILD]\"")
            endif ()
        else ()
            set(inc_ok ON)
        endif ()
    endif ()

    if (A_PP_COMPONENTS)
        if (${PkgComponentsIX} LESS ${length})
            list(GET pkg ${PkgComponentsIX} temp)
            if (NOT "${temp}" STREQUAL "")
                string(REGEX REPLACE " " ";" temp ${temp})
                string(REGEX REPLACE ":" ";" temp ${temp})
                set(${A_PP_COMPONENTS} ${temp} PARENT_SCOPE)
            endif ()
        endif ()
    endif ()

    if (A_PP_ARGS)
        if (${PkgArgsIX} LESS ${length})
            list(GET pkg ${PkgArgsIX} temp)
            if (NOT "${temp}" STREQUAL "")
                string(REGEX REPLACE ":" ";" temp ${temp})
                set(${A_PP_ARGS} ${temp} PARENT_SCOPE)
            endif ()
        endif ()
    endif ()

    if (A_PP_PREREQS)
        if (${PkgPrereqsIX} LESS ${length})
            list(GET pkg ${PkgPrereqsIX} temp)
            if (NOT "${temp}" STREQUAL "")
                string(REGEX REPLACE " " ";" temp ${temp})
                set(${A_PP_PREREQS} ${temp} PARENT_SCOPE)
            endif ()
        endif ()
    endif ()

endfunction()
##
########################################################################################################################
##
function(combine primaryList secondaryList outputList)  # Optionally, add TRUE or FALSE to indicate if you want it sorted

    set(doSort ON)
    if (NOT ${ARGN} STREQUAL "")
        set(doSort ${ARGN})
    endif ()

    set(local ${list_name})

    list(APPEND allItems ${primaryList} ${secondaryList})
    list(REMOVE_DUPLICATES allItems)
    if (doSort)
        list(SORT allItems)
    endif ()

    set(${outputList} "${allItems}" PARENT_SCOPE)

endfunction()
##
########################################################################################################################
##
function(resolveDependencies inputList allData outputList)
    # inputList is unifiedFeatureList
    # allData   is AllPackageData

    set(resolved "")
    set(packageList "")
    set(visited "")
    set(longestPkgName 0)

    # Internal helper to walk dependencies
    macro(visit feature_name pkg is_a_prereq)
        if (NOT "${feature_name}" IN_LIST visited)
            list(APPEND visited "${feature_name}")

            parsePackage(${allData}
                    FEATURE "${feature_name}"
                    PKG_INDEX 0
                    INDEX idx_
                    PREREQS pre_
                    ARGS args_
                    NAME pkgname_
            )

            string(LENGTH "${pkgname_}" this_pkglength_)
            if (${this_pkglength_} GREATER ${longestPkgName})
                set(longestPkgName ${this_pkglength_})
            endif ()

            foreach(pr_entry_ IN LISTS pre_)
                string(FIND "${pr_entry_}" "=" eq_pos_)
                if (eq_pos_ GREATER -1)
                    string(SUBSTRING "${pr_entry_}" 0 ${eq_pos_} pr_feat_)
                else()
                    set(pr_feat_ "${pr_entry_}")
                endif()

                set(found_entry_in_input_ "")
                # TODO: Line below changed from inputLiist to allData
                foreach(e_ IN LISTS ${allData}) # inputList)
                    SplitAt("${e_}" fname_ dc_)
                    if(fname_ MATCHES "^${pr_feat_}\\.")
                        set(found_entry_in_input_ "${fname_}")
                        break()
                    endif()
                endforeach()

                if(found_entry_in_input_)
                    visit("${found_entry_in_input_}" "${_pkg}" ON)
                endif()
            endforeach()

            if (${is_a_prereq})
                list(APPEND resolved "${feature_name}.P")
            else ()
                list(APPEND resolved "${feature_name}")
            endif ()

            list(APPEND packageList ${pkgname_})

        endif()

        unset(args_)
        unset(dnc_)
        unset(e_)
        unset(eq_pos_)
        unset(feat_)
        unset(found_entry_in_input_)
        unset(idx_)
        unset(pr_entry_)
        unset(pr_feat_)
        unset(pre_)
        unset(this_pkglength_)

    endmacro()

    # Pass 1: Handle LIBRARIES and their deep prerequisites first
    foreach(item IN LISTS inputList)
        SplitAt("${item}" "|" _feature_name _pkg)
        parsePackage(inputList FEATURE "${_feature_name}" PKG_INDEX 0 KIND _kind ARGS _args)
        if ("${_kind}" STREQUAL "LIBRARY")
            visit("${_feature_name}" "${_pkg}" OFF)
        endif()
    endforeach()

    # Pass 2: Handle everything else
    foreach(item IN LISTS inputList)
        SplitAt("${item}" "|" _feature_name _pkg)
        visit("${_feature_name}" "${_pkg}" OFF)
    endforeach()

    set(${outputList}       ${resolved}         PARENT_SCOPE)
    set(longestPkgName      ${longestPkgName}   PARENT_SCOPE)
    set(packages            ${packageList}      PARENT_SCOPE)

    unset(item)
    unset(_feature_name)
    unset(_pkg)
    unset(_kind)
    unset(_dnc)
    unset(_args)

endfunction()
##
########################################################################################################################
##
function(scanLibraryTargets libName packageData)

    set(${libName}_COMPONENTS)
    set(${libName}_COMPONENTS ${${libName}_COMPONENTS} PARENT_SCOPE)

    # Check common target name patterns
    set(targetName "")
    if (TARGET ${APP_VENDOR}::${libName})
        set(targetName "${APP_VENDOR}::${libName}")
    elseif (TARGET ${libName}::${libName})
        set(targetName "${libName}::${libName}")
    elseif (TARGET ${libName})
        set(targetName "${libName}")
    endif()

    if ("${targetName}" STREQUAL "")
        message(STATUS "  scanLibraryTargets: Could not find target for ${libName}")
        return()
    endif()

    message(STATUS "  Scanning ${targetName} for provided imports...")

    get_target_property(libs ${targetName} INTERFACE_LINK_LIBRARIES)
    if (libs)
        foreach(lib IN LISTS libs)
            # 1. Clean up target name (remove generator expressions)
            string(REGEX REPLACE "\\$<.*>" "" clean_lib "${lib}")
            if ("${clean_lib}" STREQUAL "")
                continue()
            endif()

            # 2. Extract raw name for matching
            set(raw_import_name "${clean_lib}")
            if ("${clean_lib}" MATCHES "::")
                # Handle HoffSoft::name or Namespace::name
                string(REGEX REPLACE ".*::" "" raw_import_name "${clean_lib}")
            endif()

            # 3. Cross-reference against packageData
            foreach(feature_line IN LISTS packageData)
                SplitAt("${feature_line}" "|" feat_name packages)
                string(REPLACE "," ";" package_list "${packages}")

                foreach(pkg_entry IN LISTS package_list)
                    # 4. Extract package details
                    # Format is usually: PKGNAME|NAMESPACE|KIND|METHOD|URL|GIT_TAG|INCDIR|COMPONENTS|ARGS|PREREQS
                    # but let's be careful about how many | there are.
                    string(REPLACE "|" ";" pkg_details "${pkg_entry}")
                    list(GET pkg_details ${PkgNameIX} pkg_name)
                    list(GET pkg_details ${PkgNamespaceIX} ns)
                    list(GET pkg_details ${PkgComponentsIX} components) # COMPONENTS are at index 7 (0-based)

                    # Does the library link to this package?
                    set(MATCHED OFF)
                    if ("${raw_import_name}" STREQUAL "${pkg_name}" OR "${raw_import_name}" STREQUAL "${ns}")
                        set(MATCHED ON)
                    elseif(components)
                        # Check components
                        string(REPLACE " " ";" component_list "${components}")
                        foreach(comp IN LISTS component_list)
                            # Match against component name (e.g. Core) or ns_component (e.g. SOCI_Core)
                            # or common variations like pkg_component (e.g. soci_core)
                            string(TOLOWER "${pkg_name}" pkg_lc)
                            string(TOLOWER "${comp}" comp_lc)

                            if ("${raw_import_name}" STREQUAL "${comp}" OR
                                "${raw_import_name}" STREQUAL "${ns}_${comp}" OR
                                "${raw_import_name}" STREQUAL "${pkg_name}_${comp}" OR
                                "${raw_import_name}" STREQUAL "${pkg_lc}_${comp_lc}")
                                set(MATCHED ON)
                                break()
                            endif()
                        endforeach()
                    endif()

                    if (MATCHED)
                        message(STATUS "    -> Feature '${feat_name}' (${pkg_name}) is already provided by ${targetName} as ${clean_lib}")
                        list(APPEND ${libName}_COMPONENTS ${pkg_name})
                        set(${pkg_name}_ALREADY_FOUND ON CACHE INTERNAL "")
                        set(${pkg_name}_PROVIDED_TARGET "${clean_lib}" CACHE INTERNAL "")
                        break()
                    endif()
                endforeach()
                if (MATCHED)
                    break()
                endif()
            endforeach()
        endforeach()
    endif()
    set(${libName}_COMPONENTS ${${libName}_COMPONENTS} PARENT_SCOPE)

endfunction()
##
########################################################################################################################
##
macro(handleTarget _pkgname)
    string(TOLOWER "${_pkgname}" pkgnamelc)
    if (this_incdir)
        if (EXISTS "${this_incdir}")
            target_include_directories(${_pkgname} PUBLIC ${this_incdir})
            list(APPEND _IncludePathsList ${this_incdir})
        endif ()
    else ()
        if (EXISTS ${${pkgnamelc}_SOURCE_DIR}/include)
            list(APPEND _IncludePathsList ${${pkgnamelc}_SOURCE_DIR}/include)
        endif ()
    endif ()

    set(_anyTargetFound OFF)
    if (NOT ${_pkgname} IN_LIST NoLibPackages)
        list(APPEND _DefinesList USING_${this_feature})

        # 1. Check for the specific target cached by scanLibraryTargets
        # This is the "Magic" that links you to HoffSoft::magic_enum instead of fetching a new one
        if (${_pkgname}_PROVIDED_TARGET AND TARGET ${${_pkgname}_PROVIDED_TARGET})
            set(_actualTarget ${${_pkgname}_PROVIDED_TARGET})
            message(STATUS "  Linking ${_pkgname} to existing target: ${_actualTarget}")

            addTargetProperties(${_actualTarget} ${_pkgname} ON)

            # Ensure the include directories from the existing target are propagated
            get_target_property(_target_incs ${_actualTarget} INTERFACE_INCLUDE_DIRECTORIES)
            if (_target_incs)
                list(APPEND _IncludePathsList ${_target_incs})
            endif()
            set(_anyTargetFound ON)
        endif()

        # 2. Standard component check
        if (NOT _anyTargetFound)
            foreach (_component IN LISTS this_find_package_components)
                if (TARGET ${_component})
                    addTargetProperties(${_component} ${_pkgname} ON)
                    set(_anyTargetFound ON)
                endif ()
            endforeach ()
        endif()

        # 3. Standard naming fallback
        if (NOT _anyTargetFound)
            if (TARGET ${_pkgname}::${_pkgname})
                addTargetProperties(${_pkgname}::${_pkgname} ${_pkgname} ON)
                set(_anyTargetFound ON)
            elseif (TARGET ${_pkgname})
                addTargetProperties(${_pkgname} ${_pkgname} ON)
                set(_anyTargetFound ON)
            elseif (TARGET HoffSoft::${_pkgname})
                addTargetProperties(HoffSoft::${_pkgname} ${_pkgname} ON)
                set(_anyTargetFound ON)
            endif ()
        endif()
    endif ()

    # Setup source/build paths for handlers
    if (NOT this_src)
        set(this_src "${EXTERNALS_DIR}/${pkg}")
    endif ()
    if (NOT this_build)
        set(this_build "${BUILD_DIR}/_deps/${_pkglc}-build")
    endif ()

    unset(_component)
    unset(_anyTargetFound)
    unset(_pkglc)

endmacro()
##
########################################################################################################################
##
function(processFeatures featureList returnVarName)

    function(replacePositionalParameters tokenString outputVar addAllRegardless)

        set(hints)

        # Define the paths to the two configuration files
        foreach (hint IN LISTS tokenString)
            string(FIND "${hint}" "{" openBrace)
            string(FIND "${hint}" "}" closeBrace)
            if (${openBrace} LESS 0 AND ${closeBrace} LESS 0)
                list(APPEND hints "${hint}")
                continue()
            endif ()

            math(EXPR firstCharOfPkg "${openBrace} + 1")
            math(EXPR pkgNameLen "${closeBrace} - ${openBrace} - 1")
            string(SUBSTRING "${hint}" ${firstCharOfPkg} ${pkgNameLen} pkgName)

            if (MONOREPO AND MONOBUILD)
                set(SOURCE_PATH "${OUTPUT_DIR}")
            else ()
                string(REGEX REPLACE "${APP_NAME}/" "${pkgName}/" SOURCE_PATH "${OUTPUT_DIR}")
            endif ()

            set(pkgName "${pkgName}Config.cmake")

            set(candidates)
            set(conditionals)

            set(actualSourceFile "${SOURCE_PATH}/${pkgName}")
            if (EXISTS "${actualSourceFile}" OR addAllRegardless)
                if (EXISTS "${actualSourceFile}")
                    msg(NOTICE "  Found ${actualSourceFile}")
                    set(sourceFileFound ON)
                else ()
                    msg(NOTICE "Missing ${actualSourceFile} but still added it to list")
                    set(sourceFileFound OFF)
                endif ()
                list(APPEND candidates "${actualSourceFile}")
            else ()
                msg(NOTICE "Missing ${actualSourceFile}")
                set(sourceFileFound OFF)
            endif ()

            set(actualStagedFile "${STAGED_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            if (EXISTS "${actualStagedFile}" OR addAllRegardless)
                if (EXISTS "${actualStagedFile}")
                    msg(NOTICE "  Found ${actualStagedFile}")
                    set(stagedFileFound ON)
                    list(APPEND conditionals "${actualStagedFile}")
                else ()
                    msg(NOTICE "Missing ${actualStagedFile} but still added it to list")
                    set(stagedFileFound OFF)
                    list(APPEND candidates "${actualStagedFile}")
                endif ()
            else ()
                msg(NOTICE "Missing ${actualStagedFile}")
                set(stagedFileFound OFF)
            endif ()

            set(actualSystemFile "${SYSTEM_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            if (EXISTS "${actualSystemFile}" OR addAllRegardless)
                if (EXISTS "${actualSystemFile}")
                    msg(NOTICE "  Found ${actualSystemFile}")
                    set(systemFileFound ON)
                    list(APPEND conditionals "${actualSystemFile}")
                else ()
                    msg(NOTICE "Missing ${actualSystemFile} but still added it to list")
                    set(systemFileFound OFF)
                    list(APPEND candidates "${actualSystemFile}")
                endif ()
            else ()
                msg(NOTICE "Missing ${actualSystemFile}")
                set(systemFileFound OFF)
            endif ()

            # Staged and Source files are the same?
            if (NOT addAllRegardless)
                if (sourceFileFound AND stagedFileFound
                        AND ${actualSourceFile} IS_NEWER_THAN ${actualStagedFile}
                        AND ${actualStagedFile} IS_NEWER_THAN ${actualSourceFile})

                    msg(NOTICE "Source and Staged are the same. We'll use Staged.")
                    set (candidates "${actualStagedFile}")
                else ()
                    newestFile("${conditionals}" inOrder)
                    list(APPEND candidates "${inOrder}")
                endif ()
            endif ()

            set(listOfFolders)
            foreach (candidate IN LISTS candidates)
                get_filename_component(candidate "${candidate}" PATH)
                list(APPEND listOfFolders "${candidate}")
            endforeach ()

            list(APPEND hints "${listOfFolders}")

        endforeach ()

        list(REMOVE_DUPLICATES hints)
        set (${outputVar} ${hints} PARENT_SCOPE)
    endfunction()

    unset(revised_features)
    set(_switches OVERRIDE_FIND_PACKAGE)
    set(_single_args PACKAGE)
    set(_multi_args FIND_PACKAGE_ARGS COMPONENTS)
    set(_prefix AA)

    macro (_)

        set (_pkg)
        set (_ns)
        set (_kind)
        set (_method)
        set (_url)
        set (_tag)
        set (_incdir)
        set (_components)
        set (_hints)
        set (_paths)
        set (_args)
        set (_required)
        set (_prerequisites)
        set (_first_hint)
        set (_first_path)
        set (_first_component)

    endmacro()

    foreach(feature IN LISTS featureList)

        _()

        separate_arguments(feature NATIVE_COMMAND "${feature}")
        cmake_parse_arguments(${_prefix} "${_switches}" "${_single_args}" "${_multi_args}" ${feature})
        list (POP_FRONT AA_UNPARSED_ARGUMENTS _feature)
        # Sanity check

        if (AA_OVERRIDE_FIND_PACKAGE AND (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES))
            msg(ALWAYS FATAL_ERROR "APP_FEATURES: Cannot combine OVERRIDE_FIND_PACKAGE with FIND_PACKAGE_ARGS")
        endif ()

        if (AA_PACKAGE OR "PACKAGE" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA_PACKAGE}" STREQUAL "")
                set (_pkg "${AA_PACKAGE}")
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: PACKAGE keyword given with no package name")
                list(REMOVE_ITEM AA_UNPARSED_ARGUMENTS "PACKAGE")
            endif ()
        endif ()

        if (AA_OVERRIDE_FIND_PACKAGE)
            set(_args "OVERRIDE_FIND_PACKAGE")
        elseif (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            set(_args "FIND_PACKAGE_ARGS")
            if (NOT "${AA_FIND_PACKAGE_ARGS}" STREQUAL "")
                set (featureless ${feature})
                list (REMOVE_ITEM featureless "${_feature}" "FIND_PACKAGE_ARGS")
                cmake_parse_arguments("AA1" "REQUIRED;OPTIONAL" "" "COMPONENTS;PATHS;HINTS" ${featureless}) #${AA_FIND_PACKAGE_ARGS})

                if (AA1_HINTS OR "HINTS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
                    if (NOT "${AA1_HINTS}" STREQUAL "")
                        replacePositionalParameters("${AA1_HINTS}" _hints OFF)
                        if (_hints)
                            string(JOIN " " _hints "HINTS" ${_hints})
                        else ()
                            msg(ALWAYS "APP_FEATURES: No files found for HINTS in FIND_PACKAGE_ARGS HINTS")
                        endif ()
                    else ()
                        msg(ALWAYS WARNING "APP_FEATURES: FIND_PACKAGE_ARGS HINTS has no hints")
                        set (_hints)
                        list (REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "HINTS")
                    endif ()
                endif ()

                if (AA1_PATHS OR "PATHS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
                    if (NOT "${AA1_PATHS}" STREQUAL "")
                        replacePositionalParameters("${AA1_PATHS}" _paths ON)
                        if (_paths)
                            string(JOIN " " _paths "PATHS" ${_paths})
                        else ()
                            msg(ALWAYS "APP_FEATURES: No files found for PATHS in FIND_PACKAGE_ARGS PATHS")
                        endif ()
                    else ()
                        msg(ALWAYS WARNING "APP_FEATURES: FIND_PACKAGE_ARGS PATHS has no paths")
                        set (_paths)
                        list (REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "PATHS")
                    endif ()
                endif ()

                if (AA1_REQUIRED AND AA1_OPTIONAL)
                    msg(ALWAYS FATAL_ERROR "APP_FEATURES: FIND_PACKAGE_ARGS cannot contain both REQUIRED,OPTIONAL")
                endif ()

                if (AA1_REQUIRED)
                    set (_required "REQUIRED")
                endif ()

                if (AA1_OPTIONAL)
                    set (_required "OPTIONAL")
                endif ()

#                if (AA1_COMPONENTS)
#                    if (NOT "${AA1_COMPONENTS}" STREQUAL "")
#                        string (JOIN ":" _components "COMPONENTS" ${AA1_COMPONENTS})
#                    else ()
#                        msg(ALWAYS WARNING "APP_FEATURES: FIND_PACKAGE_ARGS COMPONENTS given with no components")
#                    endif ()
#                    unset(AA_COMPONENTS)
#                    list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "COMPONENTS")
#                endif ()
            else ()
                list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "FIND_PACKAGE_ARGS")
            endif ()
            string(JOIN " " _args "${_args}" ${_required} ${_hints} ${_paths} ${AA1_UNPARSED_ARGUMENTS})
        endif ()

        if (AA_COMPONENTS OR "COMPONENTS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA_COMPONENTS}" STREQUAL "")
                #            string (POP_FRONT "${AA_COMPONENTS}" _first_component)
                #            string (JOIN "," _components "COMPONENTS=${_first_component}" ${AA_COMPONENTS})
                string (JOIN ":" _components ${AA_COMPONENTS})
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: COMPONENTS keyword given with no components")
            endif ()
        endif ()

        #    FEATURE | PKGNAME | [NAMESPACE] | KIND | METHOD | URL or SRCDIR | [GIT_TAG] or BINDIR | [INCDIR] | [COMPONENT [COMPONENT [ COMPONENT ... ]]]  | [ARG [ARG [ARG ... ]]] | [PREREQ | [PREREQ | [PREREQ ... ]]]
        set (_prerequisites "")

        string (JOIN "|" feature
                "${_feature}"
                "${_pkg}"
                "${_ns}"
                "${_kind}"
                "${_method}"
                "${_url}"
                "${_tag}"
                "${_incdir}"
                "${_components}"
                "${_args}"
                "${_prereqiusites}"
        )

        list(APPEND revised_features "${feature}")

    endforeach ()

    set (${returnVarName} "${revised_features}" PARENT_SCOPE)

endfunction()