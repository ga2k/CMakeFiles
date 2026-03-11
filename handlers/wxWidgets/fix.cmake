include("${cmake_root}/tools.cmake")

function(wxWidgets_fix target tag sourceDir)

#    cmake_policy(SET CMP0111 OLD)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of ${target}")
    endif ()

    unset(patches)
    list(APPEND patches
            "${target}/include|${sourceDir}/include/wx/"
            #  "${target}/src/common|${sourceDir}/src/common/"
            # "${target}/src/osx|${sourceDir}/src/osx/carbon/"
            "${target}/src|${sourceDir}"
    )
    replaceFile(${target} "${patches}")
    set(HANDLED ON PARENT_SCOPE)

endfunction()
