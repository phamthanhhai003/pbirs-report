#!/bin/bash
# Portable PowerShell invoker — works from WSL, Git Bash, and MSYS2.
# Usage: bash scripts/ps.sh -File scripts/foo.ps1 [-Arg val ...]
#        bash scripts/ps.sh -Command "Get-Process ..."

if grep -qi microsoft /proc/version 2>/dev/null; then
    # WSL — must call the Windows binary explicitly
    powershell.exe -ExecutionPolicy Bypass "$@"
elif [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]] || [[ "$(uname -s)" == CYGWIN* ]]; then
    # Git Bash / MSYS2 / Cygwin on Windows
    powershell.exe -ExecutionPolicy Bypass "$@"
else
    # Fallback (native Linux — unlikely but safe)
    echo "ERROR: PowerShell not available on this platform." >&2
    exit 1
fi
