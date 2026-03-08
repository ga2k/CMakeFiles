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
msg("WTF IS GOING ON")
        get_target_property(type "${t}" TYPE)
        if(type STREQUAL "INTERFACE_LIBRARY" OR type STREQUAL "SHARED_LIBRARY")
            msg("get_target_property(_raw_includes \"${t}\" INTERFACE_INCLUDE_DIRECTORIES)")
            get_target_property(_raw_includes "${t}" INTERFACE_INCLUDE_DIRECTORIES)
            if (NOT _raw_includes)
                msg(ALWAYS "\"${t}\": No INTERFACE_INCLUDE_DIRECTORIES for \"${t}\" yet.")
                set(_wx_incs "${sourceDir}/include/wx" "${EXTERNALS_DIR}/include/wx")
#
                file(GLOB_RECURSE _wx_setup_incs  LIST_DIRECTORIES true ${_wx_incs})

                foreach(inc IN LISTS _wx_setup_incs) # _wx_setup_incs)
                    if(IS_DIRECTORY "${inc}")
                        if (inc MATCHES ".*wx$")
                            get_filename_component(inc "${inc}" PATH)
                            if (NOT inc MATCHES ".*msvc$")
                                list(APPEND local_includes "$<BUILD_INTERFACE:${inc}>")
                            endif ()
                        endif ()
                    endif ()
                endforeach ()
                list(REMOVE_DUPLICATES local_includes)

                msg(ALWAYS "\"${t}\": Setting it to \"${local_includes}\"")
                list(APPEND _wxIncludePaths "${local_includes}")
                set(_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)
                set_property(TARGET "${t}" APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${local_includes}")
            else ()
                msg("TARGET ${t} has ${_raw_includes}")
                set(BranNeuDae "")
                foreach(thing IN LISTS _raw_includes)
                    if(thing MATCHES "^\\$<BUILD_INTERFACE.*unicode.*")
                        msg("Ditching ${thing}")
                    else ()
                        list(APPEND BranNeuDae "${thing}")
                    endif ()
                endforeach ()
                set_property(TARGET "${t}" PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${BranNeuDae}")
            endif ()
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
    endforeach()












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
