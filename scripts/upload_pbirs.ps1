param(
    [string]$FilePath = "C:\Users\Admin\OneDrive\Documents\Credit Report.pbix",
    [string]$BaseUrl  = "http://localhost/reports/api/v2.0",
    [string]$User     = "Admin",
    [string]$Pass     = "20032003"
)

$cred = New-Object System.Management.Automation.PSCredential(
    $User,
    (ConvertTo-SecureString $Pass -AsPlainText -Force)
)

$reportName = [System.IO.Path]::GetFileNameWithoutExtension($FilePath)
$fileBytes  = [System.IO.File]::ReadAllBytes($FilePath)
$enc        = [System.Text.Encoding]::UTF8
$boundary   = [System.Guid]::NewGuid().ToString()

# Build multipart body
$nl = "`r`n"
$header  = $enc.GetBytes("--$boundary$nl" +
    "Content-Disposition: form-data; name=`"Report`"; filename=`"$reportName.pbix`"$nl" +
    "Content-Type: application/octet-stream$nl$nl")
$footer  = $enc.GetBytes("$nl--$boundary--$nl")

$bodyStream = New-Object System.IO.MemoryStream
$bodyStream.Write($header,    0, $header.Length)
$bodyStream.Write($fileBytes, 0, $fileBytes.Length)
$bodyStream.Write($footer,    0, $footer.Length)
$body = $bodyStream.ToArray()

Write-Host "Uploading '$reportName' ($([math]::Round($fileBytes.Length/1MB, 1)) MB)..."

# Check if report exists
$existing = Invoke-RestMethod -Uri "$BaseUrl/PowerBIReports" -Credential $cred -UseBasicParsing
$match = $existing.value | Where-Object { $_.Name -eq $reportName }

if ($match) {
    Write-Host "Found existing report: $($match.Path) ??? deleting..."
    Invoke-RestMethod -Uri "$BaseUrl/PowerBIReports($($match.Id))" -Method DELETE -Credential $cred -UseBasicParsing
    Write-Host "Deleted."
}

# Upload
try {
    $resp = Invoke-WebRequest -Uri "$BaseUrl/PowerBIReports" `
        -Method POST `
        -Body $body `
        -ContentType "multipart/form-data; boundary=$boundary" `
        -Credential $cred `
        -UseBasicParsing
    Write-Host "Upload OK: HTTP $($resp.StatusCode)"
    $resp.Content | ConvertFrom-Json | Select-Object Name, Path, Id
} catch {
    Write-Host "Upload failed: $($_.Exception.Response.StatusCode.value__)"
    Write-Host $_.ErrorDetails.Message
}

