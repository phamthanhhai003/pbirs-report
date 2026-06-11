param(
    [string]$FilePath,
    [string]$BaseUrl,
    [string]$User,
    [string]$Pass   = $env:PBIRS_PASS,
    [string]$Folder = ""   # override $ReportFolder from config, e.g. "/v2"
)

. "$PSScriptRoot\config.ps1"

if (!$Folder -and $ReportFolder) { $Folder = $ReportFolder }

function Get-OpenPbixPath {
    $pbi = Get-Process | Where-Object { $_.MainWindowTitle -match 'Power BI Desktop' } |
        Select-Object -First 1
    if (!$pbi) { return $null }

    $cmd = (Get-WmiObject Win32_Process -Filter "ProcessId=$($pbi.Id)").CommandLine
    if ($cmd -match '"([^"]+\.pbix)"') { return $Matches[1] }
    if ($cmd -match '(\S+\.pbix)')    { return $Matches[1] }

    $name = ($pbi.MainWindowTitle -split ' - Power BI')[0].Trim()
    $searchRoots = @(
        [Environment]::GetFolderPath('MyDocuments'),
        [Environment]::GetFolderPath('Desktop'),
        (Join-Path $env:USERPROFILE 'OneDrive\Documents'),
        (Join-Path $env:USERPROFILE 'Documents')
    ) | Where-Object { Test-Path $_ }

    foreach ($root in $searchRoots) {
        $found = Get-ChildItem $root -Filter "$name.pbix" -Recurse -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if ($found) { return $found.FullName }
    }
    return $null
}

if (!$FilePath) { $FilePath = if ($PbixPath) { $PbixPath } else { Get-OpenPbixPath } }
if (!$BaseUrl)  { $BaseUrl  = "$PbirsHost/api/v2.0" }
if (!$User)     { $User     = $PbirsUser }

if (!$FilePath) {
    Write-Host "ERROR: No .pbix file found. Open file in PBI Desktop RS or set PbixPath in config.ps1."
    exit 1
}

Write-Host "File: $FilePath"

$cred = New-Object System.Management.Automation.PSCredential(
    $User,
    (ConvertTo-SecureString $Pass -AsPlainText -Force)
)

$reportName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$fileBytes  = [System.IO.File]::ReadAllBytes($FilePath)
$boundary   = [System.Guid]::NewGuid().ToString()
$enc        = [System.Text.Encoding]::UTF8
$nl         = "`r`n"

$header = $enc.GetBytes("--$boundary$nl" +
    "Content-Disposition: form-data; name=`"Report`"; filename=`"$reportName.pbix`"$nl" +
    "Content-Type: application/octet-stream$nl$nl")
$footer = $enc.GetBytes("$nl--$boundary--$nl")

$bodyStream = New-Object System.IO.MemoryStream
$bodyStream.Write($header,    0, $header.Length)
$bodyStream.Write($fileBytes, 0, $fileBytes.Length)
$bodyStream.Write($footer,    0, $footer.Length)
$body = $bodyStream.ToArray()

Write-Host "Uploading '$reportName' ($([math]::Round($fileBytes.Length/1MB, 1)) MB)..."

$targetPath = if ($Folder) { "$($Folder.TrimEnd('/'))/$reportName" } else { "/$reportName" }
Write-Host "Target path: $targetPath"

# Delete existing report at target path if present
$existing = Invoke-RestMethod -Uri "$BaseUrl/PowerBIReports" -Credential $cred -UseBasicParsing
$match    = $existing.value | Where-Object { $_.Path -eq $targetPath }
if ($match) {
    Write-Host "Deleting existing: $($match.Path)"
    Invoke-RestMethod -Uri "$BaseUrl/PowerBIReports($($match.Id))" -Method DELETE -Credential $cred -UseBasicParsing
}

try {
    # Upload to root first
    $resp   = Invoke-WebRequest -Uri "$BaseUrl/PowerBIReports" `
        -Method POST -Body $body `
        -ContentType "multipart/form-data; boundary=$boundary" `
        -Credential $cred -UseBasicParsing
    $result = $resp.Content | ConvertFrom-Json
    Write-Host "Uploaded: $($result.Path)"

    # Move to target folder if specified
    if ($Folder -and $result.Path -ne $targetPath) {
        Write-Host "Moving to $targetPath ..."
        $moveBody = @{ Path = $targetPath } | ConvertTo-Json
        Invoke-RestMethod -Uri "$BaseUrl/PowerBIReports($($result.Id))/Model.MoveItem()" `
            -Method POST -Body $moveBody -ContentType "application/json" `
            -Credential $cred -UseBasicParsing | Out-Null

        # Fetch updated item to confirm
        $updated = Invoke-RestMethod -Uri "$BaseUrl/PowerBIReports" -Credential $cred -UseBasicParsing
        $result  = $updated.value | Where-Object { $_.Path -eq $targetPath } | Select-Object -First 1
    }

    Write-Host "OK: $($result.Name) → $($result.Path)"
} catch {
    Write-Host "Failed: $($_.Exception.Response.StatusCode.value__)"
    Write-Host $_.ErrorDetails.Message
}
