function(cpptrace_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "v0.7.3")
        message(FATAL_ERROR "Attempting to patch wrong version of cpptrace")
    endif ()

    set(pkg ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${pkg} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${pkg} 0 ${subLength} pkg)

    message("Applying local patches to ${pkg}...")

    ReplaceInFile("${sourceDir}/Autoconfig.cmake"
[=[
    check_cxx_source_compiles(${full_source} ${var})
]=]

[=[
    if (${var} STREQUAL HAS_CXXABI
        OR ${var} STREQUAL HAS_EXECINFO
    )
        set(${var} TRUE PARENT_SCOPE)\n"
    elseif (${var} STREQUAL HAS_MACH_VM)"
        set(${var} FALSE PARENT_SCOPE)"
    else ()"
        check_cxx_source_compiles(${full_source} ${var}) # Fixed GH"
        set(${var} TRUE PARENT_SCOPE)"
    endif ()
]=])
endfunction()

cpptrace_fix("${this_pkgname}" "${this_tag}" "${this_src}")
set(HANDLED ON)
