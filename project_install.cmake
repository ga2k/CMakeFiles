enable_language(CXX)
include(GNUInstallDirs)

message(STATUS "=== Configuring Components ===")

# App configuration (app.yaml) generation paths
set(APP_YAML_PATH "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/${APP_NAME}.yaml")

## Track if Core already exists before this project adds sources
#set(ALREADY_HAVE_CORE OFF)
#if (TARGET HoffSoft::HoffSoft)
#    set(ALREADY_HAVE_CORE ON)
#endif ()

# Enter the project's src folder (defines targets)
if (MONOREPO AND MONOBUILD)
    # This is done in the root CMakeLists.txt
else ()
    add_subdirectory(src)
endif ()

## Consumer workaround for yaml-cpp when consuming HoffSoft::HoffSoft install package
#if (ALREADY_HAVE_CORE)
#    find_package(yaml-cpp CONFIG QUIET)
#    if (TARGET yaml-cpp::yaml-cpp)
#        message(STATUS "Linking yaml-cpp::yaml-cpp explicitly as a workaround for HoffSoft::HoffSoft package")
#        if (TARGET main)
#            target_link_libraries(main LINK_PRIVATE yaml-cpp::yaml-cpp)
#        endif ()
#    endif ()
#endif ()

# Optional resources fetching per project
# @formatting:off
include(ExternalProject)
if (APP_GLOBAL_RESOURCES)
    set(GLOBAL_RESOURCES_DIR "${CMAKE_SOURCE_DIR}/global-resources")
    file(MAKE_DIRECTORY "${GLOBAL_RESOURCES_DIR}")
    ExternalProject_Add(${APP_NAME}ResourceRepo
            GIT_REPOSITORY "${APP_GLOBAL_RESOURCES}"
            GIT_TAG master
            GIT_SHALLOW TRUE
            UPDATE_DISCONNECTED TRUE
            CONFIGURE_COMMAND ""
            BUILD_COMMAND ""
            INSTALL_COMMAND ""
            TEST_COMMAND ""
            SOURCE_DIR "${GLOBAL_RESOURCES_DIR}"
            BUILD_BYPRODUCTS "${GLOBAL_RESOURCES_DIR}/.fetched"
            COMMAND ${CMAKE_COMMAND} -E touch "${GLOBAL_RESOURCES_DIR}/.fetched"
    )
    add_custom_target(fetch_resources DEPENDS ${APP_NAME}ResourceRepo)
    if (TARGET ${APP_NAME})
        add_dependencies(${APP_NAME} fetch_resources)
    endif ()
endif ()
# @formatting:on

## App configuration (app.yaml) generation paths
#set(APP_YAML_PATH "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/${APP_NAME}.yaml")
set(APP_YAML_TEMPLATE_PATH "${CMAKE_SOURCE_DIR}/cmake/templates/app.yaml.in")
include(${CMAKE_SOURCE_DIR}/cmake/generate_app_config.cmake)
install(FILES "${APP_YAML_PATH}" DESTINATION ${CMAKE_INSTALL_BINDIR})

# Code generators (optional)
include(${CMAKE_SOURCE_DIR}/cmake/generator.cmake)

if (APP_GENERATE_RECORDSETS OR APP_GENERATE_UI_CLASSES)

#    if (MONOREPO)
#        set(GEN_DEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/MyCare/src/generated)
#    else ()
#        set(GEN_DEST_DIR ${CMAKE_CURRENT_SOURCE_DIR}/src/generated)
#    endif ()
    set(GEN_DEST_DIR ${BUILD_DIR}/generated)

    if (APP_GENERATE_RECORDSETS)
        generateRecordsets(
                ${GEN_DEST_DIR}/rs
                ${APP_GENERATE_RECORDSETS}
                ${APP_NAME})
    endif ()
    if("${APP_TYPE}" MATCHES "Executable")
        set(EXPORTS_VAR "")
    else ()
        set(EXPORTS_VAR ${APP_NAME}_EXPORTS)
    endif ()
    if (APP_GENERATE_UI_CLASSES)
        generateUIClasses(
                ${GEN_DEST_DIR}/ui
                ${APP_GENERATE_UI_CLASSES}
                ${APP_NAME}
                "${EXPORTS_VAR}")
    endif ()
endif ()

# ========================= Install & packaging =========================
#
set_target_properties(${APP_NAME} PROPERTIES RESOURCE "")

if(APP_GLOBAL_RESOURCES)
    # Based on your tree: $CMAKE_INSTALL_DATADIR/HoffSoft/HoffSoft/Resources
    # Note: Global resources seem to belong to the vendor's primary 'HoffSoft' folder in your tree
    install(DIRECTORY "${CMAKE_SOURCE_DIR}/global-resources/"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/${APP_VENDOR}/Resources"
            COMPONENT GlobalResources
    )
endif()

# @formatting:off
install(TARGETS                 ${APP_NAME}
                                ${HS_DependenciesList}
        EXPORT                  ${APP_NAME}Target
        LIBRARY                 DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME                 DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE                 DESTINATION ${CMAKE_INSTALL_LIBDIR}
        CXX_MODULES_BMI         DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILE_SET CXX_MODULES    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
        FILE_SET HEADERS        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        FILE_SET headers        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        INCLUDES                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        BUNDLE                  DESTINATION .
        RESOURCE                ${resource_list}
)

# Install Global Shared Resources
if(APP_GLOBAL_RESOURCES)
    if(APPLE)
        # Shared resources go to Application Support
        set(GLOBAL_RES_DEST "Library/Application Support/${APP_VENDOR}/${APP_NAME}")
    else()
        # Linux/Windows fallback
        set(GLOBAL_RES_DEST "share/${APP_VENDOR}/${APP_NAME}")
    endif()

    install(DIRECTORY ${CMAKE_SOURCE_DIR}/global-resources/
            DESTINATION ${GLOBAL_RES_DEST}/${APP_NAME}
            COMPONENT GlobalResources
    )
endif()

# PCM/PCM-like files
install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/src/CMakeFiles/${APP_NAME}.dir/"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILES_MATCHING
        PATTERN "*.pcm"
        PATTERN "*.ifc"
        PATTERN "*.json"
)

install(EXPORT      ${APP_NAME}Target
        FILE        ${APP_NAME}Target.cmake
        NAMESPACE   ${APP_VENDOR}::
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake"
        CXX_MODULES_DIRECTORY "cxx/${APP_VENDOR}/${APP_NAME}"
)

if (APP_CREATES_PLUGINS)
    install(TARGETS                          ${APP_CREATES_PLUGINS}
            EXPORT                           ${APP_NAME}PluginTarget
            LIBRARY DESTINATION              ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            RUNTIME DESTINATION              ${CMAKE_INSTALL_BINDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            ARCHIVE DESTINATION              ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            CXX_MODULES_BMI DESTINATION      ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
            FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
            FILE_SET HEADERS DESTINATION     ${CMAKE_INSTALL_INCLUDEDIR}
            INCLUDES DESTINATION             ${CMAKE_INSTALL_INCLUDEDIR}
    )
endif ()
# @formatting:on

# Static libraries (copy built libs)
install(DIRECTORY ${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/ DESTINATION ${CMAKE_INSTALL_LIBDIR})

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
        "${OUTPUT_DIR}/${APP_NAME}ConfigVersion.cmake"
        VERSION ${APP_VERSION}
        COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
        ${CMAKE_SOURCE_DIR}/cmake/templates/Config.cmake.in
        "${OUTPUT_DIR}/${APP_NAME}Config.cmake"
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

add_custom_target(${APP_NAME}Config SOURCES "${CMAKE_SOURCE_DIR}/cmake/templates/Config.cmake.in")
add_dependencies(${APP_NAME} ${APP_NAME}Config)

install(FILES
        "${OUTPUT_DIR}/${APP_NAME}Config.cmake"
        "${OUTPUT_DIR}/${APP_NAME}ConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

# User guide, if present
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/${APP_NAME}/doc")
endif ()

if (APP_LOCAL_RESOURCES)
    set(LOCAL_RES_SRC "${CMAKE_CURRENT_SOURCE_DIR}/${APP_LOCAL_RESOURCES}")

    if (APPLE AND "${APP_TYPE}" STREQUAL "Executable")
        # If it's a macOS Bundle, we can still put them in the bundle
        # but per your tree requirements for a unified stagedir:
        install(DIRECTORY "${LOCAL_RES_SRC}/"
                DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/${APP_NAME}/Resources")
    else()
        # Windows/Linux/Generic: $CMAKE_INSTALL_DATADIR/HoffSoft/${APP_NAME}/Resources
        install(DIRECTORY "${LOCAL_RES_SRC}/"
                DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/${APP_NAME}/Resources")
    endif()
endif ()

# Handle Linux desktop files specifically
if (LINUX)
    file(GLOB _hs_desktop_files "${LOCAL_RES_SRC}/*.desktop")
    if (_hs_desktop_files)
        install(FILES ${_hs_desktop_files}
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
    endif ()
    unset(_hs_desktop_files)
endif()

if (WIN32)
    install(CODE "
        include(\"${CMAKE_CURRENT_SOURCE_DIR}/cmake/cmake_copy_files.cmake\")
        copy_files_to_target_dir(
            TARGET_DIR
                \"\${OUTPUT_DIR}/bin\"
            SOURCE_DIRS
                \"\${OUTPUT_DIR}/bin\"
                \"\${OUTPUT_DIR}/bin/Plugins\"
                \"\${OUTPUT_DIR}/lib\"
                \"\${OUTPUT_DIR}/lib/Plugins\"
                \"\${OUTPUT_DIR}/bin\"
                \"\${BUILD_DIR}/bin\"
                \"\${BUILD_DIR}/lib\"
                \"\${EXTERNALS_DIR}/Boost/stage/lib\"
            FILE_PATTERNS
                \"*.exe\" \"*.dll\" \"*.plugin\" \"*.lib\"
        )
    ")
endif ()
