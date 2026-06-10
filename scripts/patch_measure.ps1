$rsDir = 'C:\Program Files\Microsoft Power BI Desktop RS\bin'
$teDir = 'C:\Program Files (x86)\Tabular Editor'
Get-ChildItem $rsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $teDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $teDir 'Microsoft.AnalysisServices.Tabular.dll')

$server  = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect('localhost:54386')
$measure = $server.Databases[0].Model.Tables['final_provision_report'].Measures['Provision_HTML']
$expr    = $measure.Expression

$totalLoansCard = "<div style='background:#fff;border:1px solid #e2e8f0;border-radius:6px;padding:10px 16px;min-width:120px;'><div style='font-size:9px;color:#6b7280;text-transform:uppercase;letter-spacing:0.5px;margin-bottom:3px;'>Total Loans</div><div style='font-size:20px;font-weight:800;color:#003366;font-family:Consolas,monospace;'>" + '" & FORMAT(RowCount,"#,##0") & "' + "</div></div>"

$insertAfter = "<div style='display:flex;gap:12px;flex-wrap:wrap;padding:14px 16px;background:#f8fafc;border-bottom:1px solid #e2e8f0;'>" + '" &'
$insertPoint = $expr.IndexOf($insertAfter) + $insertAfter.Length

$new = $expr.Substring(0, $insertPoint) + "`n    " + $totalLoansCard + " &" + $expr.Substring($insertPoint)

$measure.Expression = $new
$server.Databases[0].Model.SaveChanges()
$server.Disconnect()
Write-Host "Done - Total Loans card restored"
