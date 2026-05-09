include_guard(GLOBAL)

# GfxTarget.cmake references OpenSSL::SSL/Crypto in INTERFACE_LINK_LIBRARIES.
# GfxConfig.cmake validates these immediately when it includes GfxTarget.wrapped.cmake.
# The SSL feature (METHOD "PROCESS") is listed after GFX in APP_FEATURES, so OpenSSL
# is not yet found when find_package(Gfx) runs. Probe early with QUIET so that
# OpenSSL::SSL/Crypto exist before GfxConfig.cmake executes.
find_package(OpenSSL QUIET COMPONENTS SSL Crypto)

# CoreConfigVersion.cmake is an old-format targets file CMake 3.31+ loads during
# find_package version-checking. It calls target_sources(HoffSoft::Core INTERFACE
# FILE_SET "CXX_MODULES") referencing .ixx files not staged under
# lib64/cmake/cxx/HoffSoft/Core/src/. Strip the CXX_MODULES file set before
# find_package(Core) runs. Idempotent: if already patched, string(FIND) returns -1.
find_file(_hs_core_cv
    NAMES "CoreConfigVersion.cmake"
    PATHS ${CMAKE_PREFIX_PATH}
    PATH_SUFFIXES "lib64/cmake" "lib/cmake" "cmake"
    NO_DEFAULT_PATH
    NO_CACHE
)
if(_hs_core_cv)
    file(READ "${_hs_core_cv}" _hs_cvc)
    string(FIND "${_hs_cvc}" [=[FILE_SET "CXX_MODULES"]=] _hs_at)
    if(NOT _hs_at EQUAL -1)
        string(SUBSTRING "${_hs_cvc}" 0 ${_hs_at} _hs_pre)
        string(FIND "${_hs_pre}" "INTERFACE" _hs_iface REVERSE)
        string(SUBSTRING "${_hs_cvc}" 0 ${_hs_iface} _hs_pre)
        set(_hs_pre "${_hs_pre})")
        string(SUBSTRING "${_hs_cvc}" ${_hs_at} -1 _hs_post)
        string(FIND "${_hs_post}" "else()" _hs_else)
        string(SUBSTRING "${_hs_post}" ${_hs_else} -1 _hs_post)
        set(_hs_cvc "${_hs_pre}\n${_hs_post}")
        file(WRITE "${_hs_core_cv}" "${_hs_cvc}")
    endif()
    unset(_hs_cvc)
    unset(_hs_at)
    unset(_hs_pre)
    unset(_hs_iface)
    unset(_hs_post)
    unset(_hs_else)
endif()
unset(_hs_core_cv)

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

# Called by fetchContents after find_package(Gfx) succeeds. Removes non-existent
# paths from HoffSoft::wxmono's INTERFACE_INCLUDE_DIRECTORIES. GfxTarget.cmake
# bakes wxWidgets build-tree paths (lib64/wx/include/gtk3-unicode-3.3, include/wx-3.3)
# that are never staged to the install prefix. CMake validates transitive include dirs
# at generate time and errors on missing paths via HoffSoft::Gfx -> HoffSoft::wxWidgets
# -> HoffSoft::wxmono. Consumers get wx headers through wx::wxmono (WX_Helper.cmake).
function(Gfx_postMakeAvailable src build outDir buildType)
    if(APP_NAME STREQUAL "Gfx")
        return()
    endif()
    if(TARGET "HoffSoft::wxmono")
        get_target_property(_wxm_incs "HoffSoft::wxmono" INTERFACE_INCLUDE_DIRECTORIES)
        if(_wxm_incs)
            set(_wxm_existing "")
            foreach(_d IN LISTS _wxm_incs)
                if(IS_DIRECTORY "${_d}")
                    list(APPEND _wxm_existing "${_d}")
                endif()
            endforeach()
            set_target_properties("HoffSoft::wxmono" PROPERTIES
                INTERFACE_INCLUDE_DIRECTORIES "${_wxm_existing}")
            unset(_wxm_existing)
        endif()
        unset(_wxm_incs)
    endif()
    set(HANDLED ON PARENT_SCOPE)
endfunction()
