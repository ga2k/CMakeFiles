
function(addGfxFeatures dry_run)
    # @formatter:off
    addPackageData(PLUGIN   FEATURE "APPEARANCE"  PKGNAME "Appearance"    METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN   FEATURE "LOGGER"      PKGNAME "Logger"        METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(PLUGIN   FEATURE "PRINT"       PKGNAME "Print"         METHOD "IGNORE" DRY_RUN ${dry_run})
    addPackageData(OPTIONAL FEATURE "WIDGETS"     PKGNAME "wxWidgets"     METHOD "FETCH_CONTENTS"
            GIT_REPOSITORY "https://github.com/wxWidgets/wxWidgets.git" GIT_TAG "master"
            ARG REQUIRED DRY_RUN ${dry_run})
    addPackageData(LIBRARY FEATURE "GFX" PKGNAME "Gfx" METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS REQUIRED CONFIG PREREQ CORE DRY_RUN ${dry_run})
    # @formatter:on

#    if(Appearance IN_LIST APP_FEATURES)
        registerPlugin("Appearance")
#    endif ()
#    if(Logger IN_LIST APP_FEATURES)
        registerPlugin("Logger")
#    endif ()
#    if(Print IN_LIST APP_FEATURES)
        registerPlugin("Print")
#    endif ()

endfunction()

function(FindGfx_init)
    commonInit(Gfx)
endfunction()
