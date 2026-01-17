@echo off

@REM python3 cmake\filter-presets.py cmake\templates\CMakePresets.in .\CMakePresets.json
python3 cmake\filter-presets.py cmake/templates/CMakePresets.in CMakePresets.json
if %ERRORLEVEL%==0 echo "CMake presets have been set UP!"

@echo off
setlocal enabledelayedexpansion

:: --- 1. Install CoreUtils first ---
:: Check for 'grep' or 'ls' as a proxy for CoreUtils
where grep >nul 2>nul
if %errorlevel% neq 0 (
    echo [SETUP] CoreUtils not found. Installing...
    if exist "coreutils-5.3.0.exe" (
        start /wait "" "coreutils-5.3.0.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
        echo [SETUP] CoreUtils installation triggered.
    ) else (
        if exist "cmake\coreutils-5.3.0.exe" (
            start /wait "" "cmake\coreutils-5.3.0.exe" /VERYSILENT /SUPPRESSMSGBOXES /NORESTART
            echo [SETUP] CoreUtils installation triggered.
        ) else (
            echo [ERROR] coreutils-5.3.0.exe not found!
        )
    )
) else (
    echo [SETUP] CoreUtils already installed.
)

:: --- 2. Check and Install Perl ---
where perl >nul 2>nul
if %errorlevel% neq 0 (
    echo [SETUP] Perl not found. Preparing to download and install...

    set "PERL_MSI=strawberry-perl-5.42.0.1-64bit.msi"
    set "PERL_URL=https://github.com/StrawberryPerl/Perl-Dist-Strawberry/releases/download/SP_54001_64bit/strawberry-perl-5.40.0.1-64bit.msi"

    :: Use native Windows curl to download if the file isn't already there
    if not exist "!PERL_MSI!" (
        echo [SETUP] Downloading Strawberry Perl from !PERL_URL! ...
        curl -L -o "!PERL_MSI!" "!PERL_URL!"
        if %errorlevel% neq 0 (
            echo [ERROR] Failed to download Perl.
            exit /b 1
        )
    )

    echo [SETUP] Installing Strawberry Perl silently...
    REM start /wait msiexec.exe /i "!PERL_MSI!" /qn /norestart
    start /wait msiexec.exe /i "!PERL_MSI!"

    if %errorlevel% equ 0 (
        echo [SETUP] Perl installed successfully.
        :: Optional: clean up the installer to save space
        :: del "!PERL_MSI!"
    ) else (
        echo [ERROR] Perl installation failed with code %errorlevel%.
    )
) else (
    echo [SETUP] Perl already installed.
)

echo [SETUP] Environment check complete.
endlocal
