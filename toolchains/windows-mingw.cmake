# cmake/toolchains/windows-mingw.cmake
# Clang 21 cross-compile targeting Windows x86-64 via MinGW-w64

set(CMAKE_SYSTEM_NAME Windows)
set(CMAKE_SYSTEM_PROCESSOR x86_64)

# Toolchain paths
set(MINGW_SYSROOT /usr/x86_64-w64-mingw32/sys-root/mingw)
set(MINGW_TARGET x86_64-w64-mingw32)
set(MINGW_GCC_VER 15.1.0)

# Compilers — use your native Clang 21 with Windows target
set(CMAKE_C_COMPILER   clang)
set(CMAKE_CXX_COMPILER clang++)
set(CMAKE_C_COMPILER_TARGET   ${MINGW_TARGET})
set(CMAKE_CXX_COMPILER_TARGET ${MINGW_TARGET})

# Linker
set(CMAKE_LINKER lld)
set(CMAKE_EXE_LINKER_FLAGS_INIT    "-fuse-ld=lld")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fuse-ld=lld")

# Sysroot
set(CMAKE_SYSROOT ${MINGW_SYSROOT})
set(CMAKE_FIND_ROOT_PATH ${MINGW_SYSROOT})

# Resource compiler (for wxWidgets .rc files)
set(CMAKE_RC_COMPILER /usr/bin/x86_64-w64-mingw32-windres)

# C++ include paths (GCC headers inside sysroot)
include_directories(SYSTEM
    ${MINGW_SYSROOT}/include/c++/${MINGW_GCC_VER}
    ${MINGW_SYSROOT}/include/c++/${MINGW_GCC_VER}/${MINGW_TARGET}
    ${MINGW_SYSROOT}/lib/gcc/${MINGW_TARGET}/${MINGW_GCC_VER}/include
)

# Tell CMake to search only in the cross sysroot, not the host
set(CMAKE_FIND_ROOT_PATH_MODE_PROGRAM NEVER)  # host tools (cmake, ninja etc)
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY ONLY)   # target libs
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE ONLY)   # target headers
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE ONLY)   # target cmake packages

# Windows target version — 0x0A00 = Windows 10
add_compile_definitions(
    _WIN32_WINNT=0x0A00
    WINVER=0x0A00
    WIN32_LEAN_AND_MEAN
    UNICODE
    _UNICODE
)
set(CMAKE_EXE_LINKER_FLAGS_INIT    "-fuse-ld=lld -Wl,--major-os-version,10 -Wl,--minor-os-version,0")
set(CMAKE_SHARED_LINKER_FLAGS_INIT "-fuse-ld=lld -Wl,--major-os-version,10 -Wl,--minor-os-version,0")
set(CMAKE_MODULE_LINKER_FLAGS_INIT "-fuse-ld=lld -Wl,--major-os-version,10 -Wl,--minor-os-version,0")

