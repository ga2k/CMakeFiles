function(FindCore_init)
    foreach (feet IN LISTS APP_FEATURES)
        cmake_parse_arguments("AAZ" "REQUIRED;OPTIONAL" "PACKAGE;NAMESPACE" "PATHS;HINTS" ${feet})
        if (AAZ_UNPARSED_ARGUMENTS)
            list(GET AAZ_UNPARSED_ARGUMENTS 0 AAZ_FEATURE)
            if (AAZ_FEATURE STREQUAL CORE)
                initCore()
                return()
            endif ()
        endif ()
    endforeach ()
    set(HANDLED ON)
endfunction()

macro(initCore)
    list(REMOVE_ITEM APP_FEATURES "CORE")
    if (NOT APP_NAME STREQUAL "Core")
        list(PREPEND APP_FEATURES "CORE PACKAGE Core ARGS PATHS {Core}")
    endif ()
    set(fn "addCoreFeatures")
    cmake_language(CALL registerPackageCallback "${fn}")
endmacro()

function(addCoreFeatures dry_run)

    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dry_run})

endfunction()
