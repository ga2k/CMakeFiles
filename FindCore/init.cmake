include_guard(GLOBAL)

# cpptrace is statically embedded in libhoffsoft_core.so; no target is installed.
# CMake 3.31+ loads CoreConfigVersion.cmake during find_package() version checking,
# and that file references cpptrace::cpptrace in INTERFACE_LINK_LIBRARIES. The stub
# satisfies CMake's validation and also prevents a redundant FetchContent fetch.
if(NOT TARGET cpptrace::cpptrace)
    add_library(cpptrace::cpptrace INTERFACE IMPORTED GLOBAL)
endif()

function(addCoreFeatures dry_run)
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core"
            METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dry_run})
endfunction()

function(FindCore_init dry_run)
    commonInit (Core ${dry_run})
endfunction()
