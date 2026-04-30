# post_process_export.cmake
# Invoked as: cmake -P post_process_export.cmake <TargetFile.cmake> <Vendor>
#
# Patches a build-tree export file to remove C++ module synthesis triggers and
# FetchContent-only deps that have no corresponding installed targets, so that
# consuming projects pointing at the build-tree export work without staging.

set(_target_file "${CMAKE_ARGV3}")
set(_vendor      "${CMAKE_ARGV4}")

if(NOT EXISTS "${_target_file}")
    message(STATUS "post_process_export: ${_target_file} not found, skipping")
    return()
endif()

# Derive library name from filename: e.g. GfxTarget.cmake -> Gfx
get_filename_component(_filename "${_target_file}" NAME_WE)
string(REPLACE "Target" "" _libname "${_filename}")

file(READ "${_target_file}" outvar)

# Remove the cxx-modules include that CMake emits for FILE_SET CXX_MODULES targets.
set(_cxx_inc [=[include("${CMAKE_CURRENT_LIST_DIR}/cxx/]=])
string(JOIN "" _cxx_inc "${_cxx_inc}" "${_vendor}/${_libname}" [=[/cxx-modules-]=] "${_libname}" [=[Target.cmake")]=])
string(REPLACE "${_cxx_inc}" "# (cxx-modules include removed by post_process_export)" outvar "${outvar}")
unset(_cxx_inc)

# Remove FILE_SET "CXX_MODULES" from the INTERFACE property block.
string(FIND "${outvar}" [=[FILE_SET "CXX_MODULES"]=] _foundAt)
if(NOT _foundAt EQUAL -1)
    string(SUBSTRING "${outvar}" 0 ${_foundAt} _firstBit)
    string(FIND "${_firstBit}" "INTERFACE" _interfaceAt REVERSE)
    string(SUBSTRING "${outvar}" 0 ${_interfaceAt} _firstBit)
    set(_firstBit "${_firstBit})")
    string(SUBSTRING "${outvar}" ${_foundAt} -1 _lastBit)
    string(FIND "${_lastBit}" "else()" _elseBit)
    string(SUBSTRING "${_lastBit}" ${_elseBit} -1 _finally)
    set(outvar "${_firstBit}\n${_finally}")
    unset(_firstBit)
    unset(_lastBit)
    unset(_finally)
    unset(_interfaceAt)
    unset(_elseBit)
endif()
unset(_foundAt)

# Strip FetchContent-only deps that are statically embedded in the shared
# library and have no corresponding installed target.
foreach(_fc_dep "yaml-cpp::yaml-cpp")
    string(REPLACE "${_fc_dep};" "" outvar "${outvar}")
    string(REPLACE ";${_fc_dep}" "" outvar "${outvar}")
    string(REPLACE "${_fc_dep}"  "" outvar "${outvar}")
endforeach()
unset(_fc_dep)

file(WRITE "${_target_file}" "${outvar}")

unset(_libname)
unset(_filename)
unset(_vendor)
unset(_target_file)
