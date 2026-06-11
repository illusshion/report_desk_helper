# Clean + resize skin PNGs for Report Desk (uses fix_skin_assets.py).
param(
    [string]$SkinsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_skins'),
    [int]$MaxSide = 256,
    [switch]$Force,
    [switch]$Redownload
)

$py = Join-Path $PSScriptRoot 'fix_skin_assets.py'
if (-not (Test-Path $py)) {
    Write-Error "Missing $py"
    exit 1
}

$args = @($py, '--dir', $SkinsDir, '--max-side', $MaxSide)
if ($Redownload -or $Force) { $args += '--redownload' }

& python @args
exit $LASTEXITCODE
