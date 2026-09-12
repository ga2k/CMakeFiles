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

   # macOS 27 SDK: float.h gates all macro definitions on !__has_feature(modules).
   # ObjC++ .mm compilation enables Clang modules implicitly for framework headers,
   # so FLT_MAX/DBL_MAX are never defined — including in Apple's own NSWindow.h.
   # Some .mm files (e.g. carbon/fontdlgosx.mm) import <AppKit/AppKit.h> directly
   # before any wx header that could inject the fallbacks, so the only safe insertion
   # point that covers every wx translation unit is wxprec.h, which is always first.
   # config.cpp also needs a local fallback because it is a plain .cpp file that
   # includes <float.h>/<cfloat> inside an #if guard (different compilation context).
   if (APPLE)
       set(_wxprec "${sourceDir}/include/wx/wxprec.h")
       if (EXISTS "${_wxprec}")
           file(READ "${_wxprec}" _content)
           if (NOT _content MATCHES "__FLT_MAX__")
               string(REPLACE
                   "#include \"wx/defs.h\""
                   "#include \"wx/defs.h\"\n\n// macOS 27 SDK: float.h skips macro definitions when Clang modules are active.\n// Define the float/double limits here — the earliest point in every wx TU —\n// using Clang's unconditional predefined builtins so framework imports find them.\n#ifdef __APPLE__\n#  ifndef FLT_MAX\n#    define FLT_MAX __FLT_MAX__\n#    define FLT_MIN __FLT_MIN__\n#    define DBL_MAX __DBL_MAX__\n#    define DBL_MIN __DBL_MIN__\n#  endif\n#endif"
                   _content "${_content}")
               file(WRITE "${_wxprec}" "${_content}")
               message(STATUS "Patched wx/include/wx/wxprec.h: FLT/DBL_MAX builtins for macOS 27 SDK")
           endif ()
       endif ()

       set(_config_cpp "${sourceDir}/src/common/config.cpp")
       if (EXISTS "${_config_cpp}")
           file(READ "${_config_cpp}" _content)
           if (_content MATCHES "#include <float\\.h>" OR _content MATCHES "#include <cfloat>")
               string(REGEX REPLACE
                   "#include <(float\\.h|cfloat)>[^\n]*\n"
                   "#include <cfloat>       // for FLT_MAX\n#ifndef FLT_MAX         // SDK/PCH module guard may skip macro definitions\n#  define FLT_MAX __FLT_MAX__\n#  define FLT_MIN __FLT_MIN__\n#endif\n"
                   _content "${_content}")
               file(WRITE "${_config_cpp}" "${_content}")
               message(STATUS "Patched wx/src/common/config.cpp: FLT_MAX/FLT_MIN fallback for macOS 27 SDK")
           endif ()
       endif ()
   endif ()

   set(HANDLED ON PARENT_SCOPE)

endfunction()

