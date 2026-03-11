include("${cmake_root}/tools.cmake")

function(soci_fix target tag sourceDir)

    unset(patches)
    list(APPEND patches
            # Test whole folder
            "soci/3rdparty|${_soci_local_src}/3rdparty"
            # Test single file
            "soci/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/fmt-src/include/fmt/"

            "soci/include|${_soci_local_src}/include"

            "soci/CMakeLists.txt|${_soci_local_src}"
            "soci/cmake/soci_define_backend_target.cmake|${_soci_local_src}/cmake"

            "soci/src|${_soci_local_src}/src"
    )

    replaceFiles(soci "${patches}")

    set(HANDLED ON PARENT_SCOPE)
endfunction()
