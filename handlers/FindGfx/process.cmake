function(FindGfx_process incs libs defs)

    fittest(PACKAGE     "Gfx"
            FILENAME    "Gfx.cmake"

            OUTPUT      candidates

            SOURCE_DIR  "${CMAKE_SOURCE_DIR}/../Gfx"
            STAGED_DIR  "${STAGED_PATH}"
            SYSTEM_DIR  "${SYSTEM_PATH}"
    )

    list(LENGTH candidates numCandidates)
    if(numCandidates EQUAL 0)
        msg(ALWAYS FATAL_ERROR "Gfx Library configuration file \"Gfx.cmake\" not found")
    elseif (numCandidates EQUAL 1)
        set(config_file "${candidates}")
    else ()
        list(GET candidates 0 config_file)
    endif ()

    registerLibrary(CORE HoffSoft Gfx "${config_file}")
    initGfx()

endfunction()
