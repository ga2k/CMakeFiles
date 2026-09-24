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

# Remove EVERY "if(cmake >= 3.28) target_sources(... FILE_SET CXX_MODULES
# ...) else() message(...) endif()" block -- a target file can legitimately
# contain more than one (e.g. one per exported target that has its own
# FILE_SET CXX_MODULES, such as Core plus the shared HoffSoftCxxStd target),
# so this loops rather than handling only the first. Leaving a bare
# "target_sources(Target\n)" behind (as an earlier version of this script did)
# is itself invalid: CMake rejects target_sources() called with only a target
# name and no PUBLIC/PRIVATE/INTERFACE keyword ("incorrect number of
# arguments"), which breaks consumers on newer CMake.
string(FIND "${outvar}" [=[FILE_SET "CXX_MODULES"]=] _foundAt)
while(NOT _foundAt EQUAL -1)
    string(SUBSTRING "${outvar}" 0 ${_foundAt} _firstBit)
    string(FIND "${_firstBit}" [=[if(NOT CMAKE_VERSION VERSION_LESS "3.28.0")]=] _ifAt REVERSE)
    string(SUBSTRING "${outvar}" 0 ${_ifAt} _firstBit)
    string(SUBSTRING "${outvar}" ${_foundAt} -1 _lastBit)
    string(FIND "${_lastBit}" "endif()" _endifAt)
    string(LENGTH "endif()" _endifLen)
    math(EXPR _afterEndif "${_endifAt} + ${_endifLen}")
    string(SUBSTRING "${_lastBit}" ${_afterEndif} -1 _finally)
    set(outvar "${_firstBit}# (cxx-modules target_sources block removed by post_process_export)${_finally}")
    unset(_firstBit)
    unset(_lastBit)
    unset(_finally)
    unset(_ifAt)
    unset(_endifAt)
    unset(_endifLen)
    unset(_afterEndif)
    string(FIND "${outvar}" [=[FILE_SET "CXX_MODULES"]=] _foundAt)
endwhile()
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
