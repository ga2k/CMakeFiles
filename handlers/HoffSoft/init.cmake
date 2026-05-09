include_guard(GLOBAL)

# cpptrace is statically embedded in libhoffsoft_core.so; no installed target.
# CoreConfigVersion.cmake (an old-format targets file loaded by CMake 3.31+ during
# find_package version-checking) references cpptrace::cpptrace in
# IMPORTED_CXX_MODULES_LINK_LIBRARIES and validates it immediately. The stub
# satisfies that check. The if(NOT TARGET) guard in fetchContents also sees this
# stub and skips fetching cpptrace from source.
if(NOT TARGET cpptrace::cpptrace)
    add_library(cpptrace::cpptrace INTERFACE IMPORTED GLOBAL)
endif()

# GfxTarget.cmake references OpenSSL::SSL/Crypto in INTERFACE_LINK_LIBRARIES.
# GfxConfig.cmake validates these immediately when it includes GfxTarget.wrapped.cmake.
# The SSL feature (METHOD "PROCESS") is listed after GFX in APP_FEATURES, so OpenSSL
# is not yet found when find_package(Gfx) runs. Probe early with QUIET so that
# OpenSSL::SSL/Crypto exist before GfxConfig.cmake executes.
find_package(OpenSSL QUIET COMPONENTS SSL Crypto)

function (HoffSoft_init dry_run)
    FindCore_init(${dry_run})
    FindGfx_init(${dry_run})
endfunction()

########################################################################################################################

function(addCoreFeatures dry_run)
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core"
            METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS NO_CMAKE_FIND_ROOT_PATH REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dry_run})
endfunction()

function(FindCore_init dry_run)
    commonInit (Core ${dry_run})
endfunction()

########################################################################################################################

function(addGfxFeatures dry_run)
    # @formatter:off
    addPackageData(PLUGIN   FEATURE "APPEARANCE"  PKGNAME "Appearance"    METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN   FEATURE "LOGGER"      PKGNAME "Logger"        METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN   FEATURE "PRINT"       PKGNAME "Print"         METHOD "IGNORE" DRY_RUN ${dry_run})

    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS NO_CMAKE_FIND_ROOT_PATH REQUIRED CONFIG PREREQ CORE DRY_RUN ${dry_run})
    # @formatter:on

endfunction()

function(FindGfx_init dry_run)
    commonInit(Gfx ${dry_run})
endfunction()

# Called by fetchContents after find_package(Gfx) succeeds. Strips the wxWidgets
# build-tree setup-header directory (lib64/wx/include/gtk3-unicode-3.3) from
# HoffSoft::wxmono's INTERFACE_INCLUDE_DIRECTORIES. That directory is generated
# during wxWidgets' configure step but is not staged to the install prefix.
# CMake validates transitive include dirs at generate time and errors on the missing path
# via the chain HoffSoft::Gfx -> HoffSoft::wxWidgets -> HoffSoft::wxmono.
function(Gfx_postMakeAvailable src build outDir buildType)
    if(APP_NAME STREQUAL "Gfx")
        return()
    endif()
    if(TARGET "HoffSoft::wxmono")
        get_target_property(_wxm_incs "HoffSoft::wxmono" INTERFACE_INCLUDE_DIRECTORIES)
        if(_wxm_incs)
            list(FILTER _wxm_incs EXCLUDE REGEX ".*/wx/include/")
            set_target_properties("HoffSoft::wxmono" PROPERTIES
                INTERFACE_INCLUDE_DIRECTORIES "${_wxm_incs}")
        endif()
        unset(_wxm_incs)
    endif()
    set(HANDLED ON PARENT_SCOPE)
endfunction()
