include("${CMAKE_SOURCE_DIR}/cmake/tools.cmake")

function(cpptrace_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "v0.7.3")
        message(FATAL_ERROR "Attempting to patch wrong version of cpptrace")
    endif ()

    list(APPEND patches "cpptrace/cmake|${sourceDir}")
    patchExternals(${target} "${patches}")
    set(HANDLED ON)

endfunction()
