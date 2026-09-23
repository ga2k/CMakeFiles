@echo off
REM windres's default .rc preprocessor is gcc/cc1, which on this machine fails to load
REM api-ms-win-crt-utility-l1-1-0.dll (a broken/AV-interfered gcc install, unrelated to
REM this project). clang works fine as a drop-in C preprocessor instead; windres just
REM needs to be told the MinGW target explicitly (plain clang.exe doesn't assume it the
REM way gcc.exe naturally does) and RC_INVOKED explicitly (windres only auto-adds that
REM for its recognized default preprocessor, not a custom --preprocessor=).
C:\msys64\ucrt64\bin\clang.exe --target=x86_64-w64-mingw32 -E -xc -DRC_INVOKED %*
