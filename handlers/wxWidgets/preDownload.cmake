function (wxWidgets_preDownload pkgname url tag srcDir)

    # Use a persistent local clone so wxWidgets survives `make clean`
    set(_wx_local_src "$ENV{HOME}/dev/archives/wxWidgets-src")

    if (NOT EXISTS "${_wx_local_src}/CMakeLists.txt")
        message(STATUS "Cloning wxWidgets with submodules to ${_wx_local_src} (one-time)...")
        execute_process(
                COMMAND git clone --recurse-submodules https://github.com/wxWidgets/wxWidgets.git "${_wx_local_src}"
                RESULT_VARIABLE _wx_clone_result
        )
        if (NOT _wx_clone_result EQUAL 0)
            message(FATAL_ERROR "Failed to clone wxWidgets to ${_wx_local_src}")
        endif ()
    endif ()

    set(FETCHCONTENT_SOURCE_DIR_WXWIDGETS "${_wx_local_src}" CACHE PATH "Pre-cloned wxWidgets source" FORCE)
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)

    wxWidgets_set_build_options()
    set(HANDLED OFF PARENT_SCOPE)
endfunction()
