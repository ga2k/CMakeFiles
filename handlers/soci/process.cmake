function(soci_process incs libs defs)
    if(WIN32)
        find_library(SOCI REQUIRED
                NAMES "soci_core_4_2"
                PATHS "C:/Program Files/Git/usr/local/lib")
        find_library(SOCI_SQLite3 REQUIRED
                NAMES "soci_sqlite3_4_2"
                PATHS "C:/Program Files/Git/usr/local/lib")
        list(APPEND libs  SOCI SOCI_SQLite3)
        list(APPEND incs "C:/Program Files/Git/usr/local/include")
        set (_LibrariesList    ${libs} PARENT_SCOPE)
        set (_IncludePathsList ${incs} PARENT_SCOPE)
    else ()
        message(FATAL_ERROR "SOCI for Linux/macOS should not use \"process\"")
    endif ()
endfunction()

if (DATABASE IN_LIST APP_FEATURES)
    soci_process(_IncludePathsList _LibrariesList _DefinesList)
endif ()
set(HANDLED ON)

