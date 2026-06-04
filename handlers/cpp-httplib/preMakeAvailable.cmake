include(FetchContent)
include("${cmake_root}/tools.cmake")

function(cpp-httplib_preMakeAvailable pkgname)

    set(HTTPLIB_REQUIRE_OPENSSL ON PARENT_SCOPE)
    set(HANDLED OFF)
    set(HANDLED ${HANDLED} PARENT_SCOPE)

endfunction()
