include_guard(GLOBAL)

include(${CMAKE_SOURCE_DIR}/cmake/tools.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/array.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/object.cmake)
#include(${CMAKE_SOURCE_DIR}/cmake/object_sql_enhanced.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/sql_like.cmake)

# @formatter:off
set(PkgColNames Name PkgName Namespace Kind Method Url GitRepository GitTag SrcDir BuildDir IncDir Components Args Prereq)
set(FIXName          0)
set(FIXPkgName       1)
set(FIXNamespace     2)
set(FIXKind          3)
set(FIXMethod        4)
set(FIXUrl           5)
set(FIXGitRepository 6)
set(FIXGitTag        7)
set(FIXSrcDir        8)
set(FIXBuildDir      9)
set(FIXIncDir       10)
set(FIXComponents   11)
set(FIXArgs         12)
set(FIXPrereqs      13)
math(EXPR FIXLength "${FIXPrereqs} + 1")

CREATE(TABLE hLongest LABEL tLongestStrings COLUMNS "VERB;OBJECT;SUBJECT_PREP;SUBJECT;ITEM_PREP;ITEM;HANDLER")
INSERT(INTO hLongest VALUES "0" "0" "0" "0" "0" "0" "0")
DUMP(FROM hLongest VERBOSE)
# @formatter:on

include(FetchContent)

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
function(initialiseFeatureHandlers DRY_RUN COLOUR)
    if (MONOREPO)
        file(GLOB_RECURSE handlers "${CMAKE_SOURCE_DIR}/${APP_VENDOR}/cmake/handlers/*.cmake")
    else ()
        file(GLOB_RECURSE handlers "${CMAKE_SOURCE_DIR}/cmake/handlers/*.cmake")
    endif ()

    foreach (handler IN LISTS handlers)
        get_filename_component(handlerName "${handler}" NAME_WE)
        get_filename_component(_path "${handler}" DIRECTORY)
        get_filename_component(packageName "${_path}" NAME_WE)

        SELECT(VALUE FROM hLongest WHERE ROWID = 1 AND COLUMN = HANDLER INTO _longest)
        longest(RIGHT GAP
                CURRENT ${_longest}
                TEXT "${handlerName}"
                LONGEST _longest
                PADDED text)
        UPDATE(hLongest COLUMN "HANDLER" SET "${_longest}" WHERE ROWID = 1)

        if (COLOUR)
            set(msg "Adding handler ${BOLD}${text}${NC} for package ${BOLD}${packageName}${NC}")
        else ()
            set(msg "Adding handler ${text} for package ${packageName}")
        endif ()
        if (${handlerName} STREQUAL "init")
            string(APPEND msg " and calling it ...")
        endif ()
        if (NOT DRY_RUN)
            msg(ALWAYS "${msg}")
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
    msg(ALWAYS "")
endfunction()
########################################################################################################################
########################################################################################################################
########################################################################################################################
function(addPackageData)

    # During a DRY_RUN, all data is checked, and field sized for tabulated output are computed,
    # but no data is actually stored.

    set(switches SYSTEM LIBRARY OPTIONAL PLUGIN CUSTOM)
    set(args METHOD FEATURE PKGNAME NAMESPACE URL GIT_REPOSITORY SRCDIR GIT_TAG BINDIR INCDIR COMPONENT ARG PREREQ DRY_RUN COLOUR)
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

    #    if (APD_GIT_REPOSITORY)
    #        set(URLorSRCDIR "${APD_GIT_REPOSITORY}")
    #    elseif (APD_SRCDIR)
    #        set(URLorSRCDIR "${APD_SRCDIR}")
    #    elseif (APD_URL)
    #        set(URLorSRCDIR "${APD_URL}")
    #    endif ()
    #    if (APD_GIT_TAG)
    #        set(TAGorBINDIR "${APD_GIT_TAG}")
    #    elseif (APD_BINDIR)
    #        set(TAGorBINDIR "${APD_BINDIR}")
    #    endif ()
    string(REPLACE ";" "&" APD_COMPONENTS "${APD_COMPONENTS}")
    string(JOIN "&" APD_ARGS ${APD_ARGS} ${APD_FIND_PACKAGE_ARGS})
    if (APD_PREREQS)
        string(REPLACE ";" "&" APD_PREREQS "${APD_PREREQS}")
    endif ()

    if (NOT APD_DRY_RUN)
        CREATE(TABLE hOutput LABEL ${APD_PKGNAME} COLUMNS "${PkgColNames}")
        INSERT(INTO hOutput VALUES
                "${APD_FEATURE}"
                "${APD_PKGNAME}"
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
                "${APD_PREREQS}"
        )
    endif ()
    function(createOrAppendTo)

        function(_ VERB OBJECT SUBJECT_PREP SUBJECT ITEM_PREP ITEM TEMPLATE)
            macro(_doLine _var_)
                #                if ("${${_var_}}" STREQUAL "")
                #                    set(arg " ")
                #                else ()
                set(arg "${${_var_}}")
                #                endif ()
                if (current_tag STREQUAL "OBJECT" OR current_tag STREQUAL "SUBJECT")
                    set(PAD_CHAR ".")
                    set(GAP "GAP")
                    set(MIN_LENGTH 3)
                else ()
                    set(PAD_CHAR " ")
                    set(GAP "")
                    set(MIN_LENGTH 1)
                endif ()
                SELECT(VALUE FROM hLongest WHERE ROWID = 1 AND COLUMN ${current_tag} INTO _longest)
                longest(${GAP} MIN_LENGTH ${MIN_LENGTH} ${JUSTIFY} CURRENT ${_longest} PAD_CHAR "${PAD_CHAR}" TEXT "${arg}" PADDED ${current_tag} LONGEST _longest)
                UPDATE(hLongest COLUMN ${current_tag} SET "${_longest}" WHERE ROWID = 1)
            endmacro()

            if (NOT cat_quiet)

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
                            if (APD_COLOUR)
                                if (VERB MATCHES "created")
                                    set(VERB "${GREEN}${VERB}${NC}")
                                elseif (VERB STREQUAL "added")
                                    set(VERB "${VERB}${NC}")
                                elseif (VERB STREQUAL "replaced")
                                    set(VERB "${RED}${VERB}${NC}")
                                elseif (VERB STREQUAL "extended")
                                    set(VERB "${YELLOW}${VERB}${NC}")
                                elseif (VERB STREQUAL "skipped")
                                    set(VERB "${BLUE}${VERB}${NC}")
                                endif ()
                            endif ()
                        elseif (current_tag STREQUAL "OBJECT")
                            _doLine(OBJECT)
                            if (APD_COLOUR)
                                set(OBJECT "${BOLD}${OBJECT}${NC}")
                            endif ()
                        elseif (current_tag STREQUAL "SUBJECT_PREP")
                            _doLine(SUBJECT_PREP)
                        elseif (current_tag STREQUAL "SUBJECT")
                            _doLine(SUBJECT)
                            if (APD_COLOUR)
                                set(SUBJECT "${YELLOW}${SUBJECT}${NC}")
                            endif ()
                        elseif (current_tag STREQUAL "ITEM_PREP")
                            _doLine(ITEM_PREP)
                        elseif (current_tag STREQUAL "ITEM")
                            if (ITEM STREQUAL "")
                                set(arg " ")
                            else ()
                                set(arg "${ITEM}")
                            endif ()
                            _doLine("ITEM")
                            if (APD_COLOUR)
                                set(ITEM "${BLUE}${ITEM}${NC}")
                            endif ()
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

                if (NOT APD_DRY_RUN)
                    msg("${outstr}")
                endif ()
            endif ()

        endfunction()

        set(switches QUIET QUITE REPLACE EXTEND UNIQUE)
        set(args TARGET SUBJECT FEATURE RECORD FIELD TEMPLATE)
        set(lists "")

        set(cat_quiet OFF)
        set(cat_extend ON)
        set(cat_replace OFF)
        set(cat_unique OFF)
        set(cat_target_handle "")
        set(cat_subject_handle "")
        set(cat_target "")
        set(cat_subject "")
        set(cat_feature "")
        set(cat_data "")
        set(cat_template "")

        cmake_parse_arguments("CAT" "${switches}" "${args}" "${lists}" ${ARGN})
        if (CAT_TARGET)
            set(cat_target_handle "${CAT_TARGET}")
        endif ()
        if (DEFINED CAT_UNPARSED_ARGUMENTS)
            list(POP_FRONT CAT_UNPARSED_ARGUMENTS cat_subject_handle)
        endif ()

        if (cat_target_handle AND NOT cat_subject_handle)
            set(cat_subject_handle ${cat_target_handle})
        elseif (cat_subject_handle AND NOT cat_target_handle)
            set(cat_target_handle ${cat_subject_handle})
        elseif (NOT cat_target_handle AND NOT cat_subject_handle)
            msg(ALWAYS FATAL_ERROR "Need one or both of TARGET or SUBJECT. Note:- SUBJECT does not need the SUBJECT keyword.")
        endif ()
        LABEL(OF ${cat_target_handle} INTO cat_target)
        LABEL(OF ${cat_subject_handle} INTO cat_subject)

        if (DEFINED CAT_TEMPLATE AND NOT CAT_TEMPLATE STREQUAL "")
            set(cat_template "${CAT_TEMPLATE}")
        else ()
            return()
        endif ()
        if (CAT_QUIET)
            set(cat_quiet ON)
            unset(cat_template)
        endif ()
        if (CAT_REPLACE)
            set(cat_extend OFF)
            set(cat_replace ON)
        endif ()
        if (CAT_EXTEND)
            set(cat_extend ON)
            set(cat_replace OFF)
        endif ()
        if (CAT_UNIQUE)
            set(cat_unique ON)
        endif ()
        if (NOT CAT_FEATURE OR "${CAT_FEATURE}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no FEATURE in call to createOrAppendTo()")
        else ()
            set(cat_feature "${CAT_FEATURE}")
        endif ()
        if (CAT_RECORD AND NOT "${CAT_RECORD}" STREQUAL "")
            set(cat_data "${CAT_RECORD}")
            set(cat_record ON)
            set(cat_field OFF)
        endif ()
        if (CAT_FIELD AND NOT "${CAT_FIELD}" STREQUAL "")
            set(cat_data "${CAT_FIELD}")
            set(cat_record OFF)
            set(cat_field ON)
        endif ()

        set(out_verb)
        set(out_object)
        set(out_subject_prep)
        set(out_subject)
        set(out_item_prep)
        set(out_item)
        set(out_template "${cat_template}")

        if (cat_field)
            SELECT(VALUE FROM ${cat_subject_handle} WHERE COLUMN "Name" = "${cat_data}" INTO fieldValue)
            if ((fieldValue AND cat_unique) OR (fieldValue AND NOT cat_unique AND NOT cat_extend))
                set(out_verb "skipped")
                set(out_object ${cat_data})
                set(out_subject_prep "for")
                set(out_subject ${cat_subject})
                set(out_item_prep "in")
                set(out_item ${cat_target})
                if (APD_COLOUR)
                    set(out_template "${cat_template} : ${GREEN}(exists)${NC}")
                else ()
                    set(out_template "${cat_template} : (exists)")
                endif ()
            elseif ((fieldValue AND NOT cat_unique AND cat_extend) OR NOT fieldValue)
                if (NOT APD_DRY_RUN)
                    INSERT(INTO ${cat_subject_handle} VALUES "${cat_data}")
                endif ()
                set(out_verb "added")
                set(out_object "${cat_data}")
                set(out_subject_prep "to")
                set(out_subject ${cat_subject})
                set(out_item_prep "in")
                set(out_item ${cat_target})
            else ()
                set(out_verb "skipped")
                set(out_object ${cat_data})
                set(out_subject_prep "for")
                set(out_subject ${cat_subject})
                set(out_item_prep "in")
                set(out_item ${cat_target})
                if (APD_COLOUR)
                    set(out_template "${cat_template} : ${RED}(couldn't work out what was needed!)${NC}")
                else ()
                    set(out_template "${cat_template} : (couldn't work out what was needed!)")
                endif ()
            endif ()

            _("${out_verb}" "${out_object}" "${out_subject_prep}" "${out_subject}" "${out_item_prep}" "${out_item}" "${out_template}")
        else ()
            if (NOT APD_DRY_RUN)
                LABEL(OF ${cat_data} INTO locPkgName)
                SELECT(HANDLE FROM ${cat_target_handle} WHERE KEY = ${cat_feature} INTO h)
            endif ()
            set(weCreatedH OFF)

            if (NOT h)
                set(weCreatedH ON)

                if (NOT APD_DRY_RUN)
                    CREATE(TABLE h LABEL ${cat_feature} COLUMNS "${PkgColNames}")
                endif ()
                set(out_verb "created")
                set(out_object "${cat_feature}")
                set(out_item_prep "in")
                set(out_item ${cat_target})
                _("${out_verb}" "${out_object}" "${out_subject_prep}" "${out_subject}" "${out_item_prep}" "${out_item}" "${out_template}")
                set(out_verb)
                set(out_object)
                set(out_subject_prep)
                set(out_subject)
                set(out_item_prep)
                set(out_item)
            endif ()
            set(locHandle)
            if (NOT APD_DRY_RUN)
                SELECT(* FROM h WHERE COLUMN Name = ${cat_feature} AND COLUMN PkgName = ${locPkgName} INTO locHandle)
            endif ()
            if (locHandle)
                if (NOT APD_DRY_RUN)
                    DELETE(FROM h WHERE COLUMN Name = ${cat_feature} AND COLUMN PkgName = ${locPkgName})
                    INSERT(INTO h ROW ${cat_data})
                endif ()
                set(out_verb "replaced")
                set(out_object ${cat_feature})
                set(out_subject_prep "with")
                set(out_subject ${locPkgName})
                set(out_item_prep "in")
                set(out_item ${cat_target})
                # Do nothing
            else ()
                if (NOT APD_DRY_RUN)
                    INSERT(INTO h ROW ${cat_data})
                    if (weCreatedH)
                        INSERT(INTO ${cat_target_handle} KEY ${cat_feature} HANDLE h)
                    else ()
                        UPDATE(${cat_target_handle} KEY ${cat_feature} HANDLE h)
                    endif ()
                endif ()
                if (weCreatedH)
                    set(out_verb "initialised")
                else ()
                    set(out_verb "extended")
                endif ()
                set(out_object ${cat_feature})
                set(out_subject_prep "with")
                set(out_subject ${locPkgName})
                set(out_item_prep "in")
                set(out_item ${cat_target})
                if (NOT result)
                    # OOPS
                endif ()
            endif ()
            _("${out_verb}" "${out_object}" "${out_subject_prep}" "${out_subject}" "${out_item_prep}" "${out_item}" "${out_template}")
        endif ()

        #        if(NOT cat_verb OR NOT cat_object OR NOT cat_subject_prep OR NOT cat_subject)
        #            set(cat_verb "skipped")
        #            set(cat_object ${cat_data})
        #            set(cat_subject_prep "in")
        #            set(cat_subject ${cat_destination})
        #            set(cat_template "${cat_template} : ${RED}(couldn't work out what was needed!)${NC}")
        #        endif ()
    endfunction()

    set(template "[VERB:R][OBJECT:R][SUBJECT_PREP:C][SUBJECT:L][ITEM_PREP:C][ITEM:L]")
    set(APD_FEATPKG "${APD_FEATURE}/${APD_PKGNAME}")

    if (APD_KIND MATCHES "SYSTEM")
        set(root System)
    elseif (APD_KIND MATCHES "LIBRARY")
        set(root Library)
    elseif (APD_KIND MATCHES "OPTIONAL")
        set(root Optional)
    elseif (APD_KIND MATCHES "PLUGIN")
        set(root Plugin)
    elseif (APD_KIND MATCHES "CUSTOM")
        set(root Custom)
    endif ()

    # @formatter:off
    createOrAppendTo(h${root}                           FEATURE "${APD_FEATURE}" RECORD hOutput         QUITE EXTEND        TEMPLATE "${template}")
    createOrAppendTo(h${root}Packages   TARGET h${root} FEATURE "${APD_FEATURE}" FIELD ${APD_FEATPKG}   QUITE EXTEND UNIQUE TEMPLATE "${template}")
    createOrAppendTo(h${root}Names      TARGET h${root} FEATURE "${APD_FEATURE}" FIELD ${APD_FEATURE}   QUITE EXTEND UNIQUE TEMPLATE "${template}")
    # @formatter:on

endfunction()
##
######################################################################################
##
function(getFeaturePkgList hInput feature receivingVarName)
    # iterate over array to find line with feature
    object(LENGTH numFeatures FROM "${hInput}")
    if (numFeatures GREATER 0)
        foreach (currIndex RANGE ${numFeatures})
            object(GET _thisArray FROM "${hInput}" INDEX ${currIndex})
            object(KIND _thisArray _thisArrayKind)
            if (_thisArrayKind STREQUAL "ARRAYS")
                getFeaturePkgList(_thisArray "${feature}" "${receivingVarName}")
                set("${receivingVarName}" "${receivingVarName}" PARENT_SCOPE)
                return()
            endif ()
            object(GET _foundAt FROM "_thisArray" MATCHING "${feature}")
            if (_foundAt)
                set(${receivingVarName} thisArray PARENT_SCOPE)
                return()
            endif ()
        endforeach ()
    endif ()
    unset("${receivingVarName}" PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeatureIndex hSource feature receivingVarName)
    # iterate over array to find line with feature
    #    object(ITER_HANDLES found FROM ${hSource} CHILDREN)
    set(foundAt)
    set(index 0)
    function(fn hRec)
        object(STRING feat FROM ${hRec} INDEX ${FIXFeature})
        object(STRING name FROM ${hRec} INDEX ${FIXPkgName})
        if ("${feat}" STREQUAL "${feature}" OR "${name}" STREQUAL "${feature}")
            set(foundAt ${index})
        else ()
            inc(index)
        endif ()
    endfunction()
    foreachobject(FROM hSource CHILDREN CALL fn)
    set(${receivingVarName} "${foundAt}" PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeaturePackage hSource feature index receivingVarName)
    getObjectType(${hSource} type)
    unset(${receivingVarName} PARENT_SCOPE)

    if (type STREQUAL "DICT" OR type STREQUAL "CATALOG")
        object(GET hFeature FROM ${hSource} NAME EQUAL "${feature}")
        #        dict(GET ${hSource} "${feature}" arr)
        if (NOT hFeature)
            return()
        endif ()
        set(hSource "hFeature")
    endif ()
    object(LENGTH numFeatures FROM ${hSource})
    if (numFeatures GREATER_EQUAL ${index})
        object(GET hPkg FROM ${hSource} INDEX ${index})
        set("${receivingVarName}" "${hPkg}" PARENT_SCOPE)
        return()
    endif ()
endfunction()
##
######################################################################################
##
function(getFeaturePackageByName hSource feature name receivingVarName)
    unset(${receivingVarName} PARENT_SCOPE)

    getObjectType(${hSource} type)
    # Returns: RECORD | ARRAY_RECORDS | ARRAY_ARRAYS | DICT | UNSET | UNKNOWN

    if (type STREQUAL "DICT" OR type STREQUAL "CATALOG")
        object(GET hPkg FROM ${hSource} NAME EQUAL "${feature}/${name}")
        #        dict(GET ${hSource} EQUAL "${feature}/${name}" pkg)
        if (NOT hPkg)
            return()
        endif ()
        set(${receivingVarName} "${hPkg}" PARENT_SCOPE)
        return()
    endif ()
    object(GET hPkg FROM ${hSource} EQUAL ${name})
    set("${receivingVarName}" "${pkg}" PARENT_SCOPE)
endfunction()
##
########################################################################################################################
##
## parsePackage can be called with a    * A  dict of FEATURE arrays,
##                                      * An array of packages (a FEATURE)
##                                      * A  package record
##
## If INPUT_TYPE is provided, we'll verify that
## If INPUT_TYPE is not provided, we'll work it out
##
function(parsePackage)
    set(options)
    set(one_value_args
            #           Keyword         Type        Direction   Description
            INPUT_TYPE  #   STRING      IN          Type of list supplied in inputListName
            #                           One of (SET, FEATURE, PACKAGE).
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
            NAMESPACE   #   VARNAME     OUT         Receive a copy of the NAMESPACE attribute (if applicable)
            KIND        #   VARNAME     OUT         Receive a copy of the KIND attribute (SYSTEM/LIBRARY/OPTIONAL)
            METHOD      #   VARNAME     OUT         Receive a copy of the METHOD attribute (FETCH_CONTENT/FIND_PACKAGE/PROCESS)
            URL         #   VARNAME     OUT         Receive a copy of the URL attribute (if applicable)
            SRC_DIR     #   VARNAME     OUT         Receive a copy of the SRCDIR attribute (if applicable)
            GIT_TAG     #   VARNAME     OUT         Receive a copy of the GIT_TAG attribute (if applicable)
            BUILD_DIR   #   VARNAME     OUT         Receive a copy of the BUILDDIR attribute (if applicable)
            INC_DIR     #   VARNAME     OUT         Receive a copy of the INCDIR attribute (if applicable)
            COMPONENTS  #   VARNAME     OUT         Receive a copy of the COMPONENT attribute in CMake LIST format
            ARGS        #   VARNAME     OUT         Receive a copy of the ARG attribute in CMake LIST format
            PREREQS     #   VARNAME     OUT         Receive a copy of the PREREQ attribute in CMake LIST format
            FETCH_FLAG  #   VARNAME     OUT         Indication that this PACKAGE needs to be downloaded somehow
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
    getObjectType(${inputListName} deducedType dc)

    set(A_SET OFF)
    set(A_FEATURE OFF)
    set(A_PACKAGE OFF)
    set(local)

    macro(inputTypeToObjectType)
        if (A_PP_INPUT_TYPE STREQUAL "SET" OR A_PP_INPUT_TYPE STREQUAL "DICT")
            set(inputTypeToType "DICT")
            set(A_SET ON)
        elseif (A_PP_INPUT_TYPE STREQUAL "FEATURE" OR A_PP_INPUT_TYPE STREQUAL "ARRAY_RECORDS")
            set(inputTypeToType "ARRAY_RECORDS")
            set(A_FEATURE ON)
        elseif (A_PP_INPUT_TYPE STREQUAL "PACKAGE" OR A_PP_INPUT_TYPE STREQUAL "RECORD")
            set(inputTypeToType "RECORD")
            set(A_PACKAGE ON)
        elseif (NOT deducedType)
            set(inputListVerifyFailed "INPUT_TYPE of \"${A_PP_INPUT_TYPE}\" unknown - needs to be SET/FEATURE/PACKAGE")
        endif ()
    endmacro()

    inputTypeToObjectType()

    if (deducedType STREQUAL "DICT" OR
            deducedType STREQUAL "ARRAY_RECORDS" OR
            deducedType STREQUAL "RECORD")
        set(A_PP_INPUT_TYPE ${deducedType})
        inputTypeToObjectType()
    else ()
        set(inputListVerifyFailed "Type of object stored in ${BOLD}${inputListName}${NC} cannot be used. Try a DICT, ARRAY_RECORDS, or RECORD")
    endif ()

    if (A_PP_INPUT_TYPE AND NOT inputListVerifyFailed AND NOT A_PP_INPUT_TYPE STREQUAL ${deducedType})
        set(inputListVerifyFailed "Data in ${BOLD}${inputListName}${NC} (${YELLOW}${deducedType}${NC}) doesn't match type from INPUT_TYPE ${BOLD}${A_PP_INPUT_TYPE}${NC} (${YELLOW}${inputTypeToType}${NC})")
    endif ()
    if (inputListVerifyFailed)
        msg(ALWAYS FATAL_ERROR "${RED}${BOLD}parsePackage() FAIL:${NC} ${inputListVerifyFailed}")
    endif ()

    if (A_SET AND NOT A_PP_FEATURE)
        msg(ALWAYS FATAL_ERROR "parsePackage() needs FEATURE parameter")
    endif ()

    if (NOT (A_PP_PACKAGE OR DEFINED A_PP_PKG_INDEX))
        msg(ALWAYS FATAL_ERROR "parsePackage() needs PACKAGE or PKG_INDEX parameter")
    endif ()

    if (DEFINED A_PP_PKG_INDEX AND A_PP_PACKAGE)
        msg(ALWAYS WARNING "parsePackage() both PKG_INDEX and PACKAGE supplied. Choosing PACKAGE")
        set(A_PP_PKG_INDEX)
    endif ()

    if (A_SET)
        if (A_PP_PACKAGE)
            dict(GET ${inputListName} EQUAL "${A_PP_FEATURE}/${A_PP_PACKAGE}" local)
            set(localIndex "UNKNOWN")
        else ()
            dict(GET ${inputListName} "${A_PP_FEATURE}" temp)
            if (temp)
                array(GET temp ${A_PP_PKG_INDEX} local)
                set(localIndex "UNKNOWN")
            endif ()
        endif ()
    elseif (A_FEATURE)
        if (DEFINED A_PP_PACKAGE)
            getFeaturePackageByName(${inputListName} "${A_PP_FEATURE}" "${A_PP_PACKAGE}" local localIndex)
        else ()
            getFeaturePackage(${inputListName} "${A_PP_FEATURE}" "${A_PP_PKG_INDEX}" local)
            set(localIndex ${A_PP_PKG_INDEX})
        endif ()
    else ()
        set(local ${${inputListName}})
        set(localIndex "UNKNOWN")
    endif ()

    record(GET local 0
            localFeature
            localName
            localNS
            localKind
            localMethod
    )

    # Initialize output variables
    if (DEFINED A_PP_OUTPUT)
        set(${A_PP_OUTPUT} "${local}" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_NAME)
        set(${A_PP_NAME} ${localName} PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_INDEX)
        set(${A_PP_INDEX} ${localIndex} PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_NAMESPACE)
        set(${A_PP_NAMESPACE} "${localNS}" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_KIND)
        set(${A_PP_KIND} ${localKind} PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_METHOD)
        set(${A_PP_METHOD} ${localMethod} PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_URL)
        set(${A_PP_URL} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_GIT_TAG)
        set(${A_PP_GIT_TAG} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_SRC_DIR)
        set(${A_PP_SRC_DIR} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_BUILD_DIR)
        set(${A_PP_BUILD_DIR} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_INC_DIR)
        set(${A_PP_INC_DIR} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_COMPONENTS)
        set(${A_PP_COMPONENTS} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_ARGS)
        set(${A_PP_ARGS} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_PREREQS)
        set(${A_PP_PREREQS} "" PARENT_SCOPE)
    endif ()
    if (DEFINED A_PP_FETCH_FLAG)
        set(${A_PP_FETCH_FLAG} ON PARENT_SCOPE)
    endif ()

    set(is_git_repo OFF)
    set(is_zip_file OFF)
    set(is_src_dir OFF)

    set(is_git_tag OFF)
    set(is_build_dir OFF)

    if (A_PP_URL)
        record(GET local ${FIXUrl} temp)
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

    if (A_PP_GIT_TAG AND is_git_tag)
        record(GET local ${FIXGitTag} temp)
        set(${A_PP_GIT_TAG} ${temp} PARENT_SCOPE)
    endif ()

    if (A_PP_SRC_DIR AND is_src_dir)
        record(GET local ${FIXSrcDir} temp)
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
                    msg(ALWAYS FATAL_ERROR "Bad SRCDIR for ${this_pkgname} (${temp}): Must start with \"[SRC]\" or \"[BUILD]\"")
                endif ()
            else ()
                set(src_ok ON)
            endif ()
        else ()
            set(src_ok OFF)
        endif ()
    endif ()

    if (A_PP_BUILD_DIR AND is_build_dir)
        record(GET local ${FIXBuildDir} temp)
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
                    msg(ALWAYS FATAL_ERROR "Bad BINDIR for ${this_pkgname} (${temp}): Must start with \"[SRC]\" or \"[BUILD]\"")
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

    if (A_PP_INC_DIR)
        record(GET local ${FIXIncDir} temp)
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
                msg(ALWAYS FATAL_ERROR "Bad INCDIR for ${this_pkgname} (${temp}): Must start with \"[SRC]\" or \"[BUILD]\"")
            endif ()
        else ()
            set(inc_ok ON)
        endif ()
    endif ()

    if (A_PP_COMPONENTS)
        record(GET local ${FIXComponents} temp)
        if (NOT "${temp}" STREQUAL "")
            string(REPLACE "&" ";" temp ${temp})
            set(${A_PP_COMPONENTS} ${temp} PARENT_SCOPE)
        endif ()
    endif ()

    if (A_PP_ARGS)
        record(GET local ${FIXArgs} temp)
        if (NOT "${temp}" STREQUAL "")
            string(REPLACE "&" ";" temp ${temp})
            set(${A_PP_ARGS} ${temp} PARENT_SCOPE)
        endif ()
    endif ()

    if (A_PP_PREREQS)
        record(GET local ${FIXPrereqs} temp)
        if (NOT "${temp}" STREQUAL "")
            string(REPLACE "&" ";" temp ${temp})
            set(${A_PP_PREREQS} ${temp} PARENT_SCOPE)
        endif ()
    endif ()

endfunction()
##
########################################################################################################################
##
function(resolveDependencies resolveThese_ featureDict_ featuresOut_ namesOut_)

    set(resolveThese "${${resolveThese_}}")
    set(featureDict "${${featureDict_}}")
    set(featuresOut "${featuresOut_}")
    set(namesOut "${namesOut_}")

    record(CREATE resolvedNames resolvedNames)
    record(CREATE packageList packageList)
    array(CREATE resolvedFeatures resolvedFeatures RECORDS)
    set(visited)

    # Internal helper to walk dependencies
    function(visit lol feature_name package_name is_a_prereq)
        if (NOT "${feature_name}/${package_name}" IN_LIST visited)
            list(APPEND visited "${feature_name}/${package_name}")
            set(visited ${visited} PARENT_SCOPE)

            parsePackage("${lol}"
                    FEATURE ${feature_name}
                    PACKAGE ${package_name}
                    PREREQS pre_
                    OUTPUT local_
            )

            foreach (pr_entry_ IN LISTS pre_)
                SplitAt("${pr_entry_}" "=" pr_feat_ pr_pkgname_)
                visit(${lol} "${pr_feat_}" "${pr_pkgname_}" ON)
            endforeach ()

            if (${is_a_prereq})
                record(APPEND resolvedNames "${feature_name}.*/${package_name}")
            else ()
                record(APPEND resolvedNames "${feature_name}/${package_name}")
            endif ()
            set(resolvedNames "${resolvedNames}" PARENT_SCOPE)

            array(APPEND resolvedFeatures RECORD "${local_}")
            set(resolvedFeatures "${resolvedFeatures}" PARENT_SCOPE)

            record(APPEND packageList ${package_name})
            set(packageList "${packageList}" PARENT_SCOPE)

            set(visited ${visited} PARENT_SCOPE)

        endif ()

        unset(dnc_)
        unset(e_)
        unset(eq_pos_)
        unset(feat_)
        unset(fname_)
        unset(found_entry_in_input_)
        unset(idx_)
        unset(local_)
        unset(pr_entry_)
        unset(pr_feat_)
        unset(pr_fname_)
        unset(pr_pkg_)
        unset(pr_pkgname_)
        unset(pr_pname_)
        unset(pr_real_pkgname_)
        unset(pre_)
        unset(this_featurelength_)
        unset(this_pkglength_)

    endfunction()

    # Pass 1: Handle LIBRARIES and their deep prerequisites first
    array(LENGTH resolveThese numberToResolve)
    foreach (rdPass RANGE 1 2)
        set(index 0)
        while (index LESS numberToResolve)
            array(GET resolveThese ${index} item)
            record(GET item ${FIXName} _feature_name _package_name)
            record(GET item ${FIXKind} _kind)
            if ((rdPass EQUAL 1 AND "${_kind}" STREQUAL "LIBRARY") OR
            (rdPass EQUAL 2 AND NOT "${_kind}" STREQUAL "LIBRARY"))
                visit(featureDict "${_feature_name}" "${_package_name}" OFF)
            endif ()
            inc(index)
        endwhile ()
    endforeach ()

    set(${featuresOut} "${resolvedFeatures}" PARENT_SCOPE)
    set(${namesOut} "${resolvedNames}" PARENT_SCOPE)
    set(packages ${packageList} PARENT_SCOPE)

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
function(scanLibraryTargets libName packageNames packageData)

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
                    if (wotPD STREQUAL "DICT")
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

        set(_pkg)
        set(_ns)
        set(_kind)
        set(_method)
        set(_repo_url)
        set(_tag)
        set(_incdir)
        set(_components)
        set(_hints)
        set(_paths)
        set(_args)
        set(_required)
        set(_prerequisites)
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

    #    object(CREATE hRevisedFeatures KIND ARRAY TYPE RECORDS LABEL revised_features)
    CREATE(COLLECTION hRevisedFeatures AS tRevisedFeatures OF RECORDS)
    set(_switches OVERRIDE_FIND_PACKAGE)
    set(_single_args PACKAGE NAMESPACE)
    set(_multi_args FIND_PACKAGE_ARGS ARGS COMPONENTS)
    set(_prefix AA)

    foreach (feature IN LISTS featureList)

        _()

        separate_arguments(feature NATIVE_COMMAND "${feature}")
        cmake_parse_arguments(${_prefix} "${_switches}" "${_single_args}" "${_multi_args}" ${feature})
        list(POP_FRONT AA_UNPARSED_ARGUMENTS _feature)
        # Sanity check

        if (AA_OVERRIDE_FIND_PACKAGE AND (AA_FIND_PACKAGE_ARGS OR "FIND_PACKAGE_ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES))
            msg(ALWAYS FATAL_ERROR "APP_FEATURES: Cannot combine OVERRIDE_FIND_PACKAGE with FIND_PACKAGE_ARGS")
        endif ()

        if (AA_PACKAGE OR "PACKAGE" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA_PACKAGE}" STREQUAL "")
                set(_pkg "${AA_PACKAGE}")
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: PACKAGE keyword given with no package name")
                list(REMOVE_ITEM AA_UNPARSED_ARGUMENTS "PACKAGE")
            endif ()
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
                #            string (POP_FRONT "${AA_COMPONENTS}" _first_component)
                #            string (JOIN "," _components "COMPONENTS=${_first_component}" ${AA_COMPONENTS})
                string(JOIN "&" _components ${AA_COMPONENTS})
            else ()
                msg(ALWAYS WARNING "APP_FEATURES: COMPONENTS keyword given with no components")
            endif ()
        endif ()

        if (AA_ARGS OR "ARGS" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            subProcess("${AA_ARGS}" retVar)
            string(JOIN "&" _args "${retVar}")
        endif ()

        # Add all the missing fields (the user's input list is just the basics,usually)
        set(hPackage)
        SELECT(* FROM ${hDataSource} WHERE NAME = ${_feature} INTO hCompleteFeature)
        #        object(GET hCompleteFeature FROM ${hDataSource} NAME EQUAL ${_feature})
        if (hCompleteFeature)
            if (AA_PACKAGE)
                SELECT(* FROM hCompleteFeature WHERE NAME = ${_pkg} INTO hPackage)
                #                object(GET hPackage FROM hCompleteFeature NAME "${_pkg}")
                if (hPackage)
                    SELECT(VALUE FROM hPackage WHERE INDEX = 1 INTO reqdPkgName)
                    #                    object(STRING reqdPkgName FROM hPackage INDEX 1)
                endif ()
            else ()
                SELECT(* FROM hCompleteFeature WHERE INDEX = 0 INTO hPackage)
                SELECT(VALUE FROM hPackage WHERE INDEX = 1 INTO defPkgName)
                #                object(GET hPackage FROM hCompleteFeature INDEX 0)
                #                object(STRING defPkgName FROM hPackage INDEX 1)
            endif ()
            if (NOT defPkgName)
                SELECT(* FROM hCompleteFeature INDEX = 0 INTO tPkg)
                SELECT(VALUE FROM tPkg INDEX = 1 INTO defPkgName)
                #                object(GET tPkg FROM hCompleteFeature INDEX 0)
                #                object(STRING defPkgName FROM tPkg INDEX 1)
            endif ()
        endif ()

        if (NOT hPackage)
            if (AA_NAME)
                msg(ALWAYS FATAL_ERROR "preProcessFeatures: Feature/Package \"${feature}/${_pkjg}\" does not exist")
            else ()
                msg(ALWAYS FATAL_ERROR "preProcessFeatures: Feature \"${feature}\" does not exist")
            endif ()
        endif ()

        string(TOUPPER "${_feature}" __temp_pkg)
        string(TOUPPER "${PLUGINS}" __temp_plugins)
        if (__temp_pkg IN_LIST __temp_plugins)
            set(__temp_pkg "PLUGIN")
        else ()
            set(__temp_pkg "${_pkg}")
        endif ()

        object(STRING _kind FROM hPackage INDEX ${FIXKind})
        if (_kind STREQUAL "SYSTEM" AND _pkg STREQUAL "${defPkgName}")
            # Don'd add this
            continue()
        endif ()

        CREATE()
        object(CREATE hOutput KIND RECORD LABEL ${_feature})
        object(SET hOutput INDEX 0
                "${_feature}"       # Name          0
                "${__temp_pkg}"     # PkgName       1
                "${_ns}"            # Namespace     2
                "${_kind}"          # Kind          3
                "${_method}"        # Method        4
                ""                  # Url           5
                "${_repo_url}"      # GitRepository 6
                "${_tag}"           # GitTag        7
                ""                  # SrcDir        8
                ""                  # BuildDir      9
                "${_incdir}"        # IncDir       10
                "${_components}"    # Components   11
                "${_args}"          # Args         12
                "${_prerequisites}" # Prereqs      13
        )
        unset(__temp_pkg)

        object(APPEND hRevisedFeatures RECORD hOutput)
    endforeach ()
    set(${outVar} "${hRevisedFeatures}" PARENT_SCOPE)
endfunction()
