function(cpptrace_init)
    # Prefer atos on macOS for symbolization, addr2line elsewhere
    if(APPLE)
        set (CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE ON CACHE BOOL "Ok?")
        set (CPPTRACE_ADDR2LINE_PATH "/usr/bin/atos" CACHE STRING "Ok?")
        # On Apple clang, execinfo is the most compatible unwinder
        set (CPPTRACE_UNWIND_WITH_EXECINFO ON CACHE BOOL "Ok?")
        # dladdr helps resolve dso/object names
        set (CPPTRACE_UNWIND_WITH_DLADDR ON CACHE BOOL "Ok?")
        # Avoid forcing libunwind to prevent mismatched availability/config
        set (CPPTRACE_UNWIND_WITH_LIBUNWIND OFF CACHE BOOL "Ok?")
        # Ensure demangling via cxxabi when available
        set (CPPTRACE_DEMANGLE_WITH_CXXABI ON CACHE BOOL "Ok?")
    elseif(WIN32)
        # On Windows, even with Clang, WinAPI and DbgHelp are the preferred backends.
        # This works for both MSVC-style (PDB) and many MinGW/Clang setups.
        set (CPPTRACE_GET_SYMBOLS_WITH_DBGHELP ON CACHE BOOL "Ok?")
        set (CPPTRACE_UNWIND_WITH_WINAPI ON CACHE BOOL "Ok?")
    else()
        set (CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE ON CACHE BOOL "Ok?")
        set (CPPTRACE_UNWIND_WITH_LIBUNWIND ON CACHE BOOL "Ok?")
        # Ensure demangling via cxxabi when available
        set (CPPTRACE_DEMANGLE_WITH_CXXABI ON CACHE BOOL "Ok?")
    endif()

    # Keep ABI stable across headers and library by disabling any inline ABI namespaces
    # (This define is consumed by cpptrace to avoid namespace-versioned symbols on some builds)
    set_property(GLOBAL APPEND PROPERTY GLOBAL_DEFINITIONS CPPTRACE_NO_ABI_NAMESPACE)
    set(HANDLED ON)
endfunction()
