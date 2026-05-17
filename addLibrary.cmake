function(addLibrary)
    cmake_parse_arguments(arg
            "PLUGIN;STATIC;SHARED;MULTI_LIBS;PRIMARY;EXECUTABLE"
            "NAME;PATH;VERSION;LINK;HEADER_VISIBILITY;SOURCE_VISIBILITY;MODULE_VISIBILITY;CXX_MODULES_FILE_SET;HEADERS_FILE_SET"
            "HEADERS;SOURCES;SOURCE;MODULES;LIBS;DEPENDS;USES;BASE_DIRS;CXX_BASE_DIRS"
            ${ARGN}
    )
    get_filename_component(LIB_PATH ${CMAKE_PARENT_LIST_FILE} DIRECTORY)
    get_filename_component(LIB_NAME ${LIB_PATH} NAME)

    if (NOT arg_HEADERS_FILE_SET)
        set (arg_HEADERS_FILE_SET "HEADERS")
    endif ()

    if (NOT arg_CXX_MODULES_FILE_SET)
        set (arg_CXX_MODULES_FILE_SET "CXX_MODULES")
    endif ()

    if (NOT arg_HEADER_VISIBILITY)
        set(arg_HEADER_VISIBILITY "PUBLIC")
    else ()
        string(TOUPPER ${arg_HEADER_VISIBILITY} arg_HEADER_VISIBILITY)
    endif ()

    if (NOT arg_SOURCE_VISIBILITY)
        set(arg_SOURCE_VISIBILITY "PRIVATE")
    else ()
        string(TOUPPER ${arg_SOURCE_VISIBILITY} arg_SOURCE_VISIBILITY)
    endif ()

    if (NOT arg_MODULE_VISIBILITY)
        set(arg_MODULE_VISIBILITY "PUBLIC")
    else ()
        string(TOUPPER ${arg_MODULE_VISIBILITY} arg_MODULE_VISIBILITY)
    endif ()

    if (arg_SOURCE)
        list(APPEND arg_SOURCES ${arg_SOURCE})
    endif ()

    if (arg_LIBS)
        list(APPEND arg_DEPENDS ${arg_LIBS})
    endif ()

    if (NOT arg_NAME)
        set(arg_NAME ${LIB_NAME})
    endif ()

    if (NOT arg_PATH)
        set(arg_PATH ${LIB_PATH})
    endif ()

    if (NOT arg_VERSION)
        set(arg_VERSION "1.0.0")
    endif ()

    if (NOT arg_BASE_DIRS)
        set(arg_BASE_DIRS ${HEADER_BASE_DIRS})
    endif ()

    if (NOT arg_CXX_BASE_DIRS)
        set(arg_CXX_BASE_DIRS "${CMAKE_CURRENT_SOURCE_DIR}")
    endif ()

    string(TOUPPER "${arg_USES}" arg_USES)

    if(NOT arg_EXECUTABLE)
        if (arg_LINK MATCHES SHARED)
            set(arg_SHARED ON)
            set(arg_STATIC OFF)
            set(arg_PLUGIN OFF)
            set(glurg " SHARED")
        elseif (arg_LINK MATCHES STATIC)
            set(arg_SHARED OFF)
            set(arg_STATIC ON)
            set(arg_PLUGIN OFF)
            set(glurg " STATIC")
        elseif (arg_LINK MATCHES PLUGIN)
            set(arg_SHARED ON)
            set(arg_STATIC OFF)
            set(arg_PLUGIN ON)
            set(glurg " SHARED")
        else ()
            if (arg_PLUGIN)
                if (arg_SHARED AND arg_STATIC)
                    message(FATAL_ERROR "Only 'PLUGIN SHARED', 'SHARED', or 'STATIC' allowed")
                elseif (arg_STATIC)
                    message(FATAL_ERROR "Plugins must be 'SHARED' libraries")
                endif ()
                if (NOT arg_SHARED)
                    message(WARNING "Plugins must be 'SHARED' libraries, SHARED has been set")
                    set(arg_SHARED ON)
                    set(arg_LINK "SHARED")
                    set(glurg " SHARED")
                else ()
                    set(glurg " SHARED")
                endif ()
            elseif (arg_STATIC AND arg_SHARED)
                message(FATAL_ERROR "Only 'PLUGIN SHARED', 'SHARED', or 'STATIC' allowed")
            elseif (arg_SHARED)
                set(arg_LINK "SHARED")
                set(glurg " SHARED")
            else ()
                set(arg_LINK "STATIC")
                set(glurg " STATIC")
            endif ()
        endif ()
    else ()
        set(arg_SHARED OFF)
        set(arg_STATIC OFF)
        set(arg_PLUGIN OFF)
        set(glurg "")

    endif ()

    if (arg_PLUGIN)
        set(PLUGIN_ENNUCIATOR "plug-in")
    elseif(arg_EXECUTABLE)
        set(PLUGIN_ENNUCIATOR "executable app")
    else ()
        set(PLUGIN_ENNUCIATOR "library")
    endif ()

    # Diagnostic logging
    string(LENGTH ${arg_NAME} THIS_LEN)
    if (NOT DEFINED LONGEST_LIBRARY_NAME_SO_FAR)
        string(LENGTH "Appearance" LONGEST_LIBRARY_NAME_SO_FAR)
        set(LONGEST_LIBRARY_NAME_SO_FAR ${LONGEST_LIBRARY_NAME_SO_FAR} CACHE STRING "")
    endif ()
    if (${THIS_LEN} GREATER ${LONGEST_LIBRARY_NAME_SO_FAR})
        set(LONGEST_LIBRARY_NAME_SO_FAR ${THIS_LEN})
        set(LONGEST_LIBRARY_NAME_SO_FAR ${LONGEST_LIBRARY_NAME_SO_FAR} CACHE STRING "" FORCE)
    endif ()
    math(EXPR NUM_SPACES_REQD "${LONGEST_LIBRARY_NAME_SO_FAR} - ${THIS_LEN}")
    if (${NUM_SPACES_REQD} LESS 0)
        set(NUM_SPACES_REQD 0)
    endif ()
    set(GAP_CHARS "                                                ")
    string(SUBSTRING "${GAP_CHARS}" 0 ${NUM_SPACES_REQD} THE_SPACES)
    message("Creating${glurg} ${PLUGIN_ENNUCIATOR} ${THE_SPACES}'${arg_NAME}' Version ${arg_VERSION}")

    string(TOLOWER ${arg_NAME} arg_NAME_LC)
    string(TOLOWER ${APP_VENDOR} arg_VENDOR_LC)

    # Create the library (maybe)
    if (NOT TARGET ${arg_NAME})
        if (arg_PLUGIN)
            add_library(${arg_NAME} SHARED)
        elseif (arg_EXECUTABLE)
            add_executable(${arg_NAME} ${PlatformFlag})
        else ()
            add_library(${arg_NAME} ${arg_LINK})
            if (arg_PRIMARY)
                add_library(${APP_VENDOR}::${APP_NAME} ALIAS ${arg_NAME})
            endif ()
        endif ()
    endif ()

    # Add sources only to the new library
    if (arg_HEADERS)
        # Public headers from the source/include tree
        # Use generator expressions in BASE_DIRS so build-tree (source) paths do not leak into the install export
        target_sources(${arg_NAME}
                ${arg_HEADER_VISIBILITY}
                FILE_SET ${arg_HEADERS_FILE_SET} TYPE HEADERS
                BASE_DIRS ${arg_BASE_DIRS}
                FILES ${arg_HEADERS}
        )
    endif ()
    if (arg_SOURCES)
        target_sources(${arg_NAME}
                ${arg_SOURCE_VISIBILITY}
                ${arg_SOURCES}
        )
    endif ()
    if (arg_MODULES)

        target_sources(${arg_NAME}
                ${arg_MODULE_VISIBILITY}
                FILE_SET ${arg_CXX_MODULES_FILE_SET} TYPE CXX_MODULES
                BASE_DIRS ${arg_CXX_BASE_DIRS}
                FILES ${arg_MODULES}
        )

        set_source_files_properties(${arg_MODULES} PROPERTIES
                # PCH must not be applied to C++ module interface units (.ixx):
                # Clang 21 processes the global module fragment with separate include
                # state from the PCH. _LIBCPP_HIDE_FROM_ABI functions tagged with
                # [[abi_tag("ne210105")]] (new in libc++ 21) end up defined twice in
                # the same compilation unit — once from the PCH and once from the
                # module's global fragment — producing "definition with same mangled
                # name" hard errors. Disabling PCH for module files is the correct
                # fix; the wx_pch.h comment already noted this intent.
                SKIP_PRECOMPILE_HEADERS ON
                CXX_SCAN_FOR_MODULES ON
        )
    endif ()

    # Configure the library
    if (arg_PLUGIN)
        set(LIB_SUF ".plugin")
        set(LIB_OUTPUT_NAME "${arg_NAME}")
    elseif (arg_EXECUTABLE)
        set(LIB_SUF ${CMAKE_EXECUTABLE_SUFFIX})
        set(LIB_OUTPUT_NAME "${arg_NAME}")
    else ()
        set(LIB_PRE ${CMAKE_${arg_LINK}_LIBRARY_PREFIX})
        set(LIB_SUF ${CMAKE_${arg_LINK}_LIBRARY_SUFFIX})
        set(LIB_OUTPUT_NAME "${arg_VENDOR_LC}_${arg_NAME_LC}")
    endif ()

    # SO_VERSION may be empty if framework.cmake ran before AppSpecific.cmake set APP_VERSION
    # (include_guard fires before per-library setup). Derive from arg_VERSION as a fallback.
    set(_hs_so_ver "${SO_VERSION}")
    if(NOT _hs_so_ver AND arg_VERSION)
        SplitAt("${arg_VERSION}" "." _hs_so_ver _hs_so_dc)
        unset(_hs_so_dc)
    endif()

    # @formatter:off
    set_target_properties(${arg_NAME} PROPERTIES
            CXX_EXTENSIONS              OFF
            CXX_STANDARD                23
            CXX_STANDARD_REQUIRED       ON
            OUTPUT_NAME                 ${LIB_OUTPUT_NAME}
            POSITION_INDEPENDENT_CODE   ON
            PREFIX                      "${LIB_PRE}"
            SUFFIX                      "${LIB_SUF}"
            SOVERSION                   "${_hs_so_ver}"
            VERSION                     "${arg_VERSION}"
    )
    unset(_hs_so_ver)

    if (APP_TYPE STREQUAL Executable)
        set_target_properties(${arg_NAME} PROPERTIES NO_SONAME ON)
    endif ()

    # Explicitly add the compile feature to help the exporter
    target_compile_features(${arg_NAME} PUBLIC cxx_std_23)

    # Compile and link options
    string(TOUPPER ${arg_NAME} arg_NAME_UC)
    target_compile_definitions(${arg_NAME}      PUBLIC  ${arg_NAME}_EXPORTS ${HS_DefinesList})
    target_compile_options(${arg_NAME}          PUBLIC  ${HS_CompileOptionsList})

    # Expose only install-time include paths to consumers; keep build-time includes private to avoid leaking
    target_include_directories(${arg_NAME}
            PRIVATE
            ${HS_IncludePathsList}
            PUBLIC
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}>
    )
    target_link_directories(${arg_NAME}         PRIVATE $<BUILD_INTERFACE:${HS_LibraryPathsList}>)
    target_link_libraries(${arg_NAME}           PRIVATE ${arg_DEPENDS})
    target_link_options(${arg_NAME}             PUBLIC  ${HS_LinkOptionsList})

    # Link Core
    if (CORE IN_LIST arg_USES)
        target_link_libraries(${arg_NAME}       PRIVATE ${APP_VENDOR}::Core)
        add_dependencies(${arg_NAME}                    ${APP_VENDOR}::Core)
    endif ()

    # Link Gfx
    if (GFX IN_LIST arg_USES)
        target_link_libraries(${arg_NAME}       PRIVATE ${APP_VENDOR}::Gfx)
        add_dependencies(${arg_NAME}                    ${APP_VENDOR}::Gfx)
    endif ()

    # ── Precompile Headers ──────────────────────────────────────────────────────
    #
    # Non-WIN32 (Linux / macOS — libc++ / libstdc++):
    #   core_pch.h   : STL headers, applied to all targets via per-target PCH.
    #   wx_pch.h     : wx + Windows SDK headers, added on top for GUI targets.
    #   .ixx files   : SKIP_PRECOMPILE_HEADERS ON (see MODULES block above) to
    #                  avoid the libc++ 21 abi_tag double-definition hard error.
    #
    # WIN32 (native Windows or cross-compile targeting Windows):
    #   MSVC STL and MinGW libstdc++ do NOT have the libc++ abi_tag problem, so
    #   PCH CAN be applied to .ixx files.  A SHARED binary is compiled once and
    #   injected into every compilation — including .ixx — via an explicit
    #   -include-pch flag.  Because all Gfx BMIs are compiled with the same binary,
    #   and downstream consumers (HealthCanvas) use that same binary, the SLOC entries
    #   for wx / Windows SDK headers are loaded ONCE rather than once per BMI.
    #   Without this, loading 60+ Gfx BMIs exhausts Clang's 2 GB SLOC limit.
    #
    #   PCH binary location depends on role:
    #     Builder (Gfx main lib / Gfx internal plugins): ${CMAKE_BINARY_DIR}/pch/
    #       — lives in the build tree, isolated per preset; promoted to staging by
    #         the install step.
    #     Consumer (HealthCanvas, targets with GFX in arg_USES): staged path
    #       ${CMAKE_INSTALL_PREFIX}/lib/cmake/pch/${APP_VENDOR}/ — the binary must
    #         have been deployed there by a prior Gfx install step.
    # ────────────────────────────────────────────────────────────────────────────

    if (WIN32 AND GUI IN_LIST arg_USES AND GUI IN_LIST APP_FEATURES)
        # All WIN32 GUI targets (Gfx main library, Gfx plugins, HealthCanvas) must use
        # the SAME shared PCH binary.  Every compilation that loads a Gfx BMI must
        # include the same PCH so Clang's module ODR checker sees consistent wx
        # class definitions across all translation units and BMIs.
        if (GFX IN_LIST arg_USES)
            # Consumer (HealthCanvas / external plugins): find PCH staged by Gfx install
            set(_hs_pch_dir "${CMAKE_INSTALL_PREFIX}/lib/cmake/pch/${APP_VENDOR}")
        else()
            # Builder (Gfx main library / Gfx internal plugins): build artifact → build tree
            set(_hs_pch_dir "${CMAKE_BINARY_DIR}/pch")
        endif()
        set(_hs_pch_bin "${_hs_pch_dir}/wx_pch.gch")

        if (NOT GFX IN_LIST arg_USES)
            # This is the wx-provider (Gfx main library). Build the shared PCH
            # binary here; plugins and consumers depend on it transitively.
            if (NOT TARGET _hs_wx_pch)
                set(_hs_wx_I "")
                foreach(_inc IN LISTS HS_wxIncludePaths)
                    if(_inc)
                        list(APPEND _hs_wx_I "-I${_inc}")
                    endif()
                endforeach()
                set(_hs_wx_D "")
                foreach(_def IN LISTS HS_wxDefines)
                    if(NOT "${_def}" MATCHES "^-D")
                        list(APPEND _hs_wx_D "-D${_def}")
                    else()
                        list(APPEND _hs_wx_D "${_def}")
                    endif()
                endforeach()
                # Target triple for cross-compile (empty on native builds)
                set(_hs_pch_target_flag "")
                if(CMAKE_CXX_COMPILER_TARGET)
                    set(_hs_pch_target_flag "--target=${CMAKE_CXX_COMPILER_TARGET}")
                endif()
                # Toolchain-provided sysroot/system-include flags (e.g. -nostdinc + -isystem)
                separate_arguments(_hs_pch_cxx_flags UNIX_COMMAND "${CMAKE_CXX_FLAGS}")
                # Directory-level compile definitions (e.g. _UCRT, _WIN32_WINNT from toolchain
                # add_compile_definitions — not in CMAKE_CXX_FLAGS)
                get_directory_property(_hs_pch_dir_defs COMPILE_DEFINITIONS)
                set(_hs_pch_dir_D "")
                foreach(_def IN LISTS _hs_pch_dir_defs)
                    if(_def)
                        if(NOT "${_def}" MATCHES "^-D")
                            list(APPEND _hs_pch_dir_D "-D${_def}")
                        else()
                            list(APPEND _hs_pch_dir_D "${_def}")
                        endif()
                    endif()
                endforeach()
                unset(_hs_pch_dir_defs)
                file(MAKE_DIRECTORY "${_hs_pch_dir}")
                add_custom_command(
                    OUTPUT  "${_hs_pch_bin}"
                    COMMAND ${CMAKE_COMMAND} -E make_directory "${_hs_pch_dir}"
                    COMMAND ${CMAKE_CXX_COMPILER}
                            ${_hs_pch_target_flag}
                            ${_hs_pch_cxx_flags}
                            "-std=c++23"
                            "$<IF:$<CONFIG:Debug>,-O0,-O2>"
                            "-D$<IF:$<CONFIG:Debug>,_DEBUG,NDEBUG>"
                            "-D_DLL" "-D_MT"
                            "-Xclang"
                            "$<IF:$<CONFIG:Debug>,--dependent-lib=msvcrtd,--dependent-lib=msvcrt>"
                            ${_hs_pch_dir_D}
                            ${_hs_wx_D}
                            ${_hs_wx_I}
                            ${HS_wxCompilerOptions}
                            "-fno-implicit-modules"
                            "-fno-implicit-module-maps"
                            "-Wno-deprecated-declarations"
                            "-Wno-ignored-attributes"
                            "-x" "c++-header"
                            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/pch/wx_pch.h"
                            "-o" "${_hs_pch_bin}"
                    DEPENDS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/pch/wx_pch.h"
                    COMMENT "Building shared wx PCH -> ${_hs_pch_bin}"
                    VERBATIM
                )
                unset(_hs_pch_target_flag)
                unset(_hs_pch_cxx_flags)
                unset(_hs_pch_dir_D)
                add_custom_target(_hs_wx_pch DEPENDS "${_hs_pch_bin}")
                install(FILES "${_hs_pch_bin}" DESTINATION "lib/cmake/pch/${APP_VENDOR}")
            endif()
        endif()

        # Apply shared PCH to ALL WIN32 GUI targets via target_compile_options
        # (bypasses SKIP_PRECOMPILE_HEADERS, reaches .ixx files too).
        target_compile_options(${arg_NAME} PRIVATE "-include-pch;${_hs_pch_bin}")
        if (TARGET _hs_wx_pch)
            add_dependencies(${arg_NAME} _hs_wx_pch)
        endif()

        unset(_hs_wx_I)
        unset(_hs_wx_D)
    else ()
        # Non-WIN32 or WIN32 non-GUI: STL-only PCH.
        target_precompile_headers(${arg_NAME} PRIVATE
            "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/pch/core_pch.h"
        )
    endif ()

    # Link wxWidgets directly (no Widgets wrapper library)
    if (GUI IN_LIST arg_USES AND GUI IN_LIST APP_FEATURES)
        target_compile_definitions(${arg_NAME}  PRIVATE
            ${HS_wxDefines}
            USING_WIDGETS
            USING_wxWidgets
            _FILE_OFFSET_BITS=64
        )
        if (NOT WIN32)
            # wx PCH (non-WIN32 GUI targets only).
            # On WIN32 the shared wx_pch.gch built above covers these headers.
            # Do NOT define WX_PRECOMP — that activates wx's own PCH mechanism and conflicts.
            target_precompile_headers(${arg_NAME} PRIVATE
                "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/pch/wx_pch.h"
            )
        endif ()
        if (${BUILD_TYPE} STREQUAL "Debug")
            target_compile_definitions(${arg_NAME}  PRIVATE DEBUG _DEBUG)
        else ()
            target_compile_definitions(${arg_NAME}  PRIVATE NDEBUG)
        endif ()

        target_compile_options(${arg_NAME}      PRIVATE ${HS_wxCompilerOptions})
        target_include_directories(${arg_NAME}  PRIVATE ${HS_wxIncludePaths})
        target_link_directories(${arg_NAME}     PRIVATE ${HS_wxLibraryPaths})
        if(NOT (WIN32 AND GFX IN_LIST arg_USES))
            # On WIN32, GFX consumers get wx symbols from libhoffsoft_gfx.dll.a
            # (Gfx.dll is built with --export-all-symbols). Linking static wx alongside
            # the import lib produces duplicate symbol errors.
            target_link_libraries(${arg_NAME} PRIVATE ${HS_wxLibraries} ${HS_wxFrameworks})
        endif()
        target_link_options(${arg_NAME}     PRIVATE ${HS_wxLinkOptions})
    endif ()
    # @formatter:on

    unset(arg_NAME_UC)
    unset(arg_NAME_LC)

endfunction()
