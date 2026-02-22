include(GNUInstallDirs)

function(FindCore_process incs libs defs)

    fittest(PACKAGE     "Core"
            FILENAME    "Core.cmake"

            OUTPUT      candidates

            SOURCE_DIR  "${CMAKE_SOURCE_DIR}/../Core"
            STAGED_DIR  "${STAGED_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${APP_VENDOR}"
            SYSTEM_DIR  "${SYSTEM_PATH}/${CMAKE_INSTALL_LIBDIR}/cmake/${APP_VENDOR}"
    )

    list(LENGTH candidates numCandidates)
    if(numCandidates EQUAL 0)
        msg(ALWAYS FATAL_ERROR "Core Library configuration file \"Core.cmake\" not found")
    elseif (numCandidates EQUAL 1)
        set(config_file "${candidates}")
    else ()
        list(GET candidates 0 config_file)
    endif ()

    registerLibrary(CORE HoffSoft Core "${config_file}")
    initCore()

endfunction()
