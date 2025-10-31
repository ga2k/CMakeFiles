function(addLibrary)
    cmake_parse_arguments(arg
            "PLUGIN;STATIC;SHARED;MULTI_LIBS;PRIMARY"
            "NAME;PATH;VERSION;LINK;HEADER_VISIBILITY;SOURCE_VISIBILITY;MODULE_VISIBILITY"
            "HEADERS;SOURCES;SOURCE;MODULES;LIBS;DEPENDS;USES"
            ${ARGN}
    )
    get_filename_component(LIB_PATH ${CMAKE_PARENT_LIST_FILE} DIRECTORY)
    get_filename_component(LIB_NAME ${LIB_PATH} NAME)

    if (NOT arg_HEADER_VISIBILITY)
        set(arg_HEADER_VISIBILITY "PRIVATE")
    else ()
        string(TOUPPER ${arg_HEADER_VISIBILITY} arg_HEADER_VISIBILITY)
    endif ()

    if (NOT arg_SOURCE_VISIBILITY)
        set(arg_SOURCE_VISIBILITY "PRIVATE")
    else ()
        string(TOUPPER ${arg_SOURCE_VISIBILITY} arg_SOURCE_VISIBILITY)
    endif ()

    if (NOT arg_MODULE_VISIBILITY)
        set(arg_MODULE_VISIBILITY "PRIVATE")
    else ()
        string(TOUPPER ${arg_MODULE_VISIBILITY} arg_MODULE_VISIBILITY)
    endif ()

    if (arg_SOURCES)
        list(APPEND arg_SOURCE ${arg_SOURCES})
    endif ()

    if (arg_DEPENDS)
        list(APPEND arg_LIBS ${arg_DEPENDS})
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

    string(TOUPPER "${arg_USES}" arg_USES)

    if (arg_LINK MATCHES SHARED)
        set(arg_SHARED ON)
        set(arg_STATIC OFF)
        set(arg_PLUGIN OFF)
    elseif (arg_LINK MATCHES STATIC)
        set(arg_SHARED OFF)
        set(arg_STATIC ON)
        set(arg_PLUGIN OFF)
    elseif (arg_LINK MATCHES PLUGIN)
        set(arg_SHARED ON)
        set(arg_STATIC OFF)
        set(arg_PLUGIN ON)
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
                set(arg_LINK SHARED)
            else ()
                set(arg_LINK SHARED)
            endif ()
        elseif (arg_STATIC AND arg_SHARED)
            message(FATAL_ERROR "Only 'PLUGIN SHARED', 'SHARED', or 'STATIC' allowed")
        elseif (arg_SHARED)
            set(arg_LINK SHARED)
        else ()
            set(arg_LINK STATIC)
        endif ()
    endif ()

    if (arg_PLUGIN)
        set(PLUGIN_ENNUCIATOR "plug-in")
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
    message("Creating ${arg_LINK} ${PLUGIN_ENNUCIATOR} ${THE_SPACES}'${arg_NAME}' Version ${arg_VERSION}")

    string(TOLOWER ${arg_NAME} arg_NAME_LC)
    string(TOLOWER ${APP_VENDOR} arg_VENDOR_LC)

    # Create the library (maybe)
    if (NOT TARGET ${arg_NAME})
        if (arg_PLUGIN)
            add_library(${arg_NAME} SHARED)
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
                PUBLIC FILE_SET HEADERS
                BASE_DIRS
                ${HEADER_BASE_DIRS}
                FILES
                ${arg_HEADERS}
        )
    endif ()
    if (arg_SOURCE)
        target_sources(${arg_NAME}
                PRIVATE #${arg_SOURCE_VISIBILITY}
                ${arg_SOURCE}
        )
    endif ()
    if (arg_MODULES)
        # Register C++20 modules with a dedicated FILE_SET so CMake knows about BMI/PCM generation and installation.
        # Keep BASE_DIRS empty (from CXX_BASE_DIRS) to avoid exporting source-tree paths; install handles PCM separately.
        target_sources(${arg_NAME}
                PUBLIC FILE_SET CXX_MODULES
                BASE_DIRS ${CXX_BASE_DIRS}
                FILES
                ${arg_MODULES}
        )
    endif ()

    # Configure the library
    if (arg_PLUGIN)
        set(LIB_PRE "")
        set(LIB_SUF ".plugin")
#        set(LIB_ARCHIVE_DIR "${OUTPUT_DIR}/plugins")
#        set(LIB_LIBRARY_DIR "${OUTPUT_DIR}/plugins")
#        set(LIB_RUNTIME_DIR "${OUTPUT_DIR}/plugins")
        set(LIB_OUTPUT_NAME "${arg_NAME}")
    else ()
        set(LIB_PRE ${CMAKE_${arg_LINK}_LIBRARY_PREFIX})
        set(LIB_SUF ${CMAKE_${arg_LINK}_LIBRARY_SUFFIX})
#        set(LIB_ARCHIVE_DIR "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
#        set(LIB_LIBRARY_DIR "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
#        set(LIB_RUNTIME_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")
        set(LIB_OUTPUT_NAME "${arg_VENDOR_LC}_${arg_NAME_LC}")
    endif ()
    set(LIB_ARCHIVE_DIR "${CMAKE_ARCHIVE_OUTPUT_DIRECTORY}")
    set(LIB_LIBRARY_DIR "${CMAKE_LIBRARY_OUTPUT_DIRECTORY}")
    set(LIB_RUNTIME_DIR "${CMAKE_RUNTIME_OUTPUT_DIRECTORY}")

    if (arg_MULTI_LIBS AND CURRENT_GFX_LIB)
        set (MULTI_LIB_DECLARATOR "_${CURRENT_GFX_LIB}")
    else ()
        set (MULTI_LIB_DECLARATOR)
    endif ()

    # @formatter:off
    set_target_properties(${arg_NAME} PROPERTIES
            ARCHIVE_OUTPUT_DIRECTORY    "${LIB_ARCHIVE_DIR}"
            CXX_EXTENSIONS              OFF
            CXX_STANDARD                23
            CXX_STANDARD_REQUIRED       ON
            LIBRARY_OUTPUT_DIRECTORY    "${LIB_LIBRARY_DIR}"
            OUTPUT_NAME                 "${LIB_OUTPUT_NAME}${MULTI_LIB_DECLARATOR}"
            POSITION_INDEPENDENT_CODE   ON
            PREFIX                      "${LIB_PRE}"
            RUNTIME_OUTPUT_DIRECTORY    "${LIB_RUNTIME_DIR}"
            SOVERSION                   "${arg_VERSION}"
            SUFFIX                      "${LIB_SUF}"
            VERSION                     "${arg_VERSION}"
    )

    # Compile and link options
    string(TOUPPER ${arg_NAME} arg_NAME_UC)
    target_compile_definitions(${arg_NAME}      PUBLIC  BUILDING_${arg_NAME_UC} ${HS_DefinesList})
    target_compile_options(${arg_NAME}          PUBLIC  ${HS_CompileOptionsList})

    # Expose only install-time include paths to consumers; keep build-time includes private to avoid leaking
    target_include_directories(${arg_NAME}
            PRIVATE
            ${HS_IncludePathsList}
            PUBLIC
#            $<BUILD_INTERFACE:${HEADER_BASE_DIRS}>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}/${arg_NAME}>
            $<INSTALL_INTERFACE:${CMAKE_INSTALL_INCLUDEDIR}/${APP_VENDOR}/overrides/magic_enum/include>
    )
    target_link_directories(${arg_NAME}         PRIVATE $<BUILD_INTERFACE:${HS_LibraryPathsList}>)
    target_link_libraries(${arg_NAME}           PRIVATE ${arg_LIBS})
    target_link_options(${arg_NAME}             PUBLIC  ${HS_LinkOptionsList})

#    # Link Core
    if (CORE IN_LIST arg_USES AND TARGET HoffSoft::Core)
        target_link_libraries(${arg_NAME}       PRIVATE HoffSoft::Core)
    endif ()

    #    # Link Gfx
    if (GFX IN_LIST arg_USES AND TARGET HoffSoft::Gfx)
        target_link_libraries(${arg_NAME}       PRIVATE HoffSoft::Gfx)
    endif ()

    # Link Widgets
    if (WIDGETS IN_LIST arg_USES AND WIDGETS IN_LIST APP_FEATURES)
        target_compile_definitions(${arg_NAME}  PRIVATE ${HS_wxDefines})
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
