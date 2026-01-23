include(FetchContent)
include("${CMAKE_SOURCE_DIR}/cmake/tools.cmake")

function(soci_preMakeAvailable pkgname)

    # SOCI's upstream CMake uses multiple install(EXPORT ...) sets (Core + per-backend).
    # When we also export SOCI targets as part of our own package, that creates
    # "target is in multiple export sets" errors at configure time.
    #
    # Force-disable SOCI's internal install/export logic before SOCI is added.
    forceSet(SOCI_INSTALL "" OFF BOOL)
    forceSet(SOCI_SKIP_INSTALL "" ON BOOL)

    # Ensure sources are populated so we can patch them *before* add_subdirectory()
    # (FetchContent_MakeAvailable would otherwise configure SOCI first, and we'd be too late).
    FetchContent_GetProperties(${pkgname})
    if (NOT ${pkgname}_POPULATED)
        message(STATUS "Pre-patching ${pkgname}: FetchContent_Populate(${pkgname})")
        FetchContent_Populate(${pkgname})
    endif ()

    if (DEFINED ${pkgname}_SOURCE_DIR AND EXISTS "${${pkgname}_SOURCE_DIR}")
        set(_soci_src "${${pkgname}_SOURCE_DIR}")
    else ()
        set(_soci_src "${EXTERNALS_DIR}/${pkgname}")
    endif ()

    if (COMMAND soci_fix)
        soci_fix("${pkgname}" "" "${_soci_src}")
    elseif (EXISTS "${CMAKE_SOURCE_DIR}/cmake/patches/${pkgname}")
        unset(_patches)
        list(APPEND _patches "${pkgname}|${_soci_src}")
        patchExternals("${pkgname}" ${_patches})
    endif ()

    unset(_soci_src)
endfunction()

