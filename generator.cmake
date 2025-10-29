
find_package(Python3 REQUIRED COMPONENTS Interpreter)

function(generateUIClasses OUT_DIR SOURCE_DIR)

    set (generator "yaml2ui.py")

    # 1) Configure-time generation so CMake can glob and add sources
    file(MAKE_DIRECTORY "${OUT_DIR}")
    execute_process(
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
            --quiet ${SHOW_SIZER_INFO_FLAG} --scan "${SOURCE_DIR}" --output "${OUT_DIR}" --app-target "${APP_NAME}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE CONFIGURE_RESULT
            ERROR_VARIABLE OOPSIE
    )
    if (NOT CONFIGURE_RESULT EQUAL 0)
        message(FATAL_ERROR "${generator} batch generation failed at configure time : ${OOPSIE}")
    endif ()

    # 2) Build-time regeneration whenever YAML specs or the generator change
    #    We use a 'stamp' file as the known OUTPUT so Ninja/Make can track the rule.
    file(GLOB_RECURSE UI_DEPENDENCIES
            CONFIGURE_DEPENDS
            "${SOURCE_DIR}/*.yaml"
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
    )

    set(UI_CLASSES_STAMP "${OUT_DIR}/.generated.stamp")
    add_custom_command(
            OUTPUT "${UI_CLASSES_STAMP}"
            BYPRODUCTS ${UI_CLASS_FILES}
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUT_DIR}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
                    --quiet ${SHOW_SIZER_INFO_FLAG} --scan "${SOURCE_DIR}" --output "${OUT_DIR}" --app-target "${APP_NAME}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${UI_CLASSES_STAMP}"
            DEPENDS ${UI_DEPENDENCIES} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
            COMMENT "Generating ixx files from YAML specs (batch mode)"
            VERBATIM
    )

    # 3) Add generated RS.ixx to your target
    #    Do an initial glob after the configure-time generation.
    file(GLOB UI_CLASS_FILES
            LIST_DIRECTORIES false
            "${OUT_DIR}/*Group.ixx"
            "${OUT_DIR}/*Page.ixx"
    )

    add_custom_target(generate_ui ALL DEPENDS "${UI_CLASSES_STAMP}")

    # Ensure your target waits for the generation step
    add_dependencies(main generate_ui)

    # Add generated sources
    target_sources(main
            PUBLIC FILE_SET CXX_MODULES
            FILES ${UI_CLASS_FILES}
    )

    target_include_directories(main PRIVATE "${OUT_DIR}")

endfunction()

function(generateRecordsets OUT_DIR SOURCE_DIR)

    set (generator "yaml2rs.py")

    # 1) Configure-time generation so CMake can glob and add sources
    file(MAKE_DIRECTORY "${OUT_DIR}")
    execute_process(
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
                    --quiet --scan "${SOURCE_DIR}" --output "${OUT_DIR}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE CONFIGURE_RESULT
            ERROR_VARIABLE OOPSIE
    )
    if (NOT CONFIGURE_RESULT EQUAL 0)
        message(FATAL_ERROR "${generator} batch generation failed at configure time : ${OOPSIE}")
    endif ()

    # 2) Build-time regeneration whenever YAML specs or the generator change
    #    We use a 'stamp' file as the known OUTPUT so Ninja/Make can track the rule.
    file(GLOB_RECURSE RS_DEPENDENCIES
            CONFIGURE_DEPENDS
            "${SOURCE_DIR}/*.yaml"
            "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
    )

    set(RS_CLASSES_STAMP "${OUT_DIR}/.generated.stamp")
    add_custom_command(
            OUTPUT "${RS_CLASSES_STAMP}"
            BYPRODUCTS ${RS_CLASS_FILES}
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUT_DIR}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
                    --quiet --scan "${SOURCE_DIR}" --output "${OUT_DIR}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${RS_CLASSES_STAMP}"
            DEPENDS ${RS_DEPENDENCIES} "${CMAKE_CURRENT_SOURCE_DIR}/cmake/${generator}"
            COMMENT "Generating RS.ixx files from YAML specs (batch mode)"
            VERBATIM
    )

    # 3) Add generated RS.ixx to your target
    #    Do an initial glob after the configure-time generation.
    file(GLOB_RECURSE RS_CLASS_FILES
            "${OUT_DIR}/*RS.ixx"
    )

    add_custom_target(generate_rs ALL DEPENDS "${RS_CLASSES_STAMP}")

    # Ensure your target waits for the generation step
    add_dependencies(main generate_rs)

    # Add generated sources
    target_sources(main
            PUBLIC FILE_SET CXX_MODULES
            FILES ${RS_CLASS_FILES}
    )
endfunction()
