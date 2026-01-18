function(cpptrace_init)
    # Prefer atos on macOS for symbolization, addr2line elsewhere
    if(APPLE)
        set (CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE ON CACHE BOOL "")
        set (CPPTRACE_ADDR2LINE_PATH "/usr/bin/atos" CACHE STRING "")
        # On Apple clang, execinfo is the most compatible unwinder
        set (CPPTRACE_UNWIND_WITH_EXECINFO ON CACHE BOOL "")
        # dladdr helps resolve dso/object names
        set (CPPTRACE_UNWIND_WITH_DLADDR ON CACHE BOOL "")
        # Avoid forcing libunwind to prevent mismatched availability/config
        set (CPPTRACE_UNWIND_WITH_LIBUNWIND OFF CACHE BOOL "")
        # Ensure demangling via cxxabi when available
        set (CPPTRACE_DEMANGLE_WITH_CXXABI ON CACHE BOOL "")
    elseif(WIN32)
        # On Windows, even with Clang, WinAPI and DbgHelp are the preferred backends.
        # This works for both MSVC-style (PDB) and many MinGW/Clang setups.
        set (CPPTRACE_GET_SYMBOLS_WITH_DBGHELP ON CACHE BOOL "")
        set (CPPTRACE_UNWIND_WITH_WINAPI ON CACHE BOOL "")

        # Force static build to simplify linking
        set(CPPTRACE_STATIC ON CACHE BOOL "" FORCE)

    else()
        set (CPPTRACE_GET_SYMBOLS_WITH_ADDR2LINE ON CACHE BOOL "")
        set (CPPTRACE_UNWIND_WITH_LIBUNWIND ON CACHE BOOL "")
        # Ensure demangling via cxxabi when available
        set (CPPTRACE_DEMANGLE_WITH_CXXABI ON CACHE BOOL "")
    endif()

    # Keep ABI stable across headers and library by disabling any inline ABI namespaces
    # (This define is consumed by cpptrace to avoid namespace-versioned symbols on some builds)
    set_property(GLOBAL APPEND PROPERTY GLOBAL_DEFINITIONS CPPTRACE_NO_ABI_NAMESPACE)
    set(HANDLED ON)
endfunction()
