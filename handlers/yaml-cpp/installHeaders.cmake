function(yaml-cpp_installHeaders targetName installIncludeDir sourceDir buildDir)
    if (EXISTS "${sourceDir}/include")
        install(DIRECTORY "${sourceDir}/include/"
                DESTINATION "${installIncludeDir}/${APP_VENDOR}"
                COMPONENT ${APP_NAME}Development)
    endif ()
    set(HANDLED ON PARENT_SCOPE)
endfunction()
