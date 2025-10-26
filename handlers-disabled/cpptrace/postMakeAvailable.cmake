function(cpptrace_postMakeAvailable sourceDir buildDir outDir buildType components)

    if (NOT "${this_tag}" STREQUAL "v0.7.3")
        message(FATAL_ERROR "Attempting to patch wrong version of cpptrace")
    endif ()

    set(pkg ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${pkg} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${pkg} 0 ${subLength} pkg)

    message("Applying local patches to ${pkg}...")

    ReplaceInFile("${this_srcDir}/Autoconfig.cmake"
            "check_cxx_source_compiles(${full_source} ${var})\n"

            "    if (${var} STREQUAL HAS_CXXABI\n"
            "        OR ${var} STREQUAL HAS_EXECINFO\n"
            "    )\n"
            "        set(${var} TRUE PARENT_SCOPE)\n"
            "    elseif (${var} STREQUAL HAS_MACH_VM)"
            "        set(${var} FALSE PARENT_SCOPE)"
            "    else ()"
            "        check_cxx_source_compiles(${full_source} ${var}) # Fixed GH"
            "        set(${var} TRUE PARENT_SCOPE)"
            "    endif ()"
    )
endfunction()

cpptrace_postMakeAvailable("${this_src}" "${this_build}" "${this_out}" "${BUILD_TYPE_LC}" "${this_find_package_components}")
set(_DefinesList      ${_DefinesList} PARENT_SCOPE)
set(_IncludePathsList ${_IncludePathsList} PARENT_SCOPE)
set(_LibrariesList    ${_LibrariesList} PARENT_SCOPE)

set(HANDLED ON)
