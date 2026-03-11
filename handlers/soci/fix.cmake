include("${cmake_root}/tools.cmake")

function(soci_fix target tag sourceDir)

#    if (NOT soci_PATCHED)
        unset(patches)
        set(_soci_local_src "${${target}_SOURCE_DIR}")
        list(APPEND patches
                # Test whole folder
                "${target}/3rdparty|${_soci_local_src}/3rdparty"
                # Test single file
                "${target}/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/fmt-src/include/fmt/"

                "${target}/include|${_soci_local_src}/include"

                "${target}/CMakeLists.txt|${_soci_local_src}"
#                "${target}/cmake/soci_define_backend_target.cmake|${_soci_local_src}/cmake"

                "${target}/src|${_soci_local_src}/src"
        )

        replaceFiles(soci "${patches}")
#    endif ()
#    set(soci_PATCHED ON PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)
endfunction()
