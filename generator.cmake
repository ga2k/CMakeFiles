
find_package(Python3 REQUIRED COMPONENTS Interpreter)

function(generateUIClasses OUT_DIR SOURCE_DIR)

    set (generator "yaml2ui.py")

    # 1) Configure-time generation so CMake can glob and add sources
    file(MAKE_DIRECTORY "${OUT_DIR}")
    execute_process(
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/cmake/${generator}"
            --quiet ${SHOW_SIZER_INFO_FLAG} --scan "${SOURCE_DIR}" --output "${OUT_DIR}" --app-target "${APP_NAME}"
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            RESULT_VARIABLE GEN_UI_CLASSES_RESULT
    )
    if (NOT GEN_UI_CLASSES_RESULT EQUAL 0)
        message(FATAL_ERROR "${generator} batch generation failed at configure time")
    endif ()

    # 2) Build-time regeneration whenever YAML specs or the generator change
    #    We use a 'stamp' file as the known OUTPUT so Ninja/Make can track the rule.
    file(GLOB_RECURSE GENERATOR_UI_CLASSES_SPECS
            CONFIGURE_DEPENDS
            "${SOURCE_DIR}/*.yaml"
            "${CMAKE_SOURCE_DIR}/cmake/${generator}"
    )

    set(GENERATOR_UI_CLASSES_STAMP "${OUT_DIR}/.generated.stamp")
    add_custom_command(
            OUTPUT "${GENERATOR_UI_CLASSES_STAMP}"
            BYPRODUCTS ${GENERATED_UI_CLASSES_IXX}
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUT_DIR}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/cmake/${generator}"
                    --quiet ${SHOW_SIZER_INFO_FLAG} --scan "${SOURCE_DIR}" --output "${OUT_DIR}" --app-target "${APP_NAME}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${GENERATOR_UI_CLASSES_STAMP}"
            DEPENDS ${GENERATOR_UI_CLASSES_SPECS} "${CMAKE_SOURCE_DIR}/cmake/${generator}"
            COMMENT "Generating ixx files from YAML specs (batch mode)"
            VERBATIM
    )

    # 3) Add generated RS.ixx to your target
    #    Do an initial glob after the configure-time generation.
    file(GLOB GENERATED_UI_CLASSES_IXX
            LIST_DIRECTORIES false
            "${OUT_DIR}/*Group.ixx"
            "${OUT_DIR}/*Page.ixx"
    )

    add_custom_target(generate_UI_CLASSES_ixx ALL DEPENDS "${GENERATOR_UI_CLASSES_STAMP}")

    # Ensure your target waits for the generation step
    add_dependencies(${APP_NAME} generate_UI_CLASSES_ixx)

    # Add generated sources
    target_sources(${APP_NAME}
            PUBLIC FILE_SET CXX_MODULES
#            BASE_DIRS "${OUT_DIR}"
            FILES ${GENERATED_UI_CLASSES_IXX}
    )

    target_include_directories(${APP_NAME} PRIVATE "${OUT_DIR}")

endfunction()

function(generateRecordsets GEN_DIR YAML_DIR)
    # Where your YAML lives (source tree) and where to put generated RS.ixx (build tree)
    #    set(YAML_DIR "${CMAKE_SOURCE_DIR}/path/to/yaml")      # adjust
    #    set(GEN_DIR "${CMAKE_BINARY_DIR}/generated/rs")      # adjust if you prefer a different folder

    # 1) Configure-time generation so CMake can glob and add sources
    file(MAKE_DIRECTORY "${GEN_DIR}")
    execute_process(
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/cmake/yaml2rs.py"
                    --quiet --scan "${YAML_DIR}" --output "${GEN_DIR}"
            WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
            RESULT_VARIABLE RS_GEN_RESULT
            ERROR_VARIABLE RS_OOPSIE
    )
    if (NOT RS_GEN_RESULT EQUAL 0)
        message(FATAL_ERROR "yaml2rs.py batch generation failed at configure time : ${RS_OOPSIE}")
    endif ()

    # 2) Build-time regeneration whenever YAML specs or the generator change
    #    We use a 'stamp' file as the known OUTPUT so Ninja/Make can track the rule.
    file(GLOB_RECURSE YAML_RS_SPECS
            CONFIGURE_DEPENDS
            "${YAML_DIR}/*.yaml"
    )

    set(RS_STAMP "${GEN_DIR}/.generated.stamp")
    add_custom_command(
            OUTPUT "${RS_STAMP}"
            BYPRODUCTS ${GENERATED_RS}
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${GEN_DIR}"
            COMMAND "${Python3_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/cmake/yaml2rs.py"
                    --quiet --scan "${YAML_DIR}" --output "${GEN_DIR}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${RS_STAMP}"
            DEPENDS ${YAML_RS_SPECS} "${CMAKE_SOURCE_DIR}/cmake/yaml2rs.py"
            COMMENT "Generating RS.ixx files from YAML specs (batch mode)"
            VERBATIM
    )

    # 3) Add generated RS.ixx to your target
    #    Do an initial glob after the configure-time generation.
    file(GLOB_RECURSE GENERATED_RS
            "${GEN_DIR}/*RS.ixx"
    )

    add_custom_target(generate_rs ALL DEPENDS "${RS_STAMP}")

    # Ensure your target waits for the generation step
    add_dependencies(${APP_NAME} generate_rs)

    # Add generated sources
    target_sources(${APP_NAME}
            PUBLIC FILE_SET CXX_MODULES
#            BASE_DIRS "${GEN_DIR}"
            FILES ${GENERATED_RS}
    )

    #    # If the generator emits headers/includes alongside the .ixx, expose the directory:
    #    target_include_directories(${TGT} PRIVATE "${GEN_DIR}")
endfunction()
