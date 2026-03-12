include_guard(GLOBAL)
function(cpptrace_init DRY_RUN)

    # @formatter:off
    # Prefer atos on macOS for symbolization, addr2line elsewhere
    if (APPLE)
        set(CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE ON  CACHE BOOL   "" FORCE)
        set(CPPTRACE_ADDR2LINE_PATH "/usr/bin/atos" CACHE STRING "" FORCE)
        # On Apple clang, execinfo is the most compatible unwinder
        set(CPPTRACE_UNWIND_WITH_EXECINFO       ON  CACHE BOOL   "" FORCE)
        # dladdr helps resolve dso/object names
        set(CPPTRACE_UNWIND_WITH_DLADDR         ON  CACHE BOOL   "" FORCE)
        # Avoid forcing libunwind to prevent mismatched availability/config
        set(CPPTRACE_UNWIND_WITH_LIBUNWIND      OFF CACHE BOOL   "" FORCE)
        # Ensure demangling via cxxabi when available
        set(CPPTRACE_DEMANGLE_WITH_CXXABI       ON  CACHE BOOL   "" FORCE)
    elseif (WIN32)
        set(CPPTRACE_GET_SYMBOLS_WITH_DBGHELP   ON  CACHE BOOL   "" FORCE)
        set(CPPTRACE_UNWIND_WITH_WINAPI         ON  CACHE BOOL   "" FORCE)
        set(CPPTRACE_DEMANGLE_WITH_WINAPI       ON  CACHE BOOL   "" FORCE)
        # Force static build to simplify linking
        set(CPPTRACE_STATIC                     ON  CACHE BOOL   "" FORCE)
    else ()
        set(CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE ON  CACHE BOOL   "" FORCE)
        set(CPPTRACE_UNWIND_WITH_LIBUNWIND      ON  CACHE BOOL   "" FORCE)
        # Ensure demangling via cxxabi when available
        set(CPPTRACE_DEMANGLE_WITH_CXXABI       ON  CACHE BOOL   "" FORCE)
    endif ()
    # @formatter:on
    # Keep ABI stable across headers and library by disabling any inline ABI namespaces
    # (This define is consumed by cpptrace to avoid namespace-versioned symbols on some builds)
    set_property(GLOBAL APPEND PROPERTY GLOBAL_DEFINITIONS CPPTRACE_NO_ABI_NAMESPACE)

    set(CPPTRACE_BUILD_TESTING OFF CACHE BOOL "" FORCE)
    set(HS_HAS_CPP_STACKTRACE ON)
    set(HANDLED ON)
endfunction()
