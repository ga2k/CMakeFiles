
message(STATUS "=== Configuring Components ===")

# Track if Core already exists before this project adds sources
set(ALREADY_HAVE_CORE OFF)
if (TARGET HoffSoft::HoffSoft)
    set(ALREADY_HAVE_CORE ON)
endif ()

# Enter the project's src folder (defines targets)
if (MONOREPO AND MONOBUILD)
    # This is done in the root CMakeLists.txt
else ()
    add_subdirectory(src)
endif ()

# Consumer workaround for yaml-cpp when consuming HoffSoft::HoffSoft install package
if (ALREADY_HAVE_CORE)
    find_package(yaml-cpp CONFIG QUIET)
    if (TARGET yaml-cpp::yaml-cpp)
        message(STATUS "Linking yaml-cpp::yaml-cpp explicitly as a workaround for HoffSoft::HoffSoft package")
        if (TARGET main)
            target_link_libraries(main LINK_PRIVATE yaml-cpp::yaml-cpp)
        endif ()
    endif ()
endif ()

# App configuration (app.yaml) generation paths
if (${APP_TYPE} STREQUAL "Library")
    set(APP_YAML_PATH "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}/${APP_VENDOR_LC}_${APP_NAME_LC}.yaml")
else ()
    set(APP_YAML_PATH "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}/${APP_NAME}.yaml")
endif ()
set(APP_YAML_TEMPLATE_PATH "${CMAKE_SOURCE_DIR}/cmake/templates/app.yaml.in")

file(MAKE_DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}")
include(${CMAKE_SOURCE_DIR}/cmake/generate_app_config.cmake)

# Optional resources fetching per project
# @formatting:off
include(ExternalProject)
if (APP_INCLUDES_RESOURCES OR APP_SUPPLIES_RESOURCES)
    set(RES_DIR "${CMAKE_CURRENT_SOURCE_DIR}/resources")
    if (APP_SUPPLIES_RESOURCES)
        ExternalProject_Add(${APP_NAME}ResourceRepo
                GIT_REPOSITORY "${APP_SUPPLIES_RESOURCES}"
                GIT_TAG master
                GIT_SHALLOW TRUE
                UPDATE_DISCONNECTED TRUE
                CONFIGURE_COMMAND ""
                BUILD_COMMAND ""
                INSTALL_COMMAND ""
                TEST_COMMAND ""
                SOURCE_DIR "${RES_DIR}"
                BUILD_BYPRODUCTS "${RES_DIR}/.fetched"
                COMMAND ${CMAKE_COMMAND} -E touch "${RES_DIR}/.fetched"
        )
        add_custom_target(fetch_resources DEPENDS ${APP_NAME}ResourceRepo)
        if (TARGET ${APP_NAME})
            add_dependencies(${APP_NAME} fetch_resources)
        endif ()
    endif ()
endif ()
# @formatting:on

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
    if (APP_GENERATE_UI_CLASSES)
        generateUIClasses(
                ${GEN_DEST_DIR}/ui
                ${APP_GENERATE_UI_CLASSES}
                ${APP_NAME})
    endif ()
endif ()

# ========================= Install & packaging =========================
#

include(GNUInstallDirs)

if ("${APP_TYPE}" STREQUAL "Library")
    install(FILES
            "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR_LC}_${APP_NAME_LC}.yaml"
            DESTINATION ${CMAKE_INSTALL_LIBDIR}
    )
else ()
    install(FILES
            "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/${APP_NAME}.yaml"
            DESTINATION ${CMAKE_INSTALL_BINDIR}
    )
endif ()
set(APP_YAML_PATH "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/${APP_NAME}.yaml")

# @formatting:off
install(TARGETS                  ${APP_NAME} ${HS_DependenciesList}
        EXPORT                   ${APP_NAME}Target
        LIBRARY                  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        RUNTIME                  DESTINATION ${CMAKE_INSTALL_BINDIR}
        ARCHIVE                  DESTINATION ${CMAKE_INSTALL_LIBDIR}
        CXX_MODULES_BMI          DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILE_SET CXX_MODULES     DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
        FILE_SET HEADERS         DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
        INCLUDES                 DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}
)

install(CODE "file(MAKE_DIRECTORY \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/${APP_NAME}/cxx/${APP_VENDOR}/${APP_NAME}\")")

# PCM/PCM-like files
install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/src/CMakeFiles/${APP_NAME}.dir"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILES_MATCHING
        PATTERN "*.pcm"
        PATTERN "*.ifc"
        PATTERN "*.json"
)

install(EXPORT      ${APP_NAME}Target
        FILE        ${APP_NAME}Target.cmake
        NAMESPACE   ${APP_VENDOR}::
        DESTINATION "${CMAKE_INSTALL_LIBDIR}/cmake/${APP_NAME}"
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

install(CODE "
  message(WARNING \"Removing $ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}/**/*.ixx\")
  file(GLOB_RECURSE junk \"$ENV{DESTDIR}${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}/*.ixx\")
  if(junk)
    file(REMOVE ${junk})
  endif()
")

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

install(FILES
        "${OUTPUT_DIR}/${APP_NAME}Config.cmake"
        "${OUTPUT_DIR}/${APP_NAME}ConfigVersion.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

# User guide, if present
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/doc/${APP_NAME}")
endif ()

# Resources directory (fonts, images, etc.)
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/resources")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/resources/"
            DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/${APP_VENDOR}/${APP_NAME}/resources")
    file(GLOB _hs_desktop_files "${CMAKE_CURRENT_SOURCE_DIR}/resources/*.desktop")
    if (_hs_desktop_files)
        install(FILES ${_hs_desktop_files}
                DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
    endif ()
    unset(_hs_desktop_files)
endif ()
