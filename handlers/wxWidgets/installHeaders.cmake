# cmake_language(CALL "${fn}" "${pkg}" "${CMAKE_INSTALL_INCLUDEDIR}" "${EXTERNALS_DIR}" "${BUILD_DIR}")

function(wxmono_installHeaders targetName installIncludeDir sourceDir buildDir)
    wxWidgets_installHeaders("${targetName}" "${installIncludeDir}"
            "${ARCHIVE_DIR}/wxWidgets/source"
            "${ARCHIVE_DIR}/wxWidgets/build")
endfunction()

function(wxWidgets_installHeaders targetName installIncludeDir sourceDir buildDir)

    # Look in the source directory where FetchContent downloaded them
    if (EXISTS "${ARCHIVE_DIR}/wxWidgets/source/include")
        SplitAt("${wxVERSION}" "." vMajor vMinorAndPatch)
        SplitAt("${vMinorAndPatch}" "." vMinor vPatch)

        install(DIRECTORY "${ARCHIVE_DIR}/wxWidgets/source/include/"
                DESTINATION "${installIncludeDir}/wx-${vMajor}.${vMinor}"
                COMPONENT ${APP_NAME}Development)
    endif ()

    # Make sure we grab the platform specific setup.h
    file(GLOB WX_SETUP_H DIRECTORIES false RELATIVE "${buildDir}/lib" "${buildDir}/lib/wx/include/*/wx/setup.h")
    if (WX_SETUP_H)
        foreach (_setup_h IN LISTS WX_SETUP_H)
            get_filename_component(_setup_dir "${_setup_h}" PATH)
            get_filename_component(_setup_dir "${_setup_dir}" PATH)
            install(DIRECTORY "${buildDir}/lib/${_setup_dir}/"
                    DESTINATION "${CMAKE_INSTALL_LIBDIR}/${_setup_dir}"
                    COMPONENT ${APP_NAME}Development)
        endforeach ()
    endif ()

    set(HANDLED ON PARENT_SCOPE)
endfunction()
