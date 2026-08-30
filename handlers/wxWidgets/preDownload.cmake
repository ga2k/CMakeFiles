function(wxWidgets_preDownload pkgname url tag srcDir)

    # Use a persistent local clone so wxWidgets survives `make clean`
    set(_wx_local_src "${ARCHIVE_DIR}/wxWidgets/source")
    if (EXISTS "${_wx_local_src}" AND NOT EXISTS "${_wx_local_src}/CMakeLists.txt")
        file(REMOVE_RECURSE "${_wx_local_src}")
    endif ()

    if (NOT EXISTS "${_wx_local_src}/CMakeLists.txt")

        # Download as a tarball — avoids the git ≥2.47 lazy objects/pack/ bug
        # that causes index-pack to fail on any fresh clone on this system.
        # ${tag} is the pinned ref from standardPackageData.cmake's GIT_TAG (a commit SHA
        # today); GitHub's archive endpoint resolves a SHA, tag, or branch name here.
        message(STATUS "Downloading wxWidgets @ ${tag} to ${_wx_local_src} (one-time)...")
        file(MAKE_DIRECTORY "${ARCHIVE_DIR}/wxWidgets")
        set(_wx_tar "${ARCHIVE_DIR}/wxWidgets/wxWidgets-${tag}.tar.gz")
        file(DOWNLOAD
            "https://github.com/wxWidgets/wxWidgets/archive/${tag}.tar.gz"
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
        unset(patches)
        list(APPEND patches
                ${_wx_local_src}|${sourceDir}
                "${_wx_local_src}/src|${sourceDir}/src"
        )
        replaceFiles(${_wx_local_src} "${patches}")

    else ()

        message(STATUS "Using already downloaded copy of wxWidgets")

    endif ()

    # Download wxWidgets submodules — GitHub tarballs don't include submodule content.
    # Skipped: src/stc/scintilla, src/stc/lexilla (wxUSE_STC OFF), 3rdparty/catch (tests only).
    # Each entry is  path|repo|sentinel|sha  — sha PINS the repo's wx branch to a fixed commit
    # so a fresh fetch is reproducible. These were captured together with the main wxWidgets
    # pin (standardPackageData.cmake) on 2026-08-30 from the tip of each repo's wx branch;
    # bump them as a set whenever the main pin moves.
    set(_wx_submodules
        "src/zlib|zlib|CMakeLists.txt|62eba04c6ff5a91aff6ce9ffd50ff7a52994412c"
        "src/png|libpng|CMakeLists.txt|3327853174bb3489b52380033a16a7af1c37cd03"
        "src/expat|libexpat|expat/lib/expat.h|25cdb80756f1fcce8536b0980ec081612858eb50"
        "src/tiff|libtiff|CMakeLists.txt|a40df5ddc406a958721ee4fc6faf5058460bc97b"
        "src/jpeg|libjpeg-turbo|jconfig.h|88cf215c8eee225148e007a66ee1dea5916fc949"
        "3rdparty/pcre|pcre|CMakeLists.txt|4f76619e6f20de93f77b5ef6213bf54e0399d166"
        "3rdparty/nanosvg|nanosvg|CMakeLists.txt|5cefd9847949af6df13f65027fd43af5a7513633"
        #    "3rdparty/libwebp|libwebp|CMakeLists.txt|<sha>"
        "3rdparty/lunasvg|lunasvg|CMakeLists.txt|e6ebb8d1e00c2307bc6937020c34c47bccbadf29"
    )
    foreach (_wx_sub IN LISTS _wx_submodules)
        string(REPLACE "|" ";" _wx_sub_parts "${_wx_sub}")
        list(GET _wx_sub_parts 0 _wx_sub_path)
        list(GET _wx_sub_parts 1 _wx_sub_repo)
        list(GET _wx_sub_parts 2 _wx_sub_sentinel)
        list(GET _wx_sub_parts 3 _wx_sub_sha)
        set(_wx_sub_dir "${_wx_local_src}/${_wx_sub_path}")
        if (NOT EXISTS "${_wx_sub_dir}/${_wx_sub_sentinel}")
            message(STATUS "Downloading wxWidgets submodule: ${_wx_sub_path} (${_wx_sub_repo} @ ${_wx_sub_sha})...")
            set(_wx_sub_tar "${ARCHIVE_DIR}/wxWidgets/${_wx_sub_repo}-${_wx_sub_sha}.tar.gz")
            set(_wx_sub_tmp "${ARCHIVE_DIR}/wxWidgets/_sub_tmp")
            file(MAKE_DIRECTORY "${_wx_sub_tmp}")
            file(DOWNLOAD
                "https://github.com/wxWidgets/${_wx_sub_repo}/archive/${_wx_sub_sha}.tar.gz"
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
