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
