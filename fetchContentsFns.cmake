include_guard(GLOBAL)

include(${CMAKE_SOURCE_DIR}/cmake/tools.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/sqlish.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/global.cmake)

# @formatter:off
set(PkgColNames FeatureName PackageName IsDefault Namespace Kind Method Url GitRepository GitTag SrcDir BuildDir IncDir Components Args Prereq)
set(FIXName          0)
set(FIXPkgName       1)
set(FIXIsDefault     2)
set(FIXNamespace     3)
set(FIXKind          4)
set(FIXMethod        5)
set(FIXUrl           6)
set(FIXGitRepository 7)
set(FIXGitTag        8)
set(FIXSrcDir        9)
set(FIXBuildDir     10)
set(FIXIncDir       11)
set(FIXComponents   12)
set(FIXArgs         13)
set(FIXPrereqs      14)
math(EXPR FIXLength "${FIXPrereqs} + 1")

CREATE(TABLE tbl_LongestStrings
    COLUMNS (VERB OBJECT SUBJECT_PREP SUBJECT ITEM_PREP ITEM HANDLER)
)
INSERT(INTO tbl_LongestStrings VALUES (0 0 0 0 0 0 0))
include(FetchContent)

function(textOut VERB OBJECT SUBJECT_PREP SUBJECT ITEM_PREP ITEM TEMPLATE DRY_RUN)
    macro(_doLine _var_)
        set(arg "${${_var_}}")
        if (current_tag STREQUAL "OBJECT" OR current_tag STREQUAL "SUBJECT")
        endif ()
        SELECT(${current_tag} AS _longest FROM tbl_LongestStrings WHERE ROWID = 1)
        if (current_tag STREQUAL "VERB" OR current_tag STREQUAL "SUBJECT_PREP")
            list(LENGTH arg knowns)
            if (knowns GREATER 1)
                # This is a list of known verbs
                foreach (one IN LISTS arg)
                    longest(${GAP} MIN_LENGTH ${MIN_LENGTH} ${JUSTIFY} CURRENT ${_longest} PAD_CHAR "${PAD_CHAR}" TEXT "${one}" PADDED ${current_tag} LONGEST _longest)
                endforeach ()
                list(GET arg 0 arg)
            endif ()
        endif ()
        longest(${GAP} MIN_LENGTH ${MIN_LENGTH} ${JUSTIFY} CURRENT ${_longest} PAD_CHAR "${PAD_CHAR}" TEXT "${arg}" PADDED ${current_tag} LONGEST _longest)
        UPDATE(tbl_LongestStrings SET ${current_tag} = "${_longest}" WHERE ROWID = 1)
    endmacro()

    set(outstr "${TEMPLATE}")

    string(REGEX MATCHALL "\\[[_A-Z]+:[^]]+\\]" placeholders "${TEMPLATE}")

    foreach (item ${placeholders})
        if (item MATCHES "\\[([_A-Z]+):([LCR])\\]")
            set(current_tag ${CMAKE_MATCH_1}) # e.g. VERB
            set(current_align ${CMAKE_MATCH_2}) # e.g. R

            if (current_align STREQUAL "L")
                set(JUSTIFY "LEFT")
            elseif (current_align STREQUAL "C")
                set(JUSTIFY "CENTRE")
            elseif (current_align STREQUAL "R")
                set(JUSTIFY "RIGHT")
            else ()
                unset(JUSTIFY)
            endif ()

            # Reminder:
            # set(TEMPLATE "[VERB:R] [OBJECT:L] [SUBJECT_PREP:R] [SUBJECT:L] [ITEM_PREP:R] [TARGET:R]")

            if (current_tag STREQUAL "VERB")
                _doLine("VERB")
                SplitAt("${VERB}" " " action thing)
                if (VERB MATCHES "created")
                    set(VERB "${BOLD}${YELLOW}${action}${NC} ${thing}")
                elseif (VERB MATCHES "added")
                    set(VERB "${BOLD}${WHITE}{action}${NC} {thing}")
                elseif (VERB MATCHES "replaced")
                    set(VERB "${BOLD}${RED}${action}${NC} ${thing}")
                elseif (VERB MATCHES "extended")
                    set(VERB "${BOLD}${CYAN}${action}${NC} ${thing}")
                elseif (VERB MATCHES "skipped")
                    set(VERB "${BOLD}${BLUE}${action}${NC} ${thing}")
                elseif (VERB MATCHES "calling")
                    set(VERB "${BOLD}${GREEN}${action}${NC} ${thing}")
                endif ()
            elseif (current_tag STREQUAL "OBJECT")
                _doLine(OBJECT)
                set(OBJECT "${BOLD}${OBJECT}${NC}")
            elseif (current_tag STREQUAL "SUBJECT_PREP")
                _doLine(SUBJECT_PREP)
                SplitAt("${SUBJECT_PREP}" " " actionic thingic)
                set(SUBJECT_PREP "${NC}${actionic} ${BOLD}${MAGENTA}${thingic}${NC}")
            elseif (current_tag STREQUAL "SUBJECT")
                _doLine(SUBJECT)
                set(SUBJECT "${BOLD}${YELLOW}${SUBJECT}${NC}")
            elseif (current_tag STREQUAL "ITEM_PREP")
                _doLine(ITEM_PREP)
            elseif (current_tag STREQUAL "ITEM")
                _doLine(ITEM)
                set(ITEM "${BLUE}${ITEM}${NC}")
            endif ()
        endif ()
    endforeach ()
    # @formatter:off
    string(REGEX REPLACE "\\[VERB:[^]]*\\]"         "${VERB} "           outstr "${outstr}")
    string(REGEX REPLACE "\\[OBJECT:[^]]*\\]"       "${OBJECT} "         outstr "${outstr}")
    string(REGEX REPLACE "\\[SUBJECT_PREP:[^]]*\\]" "${SUBJECT_PREP} "   outstr "${outstr}")
    string(REGEX REPLACE "\\[SUBJECT:[^]]*\\]"      "${SUBJECT} "        outstr "${outstr}")
    string(REGEX REPLACE "\\[ITEM_PREP:[^]]*\\]"    "${ITEM_PREP} "      outstr "${outstr}")
    string(REGEX REPLACE "\\[ITEM:[^]]*\\]"         "${ITEM} "           outstr "${outstr}")
    # @formatter:on

    if (NOT DRY_RUN)
        msg("${outstr}")
    endif ()

endfunction()

function(addTargetProperties target pkgname addToLists)

    unset(at_LibrariesList)
    unset(at_DependenciesList)
    unset(at_LibraryPathsList)

    msg(" ")
    msg("addTargetProperties called for '${target}'")
    get_target_property(_aliasTarget ${target} ALIASED_TARGET)

    if (NOT ${_aliasTarget} STREQUAL "_aliasTarget-NOTFOUND")
        msg("Target ${target} is an alias. Retargeting target to target target ${_aliasTarget}")
        addTargetProperties(${_aliasTarget} "${pkgname}" ${addToLists})
        if (addToLists)
            set(_LibrariesList ${_LibrariesList} PARENT_SCOPE)
            set(_DependenciesList ${_DependenciesList} PARENT_SCOPE)
            set(at_LibraryPathsList ${_LibraryPathsList} PARENT_SCOPE)
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

    target_compile_options("${target}" ${LIB_TYPE} "${_CompileOptionsList}")
    target_compile_definitions("${target}" ${LIB_TYPE} "${_DefinesList}")
    target_link_options("${target}" ${LIB_TYPE} "${_LinkOptionsList}")

    if (WIN32)
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

    list(APPEND at_LibrariesList ${_LibrariesList})
    list(APPEND at_LibraryPathsList ${_LibraryPathsList})
    list(APPEND at_DependenciesList ${_DependenciesList})

    set(_LibrariesList ${at_LibrariesList} PARENT_SCOPE)
    set(_LibraryPathsList ${at_LibraryPathsList} PARENT_SCOPE)
    set(_DependenciesList ${at_DependenciesList} PARENT_SCOPE)

endfunction()

#######################################################################################################################
#######################################################################################################################
#######################################################################################################################
function(initialiseFeatureHandlers DRY_RUN)
    if (MONOREPO)
        file(GLOB_RECURSE handlers "${CMAKE_SOURCE_DIR}/${APP_VENDOR}/cmake/handlers/*.cmake")
    else ()
        file(GLOB_RECURSE handlers "${CMAKE_SOURCE_DIR}/cmake/handlers/*.cmake")
    endif ()

    foreach (handler IN LISTS handlers)
        get_filename_component(handlerName "${handler}" NAME_WE)
        get_filename_component(_path "${handler}" DIRECTORY)
        get_filename_component(packageName "${_path}" NAME_WE)

        textOut("added handler" "${handlerName}" "for package" "${packageName}" "" ""
                "[VERB:R][OBJECT:L][SUBJECT_PREP:R][SUBJECT:L][ITEM_PREP:R][ITEM:L]" ${DRY_RUN})
        if (${handlerName} STREQUAL "init")
            textOut("calling handler" "${handlerName}" "for package" "${packageName}" "" ""
                    "[VERB:R][OBJECT:L][SUBJECT_PREP:R][SUBJECT:L][ITEM_PREP:R][ITEM:L]" ${DRY_RUN})
        endif ()
        if(NOT DRY_RUN)
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
        endif ()
    endforeach ()
endfunction()
########################################################################################################################
########################################################################################################################
########################################################################################################################
function(addPackageData)

    # During a DRY_RUN, all data is checked, and field sized for tabulated output are computed,
    # but no data is actually stored.

    set(switches SYSTEM LIBRARY OPTIONAL PLUGIN CUSTOM)
    set(args METHOD FEATURE PKGNAME NAMESPACE URL GIT_REPOSITORY SRCDIR GIT_TAG BINDIR INCDIR COMPONENT ARG PREREQ DRY_RUN)
    set(arrays COMPONENTS ARGS FIND_PACKAGE_ARGS PREREQS)

    cmake_parse_arguments("APD" "${switches}" "${args}" "${arrays}" ${ARGN})

    set(methods FIND_PACKAGE FETCH_CONTENTS PROCESS IGNORE)
    if (NOT APD_METHOD)
        set(APD_METHOD IGNORE)
    endif ()

    if (NOT APD_METHOD IN_LIST methods)
        msg(ALWAYS FATAL_ERROR "addPackageData: One of METHOD ${BOLD}${methods}${NC} required for ${APD_FEATURE}")
    endif ()

    set(types_of_thing 0)
    foreach (thing SYSTEM OPTIONAL LIBRARY PLUGIN CUSTOM)
        if (APD_${thing})
            inc(types_of_thing)
            set(APD_KIND ${thing})
        endif ()
    endforeach ()

    if (types_of_thing EQUAL 0)
        set(APD_OPTIONAL ON)
        set(APD_KIND OPTIONAL)
    elseif (types_of_thing GREATER 1)
        msg(ALWAYS FATAL_ERROR "addPackageData: Zero or one of SYSTEM/OPTIONAL/LIBRARY/PLUGIN/CUSTOM allowed")
    endif ()

    if (NOT APD_PKGNAME AND NOT APD_PLUGIN)
        msg(ALWAYS FATAL_ERROR "addPackageData: PKGNAME required")
    endif ()
    if (
    (APD_URL AND APD_GIT_REPOSITORY) OR
    (APD_URL AND APD_SRCDIR) OR
    (APD_GIT_REPOSITORY AND APD_SRCDIR)
    )
        msg(ALWAYS FATAL_ERROR "addPackageData: Only one of URL/GIT_REPOSITORY/SRCDIR allowed")
    endif ()

    if (NOT APD_URL AND NOT APD_GIT_REPOSITORY AND NOT APD_SRCDIR AND APD_METHOD STREQUAL "FETCH_CONTENTS")
        msg(ALWAYS FATAL_ERROR "addPackageData: One of URL/GIT_REPOSITORY/SRCDIR required")
    endif ()

    if ((APD_GIT_REPOSITORY AND NOT APD_GIT_TAG) OR (NOT APD_GIT_REPOSITORY AND APD_GIT_TAG))
        msg(ALWAYS FATAL_ERROR "addPackageData: Neither or both GIT_REPOSITORY/GIT_TAG allowed")
    endif ()

    if ((APD_URL AND APD_GIT_TAG) OR (APD_SRCDIR AND APD_GIT_TAG))
        msg(ALWAYS FATAL_ERROR "addPackageData: GIT_TAG only allowed with GIT_REPOSITORY")
    endif ()

    if (APD_GIT_TAG AND APD_BINDIR)
        msg(ALWAYS FATAL_ERROR "addPackageData: Only one of GIT_TAG or BINDIR allowed")
    endif ()

    if (APD_COMPONENT)
        list(APPEND APD_COMPONENTS ${APD_COMPONENT})
    endif ()

    if (APD_ARG)
        list(APPEND APD_ARGS ${APD_ARG})
    endif ()

    if (APD_PREREQ)
        list(APPEND APD_PREREQS ${APD_PREREQ})
    endif ()

    string(REPLACE ";" "&" APD_COMPONENTS "${APD_COMPONENTS}")
    string(JOIN "&" APD_ARGS ${APD_ARGS} ${APD_FIND_PACKAGE_ARGS})
    if (APD_PREREQS)
        string(REPLACE ";" "&" APD_PREREQS "${APD_PREREQS}")
    endif ()

    if (NOT APD_DRY_RUN)
        DROP(TABLE newRecord QUIET UNRESOLVED)
        CREATE(TABLE newRecord COLUMNS (${PkgColNames}))
        INSERT(INTO newRecord VALUES (
                "${APD_FEATURE}"
                "${APD_PKGNAME}"
                OFF
                "${APD_NAMESPACE}"
                "${APD_KIND}"
                "${APD_METHOD}"
                "${APD_URL}"
                "${APD_GIT_REPOSITORY}"
                "${APD_GIT_TAG}"
                "${APD_SRCDIR}"
                "${APD_BINDIR}"
                "${APD_INCDIR}"
                "${APD_COMPONENTS}"
                "${APD_ARGS}"
                "${APD_PREREQS}")
        )
    endif ()
    function(insertFeature)


        set(switches QUIET QUITE)
        set(args TARGET LIBRARY FEATURE PACKAGE RECORD TEMPLATE)

        cmake_parse_arguments("CAT" "${switches}" "${args}" "${lists}" ${ARGN})

        if (NOT CAT_TARGET OR "${CAT_TARGET}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no TARGET in call to insertFeature()")
        endif ()

        if (NOT CAT_FEATURE OR "${CAT_FEATURE}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no FEATURE in call to insertFeature()")
        endif ()

        if (NOT CAT_PACKAGE OR "${CAT_PACKAGE}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no PACKAGE in call to insertFeature()")
        endif ()

        if (NOT CAT_RECORD OR "${CAT_RECORD}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no RECORD in call to insertFeature()")
        endif ()

        if (NOT CAT_LIBRARY OR "${CAT_LIBRARY}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no LIBRARY in call to insertFeature()")
        endif ()

        set(out_verb)
        set(out_object)
        set(out_subject_prep)
        set(out_subject)
        set(out_item_prep)
        set(out_item "${CAT_TARGET}")
        set(out_template "${CAT_TEMPLATE}")

        if (NOT APD_DRY_RUN)
            globalObjGet("_HS_APD_SETVARS" _yetToUnset)
            if (_yetToUnset)
                foreach (var IN LISTS _yetToUnset)
                    globalObjUnset(${var})
                endforeach ()
                globalObjUnset("_HS_APD_SETVARS")
            endif ()
        endif ()

        globalObjGet("_HS_APD_${CAT_FEATURE}" _FeatureExists)
        if (_FeatureExists)
            globalObjGet("${CAT_FEATURE}_${CAT_PACKAGE}" _PackageExists)
            if (_PackageExists)
                set(out_verb "skipped package")
                set(out_object "${CAT_PACKAGE}")
                set(out_subject_prep "in feature")
                set(out_subject "${CAT_FEATURE}")
                set(out_item_prep "")
                set(out_item "")
                set(out_template "${cat_template} : ${GREEN}already added${NC}")
                set(insertRow OFF)
            else ()
                set(out_verb "added package")
                set(out_object "${CAT_PACKAGE}")
                set(out_subject_prep "to feature")
                set(out_subject "${CAT_FEATURE}")
                set(out_item_prep "in")
                globalObjSet("_HS_APD_${CAT_FEATURE}_${CAT_PACKAGE}" ON)
                set(insertRow ON)
                set(isDefault 0)
            endif ()
        else ()
            set(out_verb "created feature")
            set(out_object "${CAT_FEATURE}")
            set(out_subject_prep "with package")
            set(out_subject "${CAT_PACKAGE}")
            set(out_item_prep "in")
            globalObjSet("_HS_APD_${CAT_FEATURE}" ON)
            globalObjSet("_HS_APD_${CAT_FEATURE}_${CAT_PACKAGE}" ON)
            set(insertRow ON)
            set(isDefault 1)
        endif ()

        if (APD_DRY_RUN)
            globalObjAppendUnique("_HS_APD_SETVARS" "_HS_APD_${CAT_FEATURE}")
            globalObjAppendUnique("_HS_APD_SETVARS" "_HS_APD_${CAT_FEATURE}_${CAT_PACKAGE}")
        else ()
            if (insertRow)
                SELECT(ROW AS newData FROM ${CAT_RECORD} WHERE ROWID = 1)
                list(REMOVE_AT newData ${FIXIsDefault})
                list(INSERT newData ${FIXIsDefault} "${isDefault}")
                _hs_sql_fields_to_storage(newData _1)
                INSERT(INTO ${CAT_TARGET} VALUES (${_1}))
            endif ()
        endif ()

        textOut("${out_verb}"
                "${out_object}"
                "${out_subject_prep}"   "${out_subject}"
                "${out_item_prep}"      "${out_item}"
                "${out_template}"        ${APD_DRY_RUN})

    endfunction()

    insertFeature(TARGET "allFeatures"
            FEATURE "${APD_FEATURE}"
            PACKAGE "${APD_PKGNAME}"
            LIBRARY "${APD_KIND}"
            RECORD newRecord
            TEMPLATE "[VERB:R][OBJECT:L][SUBJECT_PREP:R][SUBJECT:L][ITEM_PREP:R][ITEM:L]"
    )

endfunction()

########################################################################################################################
##
## parsePackage can be called with a    * A table of features, or
##                                      * A single row represnting a feature/package
##
## If INPUT_TYPE is provided, we'll verify that
## If INPUT_TYPE is not provided, we'll work it out
##
function(parsePackage)
    set(options)
    set(one_value_args
            # @formatter:off
#           Keyword         Type        Direction   Description
            INPUT_TYPE  #   STRING      IN          Type of list supplied in inputListName
                        #                           One of (TABLE ROW).
                        #                           If omitted, an attempt to determine it will be made
            FEATURE     #   STRING      IN          Feature to select from inputList
                        #                           If INPUT_TYPE is ROW, FEATURE is ignored
            PACKAGE     #   STRING      IN          Package to select by name from Feature
                        #                           If INPUT_TYPE is ROW, PKG_NAME is ignored
            ARGS        #   VARNAME     OUT         Receive a copy of the ARG attribute in CMake LIST format
            BUILD_DIR   #   VARNAME     OUT         Receive a copy of the BUILDDIR attribute (if applicable)
            COMPONENTS  #   VARNAME     OUT         Receive a copy of the COMPONENT attribute in CMake LIST format
            GIT_REPO    #   VARNAME     OUT         Receive a copy of the GIT_REPOSITORY attribute (if applicable)
            GIT_TAG     #   VARNAME     OUT         Receive a copy of the GIT_TAG attribute (if applicable)
            INC_DIR     #   VARNAME     OUT         Receive a copy of the INCDIR attribute (if applicable)
            IS_DEFAULT  #   VARNAME     OUT         Receive a copy of the IS_DEFAULT attribute (if applicable)
            KIND        #   VARNAME     OUT         Receive a copy of the KIND attribute (SYSTEM/LIBRARY/OPTIONAL/PLUGIN/CUSTOM)
            METHOD      #   VARNAME     OUT         Receive a copy of the METHOD attribute (FETCH_CONTENT/FIND_PACKAGE/PROCESS)
            NAME        #   VARNAME     OUT         Receive a copy of the package name
            NAMESPACE   #   VARNAME     OUT         Receive a copy of the NAMESPACE attribute (if applicable)
            OUTPUT      #   VARNAME     OUT         Receive a copy of the entire PACKAGE
            PREREQS     #   VARNAME     OUT         Receive a copy of the PREREQ attribute in CMake LIST format
            SRC_DIR     #   VARNAME     OUT         Receive a copy of the SRCDIR attribute (if applicable)
            URL         #   VARNAME     OUT         Receive a copy of the URL attribute (if applicable)
            FETCH_FLAG  #   VARNAME     OUT         Indication that this PACKAGE needs to be downloaded somehow
    )
    # @formatter:on

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

    set(aTable)
    set(aRow)
    set(aDeducedType)

    set(local)

    macro(deduceType QUIET)
        SELECT(COUNT AS __rows FROM ${inputListName})
        if (__rows GREATER 1)
            # Looking like a table... There is more than one row. Let's check some more
            set(aDeducedType "TABLE")
            set(aTable ON)
            SELECT(ROW AS __temp_row FROM ${inputListName} WHERE ROWID = 1)
        else ()
            # Probably a row... Time will tell
            set(aDeducedType "ROW")
            set(aRow ON)
            set(__temp_row ${inputListName})
        endif ()
        # We "have" a "ROW" in "__temp_row", either the first row of the "TABLE", or the supplied "ROW" from the caller
        list(LENGTH __temp_row __fields)
        if (NOT __fields EQUAL ${FIXLength})
            if (NOT QUIET)
                set(inputListVerifyFailed "INPUT_TYPE needed, I can't determine if ${inputListName} is a TABLE or a ROW")
            endif ()
            set(aDeductedType "MYSTERY")
            set(aTable OFF)
            set(aRow OFF)

        endif ()
        unset(__rows)
        unset(__temp_row)
        unset(__fields)
    endmacro()
    macro(inputTypeToObjectType)
        if (A_PP_INPUT_TYPE MATCHES "TABLE")
            deduceType(ON)
            if (aDeducedType STREQUAL "TABLE")
                set(aTable ON)
            else ()
                set(inputListVerifyFailed "You say \"${inputListName}\" is a \"${A_PP_INPUT_TYPE}\", I think it is a ${aDeducedType}. One of us is wrong")
            endif ()
        elseif (A_PP_INPUT_TYPE MATCHES "ROW")
            deduceType(ON)
            if (aDeducedType STREQUAL "ROW")
                set(aRow ON)
            else ()
                set(inputListVerifyFailed "You say \"${inputListName}\" is a \"${A_PP_INPUT_TYPE}\", I think it is a ${aDeducedType}. One of us is wrong")
            endif ()
        elseif (NOT aDeductedType)
            deduceType(OFF)
            if (aDeductedType STREQUAL "TABLE")
                set(aRow OFF)
                set(aTable ON)
            elseif (aDeductedType STREQUAL "ROW")
                set(aRow ON)
                set(aTable OFF)
            endif ()
        else ()
            set(inputListVerifyFailed "INPUT_TYPE of \"${A_PP_INPUT_TYPE}\" unknown - needs to be TABLE, ROW, or left out and I'll work it out myself")
        endif ()
    endmacro()

    inputTypeToObjectType()

    if (aTable AND NOT A_PP_FEATURE)
        list(APPEND inputListVerifyFailed "parsePackage() needs FEATURE parameter")
    endif ()

    if (aTable AND NOT A_PP_PACKAGE)
        list(APPEND inputListVerifyFailed "parsePackage() needs PACKAGE or PKG_INDEX parameter")
    endif ()

    if (inputListVerifyFailed)
        list(PREPEND inputListVerifyFailed "${RED}${BOLD}parsePackage() FAIL:${NC}")
        string(JOIN "\n\n" __error_string ${inputListVerifyFailed})

        msg(ALWAYS FATAL_ERROR "${inputListVerifyFailed}")
    endif ()

    if (aTable)
        SELECT(ROW AS local
                FROM ${features}
                WHERE FeatureName = ${A_PP_FEATURE}
                AND PackageName = ${A_PP_PACKAGE}
        )
    else ()
        set(local ${${inputListName}})
    endif ()

    # @formatter:off
    list(GET local ${FIXName}           localFeatureName)
    list(GET local ${FIXPkgName}        localPackageName)
    list(GET local ${FIXIsDefault}      localIsDefault)
    list(GET local ${FIXNamespace}      localNS)
    list(GET local ${FIXKind}           localKind)
    list(GET local ${FIXMethod}         localMethod)
    list(GET local ${FIXUrl}            localURL)
    list(GET local ${FIXGitRepository}  localGitRepo)
    list(GET local ${FIXGitTag}         localGitTag)
    list(GET local ${FIXSrcDir}         localSrcDir)
    list(GET local ${FIXBuildDir}       localBuildDir)
    list(GET local ${FIXIncDir}         localIncDir)
    list(GET local ${FIXComponents}     localComponents)
    list(GET local ${FIXArgs}           localArgs)
    list(GET local ${FIXPrereqs}        localPrereqs)
    set(localFetchFlag ON)
    # Initialize output variables
    if (DEFINED A_PP_OUTPUT)
        set(${A_PP_OUTPUT}      "${local}"          PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_NAME)
        set(${A_PP_NAME}        ${localName}        PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_NAME)
        set(${A_PP_NAME}        ${localName}        PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_IS_DEFAULT)
        set(${A_PP_IS_DEFAULT}  ${localIsDefault}   PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_INDEX)
        set(${A_PP_INDEX}       ${localIndex}       PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_NAMESPACE)
        set(${A_PP_NAMESPACE}   ${localNS}          PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_KIND)
        set(${A_PP_KIND}        ${localKind}        PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_METHOD)
        set(${A_PP_METHOD}      ${localMethod}      PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_URL)
        set(${A_PP_URL}         ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_GIT_REPO)
        set(${A_PP_GIT_REPO}    ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_GIT_TAG)
        set(${A_PP_GIT_TAG}     ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_SRC_DIR)
        set(${A_PP_SRC_DIR}     ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_BUILD_DIR)
        set(${A_PP_BUILD_DIR}   ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_INC_DIR)
        set(${A_PP_INC_DIR}     ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_COMPONENTS)
        set(${A_PP_COMPONENTS}  ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_ARGS)
        set(${A_PP_ARGS}        ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_PREREQS)
        set(${A_PP_PREREQS}     ""                  PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_FETCH_FLAG)
        set(${A_PP_FETCH_FLAG}  ON                  PARENT_SCOPE)
    endif ()
    # @formatter:on

    set(is_git_repo OFF)
    set(is_git_tag OFF)
    set(is_zip_file OFF)
    set(is_src_dir OFF)
    set(is_build_dir OFF)
    set(is_fetched ON)

    if (localURL)
        if ("${localURL}" MATCHES ".*\.zip$" OR "${localURL}" MATCHES ".*\.tar$" OR "${localURL}" MATCHES ".*\.gz$")
            if ("${localURL}" MATCHES "^http.*")
                set(is_fetched ON)
            else ()
                set(is_fetched OFF)
            endif ()
            set(is_zip_file ON)
        else ()
            set(is_zip_file OFF)
        endif ()
        set(is_url ON)
        set(${A_PP_URL} "${localURL}" PARENT_SCOPE)
        set(${A_PP_FETCH_FLAG} "${is_fetched}" PARENT_SCOPE)
    endif ()

    if (localGitRepo)
        if ("${localGitRepo}" MATCHES "^http.*")
            set(is_fetched ON)
        else ()
            set(is_fetched OFF)
        endif ()
        set(is_git_repo ON)
        set(is_git_tag ON)
        set(is_build_dir OFF)

        set(${A_PP_GIT_REPO} "${localGitRepo}" PARENT_SCOPE)
        set(${A_PP_FETCH_FLAG} "${is_fetched}" PARENT_SCOPE)
    endif ()

    if (localGitTag AND is_git_tag)
        set(${A_PP_GIT_TAG} "${localGitTag}" PARENT_SCOPE)
    endif ()

    if (A_PP_SRC_DIR AND localSrcDir)
        string(FIND "${localSrcDir}" "[" open_bracket)
        string(FIND "${localSrcDir}" "]" close_bracket)
        if (open_bracket GREATER_EQUAL 0 AND close_bracket GREATER ${open_bracket})
            math(EXPR one_past_open_bracket "${open_bracket} + 1")
            math(EXPR one_before_close_bracket "${close_bracket} - 1")
            math(EXPR one_past_close_bracket "${close_bracket} + 1")
            math(EXPR dirroot_length "${one_before_close_bracket} - ${one_past_open_bracket} + 1")
            string(SUBSTRING "${localSrcDir}" ${one_past_open_bracket} ${dirroot_length} dirroot)
            string(SUBSTRING "${localSrcDir}" ${one_past_close_bracket} -1 src_folder)

            if (${dirroot} STREQUAL "SRC")
                set(${A_PP_SRC_DIR} ${EXTERNALS_DIR}/${src_folder} PARENT_SCOPE)
                set(src_ok ON)
            elseif (${dirroot} STREQUAL "BUILD")
                set(${A_PP_SRC_DIR} ${BUILD_DIR}/_deps/${src_folder} PARENT_SCOPE)
                set(src_ok ON)
            else ()
                msg(ALWAYS FATAL_ERROR "Bad SRCDIR for ${this_pkgname} (${localSrcDir}): Must start with \"[SRC]\" or \"[BUILD]\"")
            endif ()
        else ()
            set(src_ok ON)
        endif ()
    else ()
        set(src_ok OFF)
    endif ()

    if (A_PP_BUILD_DIR AND localBuildDir)
        string(FIND "${localBuildDir}" "[" open_bracket)
        string(FIND "${localBuildDir}" "]" close_bracket)
        if (open_bracket GREATER_EQUAL 0 AND close_bracket GREATER ${open_bracket})
            math(EXPR one_past_open_bracket "${open_bracket} + 1")
            math(EXPR one_before_close_bracket "${close_bracket} - 1")
            math(EXPR one_past_close_bracket "${close_bracket} + 1")
            math(EXPR dirroot_length "${one_before_close_bracket} - ${one_past_open_bracket} + 1")
            string(SUBSTRING "${localBuildDir}" ${one_past_open_bracket} ${dirroot_length} dirroot)
            string(SUBSTRING "${localBuildDir}" ${one_past_close_bracket} -1 src_folder)

            if (${dirroot} STREQUAL "SRC")
                set(${A_PP_BUILD_DIR} ${EXTERNALS_DIR}/${build_folder} PARENT_SCOPE)
                set(build_ok ON)
            elseif (${dirroot} STREQUAL "BUILD")
                set(${A_PP_BUILD_DIR} ${BUILD_DIR}/_deps/${build_folder} PARENT_SCOPE)
                set(build_ok ON)
            else ()
                msg(ALWAYS FATAL_ERROR "Bad BINDIR for ${this_pkgname} (${localBuildDir}): Must start with \"[SRC]\" or \"[BUILD]\"")
            endif ()
        else ()
            set(build_ok ON)
        endif ()
    endif ()

    if (src_ok) # Was AND build_ok) # But I think the existence of the build folder shouldn't have any effect here
        set(${A_PP_FETCH_FLAG} OFF PARENT_SCOPE)
    endif ()

    if (A_PP_INC_DIR)
        string(FIND "${localIncDir}" "[" open_bracket)
        string(FIND "${localIncDir}" "]" close_bracket)
        if (open_bracket GREATER_EQUAL 0 AND close_bracket GREATER ${open_bracket})
            math(EXPR one_past_open_bracket "${open_bracket} + 1")
            math(EXPR one_before_close_bracket "${close_bracket} - 1")
            math(EXPR one_past_close_bracket "${close_bracket} + 1")
            math(EXPR dirroot_length "${one_before_close_bracket} - ${one_past_open_bracket} + 1")
            string(SUBSTRING "${localIncDir}" ${one_past_open_bracket} ${dirroot_length} dirroot)
            string(SUBSTRING "${localIncDir}" ${one_past_close_bracket} -1 src_folder)

            if (${dirroot} STREQUAL "SRC")
                set(${A_PP_INC_DIR} ${EXTERNALS_DIR}/${folder} PARENT_SCOPE)
                set(inc_ok ON)
            elseif (${dirroot} STREQUAL "BUILD")
                set(${A_PP_INC_DIR} ${BUILD_DIR}/_deps/${folder} PARENT_SCOPE)
                set(inc_ok ON)
            else ()
                msg(ALWAYS FATAL_ERROR "Bad INCDIR for ${this_pkgname} (${localIncDir}): Must start with \"[SRC]\" or \"[BUILD]\"")
            endif ()
        else ()
            set(inc_ok ON)
        endif ()
    endif ()

    if (A_PP_COMPONENTS)
        if (NOT "${localComponents}" STREQUAL "")
            string(REPLACE "&" ";" localComponents ${localComponents})
            set(${A_PP_COMPONENTS} ${localComponents} PARENT_SCOPE)
        endif ()
    endif ()

    if (A_PP_ARGS)
        if (NOT "${localArgs}" STREQUAL "")
            string(REPLACE "&" ";" localArgs ${localArgs})
            set(${A_PP_ARGS} ${localArgs} PARENT_SCOPE)
        endif ()
    endif ()

    if (A_PP_PREREQS)
        if (NOT "${localPrereqs}" STREQUAL "")
            string(REPLACE "&" ";" localPrereqs ${localPrereqs})
            set(${A_PP_PREREQS} ${localPrereqs} PARENT_SCOPE)
        endif ()
    endif ()

endfunction()
##
########################################################################################################################
##
function(resolveDependencies featureDict resolveThese resolvedFeaturesTbl resolvedNamesTbl)

    set(visited)

    # Internal helper to walk dependencies
    function(visit lol feat_ is_a_prereq)

        list(GET feat_ ${FIXName} feature_name_)
        list(GET feat_ ${FIXPkgName} package_name_)
        list(GET feat_ ${FIXKind} kind_)
        list(GET feat_ ${FIXPrereqs} pre_)

        if (NOT "${feature_name_}/${package_name_}" IN_LIST visited)
            list(APPEND visited "${feature_name_}/${package_name_}")
            set(visited ${visited} PARENT_SCOPE)

            foreach (pr_entry_ IN LISTS pre_)
                SplitAt("${pr_entry_}" "=" pr_feat_ pr_pkgname_)
                if (pr_pkgname_)
                    SELECT(ROW AS local_ FROM ${lol} WHERE FeatureName = "${pr_feat_}" AND PackageName = "${pr_pkgname_}")
                else ()
                    SELECT(ROW AS local_ FROM ${lol} WHERE FeatureName = "${pr_feat_}" AND IsDefault = 1)
                endif ()
                visit(${lol} "${local_}" ON)
            endforeach ()

            if (${is_a_prereq})
                INSERT(INTO ${resolvedNamesTbl} VALUES ("${feature_name_}.*/${package_name_}"))
            else ()
                INSERT(INTO ${resolvedNamesTbl} VALUES ("${feature_name_}/${package_name_}"))
            endif ()

            separate_arguments(out_ NATIVE_COMMAND "${feat_}")
            INSERT(INTO ${resolvedFeaturesTbl} VALUES (${out_}))
            set(visited ${visited} PARENT_SCOPE)

        endif ()

    endfunction()

    # Pass 1: Handle LIBRARIES and their deep prerequisites first

    SELECT(COUNT AS numberToResolve FROM ${resolveThese})

    foreach (rdPass RANGE 1 2)
        set(loop_index 0)
        while (loop_index LESS numberToResolve)
            inc(loop_index)
            set(row_id ${loop_index})
            SELECT(ROW AS _feature FROM ${resolveThese} WHERE ROWID = ${row_id})
            list(GET _feature ${FIXKind} _kind)
            if ((rdPass EQUAL 1 AND "${_kind}" STREQUAL "LIBRARY") OR (rdPass EQUAL 2 AND NOT "${_kind}" STREQUAL "LIBRARY"))
                visit(featureDict_ "${_feature}" OFF)
            endif ()
        endwhile ()
    endforeach ()

endfunction()
##
########################################################################################################################
##
function(scanLibraryTargets packageData libName packageNames)

    set(${libName}_COMPONENTS)
    set(${libName}_COMPONENTS ${${libName}_COMPONENTS} PARENT_SCOPE)
    set(sctLongestFeatureName 0 CACHE INTERNAL "" FORCE)
    set(sctLongestPackageName 0 CACHE INTERNAL "" FORCE)

    # Check common target name patterns
    set(targetName "")
    if (TARGET ${APP_VENDOR}::${libName})
        set(targetName "${APP_VENDOR}::${libName}")
    elseif (TARGET ${libName}::${libName})
        set(targetName "${libName}::${libName}")
    elseif (TARGET ${libName})
        set(targetName "${libName}")
    endif ()

    if ("${targetName}" STREQUAL "")
        msg("  scanLibraryTargets: Could not find target for ${libName}")
        return()
    endif ()

    msg("Scanning ${targetName} for provided imports...")

    get_target_property(libs ${targetName} INTERFACE_LINK_LIBRARIES)
    if (libs)
        set(slib ${libs})
        string(REPLACE ";" "\n" slib "${slib}")
        msg("INTERFACE_LINK_LIBRARIES found in ${targetName} : \n\n${slib}\n")
        getObjectType(packageData wotPD)
        foreach (pass RANGE 1 2)
            foreach (lib IN LISTS libs)
                # 1. Clean up target name (remove generator expressions)
                string(REGEX REPLACE "\\$<.*>" "" clean_lib "${lib}")
                if ("${clean_lib}" STREQUAL "")
                    continue()
                endif ()
                # 2. Extract raw name for matching
                set(raw_import_name "${clean_lib}")
                if ("${clean_lib}" MATCHES "::")
                    # Handle HoffSoft::name or Namespace::name
                    string(REGEX REPLACE ".*::" "" raw_import_name "${clean_lib}")
                endif ()

                # 3. Cross-reference against packageData
                set(s_at 0)
                record(LENGTH packageNames s_max)
                while (s_at LESS s_max)
                    set(s_ix ${s_at})
                    inc(s_at)
                    record(GET packageNames ${s_ix} featureSlashPackage)
                    if (wotPD STREQUAL "MAP")
                        dict(GET packageData EQUAL ${featureSlashPackage} feature_line)
                    else ()
                        array(GET packageData ${s_ix} feature_line)
                    endif ()
                    getObjectType(feature_line flt)
                    record(GET feature_line ${FIXName} feat_name pkg_name)
                    record(GET feature_line ${FIXNamespace} ns)
                    record(GET feature_line ${FIXComponents} components)

                    # Does the library link to this package?
                    set(MATCHED OFF)
                    if (ns STREQUAL "")
                        set(smoochie "Matching ${raw_import_name} to ${pkg_name} ")
                    else ()
                        set(smoochie "Matching ${raw_import_name} to ${ns}::${pkg_name} ")
                    endif ()
                    set(matching_component)
                    if ("${raw_import_name}" STREQUAL "${pkg_name}" OR "${raw_import_name}" STREQUAL "${ns}")
                        set(smoochie "${smoochie} ✔️")
                        set(MATCHED ON)
                    elseif (components)
                        string(REPLACE "&" ";" components ${components})
                        set(smoochie "${smoochie} Nope ❌ Checking component ")
                        # Check components
                        foreach (comp IN LISTS components)
                            set(smoochie "${smoochie} ${comp} ")

                            # Match against component name (e.g. Core) or ns_component (e.g. SOCI_Core)
                            # or common variations like pkg_component (e.g. soci_core)
                            string(TOLOWER "${pkg_name}" pkg_lc)
                            string(TOLOWER "${comp}" comp_lc)

                            if ("${raw_import_name}" STREQUAL "${comp}" OR
                                    "${raw_import_name}" STREQUAL "${ns}_${comp}" OR
                                    "${raw_import_name}" STREQUAL "${pkg_name}_${comp}" OR
                                    "${raw_import_name}" STREQUAL "${pkg_lc}_${comp_lc}")
                                set(MATCHED ON)
                                set(matching_component ${comp})
                                set(smoochie "${smoochie} ✔️")
                                break()
                            else ()
                                set(smoochie "${smoochie} ❌ ")
                            endif ()
                        endforeach ()
                    else ()
                        set(smoochie "${smoochie} Nope ❌")
                    endif ()
                    #                msg("${smoochie}")

                    set(dispFeatureName "\"${feat_name}\"")

                    if (ns STREQUAL "")
                        if (matching_component)
                            set(dispPackageName "(${pkg_name}::${matching_component})")
                        else ()
                            set(dispPackageName "(${pkg_name})")
                        endif ()
                    else ()
                        if (matching_component)
                            set(dispPackageName "(${ns}::${matching_component})")
                        else ()
                            set(dispPackageName "(${pkg_name})")
                        endif ()
                    endif ()

                    if (pass EQUAL 1)

                        longest(RIGHT CURRENT ${sctLongestFeatureName} TEXT "${dispFeatureName}" LONGEST sctLongestFeatureName)
                        longest(LEFT CURRENT ${sctLongestPackageName} TEXT "${dispPackageName}" LONGEST sctLongestPackageName)

                        continue()
                    else ()

                        longest(RIGHT CURRENT ${sctLongestFeatureName} TEXT "${dispFeatureName}" LONGEST sctLongestFeatureName PADDED dispFeatureName)
                        longest(LEFT CURRENT ${sctLongestPackageName} TEXT "${dispPackageName}" LONGEST sctLongestPackageName PADDED dispPackageName)

                        set(sctLongestFeatureName ${sctLongestFeatureName} CACHE INTERNAL "" FORCE)
                        set(sctLongestPackageName ${sctLongestPackageName} CACHE INTERNAL "" FORCE)

                    endif ()
                    if (MATCHED)
                        msg("o   Feature ${dispFeatureName} ${dispPackageName} is provided by ${targetName} as ${clean_lib}")

                        list(APPEND ${libName}_COMPONENTS ${pkg_name})
                        set(${pkg_name}_PROVIDED_TARGET "${clean_lib}" CACHE INTERNAL "" FORCE)
                        list(APPEND __alreadyLocated "${clean_lib}")
                        set(__alreadyLocated "${__alreadyLocated}" CACHE INTERNAL "" FORCE)
                        break()
                    endif ()
                endwhile ()
            endforeach ()
        endforeach ()
    endif ()
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
            msg("  Linking ${_pkgname} to existing target: ${_actualTarget}")

            addTargetProperties(${_actualTarget} ${_pkgname} ON)

            # Ensure the include directories from the existing target are propagated
            get_target_property(_target_incs ${_actualTarget} INTERFACE_INCLUDE_DIRECTORIES)
            if (_target_incs)
                list(APPEND _IncludePathsList ${_target_incs})
            endif ()
            set(_anyTargetFound ON)
        endif ()

        # 2. Standard component check
        if (NOT _anyTargetFound)
            foreach (_component IN LISTS this_find_package_components)
                if (TARGET ${_component})
                    addTargetProperties(${_component} ${_pkgname} ON)
                    set(_anyTargetFound ON)
                endif ()
            endforeach ()
        endif ()

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
        endif ()
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
function(preProcessFeatures featureList hDataSource outVar)

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
            set(actualStagedFile "${STAGED_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")
            set(actualSystemFile "${SYSTEM_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${pkgName}")

            foreach (path IN ITEMS "actualSystemFile" "actualSourceFile" "actualStagedFile")
                if (EXISTS "${${path}}" OR addAllRegardless)
                    if (EXISTS "${${path}}")
                        msg(NOTICE "  Found ${${path}}")
                        set(${path}Found ON)
                        list(PREPEND candidates "${${path}}")
                    else ()
                        msg(NOTICE "Missing ${${path}} but still added it to list")
                        set(${path}Found OFF)
                        list(APPEND conditionals "${${path}}")
                    endif ()
                else ()
                    msg(NOTICE "Missing ${${path}}")
                    set(${path}Found OFF)
                endif ()
            endforeach ()
            msg()

            # Staged and Source files are the same?
            if (actualSourceFileFound AND actualStagedFileFound
                    AND "${actualSourceFile}" IS_NEWER_THAN "${actualStagedFile}"
                    AND "${actualStagedFile}" IS_NEWER_THAN "${actualSourceFile}")

                msg(NOTICE "Source and Staged are the same. We'll use Staged.")
                list(REMOVE_ITEM candidates "${actualStagedFileFound}")
                list(INSERT candidates 0 "${actualStagedFileFound}")
            endif ()

            list(APPEND candidates "${conditionals}")

            set(listOfFolders)
            foreach (candidate IN LISTS candidates)
                get_filename_component(candidate "${candidate}" PATH)
                list(APPEND listOfFolders "${candidate}")
            endforeach ()

            list(APPEND hints "${listOfFolders}")

        endforeach ()

        list(REMOVE_DUPLICATES hints)
        set(${outputVar} ${hints} PARENT_SCOPE)
    endfunction()
    macro(_)

        set(_pkg ${_TOK_EMPTY_FIELD})
        set(_feature ${_TOK_EMPTY_FIELD})
        set(_package ${_TOK_EMPTY_FIELD})
        set(_is_default ${_TOK_EMPTY_FIELD})
        set(_ns ${_TOK_EMPTY_FIELD})
        set(_kind ${_TOK_EMPTY_FIELD})
        set(_method ${_TOK_EMPTY_FIELD})
        set(_url ${_TOK_EMPTY_FIELD})
        set(_git_repo ${_TOK_EMPTY_FIELD})
        set(_tag ${_TOK_EMPTY_FIELD})
        set(_srcdir ${_TOK_EMPTY_FIELD})
        set(_builddir ${_TOK_EMPTY_FIELD})
        set(_incdir ${_TOK_EMPTY_FIELD})
        set(_components ${_TOK_EMPTY_FIELD})
        set(_args ${_TOK_EMPTY_FIELD})
        set(_prerequisites ${_TOK_EMPTY_FIELD})


        set(_hints)
        set(_required)
        set(_paths)
        set(_first_hint)
        set(_first_path)
        set(_first_component)
        set(AA_OVERRIDE_FIND_PACKAGE)
        set(AA_PACKAGE)
        set(AA_NAMESPACE)
        set(AA_FIND_PACKAGE_ARGS)
        set(AA_COMPONENTS)

    endmacro()
    function(subProcess subArgs retVar)
        set(featureless ${subArgs})
        list(REMOVE_ITEM featureless "FIND_PACKAGE_ARGS")
        cmake_parse_arguments("AA1" "REQUIRED;OPTIONAL" "PACKAGE;NAMESPACE" "PATHS;HINTS" ${featureless}) #${AA_FIND_PACKAGE_ARGS})

        if (AA1_HINTS OR "HINTS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA1_HINTS}" STREQUAL "")
                replacePositionalParameters("${AA1_HINTS}" _hints OFF)
                if (_hints)
                    string(JOIN "&" _hints "HINTS" ${_hints})
                else ()
                    msg(ALWAYS "APP_FEATURES: No files found for HINTS")
                endif ()
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: HINTS has no hints")
                set(_hints)
                list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "HINTS")
            endif ()
        endif ()

        if (AA1_PATHS OR "PATHS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA1_PATHS}" STREQUAL "")
                replacePositionalParameters("${AA1_PATHS}" _paths ON)
                if (_paths)
                    string(JOIN "&" _paths "PATHS" ${_paths})
                else ()
                    msg(ALWAYS "APP_FEATURES: No files found for PATHS")
                endif ()
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: PATHS has no paths")
                set(_paths)
                list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "PATHS")
            endif ()
        endif ()

        if (AA1_REQUIRED AND AA1_OPTIONAL)
            msg(ALWAYS FATAL_ERROR "APP_FEATURES: cannot contain both REQUIRED,OPTIONAL")
        endif ()

        if (AA1_REQUIRED)
            set(_required "REQUIRED")
        endif ()

        if (AA1_OPTIONAL)
            set(_required "OPTIONAL")
        endif ()
        list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "FIND_PACKAGE_ARGS" "ARGS")
        string(JOIN "&" _retargs ${_required} ${_hints} ${_paths} ${AA1_UNPARSED_ARGUMENTS})
        set(${retVar} ${_retargs} PARENT_SCOPE)
    endfunction()

    CREATE(TABLE tblRevisedFeatures COLUMNS (${PkgColNames}) INTO hRevisedFeatures)

    set(_switches OVERRIDE_FIND_PACKAGE)
    set(_single_args PACKAGE NAMESPACE)
    set(_multi_args FIND_PACKAGE_ARGS ARGS COMPONENTS)
    set(_prefix AA)

    foreach (feature IN LISTS featureList)

        _()

        separate_arguments(feature NATIVE_COMMAND "${feature}")
        cmake_parse_arguments(${_prefix} "${_switches}" "${_single_args}" "${_multi_args}" ${feature})
        list(POP_FRONT AA_UNPARSED_ARGUMENTS AA_FEATURE)

        # Sanity checks

        if (NOT AA_FEATURE)
            msg(ALWAYS FATAL_ERROR "APP_FEATURES: No FEATURE name")
        endif ()

        if (NOT DEFINED AA_PACKAGE OR NOT AA_PACKAGE STREQUAL "")
            set(AA_PACKAGE)
            set(wantDefault ON)
        elseif ("PACKAGE" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            msg(ALWAYS FATAL_ERROR "APP_FEATURES: PACKAGE keyword given with no package name")
            set(AA_PACKAGE)
            set(wantDefault ON)
        else ()
            set(wantDefault OFF)
        endif ()

        if (AA_OVERRIDE_FIND_PACKAGE AND (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES))
            msg(ALWAYS FATAL_ERROR "APP_FEATURES: Cannot combine OVERRIDE_FIND_PACKAGE with FIND_PACKAGE_ARGS")
        endif ()

        if (AA_NAMESPACE OR "NAMESPACE" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA_NAMESPACE}" STREQUAL "")
                set(_ns "${AA_NAMESPACE}")
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: NAMESPACE keyword given with no package name")
                list(REMOVE_ITEM AA_UNPARSED_ARGUMENTS "NAMESPACE")
            endif ()
        endif ()

        if (AA_OVERRIDE_FIND_PACKAGE)
            set(_args "OVERRIDE_FIND_PACKAGE")
        elseif (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            set(_args "FIND_PACKAGE_ARGS")
            if (NOT "${AA_FIND_PACKAGE_ARGS}" STREQUAL "")
                subProcess("${AA_FIND_PACKAGE_ARGS}" retVar)
                string(JOIN "&" _args "${retVar}")
            endif ()
        endif ()

        if (AA_COMPONENTS OR "COMPONENTS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA_COMPONENTS}" STREQUAL "")
                string(JOIN "&" _components ${AA_COMPONENTS})
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: COMPONENTS keyword given with no components")
            endif ()
        endif ()

        if (AA_ARGS OR "ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            subProcess("${AA_ARGS}" retVar)
            string(JOIN "&" _args "${retVar}")
        endif ()

        if (wantDefault)
            SELECT(FeatureName AS AA_FEATURE PackageName AS AA_PACKAGE IsDefault FROM ${hDataSource} WHERE "FeatureName" = "${AA_FEATURE}" AND "IsDefault" = 1)
        else ()
            SELECT(FeatureName AS AA_FEATURE PackageName AS _AA_PACKAGE IsDefault FROM ${hDataSource} WHERE "FeatureName" = "${AA_FEATURE}" AND "PackageName" = "${AA_PACKAGE}")
            set(AA_PACKAGE "${_AA_PACKAGE}")
        endif ()

        if (IsDefault STREQUAL "")
            if (AA_PACKAGE)
                msg(ALWAYS FATAL_ERROR "preProcessFeatures: Feature/Package \"${AA_FEATURE}/${AA_PACKAGE}\" does not exist")
            else ()
                msg(ALWAYS FATAL_ERROR "preProcessFeatures: Feature \"${AA_FEATURE}\" does not exist")
            endif ()
        endif ()

        #        _hs_sql_field_to_storage()
        INSERT(INTO hRevisedFeatures VALUES (
                "${AA_FEATURE}"
                "${AA_PACKAGE}"
                "${IsDefault}"
                "${_ns}"
                "${_kind}"
                "${_method}"
                "${_url}"
                "${_git_repo}"
                "${_tag}"
                "${_srcdir}"
                "${_builddir}"
                "${_incdir}"
                "${_components}"
                "${_args}"
                "${_prerequisites}")
        )

    endforeach ()

    set(${outVar} ${hRevisedFeatures} PARENT_SCOPE)
endfunction()
