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

    # @formatter:off
    set_target_properties(${arg_NAME} PROPERTIES
            CXX_EXTENSIONS              OFF
            CXX_STANDARD                23
            CXX_STANDARD_REQUIRED       ON
            OUTPUT_NAME                 ${LIB_OUTPUT_NAME}
            POSITION_INDEPENDENT_CODE   ON
            PREFIX                      "${LIB_PRE}"
            SUFFIX                      "${LIB_SUF}"
            VERSION                     ${arg_VERSION}
    )

    # Runtime search path so binaries can find staged/installed shared libs next to the prefix.
    # For Linux we want: <prefix>/bin/<app> to find <prefix>/lib64/*.so via $ORIGIN/../lib64
    if(UNIX AND NOT APPLE)
        set(_rpath_origin "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
        set_target_properties(${arg_NAME} PROPERTIES
                BUILD_RPATH              "${_rpath_origin}"
                INSTALL_RPATH            "${_rpath_origin}"
                INSTALL_RPATH_USE_LINK_PATH TRUE
        )
        unset(_rpath_origin)
    endif()

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

    # Link wxWidgets directly (no Widgets wrapper library)
    if (WIDGETS IN_LIST arg_USES AND WIDGETS IN_LIST APP_FEATURES)
        target_compile_definitions(${arg_NAME}  PRIVATE 
            ${HS_wxDefines}
            USING_WIDGETS
            USING_wxWidgets
            WXUSINGDLL
            _FILE_OFFSET_BITS=64
        )
        # NOTE: PCH disabled project-wide by request; do not define WX_PRECOMP or set target_precompile_headers here
        if (${BUILD_TYPE} STREQUAL "Debug")
            target_compile_definitions(${arg_NAME}  PRIVATE DEBUG _DEBUG)
        else ()
            target_compile_definitions(${arg_NAME}  PRIVATE NDEBUG)
        endif ()

        target_compile_options(${arg_NAME}      PRIVATE ${HS_wxCompilerOptions})
        target_include_directories(${arg_NAME}  PRIVATE ${HS_wxIncludePaths})
        target_link_directories(${arg_NAME}     PRIVATE ${HS_wxLibraryPaths})
        target_link_libraries(${arg_NAME}       PRIVATE ${HS_wxLibraries} ${HS_wxFrameworks})
        target_link_options(${arg_NAME}         PRIVATE ${HS_wxLinkOptions})
    endif ()
    # @formatter:on

    unset(arg_NAME_UC)
    unset(arg_NAME_LC)

endfunction()
