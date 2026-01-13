# This handler is called for each wxWidgets target (like wx::core, wx::base, etc.)
# during the addTarget call in fetchContents.cmake.
# It helps clean up unwanted dependencies that cause installation export errors.

get_target_property(link_libs ${target} INTERFACE_LINK_LIBRARIES)
if (link_libs)
    set(new_link_libs ${link_libs})
    list(REMOVE_ITEM new_link_libs wxscintilla wxlexilla)
    
    # Also handle namespaced versions if they exist
    list(REMOVE_ITEM new_link_libs wx::wxscintilla wx::wxlexilla)
    
    if (NOT "${new_link_libs}" STREQUAL "${link_libs}")
        message(STATUS "wxWidgets: Stripping scintilla/lexilla dependencies from ${target}")
        set_target_properties(${target} PROPERTIES INTERFACE_LINK_LIBRARIES "${new_link_libs}")
    endif()
endif()

# This handler is called by addTarget for every target created/found for the package
if (WIN32)
    # List of internal wxWidgets targets that should not be exported
    set(_wx_internal_targets
            wxregex wxzlib wxexpat wxjpeg wxpng wxtiff
            wxscintilla wxlexilla
    )

    # If the current target is one of these, remove it from the dependencies list
    # so it doesn't trigger "not in export set" errors during installation.
    foreach(_internal IN LISTS _wx_internal_targets)
        if ("${target}" MATCHES "${_internal}")
            message(STATUS "wxWidgets: Filtering internal target '${target}' from export set")
            list(REMOVE_ITEM _DependenciesList ${target})
            set(_DependenciesList ${_DependenciesList} PARENT_SCOPE)
            break()
        endif()
    endforeach()
endif()