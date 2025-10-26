# cmake/parse_yaml.cmake

function(parse_yaml_file YAML_FILE PREFIX)
    if(NOT EXISTS ${YAML_FILE})
        message(FATAL_ERROR "YAML file not found: ${YAML_FILE}")
    endif()

    file(READ ${YAML_FILE} YAML_CONTENT)

    # Split into lines
    string(REPLACE "\n" ";" YAML_LINES "${YAML_CONTENT}")

    set(CURRENT_SECTION "")
    set(CURRENT_SUBSECTION "")
    set(IN_ARRAY FALSE)
    set(ARRAY_NAME "")
    set(ARRAY_VALUES "")

    foreach(LINE IN LISTS YAML_LINES)
        # Skip comments and empty lines
        string(REGEX MATCH "^[ ]*#" IS_COMMENT "${LINE}")
        string(STRIP "${LINE}" STRIPPED_LINE)
        if(IS_COMMENT OR "${STRIPPED_LINE}" STREQUAL "")
            continue()
        endif()

        # Check indentation level
        string(REGEX MATCH "^( *)" INDENT "${LINE}")
        string(LENGTH "${CMAKE_MATCH_1}" INDENT_LEVEL)

        # Top level sections (0 indent)
        if(INDENT_LEVEL EQUAL 0)
            string(REGEX MATCH "^([^:]+):" SECTION_MATCH "${STRIPPED_LINE}")
            if(SECTION_MATCH)
                set(CURRENT_SECTION "${CMAKE_MATCH_1}")
                set(CURRENT_SUBSECTION "")
                set(IN_ARRAY FALSE)
            endif()
            # Second level (2 spaces)
        elseif(INDENT_LEVEL EQUAL 2)
            # Array item
            string(REGEX MATCH "^- (.+)" ARRAY_ITEM "${STRIPPED_LINE}")
            if(ARRAY_ITEM)
                if(IN_ARRAY)
                    list(APPEND ARRAY_VALUES "${CMAKE_MATCH_1}")
                else()
                    message(WARNING "Array item without array context: ${LINE}")
                endif()
            else()
                # Key-value pair
                string(REGEX MATCH "^([^:]+): *\"?([^\"]*)\"?" KV_MATCH "${STRIPPED_LINE}")
                if(KV_MATCH)
                    set(KEY "${CMAKE_MATCH_1}")
                    set(VALUE "${CMAKE_MATCH_2}")

                    # Check if this starts an array
                    if("${VALUE}" STREQUAL "")
                        set(IN_ARRAY TRUE)
                        set(ARRAY_NAME "${KEY}")
                        set(ARRAY_VALUES "")
                    else()
                        set(IN_ARRAY FALSE)
                        # Set the variable
                        string(TOUPPER "${CURRENT_SECTION}_${KEY}" VAR_NAME)
                        set(${PREFIX}_${VAR_NAME} "${VALUE}" PARENT_SCOPE)
                        message(STATUS "Set ${PREFIX}_${VAR_NAME} = ${VALUE}")
                    endif()
                endif()
            endif()
        endif()

        # If we were building an array and now we're not, finalize it
        if(IN_ARRAY AND NOT ARRAY_ITEM AND NOT "${STRIPPED_LINE}" STREQUAL "")
            if(ARRAY_VALUES)
                string(TOUPPER "${CURRENT_SECTION}_${ARRAY_NAME}" VAR_NAME)
                set(${PREFIX}_${VAR_NAME} "${ARRAY_VALUES}" PARENT_SCOPE)
                message(STATUS "Set ${PREFIX}_${VAR_NAME} = ${ARRAY_VALUES}")
            endif()
            set(IN_ARRAY FALSE)
        endif()
    endforeach()

    # Handle final array if file ends with one
    if(IN_ARRAY AND ARRAY_VALUES)
        string(TOUPPER "${CURRENT_SECTION}_${ARRAY_NAME}" VAR_NAME)
        set(${PREFIX}_${VAR_NAME} "${ARRAY_VALUES}" PARENT_SCOPE)
        message(STATUS "Set ${PREFIX}_${VAR_NAME} = ${ARRAY_VALUES}")
    endif()
endfunction()
