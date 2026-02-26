include_guard(GLOBAL)

function (HoffSoft_init dry_run)
    FindCore_init(${dry_run})
    FindGfx_init($dry_run})
endfunction()

########################################################################################################################

function(addCoreFeatures dry_run)
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core"
            METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dry_run})
endfunction()

function(FindCore_init dry_run)
    commonInit (Core ${dry_run})
endfunction()

########################################################################################################################

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

    registerPlugin("Appearance" ${dry_run})
    registerPlugin("Logger" ${dry_run})
    registerPlugin("Print" ${dry_run})

endfunction()

function(FindGfx_init dry_run)
    commonInit(Gfx ${dry_run})
endfunction()
