include_guard(GLOBAL)

include(${CMAKE_SOURCE_DIR}/cmake/tools.cmake)
include(${CMAKE_SOURCE_DIR}/cmake/array_enhanced.cmake)

set(FIXName 0)
set(FIXPkgName 1)
set(FIXNamespace 2)
set(FIXKind 3)
set(FIXMethod 4)
set(FIXUrl 5)
set(FIXGitTag 6)
set(FIXSrcDir 5)
set(FIXBuildDir 6)
set(FIXIncDir 7)
set(FIXComponents 8)
set(FIXArgs 9)
set(FIXPrereqs 10)
math(EXPR FIXLength "${FIXPrereqs} + 1")

set(__longest_feature "17" CACHE INTERNAL "")
set(__longest_handler "17" CACHE INTERNAL "")

macro(fetchContentsHelp)

    set(help_msg [=[
HELP
        Print this help and exit

    Currently available package features are
]=])

    record(LENGTH PKG_FEATURES items)
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

    msg(" ")
    msg("addTargetProperties called for '${target}'")
    get_target_property(_aliasTarget ${target} ALIASED_TARGET)

    if (NOT ${_aliasTarget} STREQUAL "_aliasTarget-NOTFOUND")
        msg("Target ${target} is an alias. Retargeting target to target target ${_aliasTarget}")
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

    foreach (handler IN LISTS handlers)
        get_filename_component(handlerName "${handler}" NAME_WE)
        get_filename_component(_path "${handler}" DIRECTORY)
        get_filename_component(packageName "${_path}" NAME_WE)

        string(LENGTH ${handlerName} length)
        math(EXPR num_spaces "${longest} - ${length}")
        string(REPEAT " " ${num_spaces} padding)

        set(msg "Adding handler ${padding}${BOLD}${handlerName}${NC} for package ${BOLD}${packageName}${NC}")
        if (${handlerName} STREQUAL "init")
            string(APPEND msg " and calling it ...")
        endif ()
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
    endforeach ()
endfunction()
########################################################################################################################
########################################################################################################################
########################################################################################################################
function(addPackageData)
    set(switches SYSTEM USER LIBRARY)
    set(args METHOD FEATURE PKGNAME NAMESPACE URL GIT_REPOSITORY SRCDIR GIT_TAG BINDIR INCDIR COMPONENT ARG PREREQ)
    set(arrays COMPONENTS ARGS FIND_PACKAGE_ARGS PREREQS)

    cmake_parse_arguments("APD" "${switches}" "${args}" "${arrays}" ${ARGN})

    if (NOT APD_METHOD OR (NOT ${APD_METHOD} STREQUAL "PROCESS" AND NOT ${APD_METHOD} STREQUAL "FETCH_CONTENTS" AND NOT ${APD_METHOD} STREQUAL "FIND_PACKAGE"))
        msg(ALWAYS FATAL_ERROR "addPackageData: One of METHOD FIND_PACKAGE/FETCH_CONTENTS/PROCESS required for ${APD_FEATURE}")
    endif ()

    if (NOT APD_SYSTEM AND NOT APD_USER AND NOT APD_LIBRARY)
        set(APD_USER ON)
    endif ()

    if ((APD_SYSTEM AND APD_USER) OR (APD_SYSTEM AND APD_LIBRARY) OR (APD_USER AND APD_LIBRARY))
        msg(ALWAYS FATAL_ERROR "addPackageData: Zero or one of SYSTEM/USER/LIBRARY allowed")
    else ()
        if(APD_SYSTEM)
            set(APD_KIND "SYSTEM")
        elseif(APD_LIBRARY)
            set(APD_KIND "LIBRARY")
        else ()
            set(APD_KIND "USER")
        endif ()
    endif ()

    if (NOT APD_PKGNAME)
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
    if ((APD_GIT_REPOSITORY AND NOT APD_GIT_TAG) OR
    (NOT APD_GIT_REPOSITORY AND APD_GIT_TAG))
        msg(ALWAYS FATAL_ERROR "addPackageData: Neither or both GIT_REPOSITORY/GIT_TAG allowed")
    endif ()
    if ((APD_URL AND APD_GIT_TAG) OR
    (APD_SRCDIR AND APD_GIT_TAG))
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

#    if ("${APD_NAMESPACE}" STREQUAL "")
#        set(APD_NAMESPACE "-")
#    endif ()
    if (APD_GIT_REPOSITORY)
        set(URLorSRCDIR "${APD_GIT_REPOSITORY}")
    elseif (APD_SRCDIR)
        set(URLorSRCDIR "${APD_SRCDIR}")
    elseif (APD_URL)
        set(URLorSRCDIR "${APD_URL}")
#    else ()
#        set(URLorSRCDIR "-")
    endif ()
    if (APD_GIT_TAG)
        set(TAGorBINDIR "${APD_GIT_TAG}")
    elseif (APD_BINDIR)
        set(TAGorBINDIR "${APD_BINDIR}")
#    else ()
#        set(TAGorBINDIR "-")
    endif ()
#    if (NOT APD_INCDIR)
#        set(APD_INCDIR "-")
#    endif ()
    string(REPLACE ";" ":" APD_COMPONENTS "${APD_COMPONENTS}")
#    if ("${APD_COMPONENTS}" STREQUAL "")
#        set(APD_COMPONENTS "-")
#    endif ()
#    unset(temp)
    string(JOIN ":" APD_ARGS ${APD_ARGS} ${APD_FIND_PACKAGE_ARGS})
#    if("${APD_ARGS}" STREQUAL "")
#        set(APD_ARGS "-")
#    endif ()
    if (APD_PREREQS)
        string(REPLACE ";" ":" APD_PREREQS "${APD_PREREQS}")
#    else ()
#        set(APD_PREREQS "-")
    endif ()

    record(CREATE output ${APD_FEATURE} ${FIXLength})
    record(SET output "${FIXName}"
            "${APD_FEATURE}"
            "${APD_PKGNAME}"
            "${APD_NAMESPACE}"
            "${APD_KIND}"
            "${APD_METHOD}"
            "${URLorSRCDIR}"
            "${TAGorBINDIR}"
            "${APD_INCDIR}"
            "${APD_COMPONENTS}"
            "${APD_ARGS}"
            "${APD_PREREQS}"
    )


    function(createOrAppendRecord)

        set(switches QUIET REPLACE EXTEND UNIQUE)
        set(args OBJECT FEATURE DATA TEXT MARKER)
        set(lists "")

        set(car_object  "")
        set(car_quiet   OFF)
        set(car_extend  ON)
        set(car_replace OFF)
        set(car_unique  OFF)
        set(car_feature "")
        set(car_data    "")
        set(car_text    "")
        set(car_marker  "{}")

        cmake_parse_arguments("CAR" "${switches}" "${args}" "${lists}" ${ARGN})

        if(NOT CAR_OBJECT OR "${CAR_OBJECT}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no OBJECT in call to createOrAppendRecord()")
        else ()
            set(car_object "${CAR_OBJECT}")
        endif ()

        if(CAR_QUIET)
            set(car_quiet ON)
        endif ()
        if(CAR_REPLACE)
            set(car_extend  OFF)
            set(car_replace ON)
        endif ()
        if(CAR_EXTEND)
            set(car_extend  ON)
            set(car_replace OFF)
        endif ()
        if(CAR_UNIQUE)
            set(car_unique ON)
        endif ()
        if(NOT CAR_FEATURE OR "${CAR_FEATURE}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no FEATURE in call to createOrAppendRecord()")
        else ()
            set(car_feature "${CAR_FEATURE}")
        endif ()
        if(CAR_DATA AND NOT "${CAR_DATA}" STREQUAL "")
            set(car_data "${CAR_DATA}")
        endif ()
        if(CAR_TEXT AND NOT "${CAR_TEXT}" STREQUAL "")
            set(car_text "${CAR_TEXT}")
        else ()
            set(car_text "pfft")
        endif ()
        if(CAR_MARKER AND NOT "${CAR_MARKER}" STREQUAL "")
            set(car_marker "${CAR_MARKER}")
        endif ()

        set(car_action)

        collection(GET ${car_object} EQUAL "${car_feature}" targetFeature)

        if (NOT targetFeature)
            array(CREATE targetFeature "${car_feature}" RECORDS)
            array(APPEND targetFeature RECORD "${car_data}")
            set(car_action "created")
        else ()
            if(car_extend)
                if (car_unique)
                    array(NAME "${car_data}" data_name)
                    array(FIND targetFeature "${data_name}" existing_data)
                    if(existing_data STREQUAL "")
                        array(APPEND targetFeature RECORD "${car_data}")
                        set(car_action "added to")
                    else ()
                        array(SET targetFeature NAME "${car_feature}" RECORD "${car_data}")
                        set(car_action "${MAGENTA}replaced ${NC} in")
                    endif ()
                else ()
                    array(APPEND targetFeature RECORD "${car_data}")
                    if(car_text)
                        set(car_action "${YELLOW}extended${NC}")
                    endif ()
                endif ()
            else()
                array(NAME "${car_data}" data_name)
                array(FIND targetFeature EQUAL "${data_name}" existing_data)
                if(existing_data STREQUAL "")
                    array(APPEND targetFeature RECORD "${car_data}")
                    set(car_action "added to")
                else ()
                    array(SET targetFeature NAME "${car_feature}" RECORD "${car_data}")
                    set(car_action "${MAGENTA}replaced ${NC} in")
                endif ()
            endif ()
        endif ()
        collection(SET ${car_object} "${car_feature}" "${targetFeature}")
        set(${car_object} "${${car_object}}" PARENT_SCOPE)

        if (NOT car_quiet)
            string(REPLACE "${car_marker}" "${car_action}" car_text "${car_text}")
            msg("${car_text}")
        endif ()
    endfunction()
    function(createOrAppendField)

        set(switches QUIET REPLACE EXTEND UNIQUE)
        set(args OBJECT FEATURE FIELD TEXT MARKER)
        set(lists "")

        set(caf_object  "")
        set(caf_quiet   OFF)
        set(caf_extend  ON)
        set(caf_replace OFF)
        set(caf_unique  OFF)
        set(caf_feature "")
        set(caf_data    "")
        set(caf_text    "")
        set(caf_marker  "{}")
        set(caf_action)
        cmake_parse_arguments("CAF" "${switches}" "${args}" "${lists}" ${ARGN})

        if(NOT CAF_OBJECT OR "${CAF_OBJECT}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no OBJECT in call to createOrAppendField()")
        else ()
            set(caf_object "${CAF_OBJECT}")
        endif ()

        if(CAF_QUIET)
            set(caf_quiet ON)
        endif ()
        if(CAF_REPLACE)
            set(caf_extend  OFF)
            set(caf_replace ON)
        endif ()
        if(CAF_EXTEND)
            set(caf_extend  ON)
            set(caf_replace OFF)
        endif ()
        if(CAF_UNIQUE)
            set(caf_unique ON)
        endif ()
        if(NOT CAF_FEATURE OR "${CAF_FEATURE}" STREQUAL "")
            msg(ALWAYS FATAL_ERROR "no FEATURE in call to createOrAppendField()")
        else ()
            set(caf_feature "${CAF_FEATURE}")
        endif ()
        if(CAF_FIELD AND NOT "${CAF_FIELD}" STREQUAL "")
            set(caf_field "${CAF_FIELD}")
        endif ()
        if(CAF_TEXT AND NOT "${CAF_TEXT}" STREQUAL "")
            set(caf_text "${CAF_TEXT}")
        else ()
            set(caf_text "pfft")
        endif ()
        if(CAF_MARKER AND NOT "${CAF_MARKER}" STREQUAL "")
            set(caf_marker "${CAF_MARKER}")
        endif ()

        collection(GET ${caf_object} EQUAL "${caf_feature}" targetRecord)

        if (NOT targetRecord)
            record(CREATE targetRecord "${caf_feature}" 1)
            record(APPEND targetRecord "${caf_field}")
            set(caf_action "added to")
        else ()
            if(caf_extend)
                if(caf_unique)
                    record(FIND targetRecord "${caf_field}" index)
                    if (index EQUAL -1)
                        record(APPEND targetRecord "${caf_field}")
                        set(caf_action "added to")
                    else ()
                        set(caf_action "ignored in")
                        set(caf_text "${caf_text} : ${GREEN}already exists${NC}")
                    endif ()
                else ()
                    record(APPEND targetRecord "${caf_field}")
                    set(caf_action "${YELLOW}extended${NC}")
                endif ()
            else ()
                record(FIND targetRecord "${caf_field}" index)
                if (index EQUAL -1)
                    record(APPEND targetRecord "${caf_field}")
                    set(caf_action "added to")
                else ()
                    record(SET targetRecord ${index} "${caf_field}")
                    set(caf_action "${MAGENTA}replaced ${NC} in")
                endif ()
            endif ()
        endif ()
        collection(SET ${caf_object} "${caf_feature}" ${targetRecord})

        if (NOT caf_quiet)
            string(REPLACE "${caf_marker}" "${caf_action}" caf_text "${caf_text}")
            msg("${caf_text}")
        endif ()

        set(${caf_object} "${${caf_object}}" PARENT_SCOPE)

    endfunction()

    longest(CURRENT ${__longest_feature} LEFT  PAD_CHAR " " LONGEST __longest_feature TEXT "${APD_FEATURE}" PADDED left_padded_feature)
    longest(CURRENT ${__longest_feature} RIGHT PAD_CHAR " " LONGEST __longest_feature TEXT "${APD_FEATURE}" PADDED right_padded_feature)
    longest(CURRENT ${__longest_feature} LEFT  PAD_CHAR " " LONGEST __longest_feature TEXT "${APD_PKGNAME}" PADDED left_padded_package)
    longest(CURRENT ${__longest_feature} RIGHT PAD_CHAR " " LONGEST __longest_feature TEXT "${APD_PKGNAME}" PADDED right_padded_package)

    set(globalfeatureText  "       Feature ${BOLD}${right_padded_feature}${NC} {} for package ${BOLD}${APD_PKGNAME}${NC} and was added to the ${GREEN}${BOLD}GLOBAL${NC} feature collection")
    set(systemfeatureText  "       Feature ${BOLD}${right_padded_feature}${NC} {} for package ${BOLD}${APD_PKGNAME}${NC} and was added to the ${BLUE}${BOLD}SYSTEM${NC} feature collection")
    set(libraryfeatureText "       Feature ${BOLD}${right_padded_feature}${NC} {} for package ${BOLD}${APD_PKGNAME}${NC} and was added to the ${CYAN}${BOLD}LIBRARY${NC} feature collection")
    set(generalfeatureText "       Feature ${BOLD}${right_padded_feature}${NC} {} for package ${BOLD}${APD_PKGNAME}${NC} and was added to the ${BOLD}OPTIONAL${NC} feature collection")

    set(globalpackageText  "       Package ${BOLD}${right_padded_package}${NC} created and linked to feature ${BOLD}${APD_FEATURE}${NC} in the ${GREEN}${BOLD}GLOBAL${NC} feature collection")
    set(systempackageText  "       Package ${BOLD}${right_padded_package}${NC} created and linked to feature ${BOLD}${APD_FEATURE}${NC} in the ${BLUE}${BOLD}SYSTEM${NC} feature collection")
    set(librarypackageText "       Package ${BOLD}${right_padded_package}${NC} created and linked to feature ${BOLD}${APD_FEATURE}${NC} in the ${CYAN}${BOLD}LIBRARY${NC} feature collection")
    set(generalpackageText "       Package ${BOLD}${right_padded_package}${NC} created and linked to feature ${BOLD}${APD_FEATURE}${NC} in the ${BOLD}OPTIONAL${NC} feature collection")

    set(globalnameText     "               ${BOLD}${right_padded_feature}${NC} {} the ${GREEN}${BOLD}GLOBAL${NC} feature names")
    set(systemnameText     "       Feature ${BOLD}${right_padded_feature}${NC} {} the ${BLUE}${BOLD}SYSTEM${NC} feature names")
    set(librarynameText    "       Feature ${BOLD}${right_padded_feature}${NC} {} the ${CYAN}${BOLD}LIBRARY${NC} feature names")
    set(generalnameText    "       Feature ${BOLD}${right_padded_feature}${NC} {} the ${BOLD}OPTIONAL${NC} feature names")

    set(APD_FEATPKG "${APD_FEATURE}/${APD_PKGNAME}")

    # Add new feature/pkg to the global FEATURES collection
    createOrAppendRecord(   OBJECT "FEATURES"           FEATURE "${APD_FEATURE}" DATA "${output}"           EXTEND        MARKER "{}" TEXT "${globalfeatureText}")
    createOrAppendField (   OBJECT "FEATURES"           FEATURE "PACKAGES"       FIELD ${APD_FEATPKG}       EXTEND UNIQUE MARKER "{}" TEXT "${globalpackageText}")
    createOrAppendField (   OBJECT "FEATURES"           FEATURE "NAMES"          FIELD ${APD_FEATURE}       EXTEND UNIQUE MARKER "{}" TEXT "${globalnameText}")
    if(APD_KIND MATCHES "SYSTEM")
        createOrAppendRecord(OBJECT "SYSTEM_FEATURES"   FEATURE "${APD_FEATURE}" DATA "${output}"           EXTEND        MARKER "{}" TEXT "${systemfeatureText}")
        createOrAppendField (OBJECT "SYSTEM_FEATURES"   FEATURE "PACKAGES"       FIELD ${APD_FEATPKG}       EXTEND UNIQUE MARKER "{}" TEXT "${systempackageText}")
        createOrAppendField (OBJECT "SYSTEM_FEATURES"   FEATURE "NAMES"          FIELD ${APD_FEATURE}       EXTEND UNIQUE MARKER "{}" TEXT "${systemnameText}")
    elseif(APD_KIND MATCHES "LIBRARY")
        createOrAppendRecord(OBJECT "LIBRARY_FEATURES"  FEATURE "${APD_FEATURE}" DATA "${output}"           EXTEND        MARKER "{}" TEXT "${libraryfeatureText}")
        createOrAppendField (OBJECT "LIBRARY_FEATURES"  FEATURE "PACKAGES"       FIELD ${APD_FEATPKG}       EXTEND UNIQUE MARKER "{}" TEXT "${librarypackageText}")
        createOrAppendField (OBJECT "LIBRARY_FEATURES"  FEATURE "NAMES"          FIELD ${APD_FEATURE}       EXTEND UNIQUE MARKER "{}" TEXT "${librarynameText}")
    elseif(APD_KIND MATCHES "USER")
        createOrAppendRecord(OBJECT "USER_FEATURES"     FEATURE "${APD_FEATURE}" DATA "${output}"           EXTEND        MARKER "{}" TEXT "${generalfeatureText}")
        createOrAppendField (OBJECT "USER_FEATURES"     FEATURE "PACKAGES"       FIELD ${APD_FEATPKG}       EXTEND UNIQUE MARKER "{}" TEXT "${generalpackageText}")
        createOrAppendField (OBJECT "USER_FEATURES"     FEATURE "NAMES"          FIELD ${APD_FEATURE}       EXTEND UNIQUE MARKER "{}" TEXT "${generalnameText}")
    endif()

    set(FEATURES         "${FEATURES}"         PARENT_SCOPE)
    set(SYSTEM_FEATURES  "${SYSTEM_FEATURES}"  PARENT_SCOPE)
    set(LIBRARY_FEATURES "${LIBRARY_FEATURES}" PARENT_SCOPE)
    set(USER_FEATURES    "${USER_FEATURES}"    PARENT_SCOPE)

    set(__longest_feature ${__longest_feature} CACHE INTERNAL "")
    set(__longest_handler ${__longest_handler} CACHE INTERNAL "")

endfunction()
##
######################################################################################
##
function(getFeaturePkgList arrayName feature receivingVarName)
    # iterate over array to find line with feature
    unset("${receivingVarName}" PARENT_SCOPE)
    array(LENGTH "${arrayName}" numFeatures)
    if (numFeatures GREATER 0)
        foreach(currIndex RANGE ${numFeatures})
            array(GET "${arrayName}" ${currIndex} _thisArray)

            array(KIND "_thisArray" _thisArrayKind)
            if(_thisArrayKind STREQUAL "ARRAYS")
                getFeaturePkgList("_thisArray" "${feature}" "${receivingVarName}")
                set("${receivingVarName}" "${receivingVarName}" PARENT_SCOPE)
                return()
            endif ()
            array(FIND "_thisArray" ${FIXName} MATCHING "${feature}" _foundAt)
            if (_foundAt GREATER_EQUAL 0)
                set(${receivingVarName} "${_thisArray}" PARENT_SCOPE)
                return()
            endif ()
        endforeach ()
    endif ()
    set("${receivingVarName}" "NOTFOUND" PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeatureIndex arrayName feature receivingVarName)
    # iterate over array to find line with feature
    array(FIND "${arrayName}" ${FIXName} MATCHING "${feature}" _foundAt)
    set(${receivingVarName} "${_foundAt}" PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeaturePackage arrayName feature index receivingVarName)
    array(LENGTH ${arrayName} numFeatures)
    if (numFeatures)
        foreach(featureIndex RANGE ${numFeatures})
            array(GET ${arrayName} ${featureIndex} item)
            array(LENGTH item numPackages)
            if (numPackages)
                array(GET item ${index} pkg)
                record(GET pkg ${FIXName} thisFeatureName thisPackageName)
                if (feature STREQUAL thisFeatureName)
                    set(${receivingVarName} ${pkg} PARENT_SCOPE)
                    return()
                endif ()
            endif ()
        endforeach ()
    endif ()
    set (${receivingVarName} "NOTFOUND")
    set(${indexVarName} -2 PARENT_SCOPE)
endfunction()
##
######################################################################################
##
function(getFeaturePackageByName arrayName feature name receivingVarName indexVarName)
    array(LENGTH ${arrayName} numFeatures)
    if (numFeatures)
        foreach(featureIndex RANGE ${numFeatures})
            array(GET ${arrayName} ${featureIndex} item)
            array(LENGTH item numPackages)
            if (numPackages)
                foreach(packageIndex RANGE ${numPackages})
                    array(GET item ${packageIndex} pkg)
                    record(GET pkg ${FIXName} thisFeatureName thisPackageName)
                    if (feature STREQUAL thisFeatureName AND name STREQUAL thisPackageName)
                        set(${receivingVarName} ${pkg} PARENT_SCOPE)
                        set(${indexVarName} ${packageIndex} PARENT_SCOPE)
                        return()
                    endif ()
                endforeach ()
            endif ()
        endforeach ()
    endif ()
    set (${receivingVarName} "NOTFOUND")
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
            NAMESPACE   #   VARNAME     OUT         Receive a copy of the NAMESPACE attribute (if applicable)
            KIND        #   VARNAME     OUT         Receive a copy of the KIND attribute (SYSTEM/LIBRARY/USER)
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

    if (NOT DEFINED A_PP_INPUT_TYPE)
        # How we know what we have;
        # Definitions
        # PIPELIST      Like a CMAKE LIST, except each record separator ";" is replaced by a PIPE ("|") symbol.
        #               The list(LENGTH...)    of a PIPELIST will be 1.
        #               The piplist(LENGTH...) of a PIPELIST will be from ${PkgFields} to ${FeatureFields} + n * ${PkgFields}
        # PACKAGE       A PIPELIST. array(LENGTH...) will be ${PkgFields}
        # FEATURE       A PIPELIST that Looks like this <FEATURE_NAME><PACKAGE>[,<PACKAGE>[...]]
        #               so a FEATURE has the length of ${FeatureFields} + n * ${PkgFields}
        # SET           A CMake LIST of FEATURES. Each FEATURE will be one PIPELIST

        # See if this is a PIPELIST
        list(LENGTH ${inputListName} listLength)
        record(LENGTH ${inputListName} pipeLength)

        if (${listLength} GREATER_EQUAL 2)
            # Can ONLY be a set. We'll check if it is later
            set(A_PP_INPUT_TYPE "SET")
        elseif (${listLength} EQUAL 1 AND ${pipeLength} EQUAL ${PkgFields})
            # Can ONLY be a PACKAGE. We'll check if it is later
            set(A_PP_INPUT_TYPE "PACKAGE")
        elseif (${listLength} EQUAL 1 AND ${pipeLength} GREATER_EQUAL ${FeatureFields})
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

            record(LENGTH ${${inputListName}} len)
            if (NOT ${len} EQUAL "${PkgFields}")
                set(inputListVerifyFailed "Input PACKAGE length of ${len} should be ${PkgFields}")
            endif ()
            set(local "${${inputListName}}")
        elseif (${A_PP_INPUT_TYPE} MATCHES "FEATURE")
            set(A_FEATURE ON)

            record(LENGTH ${inputListName} len)
            if (NOT ${len} GREATER_EQUAL "${FeatureFields}")
                set(inputListVerifyFailed "Input FEATURE length of ${len} should be at least ${PkgFields}")
            else ()
                string(REPLACE "," ";" sampleList "${${inputListName}}")
                list(LENGTH sampleList pkgCount)
                math(EXPR expectedFields "1 + (${pkgCount} * ${PkgFields})")
                if (NOT ${len} EQUAL "${expectedFields}")
                    set(inputListVerifyFailed "FEATURE length of ${len} should be ${expectedFields}\n${sampleList}")
                endif ()
            endif ()
        elseif (${A_PP_INPUT_TYPE} MATCHES "SET")
            set(A_SET ON)
            set (whichElement 0)
            list(LENGTH ${inputListName} numElements)
            foreach(sample IN LISTS ${inputListName})
                math(EXPR whichElement "${whichElement} + 1")
                string(REPLACE "," ";" sampleList "${sample}")
                list(LENGTH sampleList pkgCount)
                string(REPLACE ";" "&" samplePipelist "${sampleList}")
                record(LENGTH samplePipelist len)
                math(EXPR expectedFields "1 + (${pkgCount} * ${PkgFields})")
                if (NOT (${len} EQUAL ${PkgFields} OR ${len} EQUAL "${expectedFields}"))
                    list(APPEND inputListVerifyFailed "FEATURE #${whichElement} of ${numElements} in input list is invalid\n${sample}\n")
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

    if (NOT (A_PP_PACKAGE OR DEFINED A_PP_PKG_INDEX))
        msg (ALWAYS FATAL_ERROR "parsePackage() needs PACKAGE or PKG_INDEX parameter")
    endif ()

    if (DEFINED A_PP_PKG_INDEX AND A_PP_PACKAGE)
        msg(ALWAYS WARNING "parsePackage() both PACKAGE and PKG_FEATURE supplied. Need one or the other")
    endif ()

    if(A_SET OR A_FEATURE)
        if(A_FEATURE)
            SplitAt("${${inputListName}}" "|" A_PP_FEATURE local)
        endif ()
        if(DEFINED A_PP_PKG_INDEX)
            getFeaturePackage("${inputListName}" "${A_PP_FEATURE}" "${A_PP_PKG_INDEX}" local)
            SplitAt("${local}" "|" localName dc)
            set(localIndex ${A_PP_PKG_INDEX})
        else ()
            getFeaturePackageByName(inputListName "${A_PP_FEATURE}" "${A_PP_PACKAGE}" local localIndex)
            set(localName "${A_PP_PACKAGE}")
        endif ()
    else()
        set(local ${${inputListName}})
        set(localIndex "UNKNOWN")
        SplitAt("${local}" "|" localName dc)
    endif ()

    string(REPLACE "&" ";" pkg "${local}")
    list(LENGTH pkg length)

    # Easy ones
    list(GET pkg ${PkgNamespaceIX} localNS)
    list(GET pkg ${PkgKindIX}      localKind)
    list(GET pkg ${PkgMethodIX}    localMethod)

    # Initialize output variables
    if(DEFINED A_PP_OUTPUT)
        set(${A_PP_OUTPUT}      "${local}"      PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_NAME)
        set(${A_PP_NAME}        ${localName}    PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_INDEX)
        set(${A_PP_INDEX}       ${localIndex}   PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_NAMESPACE)
        set(${A_PP_NAMESPACE}   "${localNS}"    PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_KIND)
        set(${A_PP_KIND}        ${localKind}    PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_METHOD)
        set(${A_PP_METHOD}      ${localMethod}  PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_URL)
        set(${A_PP_URL}         ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_GIT_TAG)
        set(${A_PP_GIT_TAG}     ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_SRC_DIR)
        set(${A_PP_SRC_DIR}     ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_BUILD_DIR)
        set(${A_PP_BUILD_DIR}   ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_INC_DIR)
        set(${A_PP_INC_DIR}     ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_COMPONENTS)
        set(${A_PP_COMPONENTS}  ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_ARGS)
        set(${A_PP_ARGS}        ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_PREREQS)
        set(${A_PP_PREREQS}     ""              PARENT_SCOPE)
    endif ()
    if(DEFINED A_PP_FETCH_FLAG)
        set(${A_PP_FETCH_FLAG}  ON              PARENT_SCOPE)
    endif ()

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
function(resolveDependencies inputFeaturesList allData outputFeaturesList outputFeatureNamesList)
    # inputList is unifiedFeatureList
    # allData   is AllPackageData

    set(resolvedFeatureNamesList)
    set(resolvedFeaturesList)
    set(packageList)
    set(visited)
    set(longestPkgName 0)
    set(longestFeatureName 0)

    # Internal helper to walk dependencies
    function(visit lol feature_name feat idx is_a_prereq)
        if (NOT "${feature_name}" IN_LIST visited)
            list(APPEND visited "${feature_name}")
            set(visited ${visited} PARENT_SCOPE)

            parsePackage("feat"
                    PKG_INDEX ${idx}
                    INDEX idx_
                    PREREQS pre_
                    NAME pkgname_
            )

            string(LENGTH "${pkgname_}" this_pkglength_)
            if (${this_pkglength_} GREATER ${longestPkgName})
                set(longestPkgName ${this_pkglength_} PARENT_SCOPE)
            endif ()

            string(LENGTH "${feature_name}" this_featurelength_)
            if (${this_featurelength_} GREATER ${longestFeatureName})
                set(longestFeatureName ${this_featurelength_} PARENT_SCOPE)
            endif ()

            foreach(pr_entry_ IN LISTS pre_)
                SplitAt("${pr_entry_}" "=" pr_feat_ pr_pkgname_)

                set(found_entry_in_input_ "")
                # TODO: Line below changed from inputLiist to allData
                foreach(e_ IN LISTS ${lol}) # inputList)
                    record(GET e_ ${FIXName} pr_fname_)
                    record(GET e_ ${FIXPkgName} pr_pname_)
                    if("${pr_feat_}" MATCHES "${pr_fname_}" AND "${pr_pkgname_}" STREQUAL "${pr_pname_}")
                        set(found_entry_in_input_ "${pr_fname_}=${pr_pname_}")
                        getFeaturePackageByName("${lol}" "${pr_fname_}" "${pr_pname_}" prereq_pkg prereq_idx)
                        visit("${lol}" "${pr_fname_}" "${pr_fname_}|${prereq_pkg}" "${prereq_idx}" ON)
                        break()
                    endif()
                endforeach()
            endforeach()

            if (${is_a_prereq})
                list(APPEND resolvedFeatureNamesList "${feature_name}.*")
            else ()
                list(APPEND resolvedFeatureNamesList "${feature_name}")
            endif ()
            set(resolvedFeatureNamesList "${resolvedFeatureNamesList}" PARENT_SCOPE)

            list(APPEND resolvedFeaturesList "${feat}")
            set(resolvedFeaturesList "${resolvedFeaturesList}" PARENT_SCOPE)

            list(APPEND packageList ${pkgname_})
            set(packageList "${packageList}")

            set(visited ${visited} PARENT_SCOPE)

        endif()

        unset(dnc_)
        unset(e_)
        unset(eq_pos_)
        unset(feat_)
        unset(fname_)
        unset(found_entry_in_input_)
        unset(idx_)
        unset(pr_entry_)
        unset(pr_feat_)
        unset(pr_fname_)
        unset(pr_pname_)
        unset(pr_pkg_)
        unset(pr_pkgname_)
        unset(pr_real_pkgname_)
        unset(pre_)
        unset(this_featurelength_)
        unset(this_pkglength_)

    endfunction()

    # Pass 1: Handle LIBRARIES and their deep prerequisites first
    foreach(item IN LISTS ${inputFeaturesList})
        record(GET item ${FIXName} _feature_name)
        record(GET item ${FIXKind} _kind)
        if ("${_kind}" STREQUAL "LIBRARY")
            visit("${allData}" "${_feature_name}" "${item}" 0 OFF)
        endif()
    endforeach()

    # Pass 2: Handle everything else
    foreach(item IN LISTS ${inputFeaturesList})
        record(GET item ${FIXName} _feature_name)
        visit("${allData}" "${_feature_name}" "${item}" 0 OFF)
    endforeach()

    set(${outputFeaturesList}      "${resolvedFeaturesList}"        PARENT_SCOPE)
    set(${outputFeatureNamesList}  "${resolvedFeatureNamesList}"    PARENT_SCOPE)
    set(longestPkgName              ${longestPkgName}               PARENT_SCOPE)
    set(longestFeatureName          ${longestFeatureName}           PARENT_SCOPE)
    set(packages                    ${packageList}                  PARENT_SCOPE)

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
                    string(REPLACE "&" ";" pkg_details "${pkg_entry}")
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
# TODO:                        set(${pkg_name}_ALREADY_FOUND ON CACHE INTERNAL "")
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
    macro (_)

        set (_pkg "-")
        set (_ns "-")
        set (_kind "-")
        set (_method "-")
        set (_url "-")
        set (_tag "-")
        set (_incdir "-")
        set (_components "-")
        set (_hints "-")
        set (_paths "-")
        set (_args "-")
        set (_required "-")
        set (_prerequisites "-")
        set (_first_hint "-")
        set (_first_path "-")
        set (_first_component "-")

    endmacro()

    array(CREATE revised_features revised_features RECORDS)

    set(_switches OVERRIDE_FIND_PACKAGE)
    set(_single_args PACKAGE NAMESPACE)
    set(_multi_args FIND_PACKAGE_ARGS COMPONENTS)
    set(_prefix AA)

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

        if (AA_NAMESPACE OR "NAMESPACE" IN_LIST AA_KEYWORDS_MISSING_VALUES)
            if (NOT "${AA_NAMESPACE}" STREQUAL "")
                set (_ns "${AA_NAMESPACE}")
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
                set (featureless ${feature})
                list (REMOVE_ITEM featureless "${_feature}" "FIND_PACKAGE_ARGS")
                cmake_parse_arguments("AA1" "REQUIRED;OPTIONAL" "PACKAGE;NAMESPACE" "COMPONENTS;PATHS;HINTS" ${featureless}) #${AA_FIND_PACKAGE_ARGS})

                if (AA1_HINTS OR "HINTS" IN_LIST AA1_KEYWORDS_MISSING_VALUES)
                    if (NOT "${AA1_HINTS}" STREQUAL "")
                        replacePositionalParameters("${AA1_HINTS}" _hints OFF)
                        if (_hints)
                            string(JOIN ":" _hints "HINTS" ${_hints})
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
                            string(JOIN ":" _paths "PATHS" ${_paths})
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

            else ()
                list(REMOVE_ITEM AA1_UNPARSED_ARGUMENTS "FIND_PACKAGE_ARGS")
            endif ()
            string(JOIN ":" _args "${_args}" ${_required} ${_hints} ${_paths} ${AA1_UNPARSED_ARGUMENTS})
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

        record(CREATE output "${_feature}"          ${FIXLength})
        record(SET output "${FIXName}"
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
                "${_prerequisites}"
        )

        array(APPEND revised_features RECORD "${output}")

    endforeach ()


endfunction()
