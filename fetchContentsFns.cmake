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
######################################################################################
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
######################################################################################
##
function(parsePackage pkgArray)
    set(options)
    set(one_value_args ARGS FEATURE PKG_NAME PKG_INDEX
            URL GIT_TAG
            SRC_DIR BUILD_DIR
            FETCH_FLAG INC_DIR
            COMPONENTS LIST
            KIND METHOD
            PREREQS)
    set(multi_value_args)

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

    getFeaturePackage(${pkgArray} ${A_PP_FEATURE} ${A_PP_PKG_INDEX} local)
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
    list(LENGTH pkg_deets length)
    set(${A_PP_LIST} "${pkg_deets}" PARENT_SCOPE)
    list(LENGTH pkg_deets pkg_deets_size)

    if (${pkg_deets_size} GREATER 4)
        list(GET pkg_deets 1 localNS)
        list(GET pkg_deets 2 localKind)
        list(GET pkg_deets 3 localMethod)

        set(${A_PP_KIND}   ${localKind}   PARENT_SCOPE)
        set(${A_PP_METHOD} ${localMethod} PARENT_SCOPE)

        if ("${localMethod}" STREQUAL "PROCESS")
            return()
        endif ()
    else ()
        message(WARNING "${pkg_deets_size} length pkg_deets")
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
######################################################################################
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
    set(resolved "")
    set(visited "")

    macro(visit entry)
        if (NOT "${entry}" IN_LIST visited)
            list(APPEND visited "${entry}")

            SplitAt("${entry}" "." _feat _idx)
            parsePackage("${allData}"
                    FEATURE "${_feat}"
                    PKG_INDEX "${_idx}"
                    PREREQS _pre
            )

            foreach (p IN LISTS _pre)
                # Find the corresponding entry in the input list for this prerequisite feature
                # If a specific package index wasn't specified in prereqs, default to 0
                set(found_entry "")
                foreach(e IN LISTS inputList)
                    if(e MATCHES "^${p}\\.")
                        set(found_entry "${e}")
                        break()
                    endif()
                endforeach()

                if(found_entry)
                    visit("${found_entry}")
                endif()
            endforeach()

            list(APPEND resolved "${entry}")
        endif()
    endmacro()

    foreach(item IN LISTS inputList)
        visit("${item}")
    endforeach()

    set(${outputList} "${resolved}" PARENT_SCOPE)
endfunction()


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