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

copy_files_to_target_dir(
TARGET_DIR
    "${OUTPUT_DIR}/bin"
SOURCE_DIRS
    "${OUTPUT_DIR}/bin"
    "${OUTPUT_DIR}/bin/Plugins"
    "${OUTPUT_DIR}/lib"
    "${OUTPUT_DIR}/lib/Plugins"
    "${OUTPUT_DIR}/bin"
    "${BUILD_DIR}/bin"
    "${BUILD_DIR}/lib"
    "${EXTERNALS_DIR}/Boost/stage/lib"
FILE_PATTERNS
    "*.exe" "*.dll" "*.plugin" "*.lib" "${PLUGINS_SENTINAL}*"
)