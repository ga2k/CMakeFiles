# installCxxStdBmi.cmake
#
# Included via install(CODE) from cxxStdModule.cmake, with two variables
# already set: _hs_cxxstd_synth_dir (the CMakeFiles/ dir to search) and
# _hs_cxxstd_dest (where to stage std.pcm/std.compat.pcm). Runs at install
# time (not configure time) since the HoffSoftCxxStd@synth_N/ directories
# this searches only exist once some consumer's build has actually triggered
# the dyndep scan that creates them.
#
# See cxxStdModule.cmake for why this copies the synth_N shadow BMI rather
# than HoffSoftCxxStd's own library-archive BMI.

file(GLOB _hs_std_synth_bmi "${_hs_cxxstd_synth_dir}/HoffSoftCxxStd@synth_*.dir/*.bmi")
set(_hs_std_bmi "")
set(_hs_std_compat_bmi "")
foreach (_hs_bmi IN LISTS _hs_std_synth_bmi)
    get_filename_component(_hs_bmi_dir "${_hs_bmi}" DIRECTORY)
    get_filename_component(_hs_bmi_name "${_hs_bmi}" NAME_WE)
    set(_hs_bmi_modmap "${_hs_bmi_dir}/${_hs_bmi_name}.bmi.modmap")
    if (EXISTS "${_hs_bmi_modmap}")
        file(READ "${_hs_bmi_modmap}" _hs_bmi_modmap_content)
        # Only std.compat's modmap has a "-fmodule-file=" line (its own
        # dependency on std); plain std's modmap has none.
        if ("${_hs_bmi_modmap_content}" MATCHES "-fmodule-file=" AND NOT _hs_std_compat_bmi)
            set(_hs_std_compat_bmi "${_hs_bmi}")
        elseif (NOT _hs_std_bmi)
            set(_hs_std_bmi "${_hs_bmi}")
        endif ()
    endif ()
    unset(_hs_bmi_modmap_content)
endforeach ()

if (NOT _hs_std_bmi)
    message(FATAL_ERROR "Could not locate HoffSoftCxxStd's synth-scope std BMI under ${_hs_cxxstd_synth_dir}/HoffSoftCxxStd@synth_*.dir -- has a Core/Gfx module actually been compiled with 'import std;' yet?")
endif ()

file(INSTALL
        DESTINATION "${_hs_cxxstd_dest}"
        TYPE FILE
        RENAME std.pcm
        FILES "${_hs_std_bmi}"
)
# std.compat is only built if something actually writes `import std.compat;`
# (nothing in this codebase currently does) -- stage it too if present, but
# don't require it.
if (_hs_std_compat_bmi)
    file(INSTALL
            DESTINATION "${_hs_cxxstd_dest}"
            TYPE FILE
            RENAME std.compat.pcm
            FILES "${_hs_std_compat_bmi}"
    )
endif ()

unset(_hs_std_synth_bmi)
unset(_hs_std_bmi)
unset(_hs_std_compat_bmi)
unset(_hs_bmi_dir)
unset(_hs_bmi_name)
