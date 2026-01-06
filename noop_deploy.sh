: <<'BATCH'
@echo off
rem This section is only seen by Windows CMD
if exist "noop.cmd" (
    call noop.cmd
) else (
    echo [ERROR] noop.cmd not found.
    exit /b 1
)
exit /b %ERRORLEVEL%
BATCH

# This section is only seen by Bash (Linux/macOS)
if [ -f "./noop.sh" ]; then
    chmod +x ./noop.sh
    ./noop.sh
else
    echo "[ERROR] noop.sh not found."
    exit 1
fi