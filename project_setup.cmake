include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

function(registerPackageCallback fn dry_run)
    if(NOT COMMAND "${fn}")
        message(FATAL_ERROR "registerPackageCallback(): '${fn}' is not a command")
    endif()
    columnarTextOut("default" "package" "callback" "registered" "for" "handler" "${fn}"
            "[FIELD0:R][FIELD1:L][FIELD2:R][FIELD3:L][FIELD4:R][FIELD5:L]" ${dry_run})
    globalObjAppendUnique("HS_REG_PKG_CALLBACKS" "${fn}")
endfunction()

function(runPackageCallbacks)
    globalObjGet("HS_REG_PKG_CALLBACKS" _cbs)
    foreach(cb IN LISTS _cbs)
        cmake_language(CALL "${cb}" "${ARGV}") # pass-through args if you want
    endforeach()
endfunction()

function(registerLibrary libID namespace libName path)
    string(TOUPPER ${libID} LIBID)
    globalObjAppendUnique("HS_REG_LIB_${LIBID}_NAMESPACE" "${namespace}")
    globalObjAppendUnique("HS_REG_LIB_${LIBID}_NAME"      "${libName}")
    globalObjAppendUnique("HS_REG_LIB_${LIBID}_PATH"      "${path}")
    if(NOT EXISTS "${path}")
        msg(ALWAYS FATAL_ERROR "library registration path \"${RED}${BOLD}${path}${NC}\" does not exist")
    else ()
        msg("Library registration path \"${path}\" ${GREEN}successful${NC}")
    endif ()
    include("${path}")
endfunction()

function(getLibraryInfo libID obj)
    string(TOUPPER ${libID} LIBID)
    globalObjGet("HS_REG_LIB_${LIBID}" local_object)
    set(${obj} ${local_object} PARENT_SCOPE)
endfunction()

function(registerPlugin pi dry_run)
    globalObjAppendUnique(HS_REG_PI_LIST "${pi}")
    columnarTextOut("default" "plugin library" "${pi}" "registered" "" "" ""
            "[FIELD0:R][FIELD1:L][FIELD2:R][FIELD3:L][FIELD4:R][FIELD5:L]" ${dry_run})
endfunction()

macro(project_setup _Folder)

    get_filename_component(_Target "${_Folder}" NAME)
    if(NOT APP_NAME)
        include("${_Folder}/AppSpecific.cmake")
    endif ()
    msg(NOTICE "Processing project: ${APP_NAME}")

    string(TOLOWER "${APP_NAME}"    APP_NAME_LC)
    string(TOLOWER "${APP_VENDOR}"  APP_VENDOR_LC)

    string(TOUPPER "${APP_NAME}"    APP_NAME_UC)
    string(TOUPPER "${APP_VENDOR}"  APP_VENDOR_UC)

    math(EXPR _w "${_term_cols} - 2")
    string(REPEAT "═" ${_w} _li)
    string(REPEAT " " ${_w} _sp)

    set(_top "${BOLD}${CYAN}${BLUE_BG}╔${_li}╗${NC}")
    set(_mid "${BOLD}${CYAN}${BLUE_BG}║${_sp}║${NC}")
    set(_bot "${BOLD}${CYAN}${BLUE_BG}╚${_li}╝${NC}")

    set(_txt "P r o c e s s i n g")
    string(LENGTH "${_txt}   ${APP_NAME}" _txl)
    math(EXPR _tel "(${_w} - ${_txl}) / 2")
    math(EXPR _ter "${_w}  - ${_tel} - ${_txl}")

    string(REPEAT " " ${_tel} _lil)
    string(REPEAT " " ${_ter} _lir)

    set(_txt "${BOLD}${WHITE}${BLUE_BG}${_txt}   ${BOLD}${YELLOW}${APP_NAME}")
    set(_mod "${BOLD}${CYAN}${BLUE_BG}║${_lil}${_txt}${_lir}${BOLD}${CYAN}║${NC}")

    msg(ALWAYS " ")
    msg(ALWAYS "${_top}")
    msg(ALWAYS "${_mid}")
    msg(ALWAYS "${_mid}")
    msg(ALWAYS "${_mod}")
    msg(ALWAYS "${_mid}")
    msg(ALWAYS "${_mid}")
    msg(ALWAYS "${_bot}")
    msg(ALWAYS " ")

    # Propagate option-derived flags
    if (APP_SHOW_SIZER_INFO_IN_SOURCE)
        set(SHOW_SIZER_INFO_FLAG "--sizer-info")
    else ()
        set(SHOW_SIZER_INFO_FLAG "")
    endif ()

    # Propagate option-derived flags
    if (APP_DEBUG AND ${APP_DEBUG} GREATER 1)
        set(SHOW_QUIET_FLAG "")
    else ()
        set(SHOW_QUIET_FLAG "--quiet")
    endif ()

    # Feature-scoped extras for this project
    if (GUI IN_LIST APP_FEATURES)
        set(extra_wxCompilerOptions)
        set(extra_wxDefines)
        set(extra_wxFrameworks)
        set(extra_wxIncludePaths)
        set(extra_wxLibraries)
        set(extra_wxLibraryPaths)
    endif ()

    # Reset HS_* lists for this project to avoid cross-project leakage
    set(HS_CompileOptionsList "")
    set(HS_DefinesList "")
    set(HS_DependenciesList "")
    set(HS_IncludePathsList "")
    set(HS_SystemIncludePathsList "")
    set(HS_LibrariesList "")
    set(HS_LibraryPathsList "")
    set(HS_LinkOptionsList "")
    set(HS_PrefixPathsList "")

    # Define set: magic_enum override and general include paths
    list(APPEND extra_Definitions ${GUI} MAGIC_ENUM_NO_MODULE)

    list(APPEND extra_IncludePaths
            ${HEADER_BASE_DIRS}
            ${CMAKE_INSTALL_PREFIX}/include
            ${CMAKE_CXX_IMPLICIT_INCLUDE_DIRECTORIES}
    )

    # Consolidate into HS_* used by addLibrary()
    list(PREPEND HS_CompileOptionsList ${extra_CompileOptions})
    list(PREPEND HS_DefinesList ${debugFlags} ${extra_Definitions})
    list(PREPEND HS_IncludePathsList ${extra_IncludePaths})
    list(PREPEND HS_SystemIncludePathsList ${extra_SystemIncludePaths})
    list(PREPEND HS_LibrariesList ${extra_LibrariesList})
    list(PREPEND HS_LibraryPathsList ${extra_LibraryPaths})
    list(PREPEND HS_LinkOptionsList ${extra_LinkOptions})

    # check_environment() ran before AppSpecific.cmake was included, so APP_VENDOR
    # was empty when STAGE_DIR was computed.  Recompute here for WIN32, where
    # APP_VENDOR is part of the path.  For Linux/macOS the suffix is /usr/local
    # (no vendor component) so STAGE_DIR from check_environment() is correct.
    if (WIN32 AND APP_VENDOR)
        if (DEFINED DESTDIR)
            set(_ps_base "${DESTDIR}")
        else ()
            set(_ps_base "${HOME_DIR}/dev/stage${stemPath}")
        endif ()
        if (CMAKE_CROSSCOMPILING)
            set(STAGE_DIR "${_ps_base}/AppData/Roaming/${APP_VENDOR}")
        else ()
            if (DEFINED ENV{APPDATA})
                set(_ps_win_appdata "$ENV{APPDATA}")
            else ()
                set(_ps_win_appdata "$ENV{USERPROFILE}/AppData/Roaming")
            endif ()
            string(REGEX REPLACE "^[A-Za-z]:" "" _ps_win_noroot "${_ps_win_appdata}")
            set(STAGE_DIR "${_ps_base}${_ps_win_noroot}/${APP_VENDOR}")
            unset(_ps_win_appdata)
            unset(_ps_win_noroot)
        endif ()
        unset(_ps_base)
        get_filename_component(STAGE_DIR "${STAGE_DIR}" ABSOLUTE)
    endif ()
    set(CMAKE_INSTALL_PREFIX "${STAGE_DIR}" CACHE PATH "CMake Install Prefix" FORCE)
    msg(NOTICE "CMAKE_INSTALL_PREFIX=${CMAKE_INSTALL_PREFIX}")

    # Early Christmas present.
    configure_file(
            ${cmake_root}/templates/WX_Helper.cmake.in
            "${OUTPUT_DIR}/WX_Helper.cmake"
            @ONLY
    )

    fetchContents(
            PREFIX HS
            FEATURES ${APP_FEATURES}
    )

    project_install(${_Folder})

endmacro()


function(commonInit pkg discovery_phase)

    string(TOUPPER "${pkg}" _PKG)
    set(findex -1)
    set(foundFind -1)
    set(foundUse -1)

    globalObjGet(GLOBAL_FEATURES _FEATURES)
    if(discovery_phase)

        foreach (feet IN LISTS _FEATURES)
            math(EXPR findex "${findex} + 1")

            separate_arguments(_feet NATIVE_COMMAND "${feet}")
            cmake_parse_arguments("AAZ" "REQUIRED;OPTIONAL" "PACKAGE;NAMESPACE" "PATHS;HINTS" ${_feet})
            if (AAZ_UNPARSED_ARGUMENTS)
                list(GET AAZ_UNPARSED_ARGUMENTS 0 AAZ_FEATURE)
                if (AAZ_FEATURE STREQUAL _PKG AND AAZ_PACKAGE STREQUAL Find${pkg})
                    set(foundFind ${findex})
                elseif (AAZ_FEATURE STREQUAL _PKG AND AAZ_PACKAGE STREQUAL ${pkg})
                    set(foundUse ${findex})
                endif ()
            endif ()
        endforeach ()

        if(foundFind GREATER_EQUAL 0 AND foundFind GREATER foundUse)
            list(REMOVE_AT _FEATURES ${foundFind})
            if (foundUse GREATER_EQUAL 0)
                list(REMOVE_AT _FEATURES ${foundUse})
            endif ()
        elseif(foundUse GREATER_EQUAL 0 AND foundUse GREATER foundFind)
            list(REMOVE_AT _FEATURES ${foundUse})
            if(foundFind GREATER_EQUAL 0)
                list(REMOVE_AT _FEATURES ${foundFind})
            endif ()
        else ()
            # They can only be the same if they are both -1, and in that case we do nothing
        endif ()

        if (foundFind GREATER_EQUAL 0 AND foundUse LESS 0)
            list(INSERT _FEATURES ${foundFind} "${_PKG} PACKAGE ${pkg} ARGS PATHS {${pkg}}")
            #            list(PREPEND _FEATURES "${_PKG} PACKAGE ${pkg} ARGS PATHS {${pkg}}")
        endif ()

        globalObjSet(GLOBAL_FEATURES "${_FEATURES}")

        set(fn "add${pkg}Features")
        cmake_language(CALL registerPackageCallback "${fn}" ${discovery_phase})
    endif ()
    set(HANDLED ON)

endfunction()
