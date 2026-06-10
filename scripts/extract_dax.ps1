param([string]$OutputDir = "source")

. "$PSScriptRoot\config.ps1"

Get-ChildItem $RsDir -Filter "*.dll" | ForEach-Object {
    try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {}
}
Get-ChildItem $TeDir -Filter "*.dll" | ForEach-Object {
    try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {}
}
Add-Type -Path (Join-Path $TeDir "Microsoft.AnalysisServices.Tabular.dll")

$msmdsrvProc = Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object {
        (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*"
    } | Select-Object -First 1

if (!$msmdsrvProc) {
    Write-Host "ERROR: PBI Desktop RS is not running or no file is open."
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

Write-Host "Connecting to PBI Desktop RS on port $port..."

$server      = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$model       = $server.Databases[0].Model
$measuresDir = Join-Path $OutputDir "measures"
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
