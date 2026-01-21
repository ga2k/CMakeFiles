# Add this new function to strip SOCI's internal install rules
function(soci_postDeclare pkgname)
    # We need to disable SOCI's internal export/install logic because it conflicts
    # with our unified HoffSoftTarget export set.
    set(soci_src_dir "${EXTERNALS_DIR}/soci")

    if(EXISTS "${soci_src_dir}/CMakeLists.txt")
        message(STATUS "Patching SOCI to disable internal export sets...")
        # Use your helper to comment out the install logic in SOCI's root
        include(${CMAKE_SOURCE_DIR}/cmake/tools.cmake)
        ReplaceInFile("${soci_src_dir}/src/core/CMakeLists.txt" "install(EXPORT" "# install(EXPORT")
        ReplaceInFile("${soci_src_dir}/src/backends/sqlite3/CMakeLists.txt" "install(EXPORT" "# install(EXPORT")
    endif()
endfunction()