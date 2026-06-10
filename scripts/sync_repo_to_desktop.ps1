param([string]$SourceDir = "source/measures")

. "$PSScriptRoot\config.ps1"

Get-ChildItem $RsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $TeDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $TeDir 'Microsoft.AnalysisServices.Tabular.dll')

$msmdsrvProc = Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object {
        (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*"
    } | Select-Object -First 1

if (!$msmdsrvProc) {
    Write-Host "ERROR: PBI Desktop RS not running. Open the .pbix file first."
    exit 1
}

$port = (netstat -ano | Select-String $msmdsrvProc.Id.ToString() |
    Select-String "LISTENING" |
    ForEach-Object { ($_ -split '\s+')[2] -replace '.*:','' } |
    Select-Object -First 1)

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$model = $server.Databases[0].Model

$daxFiles = Get-ChildItem $SourceDir -Filter '*.dax' -Recurse
$updated = 0; $skipped = 0; $notFound = 0

foreach ($file in $daxFiles) {
    $lines = Get-Content $file.FullName -Encoding UTF8
    $header = $lines[0] -replace '^\xEF\xBB\xBF', ''   # strip BOM

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
Write-Host "Done — updated: $updated | skipped: $skipped | not found: $notFound"
