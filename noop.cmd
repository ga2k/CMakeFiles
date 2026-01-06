@echo off
setlocal

:: Define file names
set "SOURCE_FILE=noop.c"
set "EXE_NAME=noop.exe"
set "TARGET_PATH=%TEMP%\%EXE_NAME%"

echo Creating source file...
echo int main(void) { return 0; } > %SOURCE_FILE%

:: Check if cl.exe is in the path
where cl.exe >nul 2>nul
if %ERRORLEVEL% neq 0 (
    echo [ERROR] cl.exe (MSVC Compiler) not found in PATH.
    echo Please run this from a Developer Command Prompt for Visual Studio.
    del %SOURCE_FILE%
    exit /b 1
)

echo Building with cl...
:: /O2: Optimization for speed
:: /Fe: Rename output executable
:: /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup : Prevents console window popup
cl.exe /O2 %SOURCE_FILE% /Fe:"%TARGET_PATH%" /link /SUBSYSTEM:WINDOWS /ENTRY:mainCRTStartup >nul

if %ERRORLEVEL% equ 0 (
    echo Success! Binary deployed to: %TARGET_PATH%

    :: Clean up temporary build files
    del %SOURCE_FILE%
    del noop.obj
) else (
    echo [ERROR] Compilation failed.
    del %SOURCE_FILE%
    exit /b 1
)

echo Testing binary...
start /wait "" "%TARGET_PATH%"
echo Test complete. (Exited with code %ERRORLEVEL%)

endlocal