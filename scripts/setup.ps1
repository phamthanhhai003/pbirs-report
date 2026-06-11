# One-time setup script for new machines.
# Run as Administrator: powershell -ExecutionPolicy Bypass -File scripts/setup.ps1

$ErrorActionPreference = "Stop"
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Write-OK($msg)   { Write-Host "    [OK] $msg" -ForegroundColor Green }
function Write-Skip($msg) { Write-Host "    [--] $msg" -ForegroundColor Gray }
function Write-Fail($msg) { Write-Host "    [!!] $msg" -ForegroundColor Red }

# ── 1. Winget ────────────────────────────────────────────────────────────────
Write-Step "Checking winget..."
if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Fail "winget not found. Install 'App Installer' from the Microsoft Store, then re-run this script."
    exit 1
}
Write-OK "winget available"

# ── 2. Git for Windows ───────────────────────────────────────────────────────
Write-Step "Git for Windows..."
if (!(Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "    Installing Git for Windows..."
    winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements
    $env:PATH += ";C:\Program Files\Git\cmd"
    Write-OK "Git installed"
} else {
    Write-Skip "Git already installed: $(git --version)"
}

# ── 3. Node.js (required for Claude Code) ───────────────────────────────────
Write-Step "Node.js..."
if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "    Installing Node.js LTS..."
    winget install --id OpenJS.NodeJS.LTS -e --source winget --accept-package-agreements --accept-source-agreements
    $env:PATH += ";C:\Program Files\nodejs"
    Write-OK "Node.js installed"
} else {
    Write-Skip "Node.js already installed: $(node --version)"
}

# ── 4. Claude Code CLI ───────────────────────────────────────────────────────
Write-Step "Claude Code CLI..."
if (!(Get-Command claude -ErrorAction SilentlyContinue)) {
    Write-Host "    Installing Claude Code..."
    npm install -g @anthropic-ai/claude-code
    Write-OK "Claude Code installed"
} else {
    Write-Skip "Claude Code already installed: $(claude --version 2>$null)"
}

# ── 5. Tabular Editor 2 ──────────────────────────────────────────────────────
Write-Step "Tabular Editor 2..."
$TeDir = "C:\Program Files (x86)\Tabular Editor"
$TeDll = Join-Path $TeDir "Microsoft.AnalysisServices.Tabular.dll"
if (!(Test-Path $TeDll)) {
    Write-Host "    Downloading Tabular Editor 2 (latest)..."
    $TeApiUrl  = "https://api.github.com/repos/TabularEditor/TabularEditor/releases/latest"
    $TeRelease = Invoke-RestMethod $TeApiUrl
    $TeAsset   = $TeRelease.assets | Where-Object { $_.name -like "*TabularEditor.Installer*" -or $_.name -like "*.msi" } | Select-Object -First 1
    if (!$TeAsset) {
        $TeAsset = $TeRelease.assets | Where-Object { $_.name -like "*.zip" } | Select-Object -First 1
    }
    $TeTmp = "$env:TEMP\TabularEditorSetup"
    New-Item -ItemType Directory -Path $TeTmp -Force | Out-Null
    $TeFile = Join-Path $TeTmp $TeAsset.name
    Write-Host "    Downloading $($TeAsset.name)..."
    Invoke-WebRequest -Uri $TeAsset.browser_download_url -OutFile $TeFile -UseBasicParsing
    if ($TeFile -like "*.msi") {
        Write-Host "    Running installer (silent)..."
        Start-Process msiexec.exe -ArgumentList "/i `"$TeFile`" /qn INSTALLDIR=`"$TeDir`"" -Wait
    } elseif ($TeFile -like "*.zip") {
        Write-Host "    Extracting..."
        New-Item -ItemType Directory -Path $TeDir -Force | Out-Null
        Expand-Archive -Path $TeFile -DestinationPath $TeDir -Force
    }
    Write-OK "Tabular Editor 2 installed at $TeDir"
} else {
    Write-Skip "Tabular Editor 2 already present at $TeDir"
}

# ── 6. Power BI Desktop RS ───────────────────────────────────────────────────
Write-Step "Power BI Desktop RS..."
$PbiDir = "C:\Program Files\Microsoft Power BI Desktop RS\bin"
if (!(Test-Path $PbiDir)) {
    Write-Host ""
    Write-Host "    Power BI Desktop RS is NOT installed." -ForegroundColor Yellow
    Write-Host "    Download from your internal IT portal or:" -ForegroundColor Yellow
    Write-Host "    https://www.microsoft.com/en-us/download/details.aspx?id=56722" -ForegroundColor Yellow
    Write-Host "    Install it, then re-run this script." -ForegroundColor Yellow
    Write-Host ""
    Read-Host "    Press Enter to continue (or Ctrl+C to exit and install first)"
} else {
    Write-OK "Power BI Desktop RS found at $PbiDir"
}

# ── 7. config.ps1 ────────────────────────────────────────────────────────────
Write-Step "Machine config (config.ps1)..."
$ConfigSrc = Join-Path $PSScriptRoot "config.example.ps1"
$ConfigDst = Join-Path $PSScriptRoot "config.ps1"
if (!(Test-Path $ConfigDst)) {
    Copy-Item $ConfigSrc $ConfigDst
    Write-Host ""
    Write-Host "    config.ps1 created. Fill in the values below:" -ForegroundColor Yellow
    Write-Host ""

    $PbirsHost = Read-Host "    PBIRS Server URL (e.g. http://10.0.40.122/reports)"
    $PbirsUser = Read-Host "    PBIRS Username (default: Admin)"
    if (!$PbirsUser) { $PbirsUser = "Admin" }
    $PbirsPass = Read-Host "    PBIRS Password" -AsSecureString
    $PbirsPassPlain = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
        [Runtime.InteropServices.Marshal]::SecureStringToBSTR($PbirsPass)
    )

    (Get-Content $ConfigDst) `
        -replace 'http://YOUR-HOSTNAME/reports', $PbirsHost `
        -replace '\$PbirsUser\s*=\s*"Admin"', "`$PbirsUser = `"$PbirsUser`"" |
        Set-Content $ConfigDst

    # Set password as machine env var (not written to file)
    [System.Environment]::SetEnvironmentVariable("PBIRS_PASS", $PbirsPassPlain, "User")
    Write-OK "config.ps1 created. PBIRS_PASS saved to user environment variable."
} else {
    Write-Skip "config.ps1 already exists"
}

# ── 8. Git hook path ─────────────────────────────────────────────────────────
Write-Step "Git hooks path..."
Push-Location $RepoRoot
$HooksPath = git config core.hooksPath 2>$null
if ($HooksPath -ne "hooks/") {
    git config core.hooksPath "hooks/"
    Write-OK "core.hooksPath set to hooks/"
} else {
    Write-Skip "core.hooksPath already set"
}
Pop-Location

# ── Done ─────────────────────────────────────────────────────────────────────
Write-Host ""
Write-Host "============================================" -ForegroundColor Green
Write-Host "  Setup complete. Next steps:" -ForegroundColor Green
Write-Host "  1. Open Power BI Desktop RS" -ForegroundColor Green
Write-Host "  2. Open the .pbix file you want to edit" -ForegroundColor Green
Write-Host "  3. Run: claude  (in this repo folder)" -ForegroundColor Green
Write-Host "============================================" -ForegroundColor Green
