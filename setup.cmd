@echo off
@REM python3 cmake\filter-presets.py cmake\templates\CMakePresets.in .\CMakePresets.json
python3 cmake\filter-presets.py cmake/templates/CMakePresets.in CMakePresets.json
if %ERRORLEVEL%==0 echo "CMake presets have been set UP!"
