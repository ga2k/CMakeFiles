
function(addGfxFeatures dry_run)
    # @formatter:off
    addPackageData(PLUGIN   FEATURE "APPEARANCE"  PKGNAME "Appearance"    METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN   FEATURE "LOGGER"      PKGNAME "Logger"        METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN   FEATURE "PRINT"       PKGNAME "Print"         METHOD "IGNORE" DRY_RUN ${dry_run})

    if(APP_NAME STREQUAL "Gfx")
        # Building Gfx itself: fetch wxWidgets from source and build it.
        addPackageData(OPTIONAL FEATURE "GUI" PKGNAME "wxWidgets" METHOD "FETCH_CONTENTS"
                GIT_REPOSITORY "https://github.com/wxWidgets/wxWidgets.git" GIT_TAG "master"
                ARG REQUIRED DRY_RUN ${dry_run})
    else()
        # Consumer app (e.g. HealthCanvas): wx is already embedded in the staged
        # libhoffsoft_gfx.so. Ignore so we don't trigger a 1400-file source rebuild.
        # Gfx_postMakeAvailable (below) populates HS_wx* vars from the staged package.
        addPackageData(OPTIONAL FEATURE "GUI" PKGNAME "wxWidgets" METHOD "IGNORE" DRY_RUN ${dry_run})
    endif()

    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS REQUIRED CONFIG DRY_RUN ${dry_run})
    # @formatter:on

#    if(Appearance IN_LIST APP_FEATURES)
        registerPlugin("Appearance")
#    endif ()
#    if(Logger IN_LIST APP_FEATURES)
        registerPlugin("Logger")
#    endif ()
#    if(Print IN_LIST APP_FEATURES)
        registerPlugin("Print")
#    endif ()

endfunction()

# Called by fetchContents after find_package(Gfx) succeeds. WX_Helper.cmake has already
# run (as part of GfxConfig.cmake) and created the wx::wxmono shim pointing at the staged
# .so. Populate the HS_wx* accumulators so addLibrary.cmake can configure GUI targets in
# consumer apps without rebuilding wxWidgets from source.
function(Gfx_postMakeAvailable src build outDir buildType)
    if(APP_NAME STREQUAL "Gfx")
        return()  # wx handled by wxWidgets_postMakeAvailable during Gfx's own build
    endif()

    # Ensure wx::wxmono has INTERFACE_INCLUDE_DIRECTORIES so wxWidgets_export_variables
    # can read them. WX_Helper.cmake sets these on WIN32 but not Linux.
    if(TARGET wx::wxmono AND Gfx_INCLUDE_DIR)
        get_target_property(_gfx_wx_existing_incs wx::wxmono INTERFACE_INCLUDE_DIRECTORIES)
        if(NOT _gfx_wx_existing_incs)
            file(GLOB _gfx_wx_subdirs LIST_DIRECTORIES true "${Gfx_INCLUDE_DIR}/wx*")
            set(_gfx_wx_incs "${Gfx_INCLUDE_DIR}")
            foreach(_d IN LISTS _gfx_wx_subdirs)
                if(IS_DIRECTORY "${_d}")
                    list(APPEND _gfx_wx_incs "${_d}")
                endif()
            endforeach()
            if(_gfx_wx_incs)
                set_target_properties(wx::wxmono PROPERTIES
                    INTERFACE_INCLUDE_DIRECTORIES "${_gfx_wx_incs}")
            endif()
        endif()
    endif()

    # Use wxWidgets_export_variables to extract include paths, defines, and library
    # targets from the wx::wxmono shim into the _wx* local vars.
    include("${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../handlers/wxWidgets/helpers.cmake" OPTIONAL)
    if(COMMAND wxWidgets_export_variables)
        wxWidgets_export_variables("wxWidgets")
    endif()

    # Propagate to the fetchContents accumulator scope (PARENT_SCOPE = calling function).
    set(_wxIncludePaths    "${_wxIncludePaths}"    PARENT_SCOPE)
    set(_wxDefines         "${_wxDefines}"         PARENT_SCOPE)
    set(_wxLibraries       "${_wxLibraries}"       PARENT_SCOPE)
    set(_wxCompilerOptions "${_wxCompilerOptions}" PARENT_SCOPE)
    set(HANDLED ON PARENT_SCOPE)
endfunction()

function(FindGfx_init)
    commonInit(Gfx)
endfunction()
