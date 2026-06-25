include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

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