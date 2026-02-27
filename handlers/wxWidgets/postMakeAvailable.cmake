function(_collect_targets_recursive dir out)
    if(NOT EXISTS "${dir}")
        set(${out} "" PARENT_SCOPE)
        return()
    endif ()
    get_property(tgts DIRECTORY "${dir}" PROPERTY BUILDSYSTEM_TARGETS)
    set(all "${tgts}")
    get_property(subs DIRECTORY "${dir}" PROPERTY SUBDIRECTORIES)
    foreach(sd IN LISTS subs)
        _collect_targets_recursive("${sd}" sub_tgts)
        list(APPEND all ${sub_tgts})
    endforeach()
    list(REMOVE_DUPLICATES all)
    set(${out} "${all}" PARENT_SCOPE)
endfunction()

function(wxWidgets_postMakeAvailable sourceDir buildDir outDir buildType)
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)
    _collect_targets_recursive("${buildDir}" _wx_targets)
    message(STATUS "wx targets: ${_wx_targets}")

    foreach(t IN LISTS _wx_targets)
        get_target_property(type "${t}" TYPE)
        if(NOT type STREQUAL "INTERFACE_LIBRARY" AND NOT type STREQUAL "UTILITY")
            target_compile_options("${t}" PRIVATE -w)
        endif()

        # Force wx shared libs to be relocatable within the stage/install tree.
        # This fixes cases like libwx_qtu depending on libwxwebp* in the same dir.
        if(UNIX AND NOT APPLE)
            if(type STREQUAL "SHARED_LIBRARY" OR type STREQUAL "MODULE_LIBRARY" OR type STREQUAL "INTERFACE_LIBRARY")
                set_target_properties("${t}" PROPERTIES
                        INSTALL_RPATH "\$ORIGIN"
                        BUILD_RPATH   "\$ORIGIN"
                        INSTALL_RPATH_USE_LINK_PATH FALSE
                )
            endif()
        endif()
    endforeach()

    wxWidgets_export_variables(wxWidgets)
    set (_wxLibraries    "${_wxLibraries}"    PARENT_SCOPE)
    set (_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)
    set(HANDLED ON PARENT_SCOPE)
endfunction()
