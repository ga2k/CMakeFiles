set(soci_components_handled CACHE STRING "" FORCE)
set(soci_components_needed soci_core soci_sqlite3 CACHE STRING "" FORCE)
#set(soci_components_needed HoffSoft::soci_core HoffSoft::soci_sqlite3 CACHE STRING "" FORCE)

function(soci_postAddTarget target)
    set(components_handled $CACHE{soci_components_handled})
    set(components_needed  $CACHE{soci_components_needed})

    if("${target}" IN_LIST components_handled)
        return()
    endif ()

    list(APPEND components_handled ${target})
    list(REMOVE_ITEM components_needed ${target})
    set(soci_components_handled ${components_handled} CACHE STRING "" FORCE)
    set(soci_components_needed  ${components_needed}  CACHE STRING "" FORCE)

    if (NOT "${components_needed}" STREQUAL "")
        list(POP_FRONT components_needed next_soci_component)
        set(soci_components_needed  ${components_needed}  CACHE STRING "" FORCE)
        addTargetProperties(${next_soci_component} soci ON)
    endif ()
endfunction()