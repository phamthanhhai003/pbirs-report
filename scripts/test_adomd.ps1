$rsDir = 'C:\Program Files\Microsoft Power BI Desktop RS\bin'

# Load all RS DLLs first
Get-ChildItem $rsDir -Filter '*.dll' | ForEach-Object {
    try { [System.Reflection.Assembly]::LoadFrom($_.FullName) | Out-Null } catch {}
}

# Now load AdomdClient
$asm = [System.Reflection.Assembly]::LoadFrom("$rsDir\Microsoft.PowerBI.AdomdClient.dll")
Write-Host "Loaded: $($asm.FullName)"

$types = $asm.GetTypes() | Where-Object { $_.IsPublic } | Select-Object -ExpandProperty FullName
$types | Select-String 'Connection|Command'
