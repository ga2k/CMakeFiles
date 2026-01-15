function(sqlite3_postMakeAvailable sourceDir buildDir outDir buildType components)

        # Ensure SQLite3 is built as a static library
    add_library(sqlite3 STATIC ${sqlite3_SOURCE_DIR}/sqlite3.c)
    target_include_directories(sqlite3 PUBLIC ${sqlite3_SOURCE_DIR})

    list(APPEND _LibrariesList sqlite3)
    list(APPEND _IncludePathsList ${sqlite3_SOURCE_DIR})

    set(_LibrariesList      "${_LibrariesList}"     PARENT_SCOPE)
    set(_IncludePathsList   "${_IncludePathsList}"  PARENT_SCOPE)
    set(HANDLED             ON                      PARENT_SCOPE)
endfunction()