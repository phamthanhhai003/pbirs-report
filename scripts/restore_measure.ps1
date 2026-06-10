param([string]$DaxFile)

$rsDir = 'C:\Program Files\Microsoft Power BI Desktop RS\bin'
$teDir = 'C:\Program Files (x86)\Tabular Editor'
Get-ChildItem $rsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $teDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $teDir 'Microsoft.AnalysisServices.Tabular.dll')

$server  = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect('localhost:54386')
$measure = $server.Databases[0].Model.Tables['final_provision_report'].Measures['Provision_HTML']
$measure.Expression = Get-Content $DaxFile -Raw -Encoding UTF8
$server.Databases[0].Model.SaveChanges()
$server.Disconnect()
Write-Host "Restored Provision_HTML from $DaxFile"
