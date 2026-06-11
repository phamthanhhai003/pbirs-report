param(
    [string]$FilePath,
    [string]$PbixName = "",
    [string]$BaseUrl,
    [string]$User,
    [string]$Pass   = "",
    [string]$Folder = ""
)

. "$PSScriptRoot\config.ps1"

if (!$Folder -and $ReportFolder) { $Folder = $ReportFolder }
if (!$Pass)   { $Pass = if ($env:PBIRS_PASS) { $env:PBIRS_PASS } else { $PbirsPass } }

function Get-OpenPbixPath {
    param([string]$PbixName = "")

    $pbi = Get-Process PBIDesktopRS,PBIDesktop -ErrorAction SilentlyContinue |
        Where-Object { $_.MainWindowTitle -match ' - Power BI' }
    if ($PbixName) { $pbi = $pbi | Where-Object { $_.MainWindowTitle -like "*$PbixName*" } }
    $pbi = $pbi | Select-Object -First 1
    if (!$pbi) { return $null }

    $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId=$($pbi.Id)").CommandLine
    if ($cmd -match '"([^"]+\.pbix)"') { return $Matches[1] }
    if ($cmd -match '(\S+\.pbix)')     { return $Matches[1] }

    $name = ($pbi.MainWindowTitle -split ' - Power BI')[0].Trim()
    foreach ($root in @($env:USERPROFILE, "C:\", "D:\") | Where-Object { Test-Path $_ }) {
        $found = Get-ChildItem $root -Filter "$name.pbix" -Recurse -Depth 5 -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

if (!$FilePath) { $FilePath = if ($PbixPath) { $PbixPath } else { Get-OpenPbixPath -PbixName $PbixName } }
if (!$BaseUrl)  { $BaseUrl  = "$PbirsHost/api/v2.0" }
if (!$User)     { $User     = $PbirsUser }

if (!$FilePath) {
    Write-Host "ERROR: No .pbix file found. Open file in PBI Desktop RS or set PbixPath in config.ps1."
    exit 1
}

$reportName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$targetPath = if ($Folder) { "$($Folder.TrimEnd('/'))/$reportName" } else { "/$reportName" }
$sizeMB     = [math]::Round((Get-Item $FilePath).Length / 1MB, 1)

Write-Host "File       : $FilePath ($sizeMB MB)"
Write-Host "Target path: $targetPath"

$cred = New-Object System.Management.Automation.PSCredential(
    $User, (ConvertTo-SecureString $Pass -AsPlainText -Force)
)

# Delete existing at target path
$existing = Invoke-RestMethod "$BaseUrl/PowerBIReports" -Credential $cred -UseBasicParsing
$match = $existing.value | Where-Object { $_.Path -eq $targetPath }
if ($match) {
    Write-Host "Deleting existing: $($match.Path)"
    Invoke-RestMethod "$BaseUrl/PowerBIReports($($match.Id))" -Method DELETE -Credential $cred -UseBasicParsing | Out-Null
}

# Upload via JSON + base64
Write-Host "Uploading..."
$b64  = [Convert]::ToBase64String([IO.File]::ReadAllBytes($FilePath))
$body = @{
    '@odata.type' = '#Model.PowerBIReport'
    'Name'        = $reportName
    'Path'        = $targetPath
    'Content'     = $b64
} | ConvertTo-Json -Compress

try {
    $result = Invoke-RestMethod "$BaseUrl/PowerBIReports" -Method POST -Body $body `
        -ContentType "application/json" -Credential $cred -UseBasicParsing
    Write-Host "OK: $($result.Name) -> $($result.Path)"
} catch {
    Write-Host "Failed: $($_.Exception.Response.StatusCode.value__)"
    $stream = $_.Exception.Response.GetResponseStream()
    if ($stream) { (New-Object System.IO.StreamReader($stream)).ReadToEnd() }
}
