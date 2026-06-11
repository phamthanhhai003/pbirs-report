param(
    [string]$DaxFile,
    [string]$Table    = "final_provision_report",
    [string]$Measure  = "Provision_HTML",
    [string]$PbixName = ""
)

. "$PSScriptRoot\config.ps1"

Get-ChildItem $RsDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $TeDir -Filter '*.dll' | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $TeDir 'Microsoft.AnalysisServices.Tabular.dll')

# Find PBI window
$pbiProcs = Get-Process PBIDesktopRS,PBIDesktop -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -match ' - Power BI' }

if (!$pbiProcs) {
    Write-Host "ERROR: PBI Desktop RS not running. Open the .pbix file first."
    exit 1
}

if ($PbixName) {
    $pbiProcs = $pbiProcs | Where-Object { $_.MainWindowTitle -like "*$PbixName*" }
}

if (@($pbiProcs).Count -gt 1) {
    Write-Host "Multiple PBI windows open. Specify -PbixName to target one:"
    $pbiProcs | ForEach-Object { Write-Host "  - $($_.MainWindowTitle -replace ' - Power BI.*','')" }
    exit 1
}

$targetPbi = @($pbiProcs)[0]

# Map msmdsrv -> parent PBI process
$allMsmdsrv = Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object {
        (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*"
    }

$msmdsrvProc = $allMsmdsrv | Where-Object {
    $ppid = (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").ParentProcessId
    $ppid -eq $targetPbi.Id
} | Select-Object -First 1

if (!$msmdsrvProc) { $msmdsrvProc = $allMsmdsrv | Select-Object -First 1 }

if (!$msmdsrvProc) {
    Write-Host "ERROR: msmdsrv not found."
    exit 1
}

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
