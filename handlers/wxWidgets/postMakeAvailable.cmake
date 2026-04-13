function(_collect_targets_recursive dir out)

    msg("function(_collect_targets_recursive dir=${dir} out=${out}")

    if(NOT EXISTS "${dir}")
        msg("dir does not exist")
        set(${out} "" PARENT_SCOPE)
        return()
    endif ()
    msg("dir exists")

    # get_property DIRECTORY only works for directories that CMake processed via
    # add_subdirectory() in this configure run. When the binary dir is outside
    # CMAKE_BINARY_DIR (e.g. an archive/cache dir), CMake registers the scope
    # under the SOURCE dir, not the binary dir. Always use the source dir so
    # that get_property DIRECTORY reliably finds the scope.
    #
    # Also guard for the "already found" / stale-cached path where
    # FetchContent_MakeAvailable was never called and no add_subdirectory ran.
    FetchContent_GetProperties(wxWidgets)
    if(NOT wxWidgets_POPULATED)
        msg("wxWidgets not populated in this run — skipping build-tree scan")
        set(${out} "" PARENT_SCOPE)
        return()
    endif()

    # Cross-check: even if POPULATED is cached from a prior run, verify that
    # non-IMPORTED (build-tree) wx targets exist before querying directory scopes.
    set(_has_wx_build_targets OFF)
    foreach(_wx_candidate IN ITEMS wx_core wx_base wxcore wxbase)
        if(TARGET "${_wx_candidate}")
            get_target_property(_wx_imported "${_wx_candidate}" IMPORTED)
            if(NOT _wx_imported)
                set(_has_wx_build_targets ON)
                break()
            endif()
        endif()
    endforeach()
    unset(_wx_candidate)
    unset(_wx_imported)
    if(NOT _has_wx_build_targets)
        msg("No non-IMPORTED wx build targets — add_subdirectory not run this session, skipping scan")
        set(${out} "" PARENT_SCOPE)
        return()
    endif()
    unset(_has_wx_build_targets)

    # Use the SOURCE dir (not binary dir) for get_property DIRECTORY — cmake
    # registers external add_subdirectory scopes by source path, not binary path.
    if(wxWidgets_SOURCE_DIR AND EXISTS "${wxWidgets_SOURCE_DIR}")
        set(_scan_dir "${wxWidgets_SOURCE_DIR}")
    else()
        set(_scan_dir "${dir}")
    endif()

    get_property(tgts DIRECTORY "${_scan_dir}" PROPERTY BUILDSYSTEM_TARGETS)
    set(all "${tgts}")
    get_property(subs DIRECTORY "${_scan_dir}" PROPERTY SUBDIRECTORIES)
    foreach(sd IN LISTS subs)
        _collect_targets_recursive("${sd}" sub_tgts)
        list(APPEND all ${sub_tgts})
    endforeach()
    list(REMOVE_DUPLICATES all)
    set(${out} "${all}" PARENT_SCOPE)
endfunction()

function(wxWidgets_postMakeAvailable sourceDir buildDir outDir buildType)
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)

    msg("function(wxWidgets_postMakeAvailable sourceDir=${sourceDir} buildDir=${buildDir} outDir=${outDir} buildType=${buildType})")

    # When building from source, prevent the sysroot find_package(wxWidgets) result
    # (set during fetchContents PASS 0) from causing PASS 1 to skip FetchContent_MakeAvailable.
    if(BUILD_WX_FROM_SOURCE)
        set(wxWidgets_FOUND FALSE PARENT_SCOPE)
    endif()

    if(NOT sourceDir STREQUAL "${ARCHIVE_DIR}/wxWidgets/source")
        msg(FATAL_ERROR ALWAYS "sourceDir ${sourceDir} is not ${ARCHIVE_DIR}/wxWidgets/source")
    endif ()

    # Generate Wayland protocol headers/sources from XML on Linux
    if (LINUX)
        find_program(WAYLAND_SCANNER wayland-scanner REQUIRED)
        set(_wx_protocols_xml_dir "${sourceDir}/src/unix/protocols")
        set(_wx_protocols_out_dir "${sourceDir}/include/wx/protocols")
        file(MAKE_DIRECTORY "${_wx_protocols_out_dir}")
        file(GLOB _wx_protocol_xmls "${_wx_protocols_xml_dir}/*.xml")
        string(REPLACE ";" "\n" _wxes "${_wx_protocol_xmls}")
        log(LIST _wxes)
        foreach(_xml IN LISTS _wx_protocol_xmls)
            get_filename_component(_proto_name "${_xml}" NAME_WE)
            set(_header "${_wx_protocols_out_dir}/${_proto_name}-client-protocol.h")
            set(_source "${_wx_protocols_out_dir}/${_proto_name}-client-protocol.c")
            if (NOT EXISTS "${_header}")
                msg("Generating ${_header}")
                execute_process(COMMAND "${WAYLAND_SCANNER}" client-header "${_xml}" "${_header}")
            else ()
                msg("Consuming ${_header}")
            endif ()
            if (NOT EXISTS "${_source}")
                msg("Generating ${_source}")
                execute_process(COMMAND "${WAYLAND_SCANNER}" private-code "${_xml}" "${_source}")
            elseif ()
                msg("Consuming ${_source}")
            endif ()
        endforeach ()
    endif ()
    _collect_targets_recursive("${buildDir}" _wx_targets)

    set(_secondTime OFF)
    set(_triggered "BANG!")
    set(local_includes "${ARCHIVE_DIR}/wxWidgets/source/include")

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
