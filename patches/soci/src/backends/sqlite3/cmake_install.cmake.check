# Install script for directory: C:/Users/geoff/dev/projects/MCA/HoffSoft/external/debug/shared/soci/src/backends/sqlite3

# Set the install prefix
if(NOT DEFINED CMAKE_INSTALL_PREFIX)
    set(CMAKE_INSTALL_PREFIX "C:/Users/geoff/AppData/Roaming/HoffSoft")
endif()
string(REGEX REPLACE "/$" "" CMAKE_INSTALL_PREFIX "${CMAKE_INSTALL_PREFIX}")

# Set the install configuration name.
if(NOT DEFINED CMAKE_INSTALL_CONFIG_NAME)
    if(BUILD_TYPE)
        string(REGEX REPLACE "^[^A-Za-z0-9_]+" ""
                CMAKE_INSTALL_CONFIG_NAME "${BUILD_TYPE}")
    else()
        set(CMAKE_INSTALL_CONFIG_NAME "Debug")
    endif()
    message(STATUS "Install configuration: \"${CMAKE_INSTALL_CONFIG_NAME}\"")
endif()

# Set the component getting installed.
if(NOT CMAKE_INSTALL_COMPONENT)
    if(COMPONENT)
        message(STATUS "Install component: \"${COMPONENT}\"")
        set(CMAKE_INSTALL_COMPONENT "${COMPONENT}")
    else()
        set(CMAKE_INSTALL_COMPONENT)
    endif()
endif()

# Is this installation the result of a crosscompile?
if(NOT DEFINED CMAKE_CROSSCOMPILING)
    set(CMAKE_CROSSCOMPILING "TRUE")
endif()

# Set path to fallback-tool for dependency-resolution.
if(NOT DEFINED CMAKE_OBJDUMP)
    set(CMAKE_OBJDUMP "C:/Program Files/LLVM/bin/llvm-objdump.exe")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "soci_development" OR NOT CMAKE_INSTALL_COMPONENT)
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib" TYPE STATIC_LIBRARY OPTIONAL FILES "C:/Users/geoff/dev/projects/MCA/HoffSoft/out/debug/shared/lib/soci_sqlite3_4_2.lib")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "soci_runtime" OR NOT CMAKE_INSTALL_COMPONENT)
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/bin" TYPE SHARED_LIBRARY FILES "C:/Users/geoff/dev/projects/MCA/HoffSoft/out/debug/shared/bin/soci_sqlite3_4_2.dll")
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/soci_sqlite3_4_2.dll" AND
            NOT IS_SYMLINK "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/soci_sqlite3_4_2.dll")
        if(CMAKE_INSTALL_DO_STRIP)
            execute_process(COMMAND "C:/Program Files/LLVM/bin/llvm-strip.exe" "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/bin/soci_sqlite3_4_2.dll")
        endif()
    endif()
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "soci_development" OR NOT CMAKE_INSTALL_COMPONENT)
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/include/soci/sqlite3" TYPE FILE FILES "C:/Users/geoff/dev/projects/MCA/HoffSoft/external/debug/shared/soci/include/soci/sqlite3/soci-sqlite3.h")
endif()

if(CMAKE_INSTALL_COMPONENT STREQUAL "soci_development" OR NOT CMAKE_INSTALL_COMPONENT)
    if(EXISTS "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/soci-4.2.0/SOCISQLite3Targets.cmake")
        file(DIFFERENT _cmake_export_file_changed FILES
                "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/soci-4.2.0/SOCISQLite3Targets.cmake"
                "C:/Users/geoff/dev/projects/MCA/HoffSoft/build/debug/shared/_deps/soci-build/src/backends/sqlite3/CMakeFiles/Export/478b6f299e0ecaefcb94bd2a9d73eb09/SOCISQLite3Targets.cmake")
        if(_cmake_export_file_changed)
            file(GLOB _cmake_old_config_files "$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/soci-4.2.0/SOCISQLite3Targets-*.cmake")
            if(_cmake_old_config_files)
                string(REPLACE ";" ", " _cmake_old_config_files_text "${_cmake_old_config_files}")
                message(STATUS "Old export file \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/lib/cmake/soci-4.2.0/SOCISQLite3Targets.cmake\" will be replaced.  Removing files [${_cmake_old_config_files_text}].")
                unset(_cmake_old_config_files_text)
                file(REMOVE ${_cmake_old_config_files})
            endif()
            unset(_cmake_old_config_files)
        endif()
        unset(_cmake_export_file_changed)
    endif()
    file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/soci-4.2.0" TYPE FILE FILES "C:/Users/geoff/dev/projects/MCA/HoffSoft/build/debug/shared/_deps/soci-build/src/backends/sqlite3/CMakeFiles/Export/478b6f299e0ecaefcb94bd2a9d73eb09/SOCISQLite3Targets.cmake")
    if(CMAKE_INSTALL_CONFIG_NAME MATCHES "^([Dd][Ee][Bb][Uu][Gg])$")
        file(INSTALL DESTINATION "${CMAKE_INSTALL_PREFIX}/lib/cmake/soci-4.2.0" TYPE FILE FILES "C:/Users/geoff/dev/projects/MCA/HoffSoft/build/debug/shared/_deps/soci-build/src/backends/sqlite3/CMakeFiles/Export/478b6f299e0ecaefcb94bd2a9d73eb09/SOCISQLite3Targets-debug.cmake")
    endif()
endif()

string(REPLACE ";" "\n" CMAKE_INSTALL_MANIFEST_CONTENT
        "${CMAKE_INSTALL_MANIFEST_FILES}")
if(CMAKE_INSTALL_LOCAL_ONLY)
    file(WRITE "C:/Users/geoff/dev/projects/MCA/HoffSoft/build/debug/shared/_deps/soci-build/src/backends/sqlite3/install_local_manifest.txt"
            "${CMAKE_INSTALL_MANIFEST_CONTENT}")
endif()
