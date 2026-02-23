function(FindGfx_init)
    initGfx()
    set(HANDLED ON)
endfunction()

macro(initGfx)

    list(REMOVE_ITEM APP_FEATURES "GFX")
    if (NOT APP_NAME STREQUAL "Gfx")
        list(PREPEND APP_FEATURES "GFX PACKAGE Gfx ARGS PATHS {Gfx}")
    endif ()

    set(fn "addGfxFeatures")
    cmake_language(CALL registerPackageCallback "${fn}")

    registerPlugin("Appearance")
    registerPlugin("Logger")
    registerPlugin("Print")
endmacro()

function(addGfxFeatures dry_run)

    # @formatter:off
    addPackageData(PLUGIN FEATURE "APPEARANCE"  PKGNAME "Appearance"    METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN FEATURE "LOGGER"      PKGNAME "Logger"        METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN FEATURE "PRINT"       PKGNAME "Print"         METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(SYSTEM FEATURE "WIDGETS"     PKGNAME "wxWidgets"     METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wxWidgets/wxWidgets.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dry_run})

    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG PREREQ CORE DRY_RUN ${dry_run})
    # @formatter:on

    #    savePackageData()

endfunction()
