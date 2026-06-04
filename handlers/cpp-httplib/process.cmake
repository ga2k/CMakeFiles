function(cpp-httplib_process incs libs defs)

    include(FetchContent)

    set(HTTPLIB_REQUIRE_OPENSSL ON CACHE BOOL "" FORCE)

    if (NOT cpp-httplib_POPULATED)
        FetchContent_Declare(cpp-httplib
                GIT_REPOSITORY "https://github.com/yhirose/cpp-httplib.git"
                GIT_TAG        "v0.18.5"
                SOURCE_DIR     "${EXTERNALS_DIR}/cpp-httplib"
        )
        FetchContent_MakeAvailable(cpp-httplib)
    endif ()

    set(_IncludePathsList ${_IncludePathsList} "${EXTERNALS_DIR}/cpp-httplib" PARENT_SCOPE)
    set(_DefinesList      ${_DefinesList}      CPPHTTPLIB_OPENSSL_SUPPORT      PARENT_SCOPE)
    set(HANDLED           ON                                                    PARENT_SCOPE)

endfunction()
