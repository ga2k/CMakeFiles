function("cpptrace-lib_installHeaders" targetName installIncludeDir sourceDir buildDir)
    # 1. Determine the actual include directory
    if (EXISTS "${sourceDir}/include")
        set(include_dir "${sourceDir}/include")
    elseif (EXISTS "${EXTERNALS_DIR}/cpptrace/include")
        set(include_dir "${EXTERNALS_DIR}/cpptrace/include")
    endif ()

    # 2. Install it if found
    if (include_dir)
        install(DIRECTORY "${include_dir}/"
                DESTINATION "${installIncludeDir}/${APP_VENDOR}"
                COMPONENT Development)
        set(HANDLED ON PARENT_SCOPE)
    endif ()
endfunction()
