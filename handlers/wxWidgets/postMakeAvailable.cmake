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
    msg("\nCMAKE_CURRENT_FUNCTION_LIST_DIR=${CMAKE_CURRENT_FUNCTION_LIST_DIR},\nsourceDir=${sourceDir},\nbuildDir=${buildDir},\noutDir=${outDir},buildType=${buildType}\n")
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)
    _collect_targets_recursive("${buildDir}" _wx_targets)
    message(STATUS "wx targets: ${_wx_targets}")

    set(_secondTime OFF)
    set(_triggered "BANG!")
    set(local_includes "")

    foreach(t IN LISTS _wx_targets _triggered _wx_targets)

        if(t STREQUAL "BANG!")
            set(_secondTime ON)
            continue()
        endif ()

        get_target_property(type "${t}" TYPE)
        msg("${t}")

        if (NOT _secondTime)

            get_target_property(_raw_includes "${t}" INTERFACE_INCLUDE_DIRECTORIES)

            if (_raw_includes)
                msg("Grabbing \"${_raw_includes}\" from ${t}")
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

            msg(ALWAYS "\"${t}\": Setting INTERFACE_INCLUDE_DIRECTORIES to \"${local_includes}\"")
            list(APPEND _wxIncludePaths "${local_includes}")
            set(_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)
            set_property(TARGET "${t}" APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${local_includes}")

        endif ()
    endforeach ()
##
##
##
##                if(type STREQUAL "INTERFACE_LIBRARY" OR type STREQUAL "SHARED_LIBRARY")
##                    set(_wx_incs "${sourceDir}/include/wx")
##                    file(GLOB_RECURSE _wx_setup_incs  LIST_DIRECTORIES true "${_wx_incs}")
##                    foreach(inc IN LISTS _wx_setup_incs) # _wx_setup_incs)
##                        if(IS_DIRECTORY "${inc}")
##                            if (inc MATCHES ".*wx$")
##                                get_filename_component(inc "${inc}" PATH)
##                                if((NOT WIN32 AND NOT inc MATCHES ".*msvc$") AND NOT inc MATCHES ".*_deps.*")
##                                    list(APPEND local_includes "$<BUILD_INTERFACE:${inc}>")
##                                endif ()
##                            endif ()
##                        endif ()
##                    endforeach ()
##                    list(REMOVE_DUPLICATES local_includes)
##                    msg(ALWAYS "\"${t}\": Setting INTERFACE_INCLUDE_DIRECTORIES to \"${local_includes}\"")
##                    list(APPEND _wxIncludePaths "${local_includes}")
##                    set(_wxIncludePaths "${_wxIncludePaths}" PARENT_SCOPE)
##                    set_property(TARGET "${t}" APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${local_includes}")
##                endif ()
##            else ()
##                set(BranNeuDae "")
##                foreach(thing IN LISTS _raw_includes)
##                    msg("${thing} from ${t}")
##                    if(thing MATCHES "/wx-[0-9]+\\.[0-9]+")
##                        msg("removing ${thing} from ${t}")
##                    else ()
##                        list(APPEND BranNeuDae "${thing}")
##                    endif ()
##                endforeach ()
##                set_property(TARGET "${t}" PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${BranNeuDae}")
##            endif ()
###        endif ()
##
##        if(_secondTime)
##            continue()
##        endif ()
#
#        if(NOT type STREQUAL "INTERFACE_LIBRARY" AND NOT type STREQUAL "UTILITY")
#            target_compile_options("${t}" PRIVATE -w)
#        endif()
#
#        # Force wx shared libs to be relocatable within the stage/install tree.
#        # This fixes cases like libwx_qtu depending on libwxwebp* in the same dir.
#        if(type STREQUAL "SHARED_LIBRARY" OR type STREQUAL "MODULE_LIBRARY")
#
#            if(UNIX AND NOT APPLE)
#                set_target_properties("${t}" PROPERTIES
#                        INSTALL_RPATH "\$ORIGIN"
#                        BUILD_RPATH   "\$ORIGIN"
#                        INSTALL_RPATH_USE_LINK_PATH FALSE
#                )
#            endif()
#        endif()
#    endforeach()

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
