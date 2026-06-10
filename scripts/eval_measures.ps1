param(
    [string]$OutputJson = "C:\Users\Admin\AppData\Local\Temp\pbirs_measures.json",
    [string]$RsDir      = "C:\Program Files\Microsoft Power BI Desktop RS\bin",
    [string]$TeDir      = "C:\Program Files (x86)\Tabular Editor"
)

Get-ChildItem $RsDir -Filter "*.dll" | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Get-ChildItem $TeDir -Filter "*.dll" | ForEach-Object { try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {} }
Add-Type -Path (Join-Path $TeDir "Microsoft.AnalysisServices.Tabular.dll")
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.AnalysisServices.AdomdClient") | Out-Null

# Find PBI Desktop RS port
$pid_ = (Get-Process msmdsrv -ErrorAction SilentlyContinue |
    Where-Object { (Get-WmiObject Win32_Process -Filter "ProcessId=$($_.Id)").CommandLine -like "*Power BI Desktop SSRS*" } |
    Select-Object -First 1).Id
$port = (netstat -ano | Select-String $pid_.ToString() | Select-String "LISTENING" |
    ForEach-Object { ($_ -split '\s+')[2] -replace '.*:','' } | Select-Object -First 1)

# Get measure list via AMO
$server = New-Object Microsoft.AnalysisServices.Tabular.Server
$server.Connect("localhost:$port")
$db = $server.Databases[0]
$measures = @()
foreach ($table in $db.Model.Tables) {
    foreach ($m in $table.Measures) {
        $measures += @{ Table = $table.Name; Name = $m.Name }
    }
}
$server.Disconnect()

# Execute each measure via AdomdClient
$conn = New-Object Microsoft.AnalysisServices.AdomdClient.AdomdConnection("Data Source=localhost:$port")
$conn.Open()

$results = @{}
foreach ($m in $measures) {
    try {
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "EVALUATE ROW(`"R`", '$($m.Table)'[$($m.Name)])"
        $reader = $cmd.ExecuteReader()
        if ($reader.Read()) {
            $results["$($m.Table)__$($m.Name)"] = $reader.GetValue(0).ToString()
        }
        $reader.Close()
    } catch {
        $results["$($m.Table)__$($m.Name)"] = $null
    }
}

$conn.Close()

$results | ConvertTo-Json -Depth 3 | Set-Content $OutputJson -Encoding UTF8
Write-Host "Saved $($results.Count) measures to $OutputJson"
test
