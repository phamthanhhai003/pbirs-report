param(
    [string]$OutputDir  = "source",
    [string]$PbixName   = ""      # filter khi nhiều cửa sổ mở, e.g. "Credit Report"
)

. "$PSScriptRoot\config.ps1"

Get-ChildItem $RsDir -Filter "*.dll" | ForEach-Object {
    try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {}
}
Get-ChildItem $TeDir -Filter "*.dll" | ForEach-Object {
    try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {}
}
Add-Type -Path (Join-Path $TeDir "Microsoft.AnalysisServices.Tabular.dll")

# Tìm tất cả PBI Desktop RS windows đang mở
$pbiProcs = Get-Process PBIDesktopRS,PBIDesktop -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match ' - Power BI' }

if (!$pbiProcs) {
    Write-Host "ERROR: PBI Desktop RS is not running or no file is open."
    exit 1
}

# Nếu truyền PbixName → filter đúng cửa sổ
if ($PbixName) {
    $pbiProcs = $pbiProcs | Where-Object { $_.MainWindowTitle -like "*$PbixName*" }
    if (!$pbiProcs) {
        Write-Host "ERROR: No PBI window matching '$PbixName'. Open windows:"
        Get-Process PBIDesktopRS,PBIDesktop -ErrorAction SilentlyContinue |
            Where-Object { $_.MainWindowTitle -match ' - Power BI' } |
            ForEach-Object { Write-Host "  - $($_.MainWindowTitle -replace ' - Power BI.*','')" }
        exit 1
    }
}

if (@($pbiProcs).Count -gt 1 -and !$PbixName) {
    Write-Host "WARNING: Multiple PBI windows open. Extracting from first. Use -PbixName to specify:"
    $pbiProcs | ForEach-Object { Write-Host "  - $($_.MainWindowTitle -replace ' - Power BI.*','')" }
}

$targetPbi = @($pbiProcs)[0]
$pbixLabel = $targetPbi.MainWindowTitle -replace ' - Power BI.*', '' -replace '^\s+|\s+$', ''

# Tìm msmdsrv là con của targetPbi (match qua ParentProcessId)
$allMsmdsrv = Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object {
        (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*"
    }

$msmdsrvProc = $allMsmdsrv | Where-Object {
    $ppid = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").ParentProcessId
    $ppid -eq $targetPbi.Id
} | Select-Object -First 1

# Fallback: nếu không map được parent → dùng first msmdsrv
if (!$msmdsrvProc) { $msmdsrvProc = $allMsmdsrv | Select-Object -First 1 }

if (!$msmdsrvProc) {
    Write-Host "ERROR: msmdsrv not found for '$pbixLabel'."
    exit 1
}

$port = (netstat -ano | Select-String $msmdsrvProc.Id.ToString() |
    Select-String "LISTENING" |
    ForEach-Object { ($_ -split '\s+')[2] -replace '.*:','' } |
    Select-Object -First 1)

if (!$port) {
    Write-Host "ERROR: Cannot find port for msmdsrv PID $($msmdsrvProc.Id)"
    exit 1
}

Write-Host "Extracting '$pbixLabel' on port $port..."

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$db     = $server.Databases[0]
$model  = $db.Model

$measuresDir = Join-Path (Join-Path $OutputDir "measures") $pbixLabel
New-Item -ItemType Directory -Path $measuresDir -Force | Out-Null

$count = 0
foreach ($table in $model.Tables) {
    $tableDir = Join-Path $measuresDir ($table.Name -replace '[\\/:*?"<>|]', '_')
    if ($table.Measures.Count -gt 0) {
        New-Item -ItemType Directory -Path $tableDir -Force | Out-Null
    }
    foreach ($measure in $table.Measures) {
        $safeName = $measure.Name -replace '[\\/:*?"<>|]', '_'
        $outFile  = Join-Path $tableDir "$safeName.dax"
        @"
MEASURE '$($table.Name)'[$($measure.Name)] =
$($measure.Expression)
"@ | Set-Content $outFile -Encoding UTF8
        $count++
    }
}

$server.Disconnect()
Write-Host "Extracted $count measures -> $measuresDir"
