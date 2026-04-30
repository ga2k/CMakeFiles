function(cpptrace_postMakeAvailable sourceDir buildDir outDir buildType)
    if (TARGET cpptrace-lib)
        set_property(TARGET cpptrace-lib PROPERTY INTERFACE_INCLUDE_DIRECTORIES
            "$<BUILD_INTERFACE:${sourceDir}/include>"
            "$<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}>"
        )
    endif ()
    set(HANDLED ON PARENT_SCOPE)
endfunction()
