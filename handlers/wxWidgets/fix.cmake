include("${cmake_root}/tools.cmake")

function(add_pragma_once path)
   file(READ "${path}" contents)
   string(SUBSTRING "${contents}" 1 6 PRAGMA)
   if("${PRAGMA}" STREQUAL "pragma")
       message("'${PRAGMA}' is 'pragma'")
   else()
       message(WARNING "'${PRAGMA}' is not 'pragma'")
       set(contents "#pragma once\n${contents}")
       file(WRITE "${path}" "${contents}")
   endif()
endfunction()

function(wxWidgets_fix target tag sourceDir)

   cmake_policy(SET CMP0111 OLD)

   add_pragma_once("${sourceDir}/include/wx/defs.h")
   add_pragma_once("${sourceDir}/include/wx/wxcrtvararg.h")

   set(HANDLED ON PARENT_SCOPE)

endfunction()

