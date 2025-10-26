function(cpptrace_init)
    # Prefer atos on macOS for symbolization, addr2line elsewhere
    if(APPLE)
        forceSet(CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE "" ON BOOL)
        forceSet(CPPTRACE_ADDR2LINE_PATH "" "/usr/bin/atos" STRING)
        # On Apple clang, execinfo is the most compatible unwinder
        forceSet(CPPTRACE_UNWIND_WITH_EXECINFO "" ON BOOL)
        # dladdr helps resolve dso/object names
        forceSet(CPPTRACE_UNWIND_WITH_DLADDR "" ON BOOL)
        # Avoid forcing libunwind to prevent mismatched availability/config
        forceSet(CPPTRACE_UNWIND_WITH_LIBUNWIND "" OFF BOOL)
    else()
        forceSet(CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE "" ON BOOL)
        forceSet(CPPTRACE_UNWIND_WITH_LIBUNWIND "" ON BOOL)
        forceSet(CPPTRACE_UNWIND_WITH_DLADDR "" ON BOOL)
    endif()

    # Ensure demangling via cxxabi when available
    forceSet(CPPTRACE_DEMANGLE_WITH_CXXABI "" ON BOOL)

    # Keep ABI stable across headers and library by disabling any inline ABI namespaces
    # (This define is consumed by cpptrace to avoid namespace-versioned symbols on some builds)
    set_property(GLOBAL APPEND PROPERTY GLOBAL_DEFINITIONS CPPTRACE_NO_ABI_NAMESPACE)
endfunction()

# Disabled: replacing cpptrace with standard C++ facilities
# cpptrace_init()
# set(HANDLED ON)
