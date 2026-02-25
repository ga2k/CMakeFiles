include_guard(GLOBAL)
function(addCoreFeatures dry_run)
    addPackageData(LIBRARY FEATURE "CORE" PKGNAME "Core"
            METHOD "FIND_PACKAGE" NAMESPACE "HoffSoft" DEFAULT 1
            ARGS REQUIRED CONFIG PREREQ DATABASE=soci DRY_RUN ${dry_run})
endfunction()

function(FindCore_init dry_run)
    commonInit (Core ${dry_run})
    set(AUE_FEATURES "${AUE_FEATURES}" PARENT_SCOPE)
endfunction()
