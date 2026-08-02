include("${cmake_root}/tools.cmake")

function(wxWidgets_fix target tag sourceDir)

   cmake_policy(SET CMP0111 OLD)

   unset(patches)
   list(APPEND patches
           ${target}|${sourceDir}
           "${target}/src|${sourceDir}/src"
   )
   replaceFiles(${target} "${patches}")
   set(HANDLED ON PARENT_SCOPE)

endfunction()
