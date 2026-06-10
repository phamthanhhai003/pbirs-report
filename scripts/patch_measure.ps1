param(
    [string]$Action    = "remove",
    [string]$CardLabel = "Total Loans",
    [string]$Table     = "",
    [string]$Measure   = ""
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
$model = $server.Databases[0].Model

# Build candidate list — filter by Table/Measure if provided, else scan all
$candidates = @()
foreach ($t in $model.Tables) {
    if ($Table -and $t.Name -ne $Table) { continue }
    foreach ($m in $t.Measures) {
        if ($Measure -and $m.Name -ne $Measure) { continue }
        if ($m.Expression -match [regex]::Escape($CardLabel)) {
            $candidates += @{ Table = $t.Name; Measure = $m.Name; Obj = $m }
        }
    }
}

if ($candidates.Count -eq 0) {
    Write-Host "NOT FOUND: '$CardLabel' in any measure$(if ($Table) { " (Table=$Table)" })$(if ($Measure) { " (Measure=$Measure)" })"
    $server.Disconnect(); exit 0
}

$changed = 0
foreach ($c in $candidates) {
    $expr = $c.Obj.Expression

    if ($Action -eq "remove") {
        $startIdx   = $expr.IndexOf($CardLabel)
        $blockStart = $expr.LastIndexOf('"<div', $startIdx)
        $closeMarker = "</div></div>"
        $closeIdx   = $expr.IndexOf($closeMarker, $startIdx) + $closeMarker.Length
        $quoteEnd   = $expr.IndexOf('"', $closeIdx)
        $ampEnd     = $expr.IndexOf('&', $quoteEnd)
        if ($blockStart -lt 0 -or $ampEnd -lt 0) {
            Write-Host "SKIP $($c.Table).$($c.Measure) — block boundary not found"
            continue
        }
        $c.Obj.Expression = $expr.Substring(0, $blockStart) + $expr.Substring($ampEnd + 1).TrimStart()
        Write-Host "Removed '$CardLabel' from $($c.Table).$($c.Measure)"
        $changed++
    }
}

if ($changed -gt 0) {
    $model.SaveChanges()
    Write-Host "Saved ($changed measure(s) updated)"
}
$server.Disconnect()
