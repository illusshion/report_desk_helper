# Сборка релиза Report Desk + commit + чеклист публикации на GitHub.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Changelog = '',
    [switch]$SkipLuac,
    [switch]$GitCommit
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_lib.ps1')

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
$zipName = 'report_desk_helper_main.zip'
$zipPath = Join-Path $distDir $zipName
$corePath = Join-Path $distDir "report_desk\$coreAsset"
$manifestPath = Join-Path $MoonloaderRoot 'release\build_manifest.json'
$buildManifest = Get-Content $manifestPath -Raw | ConvertFrom-Json

if ($GitCommit) {
    Push-Location $MoonloaderRoot
    try {
        Add-DeskReleaseGitFiles $MoonloaderRoot
        $pending = git diff --cached --name-only
        if (-not $pending) {
            Write-Error 'Nothing staged for release commit — run build first or check file paths'
        }
        git commit -m "release: $Version"
        if ($LASTEXITCODE -ne 0) {
            throw "git commit failed (exit $LASTEXITCODE)"
        }
        Write-Host "Committed release $Version ($($pending.Count) files)" -ForegroundColor Green
        $pending | ForEach-Object { Write-Host "  $_" }
    } finally {
        Pop-Location
    }
}

Write-Host ''
Write-Host '=== GitHub publish checklist ===' -ForegroundColor Cyan
Write-Host "Repo: https://github.com/$owner/$repoName"
Write-Host ''
Write-Host '1. CHANGELOG.md - version entry ready'
if (-not $GitCommit) {
    Write-Host '2. git commit:' -ForegroundColor Yellow
    Write-Host "     .\publish_release.ps1 -Version $Version -GitCommit"
} else {
    Write-Host '2. git commit - DONE' -ForegroundColor Green
}
Write-Host '3. git push origin main  [DO BEFORE Release - fallback core on main]'
Write-Host "4. GitHub -> Releases -> New release -> tag $tag"
Write-Host '5. Attach ONLY these dist files (SHA256 in release\build_manifest.json):'
Write-Host "     $corePath"
Write-Host "       sha256: $($buildManifest.artifacts.core.sha256)"
Write-Host "     $zipPath"
Write-Host "       sha256: $($buildManifest.artifacts.zip.sha256)"
Write-Host '6. After Release publish - admins get core update on /reload'
Write-Host '7. If launcher/autoupdate/deps/mimgui changed - admins need new zip'
Write-Host ''
Write-Host 'Admin check: F7, moonloader.log -> [Report Desk] update: core up to date'
Write-Host ''
Write-Host 'Note: dev version in admin_report_desk.lua (3.xx) != release stub (1.xx) - OK'
