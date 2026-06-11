param(
    [string]$PbixName  = "",   # filter khi nhiều cửa sổ mở, e.g. "Credit Report"
    [string]$SourceDir = ""    # override toàn bộ path nếu cần
)

. "$PSScriptRoot\config.ps1"

Get-ChildItem $RsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $TeDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $TeDir 'Microsoft.AnalysisServices.Tabular.dll')

# Tìm PBI window
$pbiProcs = Get-Process PBIDesktopRS,PBIDesktop -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match ' - Power BI' }

if (!$pbiProcs) {
    Write-Host "ERROR: PBI Desktop RS not running. Open the .pbix file first."
    exit 1
}

if ($PbixName) {
    $pbiProcs = $pbiProcs | Where-Object { $_.MainWindowTitle -like "*$PbixName*" }
}

if (@($pbiProcs).Count -gt 1 -and !$PbixName) {
    Write-Host "Multiple PBI windows open. Use -PbixName to specify one:"
    $pbiProcs | ForEach-Object { Write-Host "  - $($_.MainWindowTitle -replace ' - Power BI.*','')" }
    exit 1
}

$targetPbi = @($pbiProcs)[0]
$pbixLabel = $targetPbi.MainWindowTitle -replace ' - Power BI.*', '' -replace '^\s+|\s+$', ''

# Map msmdsrv → parent PBI process
$allMsmdsrv = Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object {
        (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*"
    }

$msmdsrvProc = $allMsmdsrv | Where-Object {
    $ppid = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").ParentProcessId
    $ppid -eq $targetPbi.Id
} | Select-Object -First 1

if (!$msmdsrvProc) { $msmdsrvProc = $allMsmdsrv | Select-Object -First 1 }

if (!$msmdsrvProc) {
    Write-Host "ERROR: msmdsrv not found."
    exit 1
}

$port = (netstat -ano | Select-String $msmdsrvProc.Id.ToString() |
    Select-String "LISTENING" |
    ForEach-Object { ($_ -split '\s+')[2] -replace '.*:','' } |
    Select-Object -First 1)

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$model = $server.Databases[0].Model

# SourceDir: explicit override hoặc tự detect từ tên .pbix
if (!$SourceDir) {
    $repoRoot  = Split-Path $PSScriptRoot -Parent
    $SourceDir = Join-Path $repoRoot "source\measures\$pbixLabel"
}

if (!(Test-Path $SourceDir)) {
    Write-Host "ERROR: No measures folder for '$pbixLabel' at: $SourceDir"
    Write-Host "Available:"
    Get-ChildItem (Split-Path $SourceDir -Parent) -Directory | ForEach-Object { Write-Host "  - $($_.Name)" }
    exit 1
}

Write-Host "Syncing '$pbixLabel' from: $SourceDir"

$daxFiles = Get-ChildItem $SourceDir -Filter '*.dax' -Recurse
$updated = 0; $skipped = 0; $notFound = 0

foreach ($file in $daxFiles) {
    $lines = Get-Content $file.FullName -Encoding UTF8
    $header = $lines[0] -replace '^\xEF\xBB\xBF', ''

    if ($header -notmatch "MEASURE '([^']+)'\[([^\]]+)\]") {
        Write-Host "SKIP (no header): $($file.Name)"
        $skipped++; continue
    }

    $tableName   = $Matches[1]
    $measureName = $Matches[2]
    $expr        = ($lines[1..($lines.Length - 1)] -join "`n").TrimStart("`n")

    $table = $model.Tables | Where-Object { $_.Name -eq $tableName } | Select-Object -First 1
    if (!$table) {
        Write-Host "NOT FOUND table: $tableName ($measureName)"
        $notFound++; continue
    }

    $measure = $table.Measures | Where-Object { $_.Name -eq $measureName } | Select-Object -First 1
    if (!$measure) {
        Write-Host "NOT FOUND measure: $tableName.$measureName"
        $notFound++; continue
    }

    $measure.Expression = $expr
    Write-Host "Updated: $tableName.$measureName"
    $updated++
}

if ($updated -gt 0) { $model.SaveChanges() }
$server.Disconnect()

Write-Host ""
Write-Host "Done - updated: $updated | skipped: $skipped | not found: $notFound"

# Autosave .pbix via SendKeys Ctrl+S then upload to PBIRS
if ($updated -gt 0) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    Add-Type -AssemblyName System.Windows.Forms
    try {
        [Microsoft.VisualBasic.Interaction]::AppActivate($targetPbi.Id)
        Start-Sleep -Milliseconds 400
        [System.Windows.Forms.SendKeys]::SendWait("^s")
        Write-Host "Autosaved .pbix"
        Start-Sleep -Milliseconds 800
    } catch {
        Write-Host "Autosave failed — Ctrl+S manually in PBI Desktop RS"
    }

    Write-Host "Uploading to PBIRS..."
    & "$PSScriptRoot\upload_pbirs.ps1" -PbixName $pbixLabel
}
