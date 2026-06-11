#!/bin/bash
# Universal setup — detects WSL or Git Bash, installs the right dependencies.
# Usage: bash setup.sh

set -e

OK()   { echo "  [OK] $*"; }
SKIP() { echo "  [--] $*"; }
STEP() { echo ""; echo "==> $*"; }
FAIL() { echo "  [!!] $*" >&2; }

# ── Detect environment ────────────────────────────────────────────────────────
IS_WSL=false
IS_GITBASH=false

if grep -qi microsoft /proc/version 2>/dev/null; then
    IS_WSL=true
    ENV_NAME="WSL"
elif [[ "$(uname -s)" == MINGW* ]] || [[ "$(uname -s)" == MSYS* ]]; then
    IS_GITBASH=true
    ENV_NAME="Git Bash"
else
    FAIL "This script is intended for WSL or Git Bash on Windows."
    exit 1
fi

echo ""
echo "============================================"
echo "  PBIRS Report — Setup ($ENV_NAME detected)"
echo "============================================"

# ── 1. Node.js ───────────────────────────────────────────────────────────────
STEP "Node.js (Linux side)..."
if $IS_GITBASH; then
    SKIP "Git Bash — Node.js managed on Windows side. Skipping Linux install."
elif command -v node &>/dev/null; then
    SKIP "Node.js already installed: $(node --version)"
else
    echo "  Installing Node.js via nvm..."
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
    # Source nvm for current session
    export NVM_DIR="$HOME/.nvm"
    # shellcheck disable=SC1091
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts
    nvm use --lts
    OK "Node.js $(node --version) installed via nvm"
    echo ""
    echo "  NOTE: Add this to your ~/.bashrc or ~/.zshrc if not already present:"
    echo '  export NVM_DIR="$HOME/.nvm"'
    echo '  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
fi

# ── 2. Claude Code (Linux side) ──────────────────────────────────────────────
STEP "Claude Code CLI (Linux side)..."
if $IS_GITBASH; then
    SKIP "Git Bash — Claude Code managed on Windows side. Skipping."
elif command -v claude &>/dev/null; then
    SKIP "Claude Code already installed: $(claude --version 2>/dev/null || echo 'version unknown')"
else
    # Ensure nvm node is active
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    npm install -g @anthropic-ai/claude-code
    OK "Claude Code installed"
fi

# ── 3. Git hooks path ────────────────────────────────────────────────────────
STEP "Git hooks path..."
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
CURRENT=$(git -C "$REPO_ROOT" config core.hooksPath 2>/dev/null || true)
if [ "$CURRENT" = "hooks/" ]; then
    SKIP "core.hooksPath already set to hooks/"
else
    git -C "$REPO_ROOT" config core.hooksPath "hooks/"
    OK "core.hooksPath set to hooks/"
fi

# Make hooks executable
chmod +x "$REPO_ROOT/hooks/"* 2>/dev/null || true
chmod +x "$REPO_ROOT/scripts/ps.sh" 2>/dev/null || true
OK "Hook scripts marked executable"

# ── 4. Windows-side setup (Tabular Editor, PBI Desktop RS, config.ps1) ──────
STEP "Windows-side setup via PowerShell..."
if $IS_WSL; then
    PS_SCRIPT="$(wslpath -w "$REPO_ROOT/scripts/setup.ps1")"
    echo "  Running: powershell.exe -ExecutionPolicy Bypass -File $PS_SCRIPT -Mode WSL"
    powershell.exe -ExecutionPolicy Bypass -File "$PS_SCRIPT" -Mode WSL
elif $IS_GITBASH; then
    PS_SCRIPT="$(pwd -W)/scripts/setup.ps1"
    echo "  Running: powershell.exe -ExecutionPolicy Bypass -File $PS_SCRIPT -Mode GitBash"
    powershell.exe -ExecutionPolicy Bypass -File "$PS_SCRIPT" -Mode GitBash
fi

# ── Done ─────────────────────────────────────────────────────────────────────
echo ""
echo "============================================"
echo "  Setup complete ($ENV_NAME). Next steps:"
echo "  1. Open Power BI Desktop RS"
echo "  2. Open the .pbix file you want to edit"
echo "  3. cd $(cd "$(dirname "$0")" && pwd)"
echo "  4. claude"
echo "============================================"
