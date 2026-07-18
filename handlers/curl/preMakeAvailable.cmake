include(FetchContent)
include("${cmake_root}/tools.cmake")

# Option names below are curl's own upstream CMakeLists.txt cache variables (verified
# against curl-8_19_0), not vcpkg feature names. We only need the SMTP protocol plus the
# auth mechanisms exposed in MyHealthGuru's email settings UI (see EmailAuthorityChoice):
# plain/CRAM-MD5 password auth ships enabled by default, so only NTLM and GSSAPI/Kerberos
# need to be turned on explicitly.
function(curl_preMakeAvailable pkgname)

    message(" ")

    if (curl_ALREADY_FOUND)
        return()
    endif ()

    forceSet(BUILD_CURL_EXE "" OFF BOOL)
    forceSet(BUILD_TESTING "" OFF BOOL)

    # curl's own install(EXPORT "CURLTargets" ...) exports libcurl_shared/libcurl_static
    # under the CURL:: namespace. Our own Core export set also needs to depend on that same
    # target (Core links curl PUBLIC), and CMake refuses to let an exported target (Gfx, via
    # Core) depend on something exported into two different export sets/namespaces at once
    # ("target ... is not in this export set, but in multiple other export sets"). Same class
    # of conflict soci hits — see SOCI_INSTALL/SOCI_SKIP_INSTALL below. Disable curl's own
    # install/export entirely so ours is the only export set that ever mentions it.
    forceSet(CURL_DISABLE_INSTALL "" ON BOOL)

    forceSet(CURL_USE_OPENSSL "" ON BOOL)
    forceSet(CURL_ENABLE_NTLM "" ON BOOL)

    # libpsl (Public Suffix List) is only needed for cookie domain validation —
    # not required for SMTP. Disable it to avoid a hard find_package(REQUIRED)
    # failure on macOS where libpsl is not installed by default.
    forceSet(CURL_USE_LIBPSL "" OFF BOOL)

    # GSSAPI/Kerberos needs a system Kerberos install (MIT/Heimdal) that curl's own
    # find_package(GSS) can locate. Not attempted when cross-compiling to Windows -
    # there's no cross Kerberos toolchain wired up yet, so leave it off there.
    if (NOT WIN32)
        forceSet(CURL_USE_GSSAPI "" ON BOOL)
    endif ()
    forceSet(CURL_DISABLE_KERBEROS_AUTH "" OFF BOOL)
    forceSet(CURL_DISABLE_NEGOTIATE_AUTH "" OFF BOOL)

    forceSet(CURL_DISABLE_SMTP "" OFF BOOL)

    set(HANDLED OFF)
    set(HANDLED ${HANDLED} PARENT_SCOPE)

endfunction()
