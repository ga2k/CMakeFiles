set(soci_components_handled CACHE STRING "" FORCE)
set(soci_components_needed HoffSoft::soci_core HoffSoft::soci_sqlite3 CACHE STRING "" FORCE)

function(soci_postAddTarget target)
    message("target='${target}',soci_components_handled='${soci_components_handled}', soci_components_needed='${soci_components_needed}'")
    set(components_handled $CACHE{soci_components_handled})
    set(components_needed  $CACHE{soci_components_needed})

    list(APPEND components_handled ${target})
    list(REMOVE_ITEM components_needed ${target})

    message("components_handled='${components_handled}', components_needed='${components_needed}'")

    if (NOT "${components_needed}" STREQUAL "")
        list(POP_FRONT components_needed next_soci_component)
        message("components_needed=${components_needed}, next_soci_component=${next_soci_component}")

        set(soci_components_handled ${components_handled} CACHE STRING "" FORCE)
        set(soci_components_needed  ${components_needed}  CACHE STRING "" FORCE)

        message("soci_components_needed=$CACHE{soci_components_needed}, soci_components_handled=$CACHE{soci_components_handled}, next_soci_component=${next_soci_component}")
        addTargetProperties(${next_soci_component} soci ON)
    endif ()
endfunction()