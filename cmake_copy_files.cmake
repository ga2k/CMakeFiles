function(copy_files_to_target_dir)
    set(options)
    set(oneValueArgs TARGET_DIR)
    set(multiValueArgs SOURCE_DIRS FILE_PATTERNS)

    cmake_parse_arguments(CP "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGV})

    if(NOT CP_TARGET_DIR)
        message(FATAL_ERROR "TARGET_DIR is required!")
    endif()

    if(NOT CP_SOURCE_DIRS)
        message(FATAL_ERROR "At least one SOURCE_DIR is required!")
    endif()

    if(NOT CP_FILE_PATTERNS)
        message(FATAL_ERROR "At least one FILE_PATTERN is required!")
    endif()

    foreach(SOURCE_DIR IN LISTS CP_SOURCE_DIRS)
        foreach(PATTERN IN LISTS CP_FILE_PATTERNS)
            file(GLOB FILES "${SOURCE_DIR}/${PATTERN}")

            foreach(FILE IN LISTS FILES)
                get_filename_component(FILE_NAME ${FILE} NAME)
                message(STATUS "Copying ${FILE_NAME} from ${SOURCE_DIR} to ${CP_TARGET_DIR}")

                file(MAKE_DIRECTORY ${CP_TARGET_DIR})
                file(COPY ${FILE} DESTINATION ${CP_TARGET_DIR} FOLLOW_SYMLINK_CHAIN)
            endforeach()
        endforeach()
    endforeach()
endfunction()

