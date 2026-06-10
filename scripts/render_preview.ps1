param(
    [string]$OutputHtml = "C:\Users\Admin\AppData\Local\Temp\pbirs_preview.html",
    [string]$RsDir      = "C:\Program Files\Microsoft Power BI Desktop RS\bin",
    [string]$TeDir      = "C:\Program Files (x86)\Tabular Editor"
)

# Load DLLs
Get-ChildItem $RsDir -Filter "*.dll" | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $TeDir -Filter "*.dll" | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $TeDir "Microsoft.AnalysisServices.Tabular.dll")

# Find port
$pid_ = (Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object { (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*" } |
    Select-Object -First 1).Id

$port = (netstat -ano | Select-String $pid_.ToString() | Select-String "LISTENING" |
    ForEach-Object { ($_ -split '\s+')[2] -replace '.*:','' } | Select-Object -First 1)

$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$db = $server.Databases[0]

# Get all HTML measures (measures whose name ends with _HTML)
$htmlMeasures = @()
foreach ($table in $db.Model.Tables) {
    foreach ($m in $table.Measures) {
        if ($m.Name -like "*_HTML" -or $m.Name -like "*_html") {
            $htmlMeasures += @{ Table = $table.Name; Name = $m.Name }
        }
    }
}

# Execute each measure via XMLA
function Invoke-Dax($query, $catalog) {
    $xmla = @"
<Execute xmlns="urn:schemas-microsoft-com:xml-analysis">
  <Command><Statement>$query</Statement></Command>
  <Properties><PropertyList><Catalog>$catalog</Catalog><Format>Tabular</Format></PropertyList></Properties>
</Execute>
"@
    $result = $server.Execute($xmla)
    foreach ($res in $result) {
        if ($res.Messages.Count -gt 0) { return $null }
    }
    # Parse result XML
    $xml = [xml]$result[0].Value
    $ns  = @{ m = "urn:schemas-microsoft-com:xml-analysis:mddataset"; r = "urn:schemas-microsoft-com:xml-analysis:rowset" }
    $val = $xml.SelectSingleNode("//r:R/r:C1", (New-Object System.Xml.XmlNamespaceManager($xml.NameTable)))
    if ($val) { return $val.InnerText }
    return $null
}

# Get current (after) HTML for measures that changed
$afterHtmlMap = @{}
foreach ($m in $htmlMeasures) {
    $q   = "EVALUATE ROW(`"Result`", '$($m.Table)'[$($m.Name)])"
    $val = Invoke-Dax $q $db.Name
    $afterHtmlMap["$($m.Table)__$($m.Name)"] = $val
}

$server.Disconnect()

# Get previous (before) expressions from git
$beforeHtmlMap = @{}
foreach ($m in $htmlMeasures) {
    $safeName = $m.Name -replace '[\\/:*?"<>|]', '_'
    $daxFile  = "source\measures\$($m.Table)\$safeName.dax"
    $gitShow  = & git show "HEAD:$daxFile" 2>$null
    if ($gitShow) {
        $beforeHtmlMap["$($m.Table)__$($m.Name)"] = "(Previous DAX expression — requires live eval)"
    }
}

# Build side-by-side HTML page
$sections = ""
foreach ($key in $afterHtmlMap.Keys) {
    $name  = $key -replace '__', ' / '
    $after = $afterHtmlMap[$key]
    if (!$after) { continue }

    $sections += @"
<div class='measure-block'>
  <div class='measure-title'>$name</div>
  <div class='compare'>
    <div class='pane'>
      <div class='pane-label after'>AFTER (current)</div>
      <div class='pane-content'>$after</div>
    </div>
  </div>
</div>
"@
}

$page = @"
<!DOCTYPE html>
<html>
<head>
<meta charset='utf-8'>
<title>Report Preview</title>
<style>
  body { margin: 0; font-family: Segoe UI, sans-serif; background: #f1f5f9; }
  .header { background: #003366; color: #fff; padding: 14px 20px; font-size: 15px; font-weight: 700; border-bottom: 4px solid #f0a500; }
  .measure-block { margin: 16px; background: #fff; border-radius: 8px; box-shadow: 0 1px 4px rgba(0,0,0,.1); overflow: hidden; }
  .measure-title { background: #1e293b; color: #f0a500; font-size: 12px; font-weight: 700; padding: 8px 14px; text-transform: uppercase; letter-spacing: 1px; }
  .pane-label { font-size: 11px; font-weight: 700; padding: 6px 12px; text-transform: uppercase; }
  .pane-label.after { background: #dcfce7; color: #166534; }
  .pane-content { padding: 12px; overflow-x: auto; }
</style>
</head>
<body>
<div class='header'>Report Preview — PBIRS CI/CD</div>
$sections
</body>
</html>
"@

$page | Set-Content $OutputHtml -Encoding UTF8
Write-Host "Preview saved: $OutputHtml"
