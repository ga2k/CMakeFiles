include("${CMAKE_SOURCE_DIR}/cmake/tools.cmake")

function(soci_fix target tag sourceDir)

    unset(patches)
    list(APPEND patches
            "soci/3rdparty/fmt/include|${sourceDir}"
            "soci/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/_deps/fmt-src/include/fmt/"
            "soci/include|${sourceDir}"
            "soci/CMakeLists.txt|${sourceDir}"
            "soci/cmake/soci_define_backend_target.cmake|${sourceDir}"
            "soci/src/core/CMakeLists.txt|${sourceDir}"
            "soci/src|${sourceDir}"
    )
    patchExternals(${target} "${patches}")
    set(HANDLED ON PARENT_SCOPE)

endfunction()
