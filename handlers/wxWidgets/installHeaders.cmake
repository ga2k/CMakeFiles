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
        get_filename_component(WX_SETUP_DIR "${WX_SETUP_H}"   PATH)
        get_filename_component(WX_SETUP_DIR "${WX_SETUP_DIR}" PATH)
        install(DIRECTORY "${buildDir}/lib/${WX_SETUP_DIR}/"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}/${WX_SETUP_DIR}"
                COMPONENT ${APP_NAME}Development)
        # /home/geoffrey/dev/stage/usr/local/lib64/wx/include/qt-unicode-3.3/wx/setup.h  << Realsies
        # /home/geoffrey/dev/stage/usr/local/include/wx-3.3
        # /home/geoffrey/dev/stage/usr/local/lib64/wx/include/qt-unicode-3.3"
        #                                          wx/include/qt-unicode-3.3/wx/setup.h
    endif ()

set(HANDLED ON PARENT_SCOPE)
endfunction()
