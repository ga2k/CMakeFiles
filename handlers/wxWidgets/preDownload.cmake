function(wxWidgets_preDownload pkgname url tag srcDir)

    # Use a persistent local clone so wxWidgets survives `make clean`
    set(_wx_local_src "${ARCHIVE_DIR}/wxWidgets/source")
    if (EXISTS "${_wx_local_src}" AND NOT EXISTS "${_wx_local_src}/CMakeLists.txt")
        file(REMOVE_RECURSE "${_wx_local_src}")
    endif ()

    if (NOT EXISTS "${_wx_local_src}/CMakeLists.txt")

        message(STATUS "Cloning wxWidgets with submodules to ${_wx_local_src} (one-time)...")
        execute_process(
                COMMAND git clone --depth=1 --recurse-submodules https://github.com/wxWidgets/wxWidgets.git "${_wx_local_src}"
                RESULT_VARIABLE _wx_clone_result
        )
        if (NOT _wx_clone_result EQUAL 0)
            message(FATAL_ERROR "Failed to clone wxWidgets to ${_wx_local_src}")
        endif ()

    else ()

        message(STATUS "Using already downloaded copy of wxWidgets")

    endif ()

    unset(patches)
    list(APPEND patches
            "${pkgname}/include|${_wx_local_src}/include/wx/"
            "${pkgname}/src/common|${_wx_local_src}/src/common/"
#            "${pkgname}/src/osx/carbon|${_wx_local_src}/src/osx/carbon/"
#            "${pkgname}/src/qt|${_wx_local_src}/src/qt/"
#            "${pkgname}/src|${_wx_local_src}/src/"
    )
    replaceFile(${pkgname} "${patches}")
#
    set(FETCHCONTENT_SOURCE_DIR_WXWIDGETS "${_wx_local_src}" CACHE PATH "Pre-cloned wxWidgets source" FORCE)
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)

    wxWidgets_set_build_options()

    # Prevent the find_package(wxWidgets QUIET) probe in fetchContents PASS 0 from
    # finding the sysroot/system wx installation and marking wx as already satisfied.
    # Without this, PASS 1 skips FetchContent_MakeAvailable and wx is never built from source.
    set(CMAKE_DISABLE_FIND_PACKAGE_wxWidgets TRUE PARENT_SCOPE)

    set(HANDLED OFF)
    set(HANDLED OFF PARENT_SCOPE)
endfunction()
