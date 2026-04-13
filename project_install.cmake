enable_language(CXX)
include(GNUInstallDirs)

message(STATUS "=== Configuring Components ===")

# App configuration (app.yaml) generation paths
set(APP_YAML_PATH "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/${APP_NAME}.yaml")

# Enter the project's src folder (defines targets)
add_subdirectory(src)

# Optional resources fetching per project
# @formatting:off
include(ExternalProject)
if (APP_GLOBAL_RESOURCES)
    set(GLOBAL_RESOURCES_DIR "${CMAKE_SOURCE_DIR}/global-resources")
    file(MAKE_DIRECTORY "${GLOBAL_RESOURCES_DIR}")

    if (NOT TARGET GlobalResourcesRepo)
        ExternalProject_Add(GlobalResourcesRepo
                GIT_REPOSITORY      "${APP_GLOBAL_RESOURCES}"
                GIT_TAG             master
                GIT_SHALLOW         TRUE
                UPDATE_DISCONNECTED TRUE
                CONFIGURE_COMMAND   ""
                BUILD_COMMAND       ""
                INSTALL_COMMAND     ""
                TEST_COMMAND        ""
                SOURCE_DIR          "${GLOBAL_RESOURCES_DIR}"
                BUILD_BYPRODUCTS    "${GLOBAL_RESOURCES_DIR}/.fetched"
                COMMAND             ${CMAKE_COMMAND} -E touch "${GLOBAL_RESOURCES_DIR}/.fetched"
        )
    endif ()

    add_custom_target(${APP_NAME}fetch_resources DEPENDS GlobalResourcesRepo)
    if (TARGET ${APP_NAME})
        add_dependencies(${APP_NAME} ${APP_NAME}fetch_resources)
    endif ()
endif ()
# @formatting:on

file(MAKE_DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake")

## App configuration (app.yaml) generation paths
set(APP_YAML_TEMPLATE_PATH "${cmake_root}/templates/app.yaml.in")
include(${cmake_root}/generate_app_config.cmake)
install(FILES "${APP_YAML_PATH}" DESTINATION ${CMAKE_INSTALL_BINDIR})

# Code generators (optional)
include(${cmake_root}/generator.cmake)

if (APP_GENERATE_RECORDSETS OR APP_GENERATE_UI_CLASSES)

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
# ---- Debug + sanitize dependency targets for install(TARGETS) ----
message(STATUS "Install(${APP_NAME}): HS_DependenciesList = [${HS_DependenciesList}]")

set(_hs_install_targets "")
foreach(_t IN LISTS HS_DependenciesList)
    if(NOT TARGET ${_t})
        message(STATUS "Install(${APP_NAME}): skipping missing target '${_t}'")
        continue()
    endif()

    # Resolve alias targets (install(TARGETS) needs the real one)
    get_target_property(_aliased ${_t} ALIASED_TARGET)
    if(_aliased)
        message(STATUS "Install(${APP_NAME}): resolving alias '${_t}' -> '${_aliased}'")
        set(_t "${_aliased}")
    endif()

    # Never try to install imported targets (e.g. Core::yaml-cpp)
    get_target_property(_imported ${_t} IMPORTED)
    if(_imported)
        message(STATUS "Install(${APP_NAME}): skipping IMPORTED target '${_t}'")
        continue()
    endif()

    list(APPEND _hs_install_targets ${_t})
endforeach()

message(STATUS "Install(${APP_NAME}): installable deps = [${_hs_install_targets}]")

# On macOS app bundles, route built libraries and resources inside the bundle.
if(APPLE AND APP_TYPE MATCHES "Executable")
    set(_hs_lib_dest "${APP_NAME}.app/Contents/Frameworks")
    set(_hs_bin_dest "${APP_NAME}.app/Contents/MacOS")
else()
    set(_hs_lib_dest "${CMAKE_INSTALL_LIBDIR}")
    set(_hs_bin_dest "${CMAKE_INSTALL_BINDIR}")
endif()

# @formatting:off
install(TARGETS                 ${APP_NAME}
                                ${_hs_install_targets}
        EXPORT                  ${APP_NAME}Target
        LIBRARY                 DESTINATION ${_hs_lib_dest}
        RUNTIME                 DESTINATION ${_hs_bin_dest}
        ARCHIVE                 DESTINATION ${CMAKE_INSTALL_LIBDIR}
        CXX_MODULES_BMI         DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
        FILE_SET CXX_MODULES    DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
        FILE_SET HEADERS        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
        FILE_SET headers        DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
        INCLUDES                DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
        BUNDLE                  DESTINATION .
        RESOURCE                ${resource_list}
)

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

# For in-repo development, copy the build-tree export into OUTPUT_DIR so that
# ${OUTPUT_DIR}/${APP_NAME}Config.cmake can include it via _libdir/cmake.
# CMakeFiles/Export/ is populated during cmake's *generation* phase (after configure),
# so on the very first configure this glob finds nothing — that is harmless.
# On every subsequent incremental configure the files are already there and get copied.
if(APP_TYPE MATCHES Library)
    set(_hs_dev_cmake_dir "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake")
    file(MAKE_DIRECTORY "${_hs_dev_cmake_dir}")
    file(GLOB _hs_export_cmake_files
        "${CMAKE_BINARY_DIR}/CMakeFiles/Export/*/${APP_NAME}Target*.cmake"
    )
    foreach(_hs_f IN LISTS _hs_export_cmake_files)
        file(COPY "${_hs_f}" DESTINATION "${_hs_dev_cmake_dir}")
    endforeach()
    unset(_hs_dev_cmake_dir)
    unset(_hs_export_cmake_files)
    unset(_hs_f)
endif()

# Also stage the public headers and module interface units needed by the export FILE_SETs.
# The generated ${APP_NAME}Target.cmake references these paths under the output prefix.
if(EXISTS "${CMAKE_SOURCE_DIR}/include")
    file(MAKE_DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}")
    file(COPY "${CMAKE_SOURCE_DIR}/include/"
            DESTINATION "${OUTPUT_DIR}/${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}")
endif()

# Now for the library finder (if there really IS such a thing...)
if(APP_TYPE MATCHES Library AND EXISTS "${CMAKE_SOURCE_DIR}/${APP_NAME}.cmake")
    file(COPY "${CMAKE_SOURCE_DIR}/${APP_NAME}.cmake"
         DESTINATION "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake/${APP_VENDOR}")
endif()

# Install the headers from the 3rd party libraries
foreach(pkg IN LISTS _hs_install_targets)
    # FetchContent sets <lowercaseName>_SOURCE_DIR
    string(TOLOWER "${pkg}" pkglc)

    set(HANDLED OFF)
    set(fn "${pkg}_installHeaders")
    if (COMMAND "${fn}")
        SELECT(SrcDir AS S BuildDir AS B FROM unifiedFeatures WHERE PackageName = ${pkg})
        _hs_sql_field_to_user(S SRC_DIR)
        if(NOT SRC_DIR)
            set(SRC_DIR "${EXTERNALS_DIR}/${pkg}")
        endif ()
        _hs_sql_field_to_user(B BLD_DIR)
        if(NOT BLD_DIR)
            set(BLD_DIR "${BUILD_DIR}/${pkglc}-build")
        endif ()
        cmake_language(CALL "${fn}" "${pkg}" "${CMAKE_INSTALL_INCLUDEDIR}" "${SRC_DIR}" "${BLD_DIR}")
    endif ()
    if(NOT HANDLED)
        # 1. Bundle Headers
        # Look in the source directory where FetchContent downloaded them
        if (EXISTS "${EXTERNALS_DIR}/${pkg}/include")
            install(DIRECTORY "${EXTERNALS_DIR}/${pkg}/include/"
                    DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}"
                    COMPONENT Development)
        endif ()
        if (EXISTS "${${pkglc}_INCLUDE_DIR}")
            set(include_dir "${${pkglc}_INCLUDE_DIR}")
        elseif (EXISTS "${${pkg}_INCLUDE_DIR}/include")
            set(include_dir "${${pkg}_INCLUDE_DIR}")
        elseif (EXISTS "${EXTERNALS_DIR}/${pkglc}/include")
            set(include_dir "${EXTERNALS_DIR}/${pkglc}/include")
        elseif (EXISTS "${${pkglc}_SOURCE_DIR}/include")
            set(include_dir "${${pkglc}_SOURCE_DIR}/include")
        elseif (EXISTS X)
            set(include_dir "${${pkglc}_SOURCE_DIR}/include")
        else ()
            unset(include_dir)
        endif ()

        if(include_dir)
            install(DIRECTORY "${include_dir}/"
                       DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}"
                       COMPONENT Development)
        endif()
    endif ()

    # 2. Bundle Compiled Binaries (Static/Shared Libs)
    # Compiled libs usually land in the BINARY_DIR (build tree)
    if (EXISTS "${${pkglc}_BINARY_DIR}")
        # Install .lib / .a files
        install(DIRECTORY "${${pkglc}_BINARY_DIR}/lib/"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                COMPONENT Runtime
                FILES_MATCHING
                    PATTERN "*.lib"
                    PATTERN "*.a"
                    PATTERN "*.so*"
                    PATTERN "*d.lib"
                    PATTERN "*d.a"
                    PATTERN "*d.so*"
        )

        # Install DLLs (Windows specific - must be in the bin folder)
        if (WIN32)
            install(DIRECTORY "${${pkglc}_BINARY_DIR}/bin/"
                    DESTINATION "${CMAKE_INSTALL_BINDIR}"
                    COMPONENT Runtime
                    FILES_MATCHING
                        PATTERN "*.dll"
                        PATTERN "*d.dll"
            )
        endif()
    endif()
endforeach()

if (APP_CREATES_PLUGINS)
    install(TARGETS                          ${APP_CREATES_PLUGINS}
            EXPORT                           ${APP_NAME}PluginTarget
            LIBRARY DESTINATION              ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            RUNTIME DESTINATION              ${CMAKE_INSTALL_BINDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            ARCHIVE DESTINATION              ${CMAKE_INSTALL_LIBDIR}/${APP_VENDOR}/${APP_NAME}/plugins
            CXX_MODULES_BMI DESTINATION      ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
            FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}
            FILE_SET HEADERS DESTINATION     ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
            INCLUDES DESTINATION             ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
    )
endif ()
# @formatting:on

# Static libraries (copy built libs)
install(DIRECTORY ${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/ DESTINATION ${CMAKE_INSTALL_LIBDIR})

# Build the find_dependency block embedded into @APP_NAME@Config.cmake.
# For every namespace-qualified target in HS_LibrariesList that is NOT our
# own vendor target, emit a find_dependency() so consumers can resolve those
# targets when they include @APP_NAME@Target.cmake.
set(_hs_fd_seen "")
set(HS_FIND_DEPENDENCIES "")
foreach(_lib IN LISTS HS_LibrariesList)
    string(FIND "${_lib}" "::" _nsep)
    if(_nsep LESS 0)
        continue()
    endif()
    string(SUBSTRING "${_lib}" 0 ${_nsep} _ns)
    if(_ns STREQUAL "${APP_VENDOR}")
        continue()
    endif()
    if(_ns IN_LIST _hs_fd_seen)
        continue()
    endif()
    list(APPEND _hs_fd_seen "${_ns}")

    if(_ns STREQUAL "SOCI")
        string(APPEND HS_FIND_DEPENDENCIES "find_dependency(SOCI CONFIG COMPONENTS Core SQLite3)\n")
    elseif(_ns STREQUAL "OpenSSL")
        string(APPEND HS_FIND_DEPENDENCIES "find_dependency(OpenSSL COMPONENTS SSL Crypto)\n")
    elseif(_ns STREQUAL "cpptrace")
        string(APPEND HS_FIND_DEPENDENCIES "find_dependency(cpptrace CONFIG)\n")
    elseif(_ns STREQUAL "yaml-cpp")
        # yaml-cpp is statically embedded — consumers must not re-link it (it stays in the strip list)
    elseif(_ns STREQUAL "wxWidgets")
        # wxWidgets is handled separately via WX_Helper.cmake
    elseif(_ns STREQUAL "Qt6")
        # Qt6 is handled by the LINUX guard above in Config.cmake.in
    else()
        string(APPEND HS_FIND_DEPENDENCIES "find_dependency(${_ns})\n")
    endif()
endforeach()
unset(_hs_fd_seen)
unset(_lib)
unset(_ns)
unset(_nsep)

include(CMakePackageConfigHelpers)
write_basic_package_version_file(
        "${OUTPUT_DIR}/${APP_NAME}ConfigVersion.cmake"
        VERSION ${APP_VERSION}
        COMPATIBILITY SameMajorVersion
)

configure_package_config_file(
        ${cmake_root}/templates/Config.cmake.in
        "${OUTPUT_DIR}/${APP_NAME}Config.cmake"
        INSTALL_DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)
add_custom_target(${APP_NAME}Config SOURCES "${cmake_root}/templates/Config.cmake.in")
add_dependencies(${APP_NAME} ${APP_NAME}Config)

add_custom_target(${APP_NAME}WX_Helper SOURCES "${cmake_root}/templates/WX_Helper.cmake.in")
add_dependencies(${APP_NAME} ${APP_NAME}WX_Helper)

install(FILES
        "${OUTPUT_DIR}/${APP_NAME}Config.cmake"
        "${OUTPUT_DIR}/${APP_NAME}ConfigVersion.cmake"
        "${OUTPUT_DIR}/WX_Helper.cmake"
        DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
)

# User guide, if present
if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
    install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
            DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Docs/${APP_NAME}")
endif ()

# Install Global Shared Resources
if(APP_GLOBAL_RESOURCES)
    if(APPLE)
        # Shared resources go to Application Support
        set(GLOBAL_RES_DEST "Library/Application Support/${APP_VENDOR}/Resources/${APP_VENDOR}")
    else()
        # Linux/Windows fallback
        set(GLOBAL_RES_DEST "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_VENDOR}")
    endif()

    install(DIRECTORY ${CMAKE_SOURCE_DIR}/global-resources/
            DESTINATION ${GLOBAL_RES_DEST}
            COMPONENT GlobalResources
    )
endif()

if (APP_LOCAL_RESOURCES)
    set(LOCAL_RES_SRC "${CMAKE_CURRENT_SOURCE_DIR}/${APP_LOCAL_RESOURCES}")

    if (APPLE AND "${APP_TYPE}" STREQUAL "Executable")
        # Local resources go inside the bundle's Contents/Resources/
        install(DIRECTORY "${LOCAL_RES_SRC}/"
                DESTINATION "${APP_NAME}.app/Contents/Resources")
    else()
        # Windows/Linux/Generic
        install(DIRECTORY "${LOCAL_RES_SRC}/"
                DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_NAME}")
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
        include(\"${cmake_root}/cmake_copy_files.cmake\")
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

# macOS: use BundleUtilities to copy all non-system dylib dependencies
# into Contents/Frameworks and rewrite @rpath / @loader_path references
# so the bundle is self-contained.
if (APPLE AND APP_TYPE MATCHES "Executable")
    install(CODE "
        cmake_policy(SET CMP0009 NEW)
        include(BundleUtilities)
        # Override item resolution for two problem cases:
        # 1. libunwind: LLVM 21's libc++ references @rpath/libunwind.1.dylib; fixup_bundle
        #    calls 'otool -l' on the raw @rpath/... path before IGNORE_ITEM kicks in.
        #    Resolve to the real system path so it's classified as 'system' and skipped.
        # 2. Unversioned dylib names (e.g. libc++abi.1.dylib): the install step copies only
        #    the versioned file (libc++abi.1.0.dylib), not the unversioned symlink. When
        #    libc++.1.0.dylib references @executable_path/../Frameworks/libc++abi.1.dylib,
        #    fixup_bundle fails because the file doesn't exist. Redirect to the versioned
        #    copy already in Frameworks — fixup_bundle sees it's already been keyed and skips.
        function(gp_resolve_item_override context item exepath dirs resolved_item_var resolved_var)
          if(item MATCHES \"libunwind\")
            set(\${resolved_item_var} \"/usr/lib/libunwind.1.dylib\" PARENT_SCOPE)
            set(\${resolved_var} 1 PARENT_SCOPE)
            return()
          endif()
          # Derive the Frameworks dir from the executable path (Contents/MacOS/MyCare -> Contents/Frameworks)
          get_filename_component(_macos_dir \"\${exepath}\" DIRECTORY)
          get_filename_component(_contents_dir \"\${_macos_dir}\" DIRECTORY)
          set(_fw_dir \"\${_contents_dir}/Frameworks\")
          get_filename_component(_item_name \"\${item}\" NAME)
          if(NOT EXISTS \"\${_fw_dir}/\${_item_name}\")
            string(REGEX REPLACE \"\\\\.dylib$\" \"\" _stem \"\${_item_name}\")
            file(GLOB _versioned \"\${_fw_dir}/\${_stem}.*.dylib\")
            if(_versioned)
              list(SORT _versioned)
              list(GET _versioned 0 _first)
              set(\${resolved_item_var} \"\${_first}\" PARENT_SCOPE)
              set(\${resolved_var} 1 PARENT_SCOPE)
            endif()
          endif()
        endfunction()
        set(_bundle \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${APP_NAME}.app\")
        # Pre-strip non-system absolute rpaths from all staged binaries before fixup_bundle
        # runs. fixup_bundle calls 'install_name_tool -delete_rpath' for every rpath it
        # finds via 'otool -l'. Some rpaths (build-tree paths, LLVM toolchain paths,
        # Linux-style $ORIGIN paths) were already removed by CMake's install RPATH handling,
        # so install_name_tool fails with "no LC_RPATH load command". By stripping them here
        # first (silently), fixup_bundle's own scan finds a clean set and succeeds.
        file(GLOB_RECURSE _all_staged
            \"\${_bundle}/Contents/MacOS/*\"
            \"\${_bundle}/Contents/Frameworks/*.dylib\")
        foreach(_bin IN LISTS _all_staged)
          if(NOT IS_SYMLINK \"\${_bin}\" AND NOT IS_DIRECTORY \"\${_bin}\")
            execute_process(COMMAND otool -l \"\${_bin}\"
              OUTPUT_VARIABLE _otool RESULT_VARIABLE _r ERROR_QUIET)
            if(_r EQUAL 0)
              string(REGEX MATCHALL \"path ([^\t\n ]+) \\\\(offset\" _matches \"\${_otool}\")
              foreach(_m IN LISTS _matches)
                string(REGEX REPLACE \"path ([^\t\n ]+) \\\\(offset\" \"\\\\1\" _rp \"\${_m}\")
                if(NOT _rp MATCHES \"^@\" AND NOT _rp MATCHES \"^/usr/lib\" AND NOT _rp MATCHES \"^/System\")
                  execute_process(COMMAND install_name_tool -delete_rpath \"\${_rp}\" \"\${_bin}\"
                    RESULT_VARIABLE _dr ERROR_QUIET)
                endif()
              endforeach()
            endif()
          endif()
        endforeach()
        # Include any dylibs already placed in Frameworks by install(TARGETS)
        file(GLOB_RECURSE _fw_libs \"\${_bundle}/Contents/Frameworks/*.dylib\")
        # Search both the build-tree output dir and the staged lib dir for deps
        fixup_bundle(\"\${_bundle}\" \"\${_fw_libs}\"
            \"${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR};\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}\"
            IGNORE_ITEM \"libunwind.1.dylib\"
        )
    " COMPONENT Runtime)
endif()
