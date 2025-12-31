function(soci_process incs libs defs)
    find_package(soci CONFIG REQUIRED HINTS "C:/Program Files/Git/usr/local/lib/cmake/soci-4.2.0")
    include(${soci_CONFIG})

    list(APPEND _LibrariesList soci::SSL soci::Crypto)
    set (_LibrariesList ${_LibrariesList} PARENT_SCOPE)
    # @formatter:on
endfunction()

if (DATABASE IN_LIST APP_FEATURES)
    soci_process(_IncludePathsList _LibrariesList _DefinesList)
endif ()
set(HANDLED ON)

