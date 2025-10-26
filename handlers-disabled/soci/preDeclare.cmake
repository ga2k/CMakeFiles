function(soci_preDeclare pkgname url tag srcDir)
    set(CMAKE_POLICY_DEFAULT_CMP0077 "NEW")
endfunction()

soci_preDeclare(${this_pkgname} ${this_url} ${this_tag} "${EXTERNALS_DIR}/${this_pkgname}")
set(HANDLED OFF)
