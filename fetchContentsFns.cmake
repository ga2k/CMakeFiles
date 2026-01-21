cmake_minimum_required(VERSION 3.28)

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

    message("addTargetProperties called for '${target}'")
    get_target_property(_aliasTarget ${target} ALIASED_TARGET)

    if (NOT ${_aliasTarget} STREQUAL "_aliasTarget-NOTFOUND")
        message("Target ${target} is an alias. Retargeting target to target ${_aliasTarget}")
        addTargetProperties(${_aliasTarget} "${pkgname}" ${addToLists})
        if(addToLists)
            set(_LibrariesList ${_LibrariesList} PARENT_SCOPE)
            set(_DependenciesList ${_DependenciesList} PARENT_SCOPE)
            set(at_LibraryPathsList ${at_LibraryPathsList} PARENT_SCOPE)
        endif ()
        return()
    endif ()

    get_target_property(_targetType ${target} TYPE)

    if (${_targetType} STREQUAL "INTERFACE_LIBRARY")
        target_compile_options("${target}" INTERFACE ${_CompileOptionsList})
        target_compile_definitions("${target}" INTERFACE "${_DefinesList}")
        target_link_options("${target}" INTERFACE "${_LinkOptionsList}")
    else ()
        get_property(is_imported TARGET ${target} PROPERTY IMPORTED)
        if (is_imported)
            target_compile_options("${target}" INTERFACE ${_CompileOptionsList})
            target_compile_definitions("${target}" INTERFACE "${_DefinesList}")
            target_link_options("${target}" INTERFACE "${_LinkOptionsList}")
        else ()
            target_compile_options("${target}" PUBLIC ${_CompileOptionsList})
            target_compile_definitions("${target}" PUBLIC "${_DefinesList}")
            target_link_options("${target}" PUBLIC "${_LinkOptionsList}")
        endif ()
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

    if (${apd_METHOD} STREQUAL "PROCESS")
        unset(apd_NAMESPACE)
        unset(apd_URL)
        unset(apd_GIT_REPOSITORY)
        unset(apd_SRCDIR)
        unset(apd_GIT_TAG)
        unset(apd_BINDIR)
        unset(apd_INCDIR)
        unset(apd_COMPONENT)
        unset(apd_ARG)
        unset(apd_COMPONENTS)
        unset(apd_ARGS)

    endif ()

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
        foreach (component IN LISTS apd_COMPONENTS)
            string(JOIN " " components "${components}" "${component}")
        endforeach ()
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
function(getFeaturePkgList array feature list_var)
    # iterate over array to find line with feature
    foreach (line IN LISTS array)
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

            set(${list_var} ${local} PARENT_SCOPE)
            return()
        endif ()
    endforeach ()
endfunction()
##
######################################################################################
##
function(getFeatureIndex array feature ix_var)
    # iterate over array to find line with feature
    set(ix -1)
    foreach (line IN LISTS "${array}")
        math(EXPR ix "${ix} + 1")
        SplitAt("${line}" "|" this_feature packages)
        if ("${this_feature}" STREQUAL "${feature}")
            set(${ix_var} ${ix} PARENT_SCOPE)
            return()
        endif ()
    endforeach ()
    set(${ix_var} -1 PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeaturePackage array feature index var)
    foreach (item IN LISTS ${array})
#    foreach (item IN LISTS array)
        SplitAt("${item}" "|" this_feature packages)
        if ("${this_feature}" STREQUAL "${feature}")
            string(REPLACE "," ";" list "${packages}")
            list(GET list ${index} package)
            set(${var} "${package}" PARENT_SCOPE)
            break()
        endif ()
    endforeach ()
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
function(parsePackage pkgArray)
    set(options)
    set(one_value_args LIST
            FEATURE PKG_NAME PKG_INDEX
            URL GIT_TAG
            SRC_DIR BUILD_DIR INC_DIR
            FETCH_FLAG
            KIND METHOD
            COMPONENTS
            PREREQS
            ARGS
    )
    set(multi_value_args
    )

    # Parse the arguments
    cmake_parse_arguments(PARSE_ARGV 1 A_PP "${options}" "${one_value_args}" "${multi_value_args}")

    if (NOT A_PP_LIST)
        message(FATAL_ERROR "parsePackage() needs LIST parameter")
    endif ()

    if (NOT A_PP_FEATURE)
        message(FATAL_ERROR "parsePackage() needs FEATURE parameter")
    endif ()

    if (NOT A_PP_PKG_INDEX AND NOT A_PP_PKG_NAME)
        set(A_PP_PKG_INDEX 0)
    elseif (A_PP_PKG_INDEX AND A_PP_PKG_NAME)
        message(FATAL_ERROR "parsePackage() both PKG_NAME and PKG_FEATURE supplied. Need one or the other")
    elseif (NOT "${A_PP_PKG_NAME}" STREQUAL "")
        getFeaturePkgList("${pkgArray}" ${A_PP_FEATURE} pkg_list)
        list(FIND pkg_list ${A_PP_PKG_NAME} A_PP_PKG_INDEX)
        set(A_PP_PKG_NAME)
    endif ()

    getFeaturePackage("${pkgArray}" ${A_PP_FEATURE} ${A_PP_PKG_INDEX} local)
    # Initialize output variables
    set(${A_PP_LIST}        "" PARENT_SCOPE)
    set(${A_PP_KIND}        "" PARENT_SCOPE)
    set(${A_PP_METHOD}      "" PARENT_SCOPE)
    set(${A_PP_URL}         "" PARENT_SCOPE)
    set(${A_PP_GIT_TAG}     "" PARENT_SCOPE)
    set(${A_PP_SRC_DIR}     "" PARENT_SCOPE)
    set(${A_PP_BUILD_DIR}   "" PARENT_SCOPE)
    set(${A_PP_FETCH_FLAG}  ON PARENT_SCOPE)
    set(${A_PP_INC_DIR}     "" PARENT_SCOPE)
    set(${A_PP_COMPONENTS}  "" PARENT_SCOPE)
    set(${A_PP_ARGS}        "" PARENT_SCOPE)
    set(${A_PP_PREREQS}     "" PARENT_SCOPE)

    string(REPLACE "|" ";" pkg_deets "${local}")
    set(${A_PP_LIST} "${pkg_deets}" PARENT_SCOPE)
    list(LENGTH pkg_deets length)

    if (${length} GREATER 4)
        list(GET pkg_deets ${PkgNamespaceIX} localNS)
        list(GET pkg_deets ${PkgKindIX}      localKind)
        list(GET pkg_deets ${PkgMethodIX}    localMethod)

        set(${A_PP_KIND}   ${localKind}   PARENT_SCOPE)
        set(${A_PP_METHOD} ${localMethod} PARENT_SCOPE)

        if ("${localMethod}" STREQUAL "PROCESS")
            return()
        endif ()
    else ()
        message(WARNING "${length} length pkg_deets")
    endif ()

    set(is_git_repo OFF)
    set(is_zip_file OFF)
    set(is_src_dir OFF)

    set(is_git_tag OFF)
    set(is_build_dir OFF)

    if (A_PP_URL AND ${PkgUrlIX} LESS ${length})
        list(GET pkg_deets ${PkgUrlIX} temp)
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
        list(GET pkg_deets ${PkgGitTagIX} temp)
        set(${A_PP_GIT_TAG} ${temp} PARENT_SCOPE)
    endif ()

    if (A_PP_SRC_DIR AND is_src_dir AND ${PkgSrcDirIX} LESS ${length})
        list(GET pkg_deets ${PkgSrcDirIX} temp)
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
        list(GET pkg_deets ${PkgBuildDirIX} temp)
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
        list(GET pkg_deets ${PkgIncDirIX} temp)
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
            list(GET pkg_deets ${PkgComponentsIX} temp)
            if (NOT "${temp}" STREQUAL "")
                string(REGEX REPLACE " " ";" temp ${temp})
                set(${A_PP_COMPONENTS} ${temp} PARENT_SCOPE)
            endif ()
        else ()
            set(${A_PP_COMPONENTS} "" PARENT_SCOPE)
        endif ()
    endif ()

    if (A_PP_ARGS)
        if (${PkgArgsIX} LESS ${length})
            list(GET pkg_deets ${PkgArgsIX} temp)
            if (NOT "${temp}" STREQUAL "")
                string(REGEX REPLACE " " ";" temp ${temp})
                set(${A_PP_ARGS} ${temp} PARENT_SCOPE)
            endif ()
        else ()
            set(${A_PP_ARGS} "" PARENT_SCOPE)
        endif ()
    endif ()

    if (A_PP_PREREQS)
        if (${PkgPrereqsIX} LESS ${length})
            list(GET pkg_deets ${PkgPrereqsIX} temp)
            if (NOT "${temp}" STREQUAL "")
                string(REGEX REPLACE " " ";" temp ${temp})
                set(${A_PP_PREREQS} ${temp} PARENT_SCOPE)
            endif ()
        else ()
            set(${A_PP_PREREQS} "" PARENT_SCOPE)
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

function(resolveDependencies inputList allData outputList)
    set(current_input "${inputList}")
    set(ooo ON)

    while(ooo)
        set(ooo OFF)
        set(local_output "")

        foreach(CI IN LISTS current_input)
            # Get prerequisites for the Current Item
            SplitAt("${CI}" "." _feat _idx)
            parsePackage("${allData}"
                    FEATURE "${_feat}"
                    PKG_INDEX "${_idx}"
                    PREREQS _pre
                    LIST _dnc
            )

            foreach(PR_ENTRY IN LISTS _pre)
                # Handle FEATURE=PACKAGE syntax
                string(FIND "${PR_ENTRY}" "=" eq_pos)
                if (eq_pos GREATER -1)
                    string(SUBSTRING "${PR_ENTRY}" 0 ${eq_pos} PR_FEAT)
                else()
                    set(PR_FEAT "${PR_ENTRY}")
                endif()

                # Is the prerequisite already in our new output list?
                set(found_in_output OFF)
                foreach(check IN LISTS local_output)
                    if(check MATCHES "^${PR_FEAT}\\.")
                        set(found_in_output ON)
                        break()
                    endif()
                endforeach()

                if(NOT found_in_output)
                    # Not in output yet. Is it anywhere in the input list?
                    set(found_entry_in_input "")
                    foreach(e IN LISTS current_input)
                        if(e MATCHES "^${PR_FEAT}\\.")
                            set(found_entry_in_input "${e}")
                            break()
                        endif()
                    endforeach()

                    if(found_entry_in_input)
                        # Add PR to output now, before CI
                        list(APPEND local_output "${found_entry_in_input}")
                        set(ooo ON)
                    else()
                        # Step 6: Prerequisite not found in input list
                        message(AUTHOR_WARNING "Feature '${_feat}' requires '${PR_FEAT}', but '${PR_FEAT}' is not in the feature list.")
                    endif()
                endif()
            endforeach()

            # Add CI itself to output if not already added by a dependency check
            if(NOT "${CI}" IN_LIST local_output)
                list(APPEND local_output "${CI}")
            endif()
        endforeach()

        if(ooo)
            set(current_input "${local_output}")
        endif()
    endwhile()

    set(${outputList} "${current_input}" PARENT_SCOPE)
endfunction()
##
########################################################################################################################
##
function(scanLibraryTargets libName)
    set(targetName "HoffSoft::${libName}")
    if (NOT TARGET ${targetName})
        return()
    endif()

    message(STATUS "Scanning ${targetName} for transitive 3rd-party targets...")

    get_target_property(libs ${targetName} INTERFACE_LINK_LIBRARIES)
    if (libs)
        foreach(lib IN LISTS libs)
            # Check if this link library is one of our known package targets
            # e.g., soci::soci or magic_enum::magic_enum
            foreach(feature_data IN LISTS AllPackageData)
                SplitAt("${feature_data}" "|" feat_name packages)
                string(REPLACE "," ";" package_list "${packages}")
                foreach(pkg IN LISTS package_list)
                    SplitAt("${pkg}" "|" pkg_name ns)
                    # Check against the target name, the namespace::target, or the raw name
                    if ("${lib}" STREQUAL "${pkg_name}" OR "${lib}" STREQUAL "${ns}::${pkg_name}")
                        message(STATUS "  Feature '${feat_name}' is supplied by ${libName}")
                        set(${pkg_name}_ALREADY_FOUND ON CACHE INTERNAL "")
                    endif()
                endforeach()
            endforeach()
        endforeach()
    endif()
endfunction()
##
########################################################################################################################
##
macro(handleTarget)
    if (this_incdir)
        if (EXISTS "${this_incdir}")
            target_include_directories(${this_pkgname} PUBLIC ${this_incdir})
            list(APPEND _IncludePathsList ${this_incdir})
        endif ()
    else ()
        if (EXISTS ${${this_pkglc}_SOURCE_DIR}/include)
            list(APPEND _IncludePathsList ${${this_pkglc}_SOURCE_DIR}/include)
        endif ()
    endif ()

    set(_anyTargetFound OFF)
    if (NOT ${this_pkgname} IN_LIST NoLibPackages)
        list(APPEND _DefinesList USING_${this_feature})
        foreach (_component IN LISTS this_find_package_components)
            if (TARGET ${_component})
                addTargetProperties(${_component} ${this_pkgname} ON)
                set(_anyTargetFound ON)
            endif ()
        endforeach ()
        if (TARGET ${this_pkgname}::${this_pkgname} AND NOT _anyTargetFound)
            addTargetProperties(${this_pkgname}::${this_pkgname} ${this_pkgname} ON)
            set(_anyTargetFound ON)
        endif ()
        if (TARGET ${this_pkgname} AND NOT _anyTargetFound)
            addTargetProperties(${this_pkgname} ${this_pkgname} ON)
            set(_anyTargetFound ON)
        endif ()
    endif ()
    if (NOT _anyTargetFound)
#        list(APPEND _LibrariesList ${this_pkgname})
    endif ()

    # Setup source/build paths for handlers
    if (NOT this_src)
        set(this_src "${EXTERNALS_DIR}/${this_pkgname}")
    endif ()
    if (NOT this_build)
        set(this_build "${BUILD_DIR}/_deps/${this_pkglc}-build")
    endif ()

    unset(_component)
    unset(_anyTargetFound)

endmacro()
