include(${CMAKE_CURRENT_LIST_DIR}/helpers.cmake)
wxWidgets_export_variables(${this_pkgname})

# Synchronize with the variables expected by fetchContents.cmake
set(_wxIncludePaths ${_wxIncludePaths} PARENT_SCOPE)
set(_wxLibraries    ${_wxLibraries}    PARENT_SCOPE)

set(HANDLED ON PARENT_SCOPE)
