param(
    [string]$CorePath,
    [string]$ModuleName,
    [string]$OutPath
)
$ErrorActionPreference = 'Stop'
$text = [System.IO.File]::ReadAllText($CorePath)
$pattern = "package\.preload\['$([regex]::Escape($ModuleName))'\] = function\(\)\s*\r?\n\s*local fn, err = loadstring\(\[=\[\r?\n([\s\S]*?)\r?\n\]=\]"
$m = [regex]::Match($text, $pattern)
if (-not $m.Success) { throw "Module not found: $ModuleName" }
$content = $m.Groups[1].Value
$dir = Split-Path $OutPath -Parent
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($OutPath, $content + "`n", $Utf8NoBom)
Write-Host "Wrote $OutPath ($($content.Length) chars)"
