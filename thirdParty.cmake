include_guard(GLOBAL)

# cmake/thirdParty.cmake
# Assumes FetchContent or add_subdirectory has provided the libs under these names.
# If they aren’t provided yet, create minimal INTERFACE wrappers that point
# at Core/external include dirs (and adjust if your FetchContent names differ).

if(MONOREPO)
    set(_external_dir "${CMAKE_SOURCE_DIR}/Core/external")
else ()
    set(_external_dir "${CMAKE_SOURCE_DIR}/external")
endif ()

# REFLECTION: magic_enum
if(NOT TARGET magic_enum::magic_enum)
    add_library(magic_enum INTERFACE)
    add_library(magic_enum::magic_enum ALIAS magic_enum)
    target_include_directories(magic_enum INTERFACE "${_external_dir}/magic_enum/include")
    target_compile_definitions(magic_enum INTERFACE MAGIC_ENUM_NO_MODULE)
endif()

# SIGNAL: eventpp (header-only)
if(NOT TARGET eventpp::eventpp)
    add_library(eventpp INTERFACE)
    add_library(eventpp::eventpp ALIAS eventpp)
    target_include_directories(magic_enum INTERFACE "${_external_dir}/eventpp/include")
endif()

# TESTING: GTest (if not pulled in yet)
# Usually provided as GTest::gtest, GTest::gtest_main by FetchContent_MakeAvailable(googletest)
# If missing, you can optionally add a fallback imported/INTERFACE – but prefer the official one.

# STORAGE: yaml-cpp (compiled lib)
# Prefer the real yaml-cpp target from FetchContent. If not yet available, you can declare an imported target
# but it’s better to rely on the one successfully built by FetchContent.