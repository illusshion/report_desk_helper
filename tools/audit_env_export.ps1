# Compare core_a locals in state.lua vs assignments in report_desk_env_export.lua.
param(
    [string]$LibDir = (Join-Path $PSScriptRoot '..\lib')
)

$statePath = Join-Path $LibDir 'report_desk_state.lua'
$exportPath = Join-Path $LibDir 'report_desk_env_export.lua'
if (-not (Test-Path $statePath)) { throw "Missing: $statePath" }
if (-not (Test-Path $exportPath)) { throw "Missing: $exportPath" }

$stateText = Get-Content $statePath -Raw
$exportText = Get-Content $exportPath -Raw

# Globals assigned in state.lua (non-local top-level identifiers).
$stateGlobals = [regex]::Matches($stateText, '(?m)^([a-zA-Z_][\w]*)\s*=') |
    ForEach-Object { $_.Groups[1].Value } |
    Where-Object { $_ -notin @('if', 'for', 'while', 'function', 'return', 'end', 'else', 'elseif', 'then', 'do') } |
    Select-Object -Unique

# Symbols exported via getfenv(1).name = name
$exported = [regex]::Matches($exportText, 'getfenv\(1\)\.([a-zA-Z_][\w]*)\s*=') |
    ForEach-Object { $_.Groups[1].Value } |
    Select-Object -Unique

# Locals in state that env_export should bridge (heuristic: local X in state, exported as getfenv(1).X).
$stateLocals = [regex]::Matches($stateText, '(?m)^local\s+([a-zA-Z_][\w]*)') |
    ForEach-Object { $_.Groups[1].Value } |
    Select-Object -Unique

$bridgedLocals = $stateLocals | Where-Object { $exported -contains $_ }
$missingLocals = $stateLocals | Where-Object {
    $exported -notcontains $_ -and
    $_ -notin @('DEFAULT_QUICK_SCENARIOS', 'BUILTIN_AUTO_RULE_GG', 'BUILTIN_AUTO_RULE_TIME')
}

Write-Host "state.lua globals: $($stateGlobals.Count)"
Write-Host "env_export symbols: $($exported.Count)"
Write-Host "state locals bridged: $($bridgedLocals.Count)"
Write-Host ''

if ($missingLocals.Count -gt 0) {
    Write-Host 'Locals in state.lua not exported (review if needed by core_b/c):' -ForegroundColor Yellow
    $missingLocals | ForEach-Object { Write-Host "  $_" }
}

$orphanExports = $exported | Where-Object { $stateLocals -notcontains $_ -and $stateGlobals -notcontains $_ }
if ($orphanExports.Count -gt 0) {
    Write-Host ''
    Write-Host 'Exports without obvious source in state.lua (may come from other core_a files):' -ForegroundColor Cyan
    $orphanExports | Select-Object -First 20 | ForEach-Object { Write-Host "  $_" }
    if ($orphanExports.Count -gt 20) {
        Write-Host "  ... and $($orphanExports.Count - 20) more"
    }
}

if ($missingLocals.Count -gt 0) { exit 1 }
exit 0
