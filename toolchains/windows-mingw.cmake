# cmake/toolchains/windows-mingw.cmake
# Clang 21 cross-compile targeting Windows x86-64 via MinGW-w64

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Toolchain paths
set(MINGW_SYSROOT /usr/x86_64-w64-mingw32/sys-root/mingw)
set(MINGW_TARGET  x86_64-w64-mingw32)
set(MINGW_GCC_VER 15.1.0)

# Compilers — native Clang 21 with Windows target triple
set(CMAKE_MAKE_PROGRAM /usr/bin/ninja      CACHE FILEPATH "" FORCE)
set(CMAKE_C_COMPILER   /usr/bin/clang)
set(CMAKE_CXX_COMPILER /usr/bin/clang++)
set(CMAKE_C_COMPILER_TARGET   ${MINGW_TARGET})
set(CMAKE_CXX_COMPILER_TARGET ${MINGW_TARGET})

# Resource compiler (for wxWidgets .rc files)
set(CMAKE_RC_COMPILER /usr/bin/x86_64-w64-mingw32-windres)

# Sysroot
set(CMAKE_SYSROOT        ${MINGW_SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${MINGW_SYSROOT})

# Tell CMake to search only in the cross sysroot, not the host
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)  # host tools (cmake, ninja, etc.)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)   # target libs
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)   # target headers
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)   # target cmake packages

# Resolve Clang's resource dir for builtins (avoids GCC 15 intrinsic conflicts)
execute_process(
        COMMAND clang --target=${MINGW_TARGET} -print-resource-dir
        OUTPUT_VARIABLE CLANG_RESOURCE_DIR
        OUTPUT_STRIP_TRAILING_WHITESPACE
)

# Include paths — Clang resource dir first to win intrinsic header conflicts
# against GCC 15's x86intrin.h/ia32intrin.h, then MinGW sysroot headers.
# GCC's include dir is intentionally excluded; include-fixed is kept for
# compatibility shims that are safe with Clang.
set(CMAKE_C_FLAGS_INIT
        "-nostdinc \
     -isystem ${CLANG_RESOURCE_DIR}/include \
     -isystem ${MINGW_SYSROOT}/include \
     -isystem ${MINGW_SYSROOT}/lib/gcc/${MINGW_TARGET}/${MINGW_GCC_VER}/include-fixed")

set(CMAKE_CXX_FLAGS_INIT
        "-nostdinc \
     -isystem ${CLANG_RESOURCE_DIR}/include \
     -isystem ${MINGW_SYSROOT}/include/c++/${MINGW_GCC_VER} \
     -isystem ${MINGW_SYSROOT}/include/c++/${MINGW_GCC_VER}/${MINGW_TARGET} \
     -isystem ${MINGW_SYSROOT}/include/c++/${MINGW_GCC_VER}/backward \
     -isystem ${MINGW_SYSROOT}/include \
     -isystem ${MINGW_SYSROOT}/lib/gcc/${MINGW_TARGET}/${MINGW_GCC_VER}/include-fixed")

# Linker — LLD, static GCC/C++ runtime, static winpthreads, Windows 10 PE header
set(_COMMON_LINKER_FLAGS
        "-fuse-ld=lld \
     -static-libgcc -static-libstdc++ \
     -Wl,-Bstatic -lpthread -Wl,-Bdynamic \
     -Wl,--major-os-version,10 -Wl,--minor-os-version,0")
set(CMAKE_EXE_LINKER_FLAGS_INIT    ${_COMMON_LINKER_FLAGS})
set(CMAKE_SHARED_LINKER_FLAGS_INIT ${_COMMON_LINKER_FLAGS})
set(CMAKE_MODULE_LINKER_FLAGS_INIT ${_COMMON_LINKER_FLAGS})

# Windows target version and character set
# Note: WIN32_LEAN_AND_MEAN is intentionally omitted here — it strips shell
# APIs that wxWidgets requires. Define it per-target in your own code if needed.
add_compile_definitions(
        _WIN32_WINNT=0x0A00
        WINVER=0x0A00
        UNICODE
        _UNICODE
        NOMINMAX
)