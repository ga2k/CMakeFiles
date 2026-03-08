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
        if(type STREQUAL "INTERFACE_LIBRARY" OR type STREQUAL "SHARED_LIBRARY")
            msg("get_target_property(_raw_includes \"${t}\" INTERFACE_INCLUDE_DIRECTORIES)")
            get_target_property(_raw_includes "${t}" INTERFACE_INCLUDE_DIRECTORIES)
            if (NOT _raw_includes)
                set (local_incloodes "$<BUILD_INTERFACE:/home/geoffrey/dev/projects/MCA/Gfx/build/debug/shared/_deps/wxwidgets-build/lib/wx/include/qt-unicode-3.3>;$<BUILD_INTERFACE:/home/geoffrey/dev/projects/MCA/Gfx/external/debug/shared/wxWidgets/include>;$<INSTALL_INTERFACE:lib64/wx/include/qt-unicode-3.3>;$<INSTALL_INTERFACE:include/wx-3.3>")
                msg(ALWAYS "\"${t}\": No INTERFACE_INCLUDE_DIRECTORIES for \"${t}\" yet.")
                set(_wx_incs "${sourceDir}/include/wx" "${EXTERNALS_DIR}/include/wx")
                set(_wx_setup_inc "${buildDir}/lib/wx/include")

                file(GLOB_RECURSE _wx_setup_incs  RELATIVE ${buildDir}/lib LIST_DIRECTORIES false "${_wx_setup_inc}/**/setup.h")

                foreach(inc IN LISTS _wx_incs _wx_setup_incs)
                    if(IS_DIRECTORY "${inc}")
                        if (inc MATCHES ".*wx$")
                            get_filename_component(inc "${inc}" PATH)
                            list(APPEND local_includes "$<BUILD_INTERFACE:${inc}>")
                        endif ()
                    elseif (inc MATCHES ".*setup.h$")
                        get_filename_component(inc "${inc}" PATH)
                        get_filename_component(inc "${inc}" PATH)
                        list(APPEND local_includes "$<INSTALL_INTERFACE:${CMAKE_INSTALL_LIBDIR}/${inc}>" "$<BUILD_INTERFACE:${EXTERNALS_DIR}/include/${inc}>")
                    endif ()
                endforeach ()
                list(REMOVE_DUPLICATES local_includes)

                msg(ALWAYS ""${t}": Setting it to \"${local_includes}\"")
                list(APPEND _wxIncludePaths "${local_includes}")
                set(_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)
                set_property(TARGET "${t}" APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${local_includes}")
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
