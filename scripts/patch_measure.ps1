$rsDir = 'C:\Program Files\Microsoft Power BI Desktop RS\bin'
$teDir = 'C:\Program Files (x86)\Tabular Editor'
Get-ChildItem $rsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $teDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $teDir 'Microsoft.AnalysisServices.Tabular.dll')

$server  = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect('localhost:54386')
$measure = $server.Databases[0].Model.Tables['final_provision_report'].Measures['Provision_HTML']
$expr    = $measure.Expression

# Find and remove Total Loans card block
$startMarker = "Total Loans"
$startIdx = $expr.IndexOf($startMarker)

if ($startIdx -lt 0) {
    Write-Host "ERROR: 'Total Loans' not found in measure"
    $server.Disconnect()
    exit 1
}

# Walk back to find the opening "<div" before Total Loans
$blockStart = $expr.LastIndexOf('"<div', $startIdx)

# Walk forward to find "</div></div>" & after Total Loans value
$closeMarker = "</div></div>"
$closeIdx = $expr.IndexOf($closeMarker, $startIdx) + $closeMarker.Length

# Also skip trailing " & " or " &`n"
$tail = $expr.Substring($closeIdx)
if ($tail.TrimStart().StartsWith('"')) {
    # End of string concat  the "</div></div>" closes the string
    # Skip to end of quote + " &"
    $quoteEnd = $expr.IndexOf('"', $closeIdx)
    $ampEnd   = $expr.IndexOf('&', $quoteEnd)
    $blockEnd = $ampEnd + 1
} else {
    $blockEnd = $closeIdx
}

$new = $expr.Substring(0, $blockStart) + $expr.Substring($blockEnd).TrimStart()

Write-Host "Removed block ($($blockEnd - $blockStart) chars)"
$measure.Expression = $new
$server.Databases[0].Model.SaveChanges()
$server.Disconnect()
Write-Host "Done  Total Loans card removed from Provision_HTML"

