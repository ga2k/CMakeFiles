function(cpptrace_preDownload pkgname url tag srcDir)

    if (NOT "${tag}" STREQUAL "v0.7.3")
        message(FATAL_ERROR "Wrong version of ${pkgname}")
    endif ()

    FetchContent_Declare(${pkgname} URL ${url})
    set(this_fetch OFF PARENT_SCOPE)

endfunction()

cpptrace_preDownload(${this_pkgname} ${this_url} ${this_tag} "${EXTERNALS_DIR}/${this_pkgname}")
set(this_fetch OFF PARENT_SCOPE)
set(HANDLED ON)
