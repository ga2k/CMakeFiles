#!/bin/sh
# Compiler launcher (HS_SLOC_STATS): runs the real compile with `-Xclang -print-stats`, appends one line per
# translation unit to the log file given as $1 showing how much of Clang's 2 GiB source-location address space it used, and
# passes only the compiler's diagnostics through (the stats block is dropped).
#   log line: <pct of 2GiB> <MiB used> <local MiB> <loaded MiB> <source file>
# Usage: sloc-stats.sh <log> <compiler> <args...>   Summarise with:  sort -rn <log> | head
log=$1; shift
err=$(mktemp) || exit 1
"$@" 2>"$err"
rc=$?
awk -v out="$log" -v limit=2147483648 '
    /^\*\*\* / || /^STATISTICS/        { stats = 1 }
    !stats                            { print > "/dev/stderr"; next }
    /local SLocEntries allocated/     { if (match($0, /[0-9]+B of SLoc/)) local = substr($0, RSTART, RLENGTH - 8) + 0 }
    /loaded SLocEntries allocated/    { if (match($0, /[0-9]+B of SLoc/)) loaded = substr($0, RSTART, RLENGTH - 8) + 0 }
    END { if (stats) printf "%.1f %.0f %.0f %.0f %s\n", (local + loaded) * 100 / limit, (local + loaded) / 1048576, local / 1048576, loaded / 1048576, file >> out }
' file="$(printf '%s\n' "$@" | awk '$0=="-c"{getline; print; exit}')" "$err"
rm -f "$err"
exit $rc
