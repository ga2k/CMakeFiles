function(wxWidgets_preDownload pkgname url tag srcDir)

    # Use a persistent local clone so wxWidgets survives `make clean`
    set(_wx_local_src "${ARCHIVE_DIR}/wxWidgets/source")
    if (EXISTS "${_wx_local_src}" AND NOT EXISTS "${_wx_local_src}/CMakeLists.txt")
        file(REMOVE_RECURSE "${_wx_local_src}")
    endif ()

    if (NOT EXISTS "${_wx_local_src}/CMakeLists.txt")

        # Download as a tarball — avoids the git ≥2.47 lazy objects/pack/ bug
        # that causes index-pack to fail on any fresh clone on this system.
        message(STATUS "Downloading wxWidgets to ${_wx_local_src} (one-time)...")
        file(MAKE_DIRECTORY "${ARCHIVE_DIR}/wxWidgets")
        set(_wx_tar "${ARCHIVE_DIR}/wxWidgets/wxWidgets-master.tar.gz")
        file(DOWNLOAD
            "https://github.com/wxWidgets/wxWidgets/archive/refs/heads/master.tar.gz"
            "${_wx_tar}"
            STATUS _dl_status
        )
        list(GET _dl_status 0 _dl_result)
        if (NOT _dl_result EQUAL 0)
            message(FATAL_ERROR "Failed to download wxWidgets: ${_dl_status}")
        endif ()
        if (NOT EXISTS "${_wx_tar}")
            message(FATAL_ERROR "wxWidgets download produced no file (status was ${_dl_status})")
        endif ()
        file(SIZE "${_wx_tar}" _wx_tar_size)
        if (_wx_tar_size LESS 65536)
            file(READ "${_wx_tar}" _wx_tar_head LIMIT 256 HEX)
            message(FATAL_ERROR "wxWidgets download too small (${_wx_tar_size} bytes) — HTTP error or rate-limit? First bytes: ${_wx_tar_head}")
        endif ()
        set(_wx_tmp "${ARCHIVE_DIR}/wxWidgets/_extract_tmp")
        file(MAKE_DIRECTORY "${_wx_tmp}")
        file(ARCHIVE_EXTRACT INPUT "${_wx_tar}" DESTINATION "${_wx_tmp}")
        file(GLOB _wx_extracted LIST_DIRECTORIES true "${_wx_tmp}/wxWidgets-*")
        if (NOT _wx_extracted)
            message(FATAL_ERROR "Could not find extracted wxWidgets dir in ${_wx_tmp}")
        endif ()
        list(GET _wx_extracted 0 _wx_extracted)
        file(RENAME "${_wx_extracted}" "${_wx_local_src}")
        file(REMOVE_RECURSE "${_wx_tmp}")
        file(REMOVE "${_wx_tar}")

    else ()

        message(STATUS "Using already downloaded copy of wxWidgets")

    endif ()

    # Download wxWidgets submodules — GitHub tarballs don't include submodule content.
    # Skipped: src/stc/scintilla, src/stc/lexilla (wxUSE_STC OFF), 3rdparty/catch (tests only).
    set(_wx_submodules
        "src/zlib|zlib|CMakeLists.txt"
        "src/png|libpng|CMakeLists.txt"
        "src/expat|libexpat|expat/lib/expat.h"
        "src/tiff|libtiff|CMakeLists.txt"
        "src/jpeg|libjpeg-turbo|jconfig.h"
        "3rdparty/pcre|pcre|CMakeLists.txt"
        "3rdparty/nanosvg|nanosvg|CMakeLists.txt"
        #    "3rdparty/libwebp|libwebp|CMakeLists.txt"
        "3rdparty/lunasvg|lunasvg|CMakeLists.txt"
    )
    foreach (_wx_sub IN LISTS _wx_submodules)
        string(REPLACE "|" ";" _wx_sub_parts "${_wx_sub}")
        list(GET _wx_sub_parts 0 _wx_sub_path)
        list(GET _wx_sub_parts 1 _wx_sub_repo)
        list(GET _wx_sub_parts 2 _wx_sub_sentinel)
        set(_wx_sub_dir "${_wx_local_src}/${_wx_sub_path}")
        if (NOT EXISTS "${_wx_sub_dir}/${_wx_sub_sentinel}")
            message(STATUS "Downloading wxWidgets submodule: ${_wx_sub_path} (${_wx_sub_repo})...")
            set(_wx_sub_tar "${ARCHIVE_DIR}/wxWidgets/${_wx_sub_repo}-wx.tar.gz")
            set(_wx_sub_tmp "${ARCHIVE_DIR}/wxWidgets/_sub_tmp")
            file(MAKE_DIRECTORY "${_wx_sub_tmp}")
            file(DOWNLOAD
                "https://github.com/wxWidgets/${_wx_sub_repo}/archive/refs/heads/wx.tar.gz"
                "${_wx_sub_tar}"
                STATUS _dl_status
            )
            list(GET _dl_status 0 _dl_result)
            if (NOT _dl_result EQUAL 0)
                message(FATAL_ERROR "Failed to download wxWidgets submodule ${_wx_sub_repo}: ${_dl_status}")
            endif ()
            if (NOT EXISTS "${_wx_sub_tar}")
                message(FATAL_ERROR "wxWidgets submodule ${_wx_sub_repo} download produced no file (status was ${_dl_status})")
            endif ()
            file(SIZE "${_wx_sub_tar}" _wx_sub_tar_size)
            if (_wx_sub_tar_size LESS 4096)
                file(READ "${_wx_sub_tar}" _wx_sub_tar_head LIMIT 256 HEX)
                message(FATAL_ERROR "${_wx_sub_repo} download too small (${_wx_sub_tar_size} bytes) — HTTP error or rate-limit? First bytes: ${_wx_sub_tar_head}")
            endif ()
            file(ARCHIVE_EXTRACT INPUT "${_wx_sub_tar}" DESTINATION "${_wx_sub_tmp}")
            file(GLOB _wx_sub_extracted LIST_DIRECTORIES true "${_wx_sub_tmp}/${_wx_sub_repo}-*")
            if (NOT _wx_sub_extracted)
                message(FATAL_ERROR "Could not find extracted ${_wx_sub_repo} dir in ${_wx_sub_tmp}")
            endif ()
            list(GET _wx_sub_extracted 0 _wx_sub_extracted)
            file(MAKE_DIRECTORY "${_wx_sub_dir}")
            file(COPY "${_wx_sub_extracted}/" DESTINATION "${_wx_sub_dir}")
            file(REMOVE_RECURSE "${_wx_sub_tmp}")
            file(REMOVE "${_wx_sub_tar}")
        endif ()
    endforeach ()

    unset(patches)
    list(APPEND patches
#            "${pkgname}/include|${_wx_local_src}/include/wx/"
            "${pkgname}/src/tiff/libtiff|${_wx_local_src}/src/tiff/libtiff/"
            "${pkgname}/src/osx/carbon|${_wx_local_src}/src/osx/carbon/"
            "${pkgname}/src/qt|${_wx_local_src}/src/qt/"
    )
    replaceFile(${pkgname} "${patches}")
#
    set(FETCHCONTENT_SOURCE_DIR_WXWIDGETS "${_wx_local_src}" CACHE PATH "Pre-cloned wxWidgets source" FORCE)
    include(${CMAKE_CURRENT_FUNCTION_LIST_DIR}/helpers.cmake)

    wxWidgets_set_build_options()

    # Prevent the find_package(wxWidgets QUIET) probe in fetchContents PASS 0 from
    # finding the sysroot/system wx installation and marking wx as already satisfied.
    # Without this, PASS 1 skips FetchContent_MakeAvailable and wx is never built from source.
    set(CMAKE_DISABLE_FIND_PACKAGE_wxWidgets TRUE PARENT_SCOPE)

    set(HANDLED OFF)
    set(HANDLED OFF PARENT_SCOPE)
endfunction()
