
function(addCoreFeatures dry_run)
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core"
            METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft"
            ARGS REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dry_run})
endfunction()

function(FindCore_init)
    commonInit (Core)
endfunction()
