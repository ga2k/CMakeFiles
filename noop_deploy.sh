: <<'BATCH'
@echo off
rem This section is only seen by Windows CMD
if exist "cmake\noop.cmd" (
    call cmake\noop.cmd
) else (
    echo [ERROR] cmake\noop.cmd not found.
    exit /b 1
)
exit /b %ERRORLEVEL%
BATCH

# This section is only seen by Bash (Linux/macOS)
if [ -f "./cmake/noop.sh" ]; then
    chmod +x ./cmake/noop.sh
    ./cmake/noop.sh
else
    echo "[ERROR] ./cmake/noop.sh not found."
    exit 1
fi