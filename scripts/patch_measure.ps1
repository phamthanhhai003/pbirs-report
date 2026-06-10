param(
    [string]$Action  = "remove",
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
$m    = $server.Databases[0].Model.Tables[$Table].Measures[$Measure]
$expr = $m.Expression

if ($Action -eq "remove") {
    $startIdx = $expr.IndexOf('Total Loans')
    if ($startIdx -lt 0) { Write-Host "Total Loans not found"; exit 0 }
    $blockStart  = $expr.LastIndexOf('"<div', $startIdx)
    $closeMarker = "</div></div>"
    $closeIdx    = $expr.IndexOf($closeMarker, $startIdx) + $closeMarker.Length
    $quoteEnd    = $expr.IndexOf('"', $closeIdx)
    $ampEnd      = $expr.IndexOf('&', $quoteEnd)
    $m.Expression = $expr.Substring(0, $blockStart) + $expr.Substring($ampEnd + 1).TrimStart()
    Write-Host "Removed Total Loans card"
} elseif ($Action -eq "restore") {
    Write-Host "Use restore_measure.ps1 instead"
    exit 0
}

$server.Databases[0].Model.SaveChanges()
$server.Disconnect()
