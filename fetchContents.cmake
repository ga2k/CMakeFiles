include(FetchContent)
include(${CMAKE_SOURCE_DIR}/cmake/fetchContentsFns.cmake)

set(SystemCategoryData)
set(UserCategoryData)

macro(call_handler fn pkg)
    set(fn ${fn})
    set(HANDLED OFF)
    set(handler "${CMAKE_SOURCE_DIR}/cmake/handlers/${pkg}/${fn}.cmake")
    if (EXISTS ${handler})
        include("${handler}")
    endif ()
endmacro()

function(addTarget target pkgname addToLists components)

    set(old_LibrariesList ${_LibrariesList})
    set(old_DependenciesList ${_DependenciesList})

    unset(at_LibrariesList)
    unset(at_DependenciesList)
    if ("${pkgname}" STREQUAL "wxxml" OR "${target}" STREQUAL "wxxml")
        return()
    endif ()
    message("addTarget called for '${target}'")
    get_target_property(_aliasTarget ${target} ALIASED_TARGET)

    if (NOT ${_aliasTarget} STREQUAL "_aliasTarget-NOTFOUND")
        message("Target ${target} is an alias. Retargeting target to target ${_aliasTarget}")
        addTarget(${_aliasTarget} "${pkgname}" ${addToLists} "${components}")
        set(_LibrariesList ${_LibrariesList} PARENT_SCOPE)
        set(_DependenciesList ${_DependenciesList} PARENT_SCOPE)
        return()
    endif ()

    get_target_property(_targetType ${target} TYPE)
    #    if (${_targetType} STREQUAL "INTERFACE_LIBRARY")
    #        message("Not configuring target ${target} : it's an interface.")
    #    endif ()

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
    endif ()

    set_target_properties("${target}" PROPERTIES
            RUNTIME_OUTPUT_DIRECTORY ${OUTPUT_DIR}/bin
            LIBRARY_OUTPUT_DIRECTORY ${OUTPUT_DIR}/dll
            ARCHIVE_OUTPUT_DIRECTORY ${OUTPUT_DIR}/lib
    )

    ################################################################################################################
    ################################################################################################################
    ################################################################################################################
    ################################################################################################################
    call_handler(postAddTarget ${pkgname}) #########################################################################
    ################################################################################################################
    ################################################################################################################
    ################################################################################################################
    ################################################################################################################

    list(APPEND at_LibrariesList ${_LibrariesList})
    list(APPEND at_DependenciesList ${_DependenciesList})

    set(_LibrariesList ${at_LibrariesList} PARENT_SCOPE)
    set(_DependenciesList ${at_DependenciesList} PARENT_SCOPE)

endfunction()


#######################################################################################################################
#######################################################################################################################
#######################################################################################################################
function(initialiseFeatureHandlers)
    file(GLOB handlers LIST_DIRECTORIES true "${CMAKE_SOURCE_DIR}/${APP_VENDOR}/cmake/handlers/*")
    foreach (handler IN LISTS handlers)
        get_filename_component(basename "${handler}" NAME_WE)
        ################################################################################################################
        ################################################################################################################
        message("Adding handler for ${basename}") ######################################################################
        call_handler(init ${basename}) #################################################################################
        ################################################################################################################
        ################################################################################################################
        ################################################################################################################
    endforeach ()
endfunction()
###################################################################################################################
###################################################################################################################
###################################################################################################################
function(addPackageData)
    set(switches SYSTEM;USER)
    set(args METHOD;CATEGORY;PKGNAME;NAMESPACE;URL;GIT_REPOSITORY;SRCDIR;GIT_TAG;BINDIR;INCDIR;COMPONENT;ARG)
    set(arrays COMPONENTS;ARGS)

    cmake_parse_arguments("aoc" "${switches}" "${args}" "${arrays}" ${ARGN})

    if (NOT aoc_METHOD OR (NOT ${aoc_METHOD} STREQUAL "PROCESS" AND NOT ${aoc_METHOD} STREQUAL "FETCH_CONTENTS" AND NOT ${aoc_METHOD} STREQUAL "FIND_PACKAGE"))
        message(FATAL_ERROR "addPackageData: One of METHOD FIND/FETCH/PROCESS required")
    endif ()

    if (aoc_SYSTEM AND aoc_USER)
        message(FATAL_ERROR "addPackageData: Zero or one of SYSTEM/USER allowed")
    endif ()
    if (NOT aoc_PKGNAME)
        message(FATAL_ERROR "addPackageData: PKGNAME required")
    endif ()
    if ((aoc_URL AND aoc_GIT_REPOSITORY) OR
    (aoc_URL AND aoc_SRCDIR) OR
    (aoc_GIT_REPOSITORY AND aoc_SRCDIR))
        message(FATAL_ERROR "addPackageData: Only one of URL/GIT_REPOSITORY/SRCDIR allowed")
    endif ()
    if (NOT aoc_URL AND NOT aoc_GIT_REPOSITORY AND NOT aoc_SRCDIR AND aoc_METHOD STREQUAL "FETCH_CONTENTS")
        message(FATAL_ERROR "addPackageData: One of URL/GIT_REPOSITORY/SRCDIR required")
    endif ()
    if ((aoc_GIT_REPOSITORY AND NOT aoc_GIT_TAG) OR
    (NOT aoc_GIT_REPOSITORY AND aoc_GIT_TAG))
        message(FATAL_ERROR "addPackageData: Neither or both GIT_REPOSITORY/GIT_TAG allowed")
    endif ()
    if ((aoc_URL AND aoc_GIT_TAG) OR
    (aoc_SRCDIR AND aoc_GIT_TAG))
        message(FATAL_ERROR "addPackageData: GIT_TAG only allowed with GIT_REPOSITIORY")
    endif ()
    if (aoc_GIT_TAG AND aoc_BINDIR)
        message(FATAL_ERROR "addPackageData: Only one of GIT_TAG or BINDIR allowed")
    endif ()

    if (aoc_COMPONENT)
        list(APPEND aoc_COMPONENTS ${aoc_COMPONENT})
    endif ()

    if (aoc_ARG)
        list(APPEND aoc_ARGS ${aoc_ARG})
    endif ()

    set(entry "${aoc_PKGNAME}")

    if (${aoc_METHOD} STREQUAL "PROCESS")
        unset(aoc_NAMESPACE)
        unset(aoc_URL)
        unset(aoc_GIT_REPOSITORY)
        unset(aoc_SRCDIR)
        unset(aoc_GIT_TAG)
        unset(aoc_BINDIR)
        unset(aoc_INCDIR)
        unset(aoc_COMPONENT)
        unset(aoc_ARG)
        unset(aoc_COMPONENTS)
        unset(aoc_ARGS)
    endif ()

    if (aoc_NAMESPACE)
        string(JOIN "|" entry "${entry}" "${aoc_NAMESPACE}")
    else ()
        string(APPEND entry "|")
    endif ()

    string(JOIN "|" entry "${entry}" ${aoc_METHOD} )

    if (aoc_GIT_REPOSITORY)
        string(JOIN "|" entry "${entry}" "${aoc_GIT_REPOSITORY}")
    elseif (aoc_SRCDIR)
        string(JOIN "|" entry "${entry}" "${aoc_SRCDIR}")
    elseif (aoc_URL)
        string(JOIN "|" entry "${entry}" "${aoc_URL}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (aoc_GIT_TAG)
        string(JOIN "|" entry "${entry}" "${aoc_GIT_TAG}")
    elseif (aoc_BINDIR)
        string(JOIN "|" entry "${entry}" "${aoc_BINDIR}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (aoc_INCDIR)
        string(JOIN "|" entry "${entry}" "${aoc_INCDIR}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (aoc_COMPONENTS)
        set(components)
        foreach (component IN LISTS aoc_COMPONENTS)
            string(JOIN " " components "${components}" "${component}")
        endforeach ()
        string(STRIP "${components}" components)
        string(JOIN "|" entry "${entry}" "${components}")
    else ()
        string(APPEND entry "|")
    endif ()

    if (aoc_ARGS)
        set(args)
        foreach (arg IN LISTS aoc_ARGS)
            string(JOIN " " args "${args}" "${arg}")
        endforeach ()
        string(STRIP "${args}" args)
        string(JOIN "|" entry "${entry}" "${args}")
    else ()
        string(APPEND entry "|")
    endif ()

    set(pkgIndex)

    if (aoc_USER OR NOT aoc_SYSTEM)
        set(activeArray UserCategoryData)
    else ()
        set(activeArray SystemCategoryData)
    endif ()
    getCatIndex(${activeArray} ${aoc_CATEGORY} pkgIndex)
    if (${pkgIndex} EQUAL -1)
        set(newEntry "${aoc_CATEGORY}|${entry}")
        list(APPEND ${activeArray} "${newEntry}")
        set(${activeArray} "${${activeArray}}" PARENT_SCOPE)
    else ()
        list(GET ${activeArray} ${pkgIndex} catLine)
        string(JOIN "," cat_line "${catLine}" "${entry}")
        list(REMOVE_AT ${activeArray} ${pkgIndex})
        list(INSERT ${activeArray} ${pkgIndex} "${cat_line}")
        set(${activeArray} "${${activeArray}}" PARENT_SCOPE)
    endif ()

endfunction()
###################################################################################################################
###################################################################################################################
###################################################################################################################
function(createStandardPackageData)

    # 1          2          3            4        5                6                     7          8                                            9
    # CATEGORY | PKGNAME | [NAMESPACE] | METHOD | URL or SRCDIR | [GIT_TAG] or BINDIR | [INCDIR] | [COMPONENT [COMPONENT [ COMPONENT ... ]]]  | [ARG [ARG [ARG ... ]]]

    #   [1] CATEGORY is the name of a group of package alternatives (eg BOOST)
    #   [2] PKGNAME is the individual package name (eg Boost)
    #   [3] NAMESPACE is the namespace the library lives in, if any (eg GTest)  or empty
    #   [4] METHOD is the method of retrieving package. Can be FETCH for Fetch_Contents, FIND for find_package, or PROCESS
    #       If METHOD=PROCESS, when their turn comes, only ${CMAKE_SOURCE_DIR}/cmake/handlers/<pkgname>/process.cmake
    #       will be run and the rest of the handling skipped. No other fields are nessessary, leave them empty
    #
    #   [5] One or the other of
    #       ----------------------------------------------------------------------------------------------------
    #       GIT_REPOSITORY is the git url where the package can be found
    #       URL is the location of a .zip, .tar, or .gz file, either remote or local
    #       ----------------------------------------------------------------------------------------------------
    #   or
    #       ----------------------------------------------------------------------------------------------------
    #       SRCDIR is the source directory if you have manually downloaded the source for the
    #       package and aren't using FetchContent to get it. Format the entry like :-
    #       [SRC]/path/to/folder        [SRC] will be replaced by the directory
    #                                   ${EXTERNALS_DIR}
    #       or
    #       [BUILD]/path/to/folder      [BUILD] will be replaced by the directory
    #                                   ${BUILD_DIR}/_deps
    #       ----------------------------------------------------------------------------------------------------
    #   [6] GIT_TAG     for identifying which git branch/tag to retrieve, OR
    #       BINDIR      is the build directory if you have manually downloaded the source. Format as SRCDIR
    #
    #   [7] INCDIR the include folder if it can't be automatically found, or empty if not needed. Format as SRCDIR
    #
    #   [8] COMPONENT [COMPONENT [COMPONENT] [...]]] Space separated list of components, or empty if none
    #   [9] ARG [ARG [ARG [...]]] Space separated list of arguments for FIND_PACKAGE_OVERRIDE, or empty if none

    #   [, ...] More packages in the same category, if any
#
#    addPackageData(SYSTEM CATEGORY "STACKTRACE" PKGNAME "cpptrace" NAMESPACE "cpptrace"
#            GIT_REPOSITORY "https://github.com/jeremy-rifkin/cpptrace.git" GIT_TAG "v0.7.3"
#            COMPONENT "cpptrace" ARG REQUIRED)

    addPackageData(SYSTEM CATEGORY "REFLECTION" PKGNAME "magic_enum" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/Neargye/magic_enum.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(SYSTEM CATEGORY "SIGNAL" PKGNAME "eventpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wqking/eventpp.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(SYSTEM CATEGORY "TESTING" PKGNAME "gtest" NAMESPACE "GTest" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/google/googletest.git" GIT_TAG "v1.15.2"
            INCDIR "[SRC]/googletest/include"
            ARGS REQUIRED NAMES GTest googletest)

    addPackageData(SYSTEM CATEGORY "YAML" PKGNAME "yaml-cpp" NAMESPACE "yaml-cpp" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/jbeder/yaml-cpp.git" GIT_TAG "master"
            COMPONENT "yaml-cpp"
            ARG REQUIRED)

    ##
    ####
    ##
    #

    addPackageData(CATEGORY "CORE" PKGNAME "HoffSoft"  METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG)
    addPackageData(CATEGORY "GFX"  PKGNAME "Gfx"   METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG)

    addPackageData(CATEGORY "BOOST" PKGNAME "Boost" NAMESPACE "Boost" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/boostorg/boost.git" GIT_TAG "boost-1.85.0"
            COMPONENT system date_time regex url algorithm
            ARGS NAMES Boost)

    addPackageData(CATEGORY "BZIP" PKGNAME "bz2" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://gitlab.com/bzip2/bzip2" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(CATEGORY "COMMS" PKGNAME "mailio" NAMESPACE "mailio" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/karastojko/mailio.git" GIT_TAG "master"
            ARG REQUIRED)

    #    addPackageData(CATEGORY "SQLITE3" PKGNAME "sqlite3"
    #            URL "https://www.sqlite.org/2025/sqlite-amalgamation-3500200.zip"
    #            INCDIR "[BUILD]/sqlite3/include"
    #            COMPONENT "sqlite3" ARG REQUIRED)

    addPackageData(CATEGORY "DATABASE" PKGNAME "soci" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/SOCI/soci.git" GIT_TAG "master"
            ARG REQUIRED)

    addPackageData(CATEGORY "SSL" PKGNAME "OpenSSL" METHOD "PROCESS")
#            GIT_REPOSITORY "https://github.com/openssl/openssl.git" GIT_TAG "openssl-3.3.2"
#            ARG REQUIRED)

    addPackageData(CATEGORY "ZLIB" PKGNAME "zlib" NAMESPACE "ZLIB" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/madler/zlib" GIT_TAG "master"
            COMPONENT "ZLIB" 
            ARG REQUIRED)

    addPackageData(CATEGORY "TOML" PKGNAME "tomlplusplus" NAMESPACE "tomlplusplus" METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "wxyz" GIT_TAG "master"
            COMPONENT tomlplusplus
            ARG REQUIRED)

    addPackageData(CATEGORY "WIDGETS" PKGNAME "wxWidgets" METHOD "PROCESS")

    set(SystemCategoryData "${SystemCategoryData}" PARENT_SCOPE)
    set(UserCategoryData "${UserCategoryData}" PARENT_SCOPE)

endfunction()
###################################################################################################################
###################################################################################################################
###################################################################################################################
function(fetchContents)

    createStandardPackageData()

    set(options HELP DEBUG)
    set(oneValueArgs PREFIX)
    set(multiValueArgs USE;NOT;OVERRIDE_FIND_PACKAGE;FIND_PACKAGE_ARGS;FIND_PACKAGE_COMPONENTS) # NOT has precedence over USE

    cmake_parse_arguments(AUE "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if (AUE_HELP)
        fetchContentsHelp()
        return()
    endif ()

    if (AUE_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "Unrecognised arguments passed to fetchContents() : ${AUE_UNPARSED_ARGUMENTS}")
    endif ()

    if (AUE_DEBUG)
        log()
        log(TITLE "Before tampering " LISTS AUE_USE AUE_NOT AUE_OVERRIDE_FIND_PACKAGE AUE_FIND_PACKAGE_ARGS AUE_FIND_PACKAGE_COMPONENTS)
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

    set(CatIX 0)
    set(CatPkgNameIX 1)
    set(CatNamespaceIX 2)
    set(CatMethodIX 3)
    set(CatUrlIX 4)
    set(CatGitTagIX 5)
    set(CatSrcDirIX 4)
    set(CatBuildDirIX 5)
    set(CatIncDirIX 6)
    set(CatComponentsIX 7)
    set(CatArgsIX 8)

    set(PkgNameIX 0)
    set(PkgNamespaceIX 1)
    set(PkgMethodIX 2)
    set(PkgUrlIX 3)
    set(PkgGitTagIX 4)
    set(PkgSrcDirIX 3)
    set(PkgBuildDirIX 4)
    set(PkgIncDirIX 5)
    set(PkgComponentsIX 6)
    set(PkgArgsIX 7)

    foreach (line IN LISTS SystemCategoryData)
        SplitAt(${line} "|" acat dc)
        list(APPEND SystemCategories ${acat})
    endforeach ()

    foreach (line IN LISTS UserCategoryData)
        SplitAt(${line} "|" acat dc)
        list(APPEND OptionalCategories ${acat})
    endforeach ()

    list(APPEND AllPackageData ${SystemCategoryData} ${UserCategoryData})

    list(APPEND PseudoCatagories
            APPEARANCE
            PRINT
            LOGGER
    )
    list(APPEND NoLibPackages
            googletest
            soci
    )

    unset(USE_ALL)
    if ("ALL" IN_LIST AUE_USE)
        set(USE_ALL ON)
        list(REMOVE_ITEM AUE_USE ALL)
    endif ()

    # We don't search for pseudo packages
    foreach (pseudoLibrary IN LISTS PseudoCatagories)
        if (${pseudoLibrary} IN_LIST AUE_USE)
            list(REMOVE_ITEM AUE_USE ${pseudoLibrary})
            list(APPEND _DefinesList USING_${pseudoLibrary})
        endif ()
    endforeach ()

    # We don't search for system packages this way
    list(REMOVE_ITEM AUE_USE ${SystemCategories})

    set(unifiedComponentList)
    set(unifiedArgumentList)
    set(unifiedCategoryList)

    # ensure the caller is using the system libraries
    foreach (sys_cat IN LISTS SystemCategories)
        string(APPEND sys_cat ".0")
        list(APPEND unifiedCategoryList "${sys_cat}")
    endforeach ()

    ## combine the caller's and the system's components and arguments into unified lists
    ##
    foreach (cat IN LISTS SystemCategories)
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
        ## get the component and argument details for this category
        ##
        ##
        parsePackage(SystemCategoryData
                CAT ${cat}
                LIST pkgs
                COMPONENTS sysComponents
                ARGS sysArguments)


        ##
        ## All system packages are REQUIRED
        list(APPEND combinedArguments "REQUIRED")
        ##
        findInList("${AUE_FIND_PACKAGE_COMPONENTS}" ${cat} " " callerComponents index)
        combine("${sysComponents}" "${callerComponents}" combinedComponents)
        if (index GREATER_EQUAL 0)
            list(REMOVE_AT AUE_FIND_PACKAGE_COMPONENTS ${index})
        endif ()
        string(JOIN " " temp ${cat} ${combinedComponents})
        if (NOT "${temp}" STREQUAL ${cat})
            list(APPEND unifiedComponentList "${temp}")
        endif ()
        ##
        findInList("${AUE_FIND_PACKAGE_ARGS}" ${cat} " " callerArguments index)
        # Caller cannot tell us to make a system package optional
        list(REMOVE_ITEM callerArguments "OPTIONAL")
        combine("${sysArguments}" "${callerArguments}" combinedArguments OFF)
        if (index GREATER_EQUAL 0)
            list(REMOVE_AT AUE_FIND_PACKAGE_ARGS ${index})
        endif ()
        string(JOIN " " temp ${cat} ${combinedArguments})
        if (NOT "${temp}" STREQUAL ${cat})
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
        SplitAt("${package_line}" " " this_cat pkg_args)
        if ("${this_cat}" STREQUAL "ALL")
            set(FIND_PACKAGE_ARGS_ALL "${pkg_args}")
            set(TARGET_LINE "${package_line}")
            break()
        endif ()
    endforeach ()
    if (TARGET_LINE)
        list(REMOVE_ITEM AUE_FIND_PACKAGE_ARGS "${TARGET_LINE}")
    endif ()

    if (USE_ALL)
        list(APPEND AUE_USE ${OptionalCategories})
    endif ()

    list(REMOVE_DUPLICATES AUE_USE)
    #    list(SORT AUE_USE)

    foreach (cat IN LISTS AUE_NOT)
        # remove any categories excluded by the AUE_NOT list
        if (NOT ${cat} IN_LIST SystemCategories)
            list(REMOVE_ITEM AUE_USE ${cat})
            list(FILTER AUE_FIND_PACKAGE_ARGS EXCLUDE REGEX "${cat}.*")
            list(FILTER AUE_FIND_PACKAGE_COMPONENTS EXCLUDE REGEX "${cat}.*")
        endif ()
    endforeach ()
    set(AUE_NOT "")
    ##
    ####################################################################################
    ## combine the caller's and the optional components and arguments into unified lists
    ##
    unset(deadCats)

    foreach (cat IN LISTS AUE_USE)

        SplitAt(${cat} "=" kat pkg)
        if (pkg)
            getCatPkgList("${UserCategoryData}" ${kat} pkg_list)
            list(FIND pkg_list ${pkg} this_pkgindex)
            if (${this_pkgindex} EQUAL -1)
                message(FATAL_ERROR "No pkg named '${pkg}' in category '${cat}'")
                continue()
            endif ()
            list(APPEND deadCats ${cat})
            set(cat ${kat})
        else ()
            set(this_pkgindex 0)
        endif ()

        ##
        ###########################################################
        ## get the component and argument details for this category
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
        ##
        parsePackage(UserCategoryData
                CAT ${cat}
                PKG_INDEX ${this_pkgindex}
                LIST pkg
                COMPONENTS optComponents
                ARGS optArguments)
        ##
        if (NOT "${pkg}" STREQUAL "")
            findInList("${AUE_FIND_PACKAGE_COMPONENTS}" ${cat} " " callerComponents index)
            combine("${callerComponents}" "${optComponents}" combinedComponents)
            if (DEFINED index)
                if("${index}" GREATER_EQUAL 0)
                    list(REMOVE_AT AUE_FIND_PACKAGE_COMPONENTS ${index})
                endif ()
            endif ()
            string(JOIN " " temp ${cat} ${combinedComponents})
            if (NOT "${temp}" STREQUAL ${cat})
                list(APPEND unifiedComponentList "${temp}")
            endif ()
            ##
            findInList("${AUE_FIND_PACKAGE_ARGS}" ${cat} " " callerArguments index)
            if (FIND_PACKAGE_ARGS_ALL)
                list(APPEND callerArguments "${FIND_PACKAGE_ARGS_ALL}")
            endif ()
            if ("OPTIONAL" IN_LIST callerArguments)
                list(REMOVE_ITEM callerArguments "REQUIRED")
                list(REMOVE_ITEM optionalArguments "REQUIRED")
            endif ()
            combine("${callerArguments}" "${optArguments}" combinedArguments OFF)
            if (DEFINED index)
                if("${index}" GREATER_EQUAL 0)
                    list(REMOVE_AT AUE_FIND_PACKAGE_ARGS ${index})
                endif ()
            endif ()
            string(JOIN " " temp ${cat} ${combinedArguments})
            if (NOT "${temp}" STREQUAL ${cat})
                list(APPEND unifiedArgumentList "${temp}")
            endif ()

            list(APPEND unifiedCategoryList ${cat}.${this_pkgindex})
            list(APPEND deadCats ${cat})
        endif ()
    endforeach ()

    list(REMOVE_ITEM AUE_USE ${deadCats})

    foreach (item IN LISTS AUE_USE)
        if (NOT ${item} STREQUAL ${kat})
            message("Unknown category: ${item}")
        endif ()
    endforeach ()

    foreach (item IN LISTS AUE_FIND_PACKAGE_COMPONENTS)
        message("Unknown find_package_categories: ${item}")
    endforeach ()

    foreach (item IN LISTS AUE_FIND_PACKAGE_ARGS)
        message("Unknown find_package_args: ${item}")
    endforeach ()
    message(" ")
    if (AUE_DEBUG)
        log(TITLE "After tampering" LISTS unifiedCategoryList unifiedArgumentList unifiedComponentList)
    endif ()
    #
    ####################################################################################################################
    #                                            B I G     L O O P                                                     #
    ####################################################################################################################
    #
    list(LENGTH unifiedCategoryList numWanted)
    set(numFailed 0)
    if (${numWanted} EQUAL 1)
        message(CHECK_START "Fetching library")
    else ()
        message(CHECK_START "Fetching ${numWanted} Libraries")
    endif ()
    list(APPEND CMAKE_MESSAGE_INDENT "\t")

    set(fail OFF)

    foreach (this_cat IN LISTS unifiedCategoryList)

        SplitAt(${this_cat} "." this_cat this_pkgindex)
        message(" ")
        message(CHECK_START "${this_cat}")
        list(APPEND CMAKE_MESSAGE_INDENT "\t")

        unset(pkg_details)
        unset(this_pkgname)
        unset(this_pkglc)
        unset(this_pkguc)
        unset(this_namespace)
        unset(this_method)
        unset(this_url)
        unset(this_tag)
        unset(this_src)
        unset(this_build)
        unset(this_inc)
        unset(this_out)
        unset(this_find_package_components)
        unset(this_namespace_package_components)
        unset(this_find_package_args)
        unset(this_hint)
        unset(OVERRIDE_FIND_PACKAGE_KEYWORD)
        unset(COMPONENTS_KEYWORD)

        parsePackage(AllPackageData
                CAT ${this_cat}
                PKG_INDEX ${this_pkgindex}
                METHOD this_method
                LIST pkg_details
                URL this_url
                GIT_TAG this_tag
                SRC_DIR this_src
                BUILD_DIR this_build
                FETCH_FLAG this_fetch
                INC_DIR this_inc
        )

        findInList("${unifiedComponentList}" ${this_cat} " " this_find_package_components)
        findInList("${unifiedArgumentList}" ${this_cat} " " this_find_package_args)

        list(POP_FRONT pkg_details this_pkgname this_namespace)
        list(LENGTH this_find_package_components num_components)
        list(LENGTH this_find_package_args num_args)

        ################################################################################################################
        ################################################################################################################
        ################################################################################################################
        if ("${this_method}" STREQUAL "PROCESS") ####################################################################
            call_handler(process ${this_pkgname}) ######################################################################
        else () ########################################################################################################
            set(HANDLED OFF) ###########################################################################################
        endif () #######################################################################################################
        ################################################################################################################
        ################################################################################################################
        ################################################################################################################
        if (NOT HANDLED)
            if (num_components GREATER 0 AND NOT ${this_namespace} STREQUAL "")

                # we need to add the pkg name to the components, but they may or may not already
                # have the pkg name prepended. So check each, putting it there if it isn't already
                unset(this_namespace_package_components)

                foreach (component IN LISTS this_find_package_components)
                    if (NOT "::" IN_LIST component AND NOT ${this_namespace} STREQUAL "")
                        set(component ${this_namespace}::${component})
                        list(APPEND this_namespace_package_components ${component})
                    endif ()
                endforeach ()

            endif ()

            if (num_args OR num_components)
                set(this_override_find_package ON)
            else ()
                set(this_override_find_package OFF)
            endif ()

            if (num_args OR num_components)
                set(OVERRIDE_FIND_PACKAGE_KEYWORD "OVERRIDE_FIND_PACKAGE")
                if (num_args)
                    list(APPEND this_hint ${this_find_package_args})
                endif ()
                if (num_components)
                    set(COMPONENTS_KEYWORD "COMPONENTS")
                endif ()
            endif ()

            unset(cmd_line)
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

            string(TOLOWER "${this_pkgname}" this_pkglc)
            string(TOUPPER "${this_pkgname}" this_pkguc)
            ###########################################################################################################
            set(tfpc "${this_find_package_components}") ###############################################################
            set(tnpc "${this_namespace_package_components}") ##########################################################
            ###########################################################################################################
            #                                                                                                              #
            ###########################################################################################################
            ###########################################################################################################
            ###########################################################################################################
            if ("${this_method}" STREQUAL "FETCH_CONTENTS") ###########################################################
                call_handler(preDownload ${this_pkgname}) ##############################################################
            endif () ##################################################################################################
            ###########################################################################################################
            ###########################################################################################################
            ###########################################################################################################
            if (NOT HANDLED)
                if (${this_method} STREQUAL "FETCH_CONTENTS")
                    if (NOT this_fetch)
                        message("FetchContent_Declare not required for ${this_pkgname}")
                    else ()
                        message("FetchContent_Declare(${this_pkgname} ${SOURCE_KEYWORD} ${this_url} SOURCE_DIR ${EXTERNALS_DIR}/${this_pkgname} ${OVERRIDE_FIND_PACKAGE_KEYWORD} ${this_find_package_args} ${COMPONENTS_KEYWORD} ${this_find_package_components} ${GIT_TAG_KEYWORD} ${this_tag})")
                        if ("${SOURCE_KEYWORD}" STREQUAL URL)
                            FetchContent_Declare(${this_pkgname} ${SOURCE_KEYWORD} ${this_url} SOURCE_DIR ${EXTERNALS_DIR}/${this_pkgname})
                        else ()
                            FetchContent_Declare(${this_pkgname} ${SOURCE_KEYWORD} ${this_url} SOURCE_DIR ${EXTERNALS_DIR}/${this_pkgname} ${OVERRIDE_FIND_PACKAGE_KEYWORD} ${this_find_package_args} ${COMPONENTS_KEYWORD} ${this_find_package_components} ${GIT_TAG_KEYWORD} ${this_tag})
                        endif ()
                    endif ()
                else ()

                    if (NOT TARGET ${this_pkgname} AND NOT TARGET ${this_namespace}::${this_pkgname})
                        list(FIND this_find_package_args "PATHS" pinx)
                        set (this_pkgname_DIR "")
                        if (${pinx} GREATER_EQUAL 0)
                            list(REMOVE_AT this_find_package_args ${pinx})
                            list(GET this_find_package_args ${pinx} this_pkgname_DIR)
                            list(REMOVE_AT this_find_package_args ${pinx})
                        else ()
                            set (this_pkgname_DIR ${CMAKE_MODULE_PATH})
                        endif ()
                        message(STATUS "find_package(${this_pkgname} ${this_find_package_args} HINTS ${CMAKE_MODULE_PATH})")
                        find_package(${this_pkgname} ${this_find_package_args} HINTS ${CMAKE_MODULE_PATH})
                        list(APPEND _LibrariesList    ${${this_pkgname}_LIBRARIES})
                        list(APPEND _IncludePathsList ${${this_pkgname}_INCLUDE_DIRS})
                    endif ()
                    set (HANDLED ON)
                endif ()
            endif ()
            ###########################################################################################################
            ###########################################################################################################
            ###########################################################################################################
            if (NOT ${this_method} STREQUAL "PROCESS") ################################################################
                call_handler(postDownload ${this_pkgname}) #############################################################
            endif () ##################################################################################################
            ###########################################################################################################
            ###########################################################################################################
            ###########################################################################################################

            if (this_fetch)

                ########################################################################################################
                ########################################################################################################
                ########################################################################################################
                if (${this_method} STREQUAL "FETCH_CONTENTS") ##########################################################
                    call_handler(preMakeAvailable ${this_pkgname}) #####################################################
                endif() ################################################################################################
                ########################################################################################################
                ########################################################################################################
                ########################################################################################################
                if (NOT HANDLED)
                    FetchContent_MakeAvailable(${this_pkgname})
                endif ()
                set(cs "${this_find_package_components}")
                ########################################################################################################

                if (NOT ${this_method} STREQUAL "FIND_PACKAGE")
                    if (NOT this_src)
                        set(this_src ${${this_pkglc}_SOURCE_DIR})
                        if (NOT this_src)
                            set(this_src "${EXTERNALS_DIR}/${this_pkgname}")
                        endif ()
                    endif ()

                    if (NOT this_build)
                        if (DEFINED ${this_pkglc}_BUILD_DIR)
                            set(this_build ${${this_pkglc}_BUILD_DIR})
                        elseif (DEFINED ${this_pkglc}_BINARY_DIR)
                            set(this_build ${${this_pkglc}_BINARY_DIR})
                        else ()
                            set(this_build "${BUILD_DIR}/_deps/${this_pkglc}-build")
                        endif ()
                    endif ()
                endif ()
                set(this_out "${OUTPUT_DIR}")

                ############################################################################################################
                ############################################################################################################
                ############################################################################################################
                if ("${this_method}" STREQUAL "FETCH_CONTENTS") ############################################################
                    call_handler(postMakeAvailable ${this_pkgname}) ########################################################
                endif () ###################################################################################################
                ############################################################################################################
                ############################################################################################################
                ############################################################################################################

                if (NOT HANDLED AND NOT ${this_cat} STREQUAL TESTING)
                    if (${this_pkgname}_POPULATED
                            OR ${this_pkglc}_POPULATED
                            OR ${this_pkgname}_FOUND
                            OR ${this_pkglc}_FOUND)

                        if (this_incdir)

                            # Our secret sauce was passed to us. This is better than guessing, I guess

                            if (EXISTS "${this_incdir}")
                                target_include_directories(${this_pkgname} PUBLIC ${this_incdir})
                                list(APPEND _IncludePathsList ${this_actual_include_dir})
                            else ()
                                message(FATAL_ERROR "INC_DIR for ${this_pkgname} (${this_incdir}) not found")
                            endif ()

                        else ()

                            # Work out an include dir by ourselves

                            if (${this_pkgname}_INCLUDE_DIRS)
                                list(APPEND _IncludePathsList ${${this_pkgname}_INCLUDE_DIRS})
                            endif ()
                            if (${this_pkguc}_INCLUDE_DIRS)
                                list(APPEND _IncludePathsList ${${this_pkguc}_INCLUDE_DIRS})
                            endif ()
                            if (${this_pkgname}_INCLUDE_DIR)
                                list(APPEND _IncludePathsList ${${this_pkgname}_INCLUDE_DIR})
                                if (EXISTS ${${this_pkglc}_BINARY_DIR}/include)
                                    list(APPEND _IncludePathsList ${${this_pkglc}_BINARY_DIR}/include)
                                endif ()
                            endif ()
                            if (${this_pkguc}_INCLUDE_DIR)
                                list(APPEND _IncludePathsList ${${this_pkguc}_INCLUDE_DIR})
                                if (EXISTS ${${this_pkguc}_BINARY_DIR}/include)
                                    list(APPEND _IncludePathsList ${${this_pkguc}_BINARY_DIR}/include)
                                endif ()
                            endif ()
                            if (EXISTS ${${this_pkglc}_SOURCE_DIR}/include)
                                list(APPEND _IncludePathsList ${${this_pkglc}_SOURCE_DIR}/include)
                            endif ()
                            if (EXISTS ${${this_pkglc}_BINARY_DIR}/include)
                                list(APPEND _IncludePathsList ${${this_pkglc}_BINARY_DIR}/include)
                            endif ()
                            if (EXISTS ${${this_pkglc}_SOURCE_DIR}/${this_pkglc}.h OR
                                    EXISTS ${${this_pkglc}_SOURCE_DIR}/${this_pkgname}.h)
                                list(APPEND _IncludePathsList ${${this_pkglc}_SOURCE_DIR})
                            endif ()
                            if (EXISTS ${${this_pkglc}_BINARY_DIR}/${this_pkglc}.h OR
                                    EXISTS ${${this_pkglc}_BINARY_DIR}/${this_pkgname}.h)
                                list(APPEND _IncludePathsList ${${this_pkglc}_BINARY_DIR})
                            endif ()
                        endif ()
                    endif ()

                    # Try to set the properties on the target

                    set(anyTargetFound OFF)

                    if (NOT ${this_pkgname} IN_LIST NoLibPackages)
                        list(APPEND _DefinesList USING_${this_cat})
                        string(REPLACE "-" "_" temppkgname ${this_pkgname})
                        list(APPEND _DefinesList USING_${temppkgname})

                        foreach (component IN LISTS this_find_package_components)

                            if (TARGET ${component})
                                addTarget(${component} ${this_pkgname} ON "${this_find_package_components}")
                                set(anyTargetFound ON)
                            elseif (TARGET ${this_namespace}::${component})
                                addTarget(${this_namespace}::${component} ${this_pkgname} ON "${this_find_package_components}")
                                set(anyTargetFound ON)
                            elseif (TARGET wx::${component})
                                addTarget(wx::${component} ${this_pkgname} ON "${this_find_package_components}")
                                set(anyTargetFound ON)
                            else ()
                                message("No target for library '${component}'")
                            endif ()

                        endforeach ()

                        if (TARGET ${this_pkgname})
                            addTarget(${this_pkgname} ${this_pkgname} ON "")
                            set(anyTargetFound ON)
                        endif ()
                    endif ()

                    # Try and add the libraries... This part is really why I created the handler concept,
                    # working out the libraries is fraught with danger...

                    if (NOT anyTargetFound)
                        if (this_namespace_package_components)
                            list(APPEND _LibrariesList ${this_namespace_package_components})
                        elseif (this_find_package_components)
                            list(APPEND _LibrariesList ${this_find_package_components})
                        else ()
                            list(APPEND _LibrariesList ${this_pkgname})
                        endif ()
                    endif ()
                endif ()
            endif ()

            ########################################################################################################
            ########################################################################################################
            ########################################################################################################
            ########################################################################################################
            call_handler(fix ${this_pkgname}) ######################################################################
            ########################################################################################################
            ########################################################################################################
            ########################################################################################################
            ########################################################################################################

        endif ()
        list(POP_BACK CMAKE_MESSAGE_INDENT)
        if (fail)
            message(CHECK_FAIL "FAILED")
            return()
        else ()
            message(CHECK_PASS "OK")
        endif ()
    endforeach ()

    set(ies "ies")

    if (numWanted EQUAL 1)
        set(ies "y")
    endif ()

    list(POP_BACK CMAKE_MESSAGE_INDENT)

    if (numFailed)
        if (${numFailed} EQUAL 1)
            if (${numWanted} EQUAL 1)
                message(CHECK_FAIL "finished. Library could not be loaded.")
            else ()
                message(CHECK_FAIL "finished. One out of ${numWanted} libraries could not be loaded.")
            endif ()
        elseif ()
            message(CHECK_FAIL "finished. ${numFailed} out of ${numWanted} libraries could not be loaded.")
        endif ()
    else ()
        if (${numWanted} EQUAL 1)
            message(CHECK_PASS "finished. Library loaded.")
        else ()
            message(CHECK_PASS "finished. All ${numWanted} librar${ies} loaded.")
        endif ()
    endif ()
    #
    # ##########################################################################################################
    #
    #
    # ###################################################################################################
    #
    list(REMOVE_DUPLICATES _CompileOptionsList)
    list(REMOVE_DUPLICATES _DefinesList)
    list(REMOVE_DUPLICATES _DependenciesList)
    list(REMOVE_DUPLICATES _ExportedDependencies)
    list(REMOVE_DUPLICATES _IncludePathsList)
    list(REMOVE_DUPLICATES _LibrariesList)
    list(REMOVE_DUPLICATES _LibraryPathsList)
    list(REMOVE_DUPLICATES _LinkOptionsList)
    list(REMOVE_DUPLICATES _PrefixPathsList)

    list(REMOVE_DUPLICATES _wxCompilerOptions)
    list(REMOVE_DUPLICATES _wxDefines)
    list(REMOVE_DUPLICATES _wxIncludePaths)
    list(REMOVE_DUPLICATES _wxLibraryPaths)
    list(REMOVE_DUPLICATES _wxLibraries)
    list(REMOVE_DUPLICATES _wxFrameworks)
    #
    # ###################################################################################################
    #
    # @formatter:off
    set(${AUE_PREFIX}_CompileOptionsList        ${_CompileOptionsList}                      )
    set(${AUE_PREFIX}_CompileOptionsList        ${_CompileOptionsList}          PARENT_SCOPE)
    set(${AUE_PREFIX}_DefinesList               ${_DefinesList}                             )
    set(${AUE_PREFIX}_DefinesList               ${_DefinesList}                 PARENT_SCOPE)
    set(${AUE_PREFIX}_DependenciesList          ${_DependenciesList}                        )
    set(${AUE_PREFIX}_DependenciesList          ${_DependenciesList}            PARENT_SCOPE)
    set(${AUE_PREFIX}_IncludePathsList          ${_IncludePathsList}                        )
    set(${AUE_PREFIX}_IncludePathsList          ${_IncludePathsList}            PARENT_SCOPE)
    set(${AUE_PREFIX}_LibrariesList             ${_LibrariesList}                           )
    set(${AUE_PREFIX}_LibrariesList             ${_LibrariesList}               PARENT_SCOPE)
    set(${AUE_PREFIX}_LibraryPathsList          ${_LibraryPathsList}                        )
    set(${AUE_PREFIX}_LibraryPathsList          ${_LibraryPathsList}            PARENT_SCOPE)
    set(${AUE_PREFIX}_LinkOptionsList           ${_LinkOptionsList}                         )
    set(${AUE_PREFIX}_LinkOptionsList           ${_LinkOptionsList}             PARENT_SCOPE)
    set(${AUE_PREFIX}_PrefixPathsList           ${_PrefixPathsList}                         )
    set(${AUE_PREFIX}_PrefixPathsList           ${_PrefixPathsList}             PARENT_SCOPE)

    set(${AUE_PREFIX}_wxCompilerOptions         ${_wxCompilerOptions}               )
    set(${AUE_PREFIX}_wxCompilerOptions         ${_wxCompilerOptions}           PARENT_SCOPE)
    set(${AUE_PREFIX}_wxDefines                 ${_wxDefines}                               )
    set(${AUE_PREFIX}_wxDefines                 ${_wxDefines}                   PARENT_SCOPE)
    set(${AUE_PREFIX}_wxIncludePaths            ${_wxIncludePaths}                          )
    set(${AUE_PREFIX}_wxIncludePaths            ${_wxIncludePaths}              PARENT_SCOPE)
    set(${AUE_PREFIX}_wxLibraryPaths            ${_wxLibraryPaths}                          )
    set(${AUE_PREFIX}_wxLibraryPaths            ${_wxLibraryPaths}              PARENT_SCOPE)
    set(${AUE_PREFIX}_wxLibraries               ${_wxLibraries}                             )
    set(${AUE_PREFIX}_wxLibraries               ${_wxLibraries}                 PARENT_SCOPE)
    set(${AUE_PREFIX}_wxFrameworks              ${_wxFrameworks}                            )
    set(${AUE_PREFIX}_wxFrameworks              ${_wxFrameworks}                PARENT_SCOPE)

    # @formatter:on

#    log(TITLE "Leaving Las Vegas" LISTS
#            HS_CompileOptionsList
#            HS_DefinesList
#            HS_DependenciesList
#            HS_ExportedDependencies
#            HS_IncludePathsList
#            HS_LibrariesList
#            HS_LibraryPathsList
#            HS_LinkOptionsList
#            HS_PrefixPathsList
#            HS_wxCompilerOptions
#            HS_wxDefines
#            HS_wxIncludePaths
#            HS_wxLibraryPaths
#            HS_wxLibraries
#            HS_wxFrameworks
#    )
endfunction()
