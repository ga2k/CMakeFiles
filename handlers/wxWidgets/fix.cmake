include("${CMAKE_SOURCE_DIR}/cmake/tools.cmake")

function(wxWidgets_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of ${target}")
    endif ()

    unset(patches)
    list(APPEND patches
            "${target}/include|${sourceDir}"
            "${target}/src|${sourceDir}"
    )
    replaceFile(${target} "${patches}")
    set(HANDLED ON PARENT_SCOPE)

endfunction()
