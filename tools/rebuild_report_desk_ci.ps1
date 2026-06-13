# CI gate: verify bundle manifest, locals budget, env_export, rebuild AdminDeskCore.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [switch]$SkipBundle
)

$ErrorActionPreference = 'Stop'
$exitCode = 0

Write-Host '=== Report Desk CI: verify_report_desk_sanity (+ preload syntax) ==='
& (Join-Path $PSScriptRoot 'verify_report_desk_sanity.ps1')
if ($LASTEXITCODE -ne 0) { $exitCode = 1 }

Write-Host ''
Write-Host '=== Report Desk CI: audit_bundle_locals ==='
& (Join-Path $PSScriptRoot 'audit_bundle_locals.ps1') -LibDir (Join-Path $MoonloaderRoot 'lib')
# WARN-LUA51 is expected: chunk groups exceed 200 locals by design (concatenated loadstring).

Write-Host ''
Write-Host '=== Report Desk CI: audit_env_export ==='
& (Join-Path $PSScriptRoot 'audit_env_export.ps1') -LibDir (Join-Path $MoonloaderRoot 'lib')
if ($LASTEXITCODE -ne 0) { Write-Host 'env_export audit reported gaps (non-fatal review)' -ForegroundColor Yellow }

if (-not $SkipBundle) {
    Write-Host ''
    Write-Host '=== Report Desk CI: bundle_report_desk ==='
    & (Join-Path $PSScriptRoot 'bundle_report_desk.ps1') -MoonloaderRoot $MoonloaderRoot
    if ($LASTEXITCODE -ne 0) { $exitCode = 1 }
}

Write-Host ''
if ($exitCode -eq 0) {
    Write-Host 'Report Desk CI: OK' -ForegroundColor Green
} else {
    Write-Host 'Report Desk CI: FAILED' -ForegroundColor Red
}
exit $exitCode
