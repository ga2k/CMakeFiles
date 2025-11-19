function(OpenSSL_fix target tag sourceDir)
# code to create a custom target to have local patches applied before build.
# change FALSE below to TRUE to enable this feature. That's all you need here.

    if (NOT "${tag}" STREQUAL "DISABLED")
        return()
        message(FATAL_ERROR "Attempting to patch wrong version of OpenSSL")
    endif ()

    set(pkg ${CMAKE_CURRENT_FUNCTION})
    string(LENGTH ${pkg} pkgLength)
    math(EXPR subLength "${pkgLength} - 4")
    string(SUBSTRING ${pkg} 0 ${subLength} pkg)

    message(FATAL_ERROR "Applying local patches to ${pkg}...")

    # code to apply local patches immediately prior to build
endfunction()

OpenSSL_fix("${this_pkgname}" "${this_tag}" "${this_src}")
set(HANDLED ON)
