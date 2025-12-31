function(soci_process incs libs defs)
    find_package(soci CONFIG REQUIRED)

    list(APPEND _LibrariesList SOCI::SOCI)
    set (_LibrariesList ${_LibrariesList} PARENT_SCOPE)
endfunction()

if (DATABASE IN_LIST APP_FEATURES)
    soci_process(_IncludePathsList _LibrariesList _DefinesList)
endif ()
set(HANDLED ON)

