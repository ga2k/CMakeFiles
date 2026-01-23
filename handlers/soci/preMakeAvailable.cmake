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

    # Ensure sources are populated so we can patch them *before* add_subdirectory().
    # Note: After FetchContent_Populate(), we must add_subdirectory() ourselves.
    FetchContent_GetProperties(${pkgname})
    if (NOT ${pkgname}_POPULATED)
        message(STATUS "Pre-patching ${pkgname}: FetchContent_Populate(${pkgname})")
        FetchContent_Populate(${pkgname})
    endif ()

    if (NOT DEFINED ${pkgname}_SOURCE_DIR OR NOT EXISTS "${${pkgname}_SOURCE_DIR}")
        message(FATAL_ERROR "Pre-patching ${pkgname}: ${pkgname}_SOURCE_DIR not set or missing")
    endif ()

    set(_soci_src "${${pkgname}_SOURCE_DIR}")
    set(_soci_bin "${${pkgname}_BINARY_DIR}")

    if (COMMAND soci_fix)
        soci_fix("${pkgname}" "" "${_soci_src}")
    elseif (EXISTS "${CMAKE_SOURCE_DIR}/cmake/patches/${pkgname}")
        unset(_patches)
        list(APPEND _patches "${pkgname}|${_soci_src}")
        patchExternals("${pkgname}" ${_patches})
    endif ()

    # Add SOCI to the build using the patched sources.
    if (NOT TARGET soci_core AND NOT TARGET SOCI::Core)
        add_subdirectory("${_soci_src}" "${_soci_bin}" EXCLUDE_FROM_ALL)
    endif ()

    # Tell fetchContents() not to call FetchContent_MakeAvailable() again.
    set(HANDLED ON PARENT_SCOPE)

    unset(_soci_src)
    unset(_soci_bin)
endfunction()
