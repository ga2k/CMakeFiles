function(soci_preDownload pkgname url tag srcDir)
endfunction()

soci_preDownload(${this_pkgname} ${this_url} ${this_tag} "${EXTERNALS_DIR}/${this_pkgname}")
set(HANDLED OFF)
