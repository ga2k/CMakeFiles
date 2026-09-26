# cxxStdModule.cmake
#
# Provides the `std`/`std.compat` C++23 module BMI as ONE explicit, shared
# CMake target (HoffSoftCxxStd) instead of relying on CMake's automatic
# CXX_MODULE_STD synthesis.
#
# Why: CMake's CXX_MODULE_STD support creates a SEPARATE synthesized "std"
# BMI compile per directory scope that requests it (Core, Gfx, each
# FetchContent'd dependency, MyCare, ...), and empirically these are NOT
# byte-identical across separate compiles of the exact same input (verified
# by hand: sha256 of the "std" BMI differed across per-scope copies within a
# single Libs build). Clang's module deserializer isn't robust against a
# consumer being handed a DIFFERENT (even if nominally equivalent) "std" BMI
# than the one a dependency (e.g. Core's Database.pcm) was actually compiled
# against -- it segfaults in ASTDeclReader::UpdateDecl instead of erroring
# cleanly. The fix is to make there be only ONE "std" BMI, built once and
# shared the same way this project already shares other fetched dependencies
# (yaml-cpp, soci, ...): a single exported CMake target that everything
# downstream links against and inherits transitively.
#
# provideCxxStdModule() creates the HoffSoftCxxStd target (idempotent -- safe
# to call from multiple directory scopes) and installs its module BMI/sources
# into Core's own staged cxx/bmi directories, so it is automatically visible
# to every consumer that already has Core on its -fprebuilt-module-path
# (which is everything: Gfx, MyCare, ...). Callers must
# target_link_libraries(<target> PUBLIC HoffSoftCxxStd) to pull it in --
# CMake's C++ modules support propagates the BMI search path transitively
# through that link, the same way it already does for yaml-cpp/eventpp/etc.

function(provideCxxStdModule)
    if (TARGET HoffSoftCxxStd)
        return()
    endif ()

    if (NOT CMAKE_CXX_COMPILER_ID STREQUAL "Clang" AND NOT CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
        message(FATAL_ERROR "provideCxxStdModule() only knows how to locate libstdc++/libc++ std module sources for Clang")
    endif ()

    if (CMAKE_CXX_STANDARD_LIBRARY STREQUAL "libc++")
        set(_hs_std_impl "libc++")
    else ()
        set(_hs_std_impl "libstdc++")
    endif ()

    execute_process(
            COMMAND "${CMAKE_CXX_COMPILER}" -print-file-name=${_hs_std_impl}.modules.json
            OUTPUT_VARIABLE _hs_std_modules_json
            OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if (NOT EXISTS "${_hs_std_modules_json}")
        message(FATAL_ERROR "provideCxxStdModule(): could not locate ${_hs_std_impl}.modules.json (got '${_hs_std_modules_json}')")
    endif ()
    get_filename_component(_hs_std_modules_dir "${_hs_std_modules_json}" DIRECTORY)
    file(READ "${_hs_std_modules_json}" _hs_std_modules_content)

    string(JSON _hs_std_count LENGTH "${_hs_std_modules_content}" "modules")
    math(EXPR _hs_std_last "${_hs_std_count} - 1")
    set(_hs_std_sources "")
    foreach (_hs_i RANGE ${_hs_std_last})
        string(JSON _hs_src GET "${_hs_std_modules_content}" "modules" ${_hs_i} "source-path")
        get_filename_component(_hs_src_abs "${_hs_src}" ABSOLUTE BASE_DIR "${_hs_std_modules_dir}")
        list(APPEND _hs_std_sources "${_hs_src_abs}")
    endforeach ()
    unset(_hs_std_count)
    unset(_hs_std_last)
    unset(_hs_std_modules_content)
    unset(_hs_std_modules_json)
    unset(_hs_std_modules_dir)

    if (NOT _hs_std_sources)
        message(FATAL_ERROR "provideCxxStdModule(): found no module sources in ${_hs_std_impl}.modules.json")
    endif ()

    list(GET _hs_std_sources 0 _hs_std_first)
    get_filename_component(_hs_std_base "${_hs_std_first}" DIRECTORY)
    unset(_hs_std_first)

    add_library(HoffSoftCxxStd STATIC)
    target_sources(HoffSoftCxxStd
            PUBLIC
            FILE_SET CXX_MODULES TYPE CXX_MODULES
            BASE_DIRS "${_hs_std_base}"
            FILES ${_hs_std_sources}
    )
    unset(_hs_std_base)
    set_target_properties(HoffSoftCxxStd PROPERTIES
            CXX_STANDARD 23
            CXX_STANDARD_REQUIRED ON
            CXX_EXTENSIONS OFF
            CXX_MODULE_STD OFF
            POSITION_INDEPENDENT_CODE ON
    )
    unset(_hs_std_sources)
    unset(_hs_std_impl)

    # NOTE: deliberately NOT using install(TARGETS ... CXX_MODULES_BMI ...) here.
    # CMake only honors that keyword on a component-less ("full") install; every
    # install in this project passes --component explicitly (see the
    # ${APP_NAME}_export.stamp custom command and the packaging install() calls
    # in project_install.cmake), so CXX_MODULES_BMI would silently install
    # nothing. Core's own modules hit the same limitation and work around it
    # with a plain install(DIRECTORY) copy of the whole ".dir/" build output
    # (see project_install.cmake) -- do the same here for std.pcm/std.compat.pcm.
    install(TARGETS HoffSoftCxxStd
            EXPORT CoreTarget
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT CoreDevelopment
            FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/Core COMPONENT CoreDevelopment
    )
    # Stage the ACTUAL BMI every Core/Gfx module was compiled against, not
    # HoffSoftCxxStd's own "real" library compile of std.cc/std.compat.cc.
    # CMake's dyndep module scanner resolves any consumer's `import std;`
    # against a separate, per-consumer-scope "shadow" BMI compile
    # (CMakeFiles/HoffSoftCxxStd@synth_N.dir/*.bmi) rather than reusing
    # HoffSoftCxxStd's own library-archive BMI (CMakeFiles/HoffSoftCxxStd.dir/std.pcm)
    # -- verified by hand: the two are NOT byte-identical, even though every
    # synth_N shadow copy IS identical to every other one. Staging the wrong
    # one would silently reintroduce the exact BMI-identity mismatch this
    # whole mechanism exists to eliminate. The two BMI files a synth_N
    # directory holds are told apart by their .modmap content (see
    # ee2887e60fcb.bmi.modmap / 5c61ca334141.bmi.modmap as of this CMake
    # version): the FILES glob below is resolved and copied at INSTALL time
    # (not configure time), since the synth_N directories only exist once
    # some consumer's build has actually triggered the scan that creates them.
    install(CODE
            "set(_hs_cxxstd_synth_dir \"${CMAKE_CURRENT_BINARY_DIR}/CMakeFiles\")
             set(_hs_cxxstd_dest \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/Core\")
             include(\"${cmake_root}/installCxxStdBmi.cmake\")"
            COMPONENT CoreDevelopment
    )
endfunction()
