
find_package(Python3 REQUIRED COMPONENTS Interpreter)


function(generateClasses OUT_DIR SRCDIR TRRGET EXPORT_VAR)

    set (generator "yaml2code.py")

    # Optional 5th arg: where hand-editable _impl.cpp stubs get written.
    # Defaults to alongside the generated .ixx output if the caller doesn't opt in
    # to a committed location (see APP_UI_IMPL_DIR in AppSpecific.cmake).
    set(IMPL_DIR "${OUT_DIR}/impl")
    if (ARGN)
        list(GET ARGN 0 IMPL_DIR)
    endif ()

    # 1) Configure-time generation so CMake can glob and add sources
    file(MAKE_DIRECTORY "${OUT_DIR}")
    file(MAKE_DIRECTORY "${IMPL_DIR}")
    execute_process(
            COMMAND "${Python3_EXECUTABLE}"
            "${cmake_root}/${generator}"
            ${SHOW_QUIET_FLAG}
            ${SHOW_SIZER_INFO_FLAG}
            --scan "${SRCDIR}"
            --output "${OUT_DIR}"
            --impl-dir "${IMPL_DIR}"
            --app-target "${APP_NAME}"
            --export-var "${EXPORT_VAR}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            RESULT_VARIABLE CONFIGURE_RESULT
            ERROR_VARIABLE OOPSIE
    )
    if (NOT CONFIGURE_RESULT EQUAL 0)
        message(FATAL_ERROR "${generator} batch generation failed at configure time : ${OOPSIE}")
    endif ()

    # 2) Build-time regeneration whenever YAML specs or the generator change
    #    We use a 'stamp' file as the known OUTPUT so Ninja/Make can track the rule.
    file(GLOB_RECURSE CLASS_DEPENDENCIES
            CONFIGURE_DEPENDS
            "${SRCDIR}/*.yaml"
            "${cmake_root}/${generator}"
    )

    set(CLASSES_STAMP "${OUT_DIR}/.generated.stamp")
    add_custom_command(
            OUTPUT "${CLASSES_STAMP}"
            BYPRODUCTS ${CLASS_FILES}
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${OUT_DIR}"
            COMMAND "${CMAKE_COMMAND}" -E make_directory "${IMPL_DIR}"
            COMMAND "${Python3_EXECUTABLE}"
            "${cmake_root}/${generator}"
            --quiet ${SHOW_SIZER_INFO_FLAG}
            --scan "${SRCDIR}"
            --output "${OUT_DIR}"
            --impl-dir "${IMPL_DIR}"
            --app-target "${APP_NAME}"
            --export-var "${EXPORT_VAR}"
            COMMAND "${CMAKE_COMMAND}" -E touch "${CLASSES_STAMP}"
            DEPENDS ${CLASS_DEPENDENCIES} "${cmake_root}/${generator}"
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Generating .h files from YAML specs (batch mode)"
            VERBATIM
    )

    # 3) Add generated headers to your target
    #    Do an initial glob after the configure-time generation. yaml2code.py nests output
    #    under record_sets/{rs,ui}/ and user_interface/ui/, so this must recurse.
    file(GLOB_RECURSE CLASS_FILES
            LIST_DIRECTORIES false
            "${OUT_DIR}/*Group.h"
            "${OUT_DIR}/*Page.h"
            "${OUT_DIR}/*RS.h"
            "${OUT_DIR}/*Wizard.h"
            "${OUT_DIR}/*Book.h"
    )

    add_custom_target(generate_classes ALL DEPENDS "${CLASSES_STAMP}")

    # Ensure your target waits for the generation step
    add_dependencies(${TRRGET} generate_classes)

    # Plain headers now -- no target_sources()/FILE_SET registration needed for the
    # build to work, just the include path so "#include <ui/Foo.h>"-style references
    # from impl.cpp stubs and other generated headers resolve.
    target_include_directories(${TRRGET} PRIVATE "${OUT_DIR}")

    # Hand-written implementation stubs (created by generator; existing function
    # bodies are never overwritten, only missing functions get appended)
    file(GLOB_RECURSE CLASS_IMPL_FILES
            CONFIGURE_DEPENDS
            LIST_DIRECTORIES false
            "${IMPL_DIR}/*_impl.cpp"
    )
    if (CLASS_IMPL_FILES)
        target_sources(${TRRGET} PRIVATE ${CLASS_IMPL_FILES})
    endif()

endfunction()
