enable_language(CXX)
include(GNUInstallDirs)
include(ExternalProject)
include(CMakePackageConfigHelpers)

message(STATUS "=== Configuring Components ===")

file(MAKE_DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake")

function(project_install _Folder)

    # ============================================================
    # 0. App config generation (build-time only)
    # ============================================================

    # App configuration (app.yaml) generation paths
    set(APP_YAML_PATH "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/${APP_NAME}.yaml")
    add_subdirectory(${_Folder})

    set(APP_YAML_TEMPLATE_PATH "${cmake_root}/templates/app.yaml.in")
    include(${cmake_root}/generate_app_config.cmake)
    install(FILES
            "${APP_YAML_PATH}"
            DESTINATION ${CMAKE_INSTALL_BINDIR}
            COMPONENT ${APP_NAME}
    )
    include(${cmake_root}/generator.cmake)

    if (APP_GENERATE_RECORDSETS OR APP_GENERATE_UI_CLASSES)

        set(GEN_DEST_DIR ${BUILD_DIR}/generated)

        if (APP_GENERATE_RECORDSETS)
            generateRecordsets(
                    ${GEN_DEST_DIR}/rs
                    ${APP_GENERATE_RECORDSETS}
                    ${APP_NAME})
        endif ()
        if ("${APP_TYPE}" MATCHES "Executable")
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

    # ============================================================
    # 1. Dependency sanitisation (install-time only)
    # ============================================================
    message(STATUS "Install(${APP_NAME}): HS_DependenciesList = [${HS_DependenciesList}]")

    set(_hs_install_targets "")
    foreach (_t IN LISTS HS_DependenciesList)
        if (NOT TARGET ${_t})
            message(STATUS "Install(${APP_NAME}): skipping missing target '${_t}'")
            continue()
        endif ()

        get_target_property(_t_alias ${_t} ALIASED_TARGET)
        if (_t_alias)
            message(STATUS "Install(${APP_NAME}): resolving alias '${_t}' -> '${_t_alias}'")
            set(_t "${_t_alias}")
        endif ()

        get_target_property(_imported ${_t} IMPORTED)
        if (_imported)
            message(STATUS "Install(${APP_NAME}): skipping IMPORTED target '${_t}'")
            continue()
        endif ()

        # Skip targets that ship their own cmake install(EXPORT) set.
        # These packages call install(EXPORT <pkg>-targets ...) in their own CMakeLists.txt,
        # so CMake rejects them appearing in a second export set. The check cannot be done
        # at configure time via file(GLOB) because CMakeFiles/Export/ is written during the
        # generate phase — after this code runs — making filesystem-based detection unreliable
        # on fresh configures. Use a fixed list instead.
        set(_hs_self_exporting_targets "fmt")
        if (_t IN_LIST _hs_self_exporting_targets)
            message(STATUS "Install(${APP_NAME}): skipping self-exporting target '${_t}'")
            unset(_hs_self_exporting_targets)
            continue()
        endif ()
        unset(_hs_self_exporting_targets)

        list(APPEND _hs_install_targets ${_t})

    endforeach ()

    # Remove already claimed targets
    get_property(_hs_claimed GLOBAL PROPERTY HS_INSTALLED_TARGETS)
    if (_hs_claimed)
        list(REMOVE_ITEM _hs_install_targets ${_hs_claimed})
    endif ()
    unset(_hs_claimed)
    set_property(GLOBAL APPEND PROPERTY HS_INSTALLED_TARGETS ${APP_NAME} ${_hs_install_targets})

    message(STATUS "Install(${APP_NAME}): installable deps = [${_hs_install_targets}]")

    # ============================================================
    # 2. Platform install layout
    # ============================================================

    if (APPLE AND APP_TYPE MATCHES "Executable")
        set(_bundle "${APP_NAME}.app")
        set(_hs_lib_dest "${_bundle}/Contents/Frameworks")
        set(_hs_bin_dest "${_bundle}/Contents/MacOS")
        set(_res_dest "${_bundle}/Contents/Resources")
    else ()
        set(_hs_lib_dest ${CMAKE_INSTALL_LIBDIR})
        set(_hs_bin_dest ${CMAKE_INSTALL_BINDIR})
        set(_res_dest ${CMAKE_INSTALL_DATADIR})
    endif ()

    # Compute early so the desktop-files glob and resources section both have it.
    if (APP_LOCAL_RESOURCES)
        SplitAt("${APP_LOCAL_RESOURCES}" "," YAML_LOCAL_RESOURCES YAML_LOCAL_RESOURCES_UUID)
        set(LOCAL_RES_SRC "${CMAKE_CURRENT_SOURCE_DIR}/${YAML_LOCAL_RESOURCES}")
    endif ()

    # @formatting:off
    if (APP_GLOBAL_RESOURCES)
        SplitAt("${APP_GLOBAL_RESOURCES}" "," YAML_GLOBAL_RESOURCES_URL YAML_GLOBAL_RESOURCES_UUID)
        set(_global_resources_src "${CMAKE_SOURCE_DIR}/global_resources")
        file(MAKE_DIRECTORY "${_global_resources_src}")

        # Prefix-relative path embedded in app.yaml — resolved at runtime from the
        # inferred install prefix (exe dir parent, or bundle parent on macOS).
        if (APPLE)
            set(GLOBAL_RESOURCES_DIR "Library/Application Support/${APP_VENDOR}/Resources/${APP_VENDOR}")
        else ()
            # Linux / Windows: CMAKE_INSTALL_DATADIR is already prefix-relative (e.g. "share")
            set(GLOBAL_RESOURCES_DIR "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_VENDOR}")
        endif ()

        if (NOT TARGET GlobalResourcesRepo)
            ExternalProject_Add(GlobalResourcesRepo
                    GIT_REPOSITORY "${YAML_GLOBAL_RESOURCES_URL}"
                    GIT_TAG master
                    GIT_SHALLOW TRUE
                    UPDATE_DISCONNECTED TRUE
                    CONFIGURE_COMMAND ""
                    BUILD_COMMAND ""
                    INSTALL_COMMAND ""
                    TEST_COMMAND ""
                    SOURCE_DIR "${_global_resources_src}"
                    BUILD_BYPRODUCTS "${_global_resources_src}/.fetched"
                    COMMAND ${CMAKE_COMMAND} -E touch "${_global_resources_src}/.fetched"
            )
        endif ()

        add_custom_target(${APP_NAME}fetch_resources DEPENDS GlobalResourcesRepo)
        if (TARGET ${APP_NAME})
            add_dependencies(${APP_NAME} ${APP_NAME}fetch_resources)
        endif ()
    endif ()
    # @formatting:on

    # ============================================================
    # 3. Core install rules (single source of truth)
    # ============================================================

    # @formatting:off
    install(TARGETS ${APP_NAME}
            ${_hs_install_targets}
            EXPORT ${APP_NAME}Target
            LIBRARY DESTINATION ${_hs_lib_dest} COMPONENT ${APP_NAME}
            RUNTIME DESTINATION ${_hs_bin_dest} COMPONENT ${APP_NAME}
            ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT ${APP_NAME}
            CXX_MODULES_BMI DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME} COMPONENT ${APP_NAME}Development
            FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME} COMPONENT ${APP_NAME}Development
            FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR} COMPONENT ${APP_NAME}Development
            FILE_SET headers DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR} COMPONENT ${APP_NAME}Development
            INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
            BUNDLE DESTINATION .
            RESOURCE ${resource_list}
    )

    install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/${APP_NAME}/CMakeFiles/${APP_NAME}.dir/"
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME}
            COMPONENT ${APP_NAME}Development
            FILES_MATCHING
            PATTERN "*.pcm"
            PATTERN "*.ifc"
    )

    # Build the find_dependency() block embedded into @APP_NAME@Config.cmake.
    # For every namespace-qualified target in HS_LibrariesList that is NOT our
    # own vendor target, emit a find_dependency() so consumers can resolve those
    # targets when they include @APP_NAME@Target.cmake.
    set(_hs_fd_seen "")
    set(HS_FIND_DEPENDENCIES "")
    foreach (_lib IN LISTS HS_LibrariesList)
        string(FIND "${_lib}" "::" _nsep)
        if (_nsep LESS 0)
            continue()
        endif ()
        string(SUBSTRING "${_lib}" 0 ${_nsep} _ns)
        if (_ns STREQUAL "${APP_VENDOR}")
            continue()
        endif ()
        if (_ns IN_LIST _hs_fd_seen)
            continue()
        endif ()
        list(APPEND _hs_fd_seen "${_ns}")

        if (_ns STREQUAL "SOCI")
            string(APPEND HS_FIND_DEPENDENCIES "find_dependency(SOCI CONFIG COMPONENTS Core SQLite3)\n")
        elseif (_ns STREQUAL "OpenSSL")
            string(APPEND HS_FIND_DEPENDENCIES "if(APPLE)\n")
            string(APPEND HS_FIND_DEPENDENCIES "    find_dependency(OpenSSL COMPONENTS SSL Crypto HINTS /opt/homebrew /usr/local/opt/openssl /usr/local)\n")
            string(APPEND HS_FIND_DEPENDENCIES "else()\n")
            string(APPEND HS_FIND_DEPENDENCIES "    find_dependency(OpenSSL COMPONENTS SSL Crypto)\n")
            string(APPEND HS_FIND_DEPENDENCIES "endif()\n")
        elseif (_ns STREQUAL "yaml-cpp")
            # yaml-cpp is fully defined as HoffSoft::yaml-cpp in CoreTarget.cmake — no find_dependency needed
        elseif (_ns STREQUAL "wxWidgets")
            # wxWidgets is handled separately via WX_Helper.cmake
        elseif (_ns STREQUAL "Qt6")
            # Qt6 (orphaned — GTK is used instead)
        else ()
            string(APPEND HS_FIND_DEPENDENCIES "find_dependency(${_ns})\n")
        endif ()
    endforeach ()
    unset(_hs_fd_seen)
    unset(_lib)
    unset(_ns)
    unset(_nsep)

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

    install(FILES "${OUTPUT_DIR}/${APP_NAME}Config.cmake"
            "${OUTPUT_DIR}/${APP_NAME}ConfigVersion.cmake"
            "${OUTPUT_DIR}/WX_Helper.cmake"
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
            COMPONENT ${APP_NAME}Development
    )

    install(EXPORT ${APP_NAME}Target
            FILE ${APP_NAME}Target.cmake
            NAMESPACE ${APP_VENDOR}::
            DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake
            COMPONENT ${APP_NAME}Development
            CXX_MODULES_DIRECTORY cxx/${APP_VENDOR}/${APP_NAME}
    )

    # Build-tree export: after each library build, install the Development component
    # into OUTPUT_DIR so that downstream projects with <APP_NAME>_DIR pointing to
    # the out dir can resolve ${APP_VENDOR}::${APP_NAME} without staging first.
    # Uses cmake --install (which drives install(EXPORT)) rather than export(EXPORT)
    # because export(EXPORT) errors on transitive deps not in the export set
    # (e.g. wx sub-targets webp/webpdemux/sharpyuv), while install(EXPORT) is lenient.
    if (APP_TYPE MATCHES "Library")
        add_custom_target(${APP_NAME}_build_tree_export ALL
                COMMAND ${CMAKE_COMMAND} -E env --unset=DESTDIR
                ${CMAKE_COMMAND} --install "${CMAKE_BINARY_DIR}"
                --prefix "${OUTPUT_DIR}"
                --component ${APP_NAME}Development
                COMMAND ${CMAKE_COMMAND} -P "${cmake_root}/post_process_export.cmake"
                "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/cmake/${APP_NAME}Target.cmake"
                "${APP_VENDOR}"
                COMMENT "Writing ${APP_NAME} cmake export files to ${OUTPUT_DIR}"
                VERBATIM
        )
        add_dependencies(${APP_NAME}_build_tree_export ${APP_NAME})
    endif ()

    # Remove .ixx sources installed by FILE_SET CXX_MODULES — if present in the
    # stage dir, Clang ignores pre-built BMIs and recompiles module interfaces from
    # scratch in downstream projects (e.g. HealthCanvas).
    install(CODE "
        set(_cxx_dest \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME}\")
        file(GLOB_RECURSE _ixx_files \"\${_cxx_dest}/*.ixx\")
        if(_ixx_files)
            file(REMOVE \${_ixx_files})
            message(STATUS \"Removed installed .ixx sources from \${_cxx_dest}\")
        endif()
        unset(_ixx_files)
        unset(_cxx_dest)
    " COMPONENT ${APP_NAME}Development)

    # Install headers from 3rd-party libraries
    foreach (pkg IN LISTS _hs_install_targets)
        string(TOLOWER "${pkg}" pkglc)

        set(HANDLED OFF)
        set(fn "${pkg}_installHeaders")
        if (COMMAND "${fn}")
            SELECT(SrcDir AS S BuildDir AS B FROM unifiedFeatures WHERE PackageName = ${pkg})
            _hs_sql_field_to_user(S SRC_DIR)
            if (NOT SRC_DIR)
                set(SRC_DIR "${EXTERNALS_DIR}/${pkg}")
            endif ()
            _hs_sql_field_to_user(B BLD_DIR)
            if (NOT BLD_DIR)
                set(BLD_DIR "${BUILD_DIR}/${pkglc}-build")
            endif ()
            cmake_language(CALL "${fn}" "${pkg}" "${CMAKE_INSTALL_INCLUDEDIR}" "${SRC_DIR}" "${BLD_DIR}")
        endif ()
        if (NOT HANDLED)
            if (EXISTS "${EXTERNALS_DIR}/${pkg}/include")
                install(DIRECTORY "${EXTERNALS_DIR}/${pkg}/include/"
                        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}"
                        COMPONENT ${APP_NAME}Development)
            endif ()
            if (EXISTS "${${pkglc}_INCLUDE_DIR}")
                set(include_dir "${${pkglc}_INCLUDE_DIR}")
            elseif (EXISTS "${${pkg}_INCLUDE_DIR}/include")
                set(include_dir "${${pkg}_INCLUDE_DIR}")
            elseif (EXISTS "${EXTERNALS_DIR}/${pkglc}/include")
                set(include_dir "${EXTERNALS_DIR}/${pkglc}/include")
            elseif (EXISTS "${${pkglc}_SOURCE_DIR}/include")
                set(include_dir "${${pkglc}_SOURCE_DIR}/include")
            else ()
                unset(include_dir)
            endif ()

            if (include_dir)
                install(DIRECTORY "${include_dir}/"
                        DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}"
                        COMPONENT ${APP_NAME}Development)
            endif ()
        endif ()
    endforeach ()

    if (APP_CREATES_PLUGINS)
        if (APPLE AND APP_TYPE MATCHES "Executable")
            set(_plugin_lib_dest "${APP_NAME}.app/Contents/PlugIns")
        else ()
            set(_plugin_lib_dest "${CMAKE_INSTALL_LIBDIR}")
        endif ()
        install(TARGETS ${APP_CREATES_PLUGINS}
                EXPORT ${APP_NAME}PluginTarget
                LIBRARY DESTINATION ${_plugin_lib_dest} COMPONENT ${APP_NAME}
                RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT ${APP_NAME}
                ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT ${APP_NAME}
                CXX_MODULES_BMI DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/bmi/${APP_VENDOR}/${APP_NAME} COMPONENT ${APP_NAME}Development
                FILE_SET CXX_MODULES DESTINATION ${CMAKE_INSTALL_LIBDIR}/cmake/cxx/${APP_VENDOR}/${APP_NAME} COMPONENT ${APP_NAME}Development
                FILE_SET HEADERS DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR} COMPONENT ${APP_NAME}Development
                INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}
        )
    endif ()

    # User guide, if present
    if (EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md")
        install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/docs/${APP_NAME}-UserGuide.md"
                DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Docs/${APP_NAME}")
    endif ()

    # Handle Linux desktop files specifically
    if (LINUX)
        file(GLOB _hs_desktop_files "${LOCAL_RES_SRC}/*.desktop")
        if (_hs_desktop_files)
            install(FILES ${_hs_desktop_files}
                    DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/applications")
        endif ()
        unset(_hs_desktop_files)
    endif ()

    # Static libraries — pick up any *.a files install(TARGETS) doesn't cover
    # (e.g. third-party libs built as static in a LINK_TYPE=Static preset).
    install(DIRECTORY ${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/ DESTINATION ${CMAKE_INSTALL_LIBDIR}
            COMPONENT ${APP_NAME}
            FILES_MATCHING PATTERN "*.a")

    # Aux shared libs/DLLs from third-party builds (e.g. wx's webp/sharpyuv) land in
    # OUTPUT_DIR/{bin,lib}/ without a CMake install(TARGETS) rule — copy them flat.
    # libhoffsoft_* are excluded here: they are handled by install(TARGETS) above,
    # which also performs RPATH processing; a raw directory copy would produce
    # different byte content and cause CPack duplicate-file errors.
    # When cross-compiling for Windows, dependency DLLs are staged to STAGE_DIR/bin/
    # by the Core/Gfx builds, so scan both locations.
    if (WIN32)
        install(DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_BINDIR}/"
                DESTINATION "${CMAKE_INSTALL_BINDIR}"
                COMPONENT ${APP_NAME}Runtime
                FILES_MATCHING PATTERN "*.dll"
                REGEX "libhoffsoft_" EXCLUDE
        )
        if (CMAKE_CROSSCOMPILING AND DEFINED STAGE_DIR)
            install(DIRECTORY "${STAGE_DIR}/${CMAKE_INSTALL_BINDIR}/"
                    DESTINATION "${CMAKE_INSTALL_BINDIR}"
                    COMPONENT ${APP_NAME}Runtime
                    FILES_MATCHING PATTERN "*.dll"
                    REGEX "libhoffsoft_" EXCLUDE
            )
        endif ()
    endif ()

    if (UNIX AND NOT APPLE)
        install(DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                COMPONENT ${APP_NAME}Runtime
                FILES_MATCHING PATTERN "*.so*"
                REGEX "libhoffsoft_" EXCLUDE
        )
    endif ()

    if (APPLE)
        install(DIRECTORY "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}/"
                DESTINATION "${CMAKE_INSTALL_LIBDIR}"
                COMPONENT ${APP_NAME}Runtime
                FILES_MATCHING PATTERN "*.dylib"
                REGEX "libhoffsoft_" EXCLUDE
        )
    endif ()

    if (APPLE AND BUILD_DEBUG)
        set(_hs_dsym_src "${OUTPUT_DIR}/${CMAKE_INSTALL_LIBDIR}")
        set(_hs_dsym_dst "${CMAKE_INSTALL_LIBDIR}")
        install(CODE "
            file(GLOB _hs_dsyms LIST_DIRECTORIES true \"${_hs_dsym_src}/*.dSYM\")
            foreach(_hs_d IN LISTS _hs_dsyms)
                file(COPY \"\${_hs_d}\" DESTINATION \"\${CMAKE_INSTALL_PREFIX}/${_hs_dsym_dst}\")
            endforeach()
        " COMPONENT ${APP_NAME}Development)
    endif ()

    # ============================================================
    # 4. Extra resources (clean separation)
    # ============================================================

    if (APP_LOCAL_RESOURCES)
        if (APPLE AND APP_TYPE MATCHES "Executable")
            # Copy resources into the build-tree bundle at build time so the
            # complete .app (binary + resources) is staged as a unit by
            # install(TARGETS ... BUNDLE DESTINATION .).
            # add_custom_command(TARGET) requires the same directory as the
            # target, so use add_custom_target + add_dependencies instead.
            add_custom_target(${APP_NAME}_copy_resources ALL
                    COMMAND ${CMAKE_COMMAND} -E copy_directory
                    "${LOCAL_RES_SRC}"
                    "$<TARGET_BUNDLE_CONTENT_DIR:${APP_NAME}>/Resources"
                    COMMENT "Copying resources into ${APP_NAME}.app"
                    VERBATIM
            )
            add_dependencies(${APP_NAME}_copy_resources ${APP_NAME})
        else ()
            install(DIRECTORY "${LOCAL_RES_SRC}"
                    DESTINATION "${CMAKE_INSTALL_DATADIR}/${APP_VENDOR}/Resources/${APP_NAME}"
                    COMPONENT ${APP_NAME})
        endif ()
    endif ()

    if (APP_GLOBAL_RESOURCES)
        install(DIRECTORY "${_global_resources_src}"
                DESTINATION "${GLOBAL_RESOURCES_DIR}"
        )
    endif ()

    # ============================================================
    # 5. macOS fixup_bundle (ONLY ONCE, INSTALL TREE ONLY)
    # ============================================================

    if (APPLE AND APP_TYPE MATCHES "Executable")

        install(CODE "
            # Override item resolution for versioned dylib references
            function(gp_resolve_item_override context item exepath dirs resolved_item_var resolved_var)
                # Handle unversioned dylib references when only versioned ones are staged
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

            include(BundleUtilities)

            # Determine absolute bundle path, respecting DESTDIR
            set(_bundle \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${_bundle}\")
            set(_fw_dir \"\${_bundle}/Contents/Frameworks\")

            # Pre-copy libunwind from Homebrew LLVM before fixup_bundle runs.
            # fixup_bundle cannot copy-then-fixup a transitive dependency it resolves
            # to an external path — it must already be inside the bundle.
            file(GLOB _unwind_candidates
                \"/opt/homebrew/opt/llvm/lib/unwind/libunwind.1.dylib\"
                \"/opt/homebrew/Cellar/llvm/*/lib/unwind/libunwind.1.dylib\")
            if(_unwind_candidates)
                list(SORT _unwind_candidates)
                list(GET _unwind_candidates -1 _unwind_src)
                set(_unwind_dst \"\${_fw_dir}/libunwind.1.dylib\")
                if(NOT EXISTS \"\${_unwind_dst}\")
                    # Resolve the symlink (libunwind.1.dylib -> libunwind.1.0.dylib)
                    # before copying — file(COPY) would copy the symlink itself,
                    # leaving a dangling relative target in the bundle.
                    file(REAL_PATH \"\${_unwind_src}\" _unwind_real)
                    configure_file(\"\${_unwind_real}\" \"\${_unwind_dst}\" COPYONLY)
                endif()
                # Give it a proper @executable_path install name
                execute_process(COMMAND install_name_tool -id
                    \"@executable_path/../Frameworks/libunwind.1.dylib\"
                    \"\${_unwind_dst}\" ERROR_QUIET OUTPUT_QUIET)
                # Rewrite every @rpath/libunwind reference in the bundle to the embedded copy
                file(GLOB_RECURSE _all_bins
                    \"\${_bundle}/Contents/MacOS/*\"
                    \"\${_fw_dir}/*.dylib\")
                foreach(_bin IN LISTS _all_bins)
                    if(NOT IS_SYMLINK \"\${_bin}\")
                        execute_process(COMMAND install_name_tool -change
                            \"@rpath/libunwind.1.dylib\"
                            \"@executable_path/../Frameworks/libunwind.1.dylib\"
                            \"\${_bin}\" ERROR_QUIET OUTPUT_QUIET)
                    endif()
                endforeach()
            endif()

            # CFBundleIconFile = \"wxmac.icns\" expects the file at Resources/ root,
            # but CMake (non-Xcode) places it at Resources/appicons/wxmac.icns.
            # Copy it to the right place unconditionally so every install is correct.
            set(_icns_src \"\${_bundle}/Contents/Resources/appicons/wxmac.icns\")
            set(_icns_dst \"\${_bundle}/Contents/Resources/wxmac.icns\")
            if(EXISTS \"\${_icns_src}\")
                configure_file(\"\${_icns_src}\" \"\${_icns_dst}\" COPYONLY)
            endif()

            file(GLOB_RECURSE _all_staged
                \"\${_bundle}/Contents/MacOS/*\"
                \"\${_fw_dir}/*.dylib\")
            foreach(_bin IN LISTS _all_staged)
                if(NOT IS_SYMLINK \"\${_bin}\" AND NOT IS_DIRECTORY \"\${_bin}\")
                    execute_process(COMMAND otool -l \"\${_bin}\"
                        OUTPUT_VARIABLE _otool RESULT_VARIABLE _r ERROR_QUIET)
                    if(_r EQUAL 0)
                        string(REGEX MATCHALL \"path ([^\t\n ]+) \\\\(offset\" _matches \"\${_otool}\")
                        foreach(_m IN LISTS _matches)
                            string(REGEX REPLACE \"path ([^\t\n ]+) \\\\(offset\" \"\\\\1\" _rp \"\${_m}\")
                            if(NOT _rp MATCHES \"^/usr/lib\" AND NOT _rp MATCHES \"^/System\")
                                execute_process(COMMAND install_name_tool -delete_rpath \"\${_rp}\" \"\${_bin}\"
                                    ERROR_QUIET OUTPUT_QUIET)
                            endif()
                        endforeach()
                    endif()
                endif()
            endforeach()

            file(GLOB_RECURSE _fw_libs \"\${_fw_dir}/*.dylib\")
            set(_dirs
                \"\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}\"
                \"\$ENV{DESTDIR}\${CMAKE_INSTALL_PREFIX}/${CMAKE_INSTALL_LIBDIR}\"
                \"\${_fw_dir}\"
            )

            fixup_bundle(
                \"\${_bundle}\"
                \"\${_fw_libs}\"
                \"\${_dirs}\"
            )
        " COMPONENT ${APP_NAME}Runtime)

        # After fixup_bundle():
        install(CODE "
      file(GLOB_RECURSE _dylibs
          \"\${CMAKE_INSTALL_PREFIX}/${APP_NAME}.app/Contents/Frameworks/*.dylib\")
      foreach(_lib IN LISTS _dylibs)
          execute_process(COMMAND codesign --force --sign - \"\${_lib}\")
      endforeach()
      execute_process(COMMAND codesign --force --sign -
          \"\${CMAKE_INSTALL_PREFIX}/${APP_NAME}.app\")
  " COMPONENT Unspecified)
    endif ()

    # ============================================================
    # 6. CPack safety (critical)
    # ============================================================

    # Prevent double fixup_bundle behaviour in CPack pass
    set(CPACK_BUNDLE_SKIP_FIXUP TRUE CACHE BOOL "Disable CPack bundle fixup duplication")

endfunction()

