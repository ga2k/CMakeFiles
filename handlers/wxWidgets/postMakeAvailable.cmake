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

    # Generate Wayland protocol headers/sources from XML on Linux
    if (LINUX)
        find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
        set(_wx_protocols_xml_dir "${sourceDir}/src/unix/protocols")
        set(_wx_protocols_out_dir "${sourceDir}/include/wx/protocols")
        file(MAKE_DIRECTORY "${_wx_protocols_out_dir}")
        file(GLOB _wx_protocol_xmls "${_wx_protocols_xml_dir}/*.xml")
        foreach(_xml IN LISTS _wx_protocol_xmls)
            get_filename_component(_proto_name "${_xml}" NAME_WE)
            set(_header "${_wx_protocols_out_dir}/${_proto_name}-client-protocol.h")
            set(_source "${_wx_protocols_out_dir}/${_proto_name}-client-protocol.c")
            if (NOT EXISTS "${_header}")
                execute_process(COMMAND "${WAYLAND_SCANNER}" client-header "${_xml}" "${_header}")
            endif ()
            if (NOT EXISTS "${_source}")
                execute_process(COMMAND "${WAYLAND_SCANNER}" private-code "${_xml}" "${_source}")
            endif ()
        endforeach ()
    endif ()
    _collect_targets_recursive("${buildDir}" _wx_targets)

    set(_secondTime OFF)
    set(_triggered "BANG!")
    set(local_includes "")

    foreach(t IN LISTS _wx_targets _triggered _wx_targets)

        if(t STREQUAL "BANG!")
            set(_secondTime ON)
            continue()
        endif ()

        get_target_property(type "${t}" TYPE)

        if (NOT _secondTime)

            get_target_property(_raw_includes "${t}" INTERFACE_INCLUDE_DIRECTORIES)

            if (_raw_includes)
                list(APPEND local_includes ${_raw_includes})
                list(REMOVE_DUPLICATES local_includes)
            endif ()

            if(NOT type STREQUAL "INTERFACE_LIBRARY" AND NOT type STREQUAL "UTILITY")
                target_compile_options("${t}" PRIVATE -w)
            endif()

            # Force wx shared libs to be relocatable within the stage/install tree.
            # This fixes cases like libwx_qtu depending on libwxwebp* in the same dir.
            if(type STREQUAL "SHARED_LIBRARY" OR type STREQUAL "MODULE_LIBRARY")

                if(UNIX AND NOT APPLE)
                    set_target_properties("${t}" PROPERTIES
                            INSTALL_RPATH "\$ORIGIN"
                            BUILD_RPATH   "\$ORIGIN"
                            INSTALL_RPATH_USE_LINK_PATH FALSE
                    )
                endif()
            endif()

        else ()

            list(APPEND _wxIncludePaths "${local_includes}")
            set(_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)
            set_property(TARGET "${t}" APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${local_includes}")

        endif ()
    endforeach ()

    wxWidgets_export_variables(wxWidgets)

    # @formatter:off
    set(_wxCompilerOptions  "${_wxCompilerOptions}" PARENT_SCOPE)
    set(_wxDefines          "${_wxDefines}"         PARENT_SCOPE)
    set(_wxLibraries        "${_wxLibraries}"       PARENT_SCOPE)
    set(_wxIncludePaths     "${_wxIncludePaths}"    PARENT_SCOPE)
    set(_DependenciesList   "${_DependenciesList}"  PARENT_SCOPE)

    set(HANDLED             ON                      PARENT_SCOPE)
    # @formatter:on
endfunction()
