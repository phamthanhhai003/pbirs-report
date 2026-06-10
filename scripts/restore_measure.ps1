param(
    [string]$DaxFile,
    [string]$Table   = "final_provision_report",
    [string]$Measure = "Provision_HTML"
)

. "$PSScriptRoot\config.ps1"

Get-ChildItem $RsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $TeDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $TeDir 'Microsoft.AnalysisServices.Tabular.dll')

$msmdsrvProc = Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object {
        (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*"
    } | Select-Object -First 1
$port = (netstat -ano | Select-String $msmdsrvProc.Id.ToString() |
    Select-String "LISTENING" |
    ForEach-Object { ($_ -split '\s+')[2] -replace '.*:','' } |
    Select-Object -First 1)

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$lines = Get-Content $DaxFile -Encoding UTF8
if ($lines[0] -match '^(?:\xEF\xBB\xBF)?MEASURE\s') { $lines = $lines[1..($lines.Length - 1)] }
$server.Databases[0].Model.Tables[$Table].Measures[$Measure].Expression = $lines -join "`n"
$server.Databases[0].Model.SaveChanges()
$server.Disconnect()
Write-Host "Restored $Measure from $DaxFile"
