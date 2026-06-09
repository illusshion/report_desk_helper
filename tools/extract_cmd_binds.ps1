$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$core = Join-Path $root 'report_desk\AdminDeskCore.lua'
$out = Join-Path $root 'lib\report_desk_cmd_binds.lua'
$lines = [System.IO.File]::ReadAllLines($core)
$start = 31711  # 0-based index for line 31712 (loadstring content start)
$end = 32050    # 0-based exclusive for line 32051 (closing chunk)
$chunk = ($lines[$start..($end - 1)] -join "`n").TrimEnd()
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($out, $chunk + "`n", $Utf8NoBom)
Write-Host "Wrote $out ($($chunk.Length) chars, $($end - $start) lines)"
