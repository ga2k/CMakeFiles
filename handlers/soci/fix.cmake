include("${CMAKE_SOURCE_DIR}/cmake/tools.cmake")

function(soci_fix target tag sourceDir)

    if (NOT "${tag}" STREQUAL "master") # v4.0.3")
        message(FATAL_ERROR "Attempting to patch wrong version of soci")
    endif ()

    list(APPEND patches
            "soci/3rdparty/fmt/include|${sourceDir}"
            "soci/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/_deps/fmt-src/include/fmt/"
            "soci/include|${sourceDir}"
            "soci/CMakeLists.txt|${sourceDir}"
            "soci/cmake/soci_define_backend_target.cmake|${sourceDir}/cmake/"
            "soci/src/core/CMakeLists.txt|${sourceDir}/src/core"
            "soci/src|${sourceDir}"
    )
    patchExternals(${target} "${patches}")
    set(HANDLED ON PARENT_SCOPE)

endfunction()
