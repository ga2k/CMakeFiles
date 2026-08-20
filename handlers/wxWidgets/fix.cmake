include("${cmake_root}/tools.cmake")

function(wxWidgets_fix target tag sourceDir)

   cmake_policy(SET CMP0111 OLD)

   file(READ "${sourceDir}/include/wx/defs.h" contents)
   string(SUBSTRING "${contents}" 1 6 PRAGMA)
   if("${PRAGMA}" STREQUAL "pragma")
       message("'${PRAGMA}' is 'pragma'")
   else()
       message(WARNING "'${PRAGMA}' is not 'pragma'")
       set(contents "#pragma once\n${contents}")
       file(WRITE "${sourceDir}/include/wx/defs.h" "${contents}")
   endif()

   set(HANDLED ON PARENT_SCOPE)

endfunction()
