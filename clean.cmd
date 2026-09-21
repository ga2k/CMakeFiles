@echo off
setlocal EnableDelayedExpansion

if "%PROJECTS%"=="" (
    echo Set the envvar "PROJECTS" to your base projects folder
    exit /b 1
)

for %%I in ("%CD%") do set "us=%%~nxI"

if /I "%us%"=="MyCare" (
    set "them=Libs"
) else if /I "%us%"=="Libs" (
    set "them=MyCare"
) else (
    echo Where am I? Current directory should be 'MyCare' or 'Libs'
    exit /b 1
)

set "go=0"
set "dc=0"
set "pch=0"
set "num=0"

for %%A in (%*) do (
    if /I "%%~A"=="--pch"            set "pch=1"
    if /I "%%~A"=="--generated-only" set "go=1"
    if /I "%%~A"=="--deep-clean"     set "dc=1"
)

call :lower "%~1" p1
call :lower "%~2" p2
call :lower "%~3" p3

set "skip=0"

set /a "pchOrDc=!pch! | !dc!"
if !pchOrDc! EQU 1 (

    call :f "%PROJECTS%\Libs\build\!p1!\!p2!\!p3!\pch" "pch"

    if "!dc!"=="1" (
        call :f "%PROJECTS%\!them!\build\!p1!\!p2!\!p3!\pch" "pch"
    ) else (
        set "skip=1"
    )
)

if "!skip!"=="0" (
    set /a "goOrDc=!go! | !dc!"
    if !goOrDc! EQU 1 (

        call :f "%PROJECTS%\!us!\generated\!p1!\!p2!\!p3!" "generated"

        if "!dc!"=="1" (
            call :f "%PROJECTS%\!them!\generated\!p1!\!p2!\!p3!" "generated"
        ) else (
            set "skip=1"
        )
    )
)

if "!skip!"=="0" (
    call :f "%PROJECTS%\!us!\build\!p1!\!p2!\!p3!" "build"
    call :f "%PROJECTS%\!us!\out\!p1!\!p2!\!p3!"   "out"

    if "!dc!"=="1" (
        call :f "%PROJECTS%\!them!\build\!p1!\!p2!\!p3!" "build"
        call :f "%PROJECTS%\!them!\out\!p1!\!p2!\!p3!"   "out"

        call :f "%USERPROFILE%\dev\stage\!p1!\!p2!\!p3!"    "staged"
        call :f "%USERPROFILE%\dev\archives\!p1!\!p2!\!p3!" "archived"
        call :f "%PROJECTS%\!us!\external\!p1!\!p2!\!p3!"   "external"
        call :f "%PROJECTS%\!them!\external\!p1!\!p2!\!p3!" "external"

        if not exist "%USERPROFILE%\dev\archives\!p1!\!p2!\!p3!" mkdir "%USERPROFILE%\dev\archives\!p1!\!p2!\!p3!"
        if not exist "%USERPROFILE%\dev\stage\!p1!\!p2!\!p3!"    mkdir "%USERPROFILE%\dev\stage\!p1!\!p2!\!p3!"
    )
)

:finish
echo Done.    !num! files removed. I'm tired now. Sleeping. Zzzzzz....
ping -n 6 127.0.0.1 >nul
endlocal
exit /b 0

:: ---------------------------------------------------------------------
:: :f <dir> <label>  -- reports and removes <dir> if it exists, tallying
:: the running total in %num%. Mirrors clean.sh's f() helper.
:: ---------------------------------------------------------------------
:f
set "target=%~1"
set "label=%~2"
set "fc=0"
if exist "!target!" (
    for /f "delims=" %%C in ('dir /s /b /a "!target!" 2^>nul') do set /a "fc+=1"
)
set "padded=     !fc!"
set "padded=!padded:~-5!"
set "labelPadded=         %label%"
set "labelPadded=!labelPadded:~-9!"
echo Removing !padded! !labelPadded! files from !target!...
if !fc! GTR 0 (
    set /a "num+=!fc!"
    rd /s /q "!target!" 2>nul
)
exit /b 0

:: ---------------------------------------------------------------------
:: :lower <string> <outVar>  -- pure-batch ASCII lowercase, no external
:: interpreter required.
:: ---------------------------------------------------------------------
:lower
setlocal EnableDelayedExpansion
set "str=%~1"
for %%P in ("A=a" "B=b" "C=c" "D=d" "E=e" "F=f" "G=g" "H=h" "I=i" "J=j" "K=k" "L=l" "M=m" "N=n" "O=o" "P=p" "Q=q" "R=r" "S=s" "T=t" "U=u" "V=v" "W=w" "X=x" "Y=y" "Z=z") do (
    for /f "tokens=1,2 delims==" %%U in (%%P) do set "str=!str:%%U=%%V!"
)
endlocal & set "%~2=%str%"
exit /b 0
