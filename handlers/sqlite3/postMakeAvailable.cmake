# Ensure SQLite3 is built as a static library
set(HANDLED ON)
add_library(sqlite3 STATIC ${sqlite3_SOURCE_DIR}/sqlite3.c)
target_include_directories(sqlite3 PUBLIC ${sqlite3_SOURCE_DIR})
#set_target_properties(sqlite3 PROPERTIES
#    OUTPUT_NAME "sqlite3"
#    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_SYSROOT}/lib
#    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_SYSROOT}/bin
#)
#install(TARGETS sqlite3 ARCHIVE DESTINATION ${CMAKE_SYSROOT}/lib LIBRARY DESTINATION ${CMAKE_SYSROOT}/bin)
#install(FILES ${sqlite3_SOURCE_DIR}/sqlite3.h ${sqlite3_SOURCE_DIR}/sqlite3ext.h DESTINATION ${CMAKE_SYSROOT}/include)
list(APPEND _LibrariesList sqlite3)
list(APPEND _IncludePathsList ${sqlite3_SOURCE_DIR})

