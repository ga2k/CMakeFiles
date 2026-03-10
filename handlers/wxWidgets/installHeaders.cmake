# cmake_language(CALL "${fn}" "${pkg}" "${CMAKE_INSTALL_INCLUDEDIR}" "${EXTERNALS_DIR}" "${BUILD_DIR}")

function(wxWidgets_installHeaders targetName installIncludeDir sourceDir buildDir)

    # Look in the source directory where FetchContent downloaded them
    if (EXISTS "${sourceDir}/include")
        SplitAt("${wxVERSION}" "." vMajor vMinorAndPatch)
        SplitAt("${vMinorAndPatch}" "." vMinor vPatch)

        install(DIRECTORY "${sourceDir}/include/"
                DESTINATION "${installIncludeDir}/wx-${vMajor}.${vMinor}"
                COMPONENT Development)
    endif ()

    # Make sure we grab the platform specific setup.h
    file(GLOB WX_SETUP_H DIRECTORIES false RELATIVE "${buildDir}/lib" "${buildDir}/lib/wx/include/*/wx/setup.h")
    if (WX_SETUP_H)
        get_filename_component(WX_SETUP_DIR "${WX_SETUP_H}"   PATH)
        get_filename_component(WX_SETUP_DIR "${WX_SETUP_DIR}" PATH)
        install(DIRECTORY "${buildDir}/lib/${WX_SETUP_DIR}"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                COMPONENT Staging)
        # /home/geoffrey/dev/stage/usr/local/lib64/wx/include/qt-unicode-3.3/wx/setup.h  << Realsies
        # /home/geoffrey/dev/stage/usr/local/include/wx-3.3
        # /home/geoffrey/dev/stage/usr/local/lib64/wx/include/qt-unicode-3.3"
        #                                          wx/include/qt-unicode-3.3/wx/setup.h
    endif ()

    set(HANDLED ON PARENT_SCOPE)
endfunction()
