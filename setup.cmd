@echo off
python3 cmake\filter-presets.py .\CMakePresets.in .\CMakePresets.json
echo "CMake presets have been set up!"
