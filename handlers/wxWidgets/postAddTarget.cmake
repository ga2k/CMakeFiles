function (wxWidgets_postAddTarget _target)

    # This handler is called for each wxWidgets target (like wx::core, wx::base, etc.)
    # during the addTargetProperties call in fetchContents.cmake.
    # It helps clean up unwanted dependencies that cause installation export errors.

#    get_target_property(link_libs ${_target} INTERFACE_LINK_LIBRARIES)
#    if (link_libs)
#        list (APPEND componentsBeGone wxregex wxzlib wxexpat wxjpeg wxpng wxtiff wxscintilla wxlexcilla)
#        set(new_link_libs ${link_libs})
#        foreach (thisComponent IN LISTS componentsBeGone)
#            list(REMOVE_ITEM new_link_libs ${thisComponent})
#            list(REMOVE_ITEM new_link_libs wx::${thisComponent})
#        endforeach ()
#        if (NOT "${new_link_libs}" STREQUAL "${link_libs}")
#            message(STATUS "wxWidgets: Stripping ${componentsBeGone} dependencies from ${_target}")
#            set_target_properties(${_target} PROPERTIES INTERFACE_LINK_LIBRARIES "${new_link_libs}")
#        endif()
#    endif()
#
#    # This handler is called by addTargetProperties for every target created/found for the package
#    if (WIN32)
#
#        # If the current target is one of these, remove it from the dependencies list
#        # so it doesn't trigger "not in export set" errors during installation.
#        foreach(_internal IN LISTS componentsBeGone)
#            if ("${_target}" MATCHES "${_internal}")
#                message(STATUS "wxWidgets: Filtering internal target '${_target}' from export set")
#                list(REMOVE_ITEM _DependenciesList ${_target})
#                set(_DependenciesList ${_DependenciesList} PARENT_SCOPE)
#                break()
#            endif()
#        endforeach()
#    endif()
endfunction()
