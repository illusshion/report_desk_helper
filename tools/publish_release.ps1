# Сборка релиза Report Desk + подсказки для GitHub.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Changelog = '',
    [switch]$SkipLuac,
    [switch]$GitCommit
)

$ErrorActionPreference = 'Stop'
$build = Join-Path $PSScriptRoot 'build_release.ps1'
if ($Changelog -ne '') {
    & $build -MoonloaderRoot $MoonloaderRoot -Version $Version -Changelog $Changelog -SkipLuac:$SkipLuac
} else {
    & $build -MoonloaderRoot $MoonloaderRoot -Version $Version -SkipLuac:$SkipLuac
}

$repo = Get-Content (Join-Path $MoonloaderRoot 'release\repo.config.json') -Raw | ConvertFrom-Json
$owner = $repo.github_owner
$repoName = $repo.github_repo
$tag = $repo.release_tag_prefix + $Version
if ($tag -notmatch '^v') { $tag = 'v' + $Version }

$distDir = Join-Path $MoonloaderRoot 'dist'
$coreLuac = Join-Path $distDir 'report_desk\admin_report_desk_core.luac'
$coreLua = Join-Path $distDir 'report_desk\admin_report_desk_core.lua'
$coreAsset = if ((Test-Path $coreLuac) -and -not $SkipLuac) { 'admin_report_desk_core.luac' } else { 'admin_report_desk_core.lua' }
$zipName = "AdminReportDesk-$Version.zip"
$zipPath = Join-Path $distDir $zipName
$corePath = Join-Path $distDir "report_desk\$coreAsset"

if ($GitCommit) {
    Push-Location $MoonloaderRoot
    try {
        git add release/version.json CHANGELOG.md admin_report_desk_stub.lua report_desk_autoupdate.lua
        git commit -m "release: $Version"
        Write-Host "Committed release/version.json"
    } finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host '=== GitHub publish checklist ===' -ForegroundColor Cyan
Write-Host "Repo: https://github.com/$owner/$repoName"
Write-Host "1. git push origin main"
Write-Host "2. Releases -> New release -> tag $tag"
Write-Host "3. Attach files:"
Write-Host "     $corePath"
Write-Host "     $zipPath"
Write-Host "4. Admin installs zip -> moonloader, enters game -> auto-update pulls core"
Write-Host ''
Write-Host 'Test update: bump script_version in stub, rebuild, new release, /reload in game.'
