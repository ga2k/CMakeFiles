include("${cmake_root}/tools.cmake")

function(soci_fix target tag sourceDir)

#    if (NOT soci_PATCHED)
        unset(patches)
        list(APPEND patches
                # Test whole folder
                "${target}/3rdparty|${sourceDir}/3rdparty"
                # Test single file
                "${target}/3rdparty/fmt/include/fmt/base.h|${BUILD_DIR}/fmt-src/include/fmt/"

                "${target}/include|${sourceDir}/include"

                "${target}/CMakeLists.txt|${sourceDir}"
                "${target}/cmake/soci_define_backend_target.cmake|${sourceDir}/cmake"

                "${target}/src|${sourceDir}/src"
        )

        replaceFiles(soci "${patches}")
#    endif ()
#    set(soci_PATCHED ON PARENT_SCOPE)

    set(HANDLED ON PARENT_SCOPE)
endfunction()
