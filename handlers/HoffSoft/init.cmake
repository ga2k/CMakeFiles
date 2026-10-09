include_guard(GLOBAL)

# GfxTarget.cmake references OpenSSL::SSL/Crypto in INTERFACE_LINK_LIBRARIES.
# GfxConfig.cmake validates these immediately when it includes GfxTarget.wrapped.cmake.
# The SSL feature (METHOD "PROCESS") is listed after GFX in APP_FEATURES, so OpenSSL
# is not yet found when find_package(Gfx) runs. Probe early with QUIET so that
# OpenSSL::SSL/Crypto exist before GfxConfig.cmake executes.
if(APPLE)
    find_package(OpenSSL QUIET COMPONENTS SSL Crypto HINTS /opt/homebrew /usr/local/opt/openssl /usr/local)
else()
    find_package(OpenSSL QUIET COMPONENTS SSL Crypto)
endif()

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
    # Strip the target_sources FILE_SET CXX_MODULES block. CMake 4.x generates an
    # empty stub (no FILE_SET) so check for that too. Remove the whole
    # if(NOT CMAKE_VERSION VERSION_LESS "3.28.0")...endif() block either way.
    string(FIND "${_hs_cvc}" [=[FILE_SET "CXX_MODULES"]=] _hs_at)
    if(_hs_at EQUAL -1)
        string(FIND "${_hs_cvc}" "target_sources(HoffSoft::Core\n)" _hs_at)
    endif()
    if(NOT _hs_at EQUAL -1)
        string(SUBSTRING "${_hs_cvc}" 0 ${_hs_at} _hs_pre)
        string(FIND "${_hs_pre}" "if(NOT CMAKE_VERSION" _hs_if_pos REVERSE)
        if(NOT _hs_if_pos EQUAL -1)
            string(SUBSTRING "${_hs_cvc}" ${_hs_at} -1 _hs_tail)
            string(FIND "${_hs_tail}" "\nendif()\n" _hs_endif_rel)
            if(NOT _hs_endif_rel EQUAL -1)
                math(EXPR _hs_endif_abs "${_hs_at} + ${_hs_endif_rel} + 9")
                string(SUBSTRING "${_hs_cvc}" 0 ${_hs_if_pos} _hs_head)
                string(SUBSTRING "${_hs_cvc}" ${_hs_endif_abs} -1 _hs_tail2)
                set(_hs_cvc "${_hs_head}${_hs_tail2}")
                unset(_hs_head)
                unset(_hs_tail2)
                unset(_hs_endif_abs)
            endif()
            unset(_hs_tail)
            unset(_hs_endif_rel)
            unset(_hs_if_pos)
        endif()
        unset(_hs_pre)
        file(WRITE "${_hs_core_cv}" "${_hs_cvc}")
    endif()
    unset(_hs_cvc)
    unset(_hs_at)
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
#    addPackageData(PLUGIN   FEATURE "APPEARANCE"  PKGNAME "Appearance"    METHOD "IGNORE" DRY_RUN ${dry_run})
#    addPackageData(PLUGIN   FEATURE "LOGGER"      PKGNAME "Logger"        METHOD "IGNORE" DRY_RUN ${dry_run})
#    addPackageData(PLUGIN   FEATURE "PRINT"       PKGNAME "Print"         METHOD "IGNORE" DRY_RUN ${dry_run})

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
