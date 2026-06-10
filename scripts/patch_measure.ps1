param([string]$Action = "remove")

$rsDir = 'C:\Program Files\Microsoft Power BI Desktop RS\bin'
$teDir = 'C:\Program Files (x86)\Tabular Editor'
Get-ChildItem $rsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $teDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $teDir 'Microsoft.AnalysisServices.Tabular.dll')

$server  = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect('localhost:54386')
$measure = $server.Databases[0].Model.Tables['final_provision_report'].Measures['Provision_HTML']
$expr    = $measure.Expression

if ($Action -eq "remove") {
    $startIdx  = $expr.IndexOf('Total Loans')
    if ($startIdx -lt 0) { Write-Host "Total Loans not found"; exit 0 }
    $blockStart = $expr.LastIndexOf('"<div', $startIdx)
    $closeMarker = "</div></div>"
    $closeIdx = $expr.IndexOf($closeMarker, $startIdx) + $closeMarker.Length
    $quoteEnd = $expr.IndexOf('"', $closeIdx)
    $ampEnd   = $expr.IndexOf('&', $quoteEnd)
    $blockEnd = $ampEnd + 1
    $measure.Expression = $expr.Substring(0, $blockStart) + $expr.Substring($blockEnd).TrimStart()
    Write-Host "Removed Total Loans card"
} elseif ($Action -eq "restore") {
    Write-Host "Use restore_measure.ps1 instead"
    exit 0
}

$server.Databases[0].Model.SaveChanges()
$server.Disconnect()
