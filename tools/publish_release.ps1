# Сборка релиза Report Desk + commit + публикация на GitHub Releases.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Changelog = '',
    [switch]$SkipLuac,
    [switch]$GitCommit,
    [switch]$Publish,
    [switch]$Push
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
$coreLuac = Join-Path $distDir 'report_desk\AdminDeskCore.luac'
$coreLua = Join-Path $distDir 'report_desk\AdminDeskCore.lua'
$coreAsset = if ((Test-Path $coreLuac) -and -not $SkipLuac) { 'AdminDeskCore.luac' } else { 'AdminDeskCore.lua' }
$bootstrapLuac = Join-Path $distDir 'AdminDesk.luac'
$bootstrapAsset = if ((Test-Path $bootstrapLuac) -and -not $SkipLuac) { 'AdminDesk.luac' } else { 'AdminDesk.lua' }
$assetsZipPath = Join-Path $distDir 'report_desk_assets.zip'
$zipName = 'report_desk_helper_main.zip'
$zipPath = Join-Path $distDir $zipName
$corePath = Join-Path $distDir "report_desk\$coreAsset"
$manifestPath = Join-Path $MoonloaderRoot 'release\build_manifest.json'
$buildManifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
$runtimeZipPath = Join-Path $distDir 'report_desk_runtime_libs.zip'
$iconvPath = Join-Path $distDir 'iconv.dll'
$autoupdatePath = Join-Path $distDir 'report_desk_autoupdate.lua'
$depsPath = Join-Path $distDir 'report_desk_deps.lua'
$bootstrapPath = Join-Path $distDir $bootstrapAsset
$launcherPath = Join-Path $distDir 'admin_report_desk.lua'

if ($GitCommit) {
    Push-Location $MoonloaderRoot
    try {
        Add-DeskReleaseGitFiles $MoonloaderRoot
        $pending = git diff --cached --name-only
        if (-not $pending) {
            Write-Error 'Nothing staged for release commit - run build first or check file paths'
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

if ($Push) {
    Push-Location $MoonloaderRoot
    try {
        git push origin main
        if ($LASTEXITCODE -ne 0) {
            throw "git push failed (exit $LASTEXITCODE)"
        }
        Write-Host 'git push origin main - DONE' -ForegroundColor Green
        Write-Host 'Wait 1-2 min for raw.githubusercontent.com cache before admins update' -ForegroundColor Yellow
    } finally {
        Pop-Location
    }
}

if ($Publish) {
    $gh = Get-Command gh -ErrorAction SilentlyContinue
    if (-not $gh) {
        Write-Error 'GitHub CLI (gh) not found. Install: https://cli.github.com/ or publish manually.'
    }
    if (-not $Push) {
        Write-Warning 'Publish without -Push: ensure main branch is already pushed (fallback core + version.json)'
    }

    $sha256Path = Join-Path $distDir 'report_desk_sha256.lua'
    $zipModPath = Join-Path $distDir 'report_desk_zip.lua'
    $fsModPath = Join-Path $distDir 'report_desk_fs.lua'
    $mimguiZipPath = Join-Path $distDir 'mimgui-v1.7.1.zip'

    $releaseAssets = @(
        $bootstrapPath,
        $corePath,
        $assetsZipPath,
        $zipPath,
        $runtimeZipPath,
        $iconvPath,
        $autoupdatePath,
        $depsPath,
        $sha256Path,
        $zipModPath,
        $fsModPath,
        $mimguiZipPath
    )
    if (Test-Path $launcherPath) {
        $releaseAssets += $launcherPath
    }
    foreach ($asset in $releaseAssets) {
        if (-not (Test-Path $asset)) {
            Write-Error "Missing release asset: $asset"
        }
    }

    $notes = if ($Changelog -ne '') { $Changelog } else { "Report Desk $Version" }
    $releaseExists = $false
    try {
        gh release view $tag --repo "$owner/$repoName" 1>$null 2>$null
        if ($LASTEXITCODE -eq 0) { $releaseExists = $true }
    } catch {
        $releaseExists = $false
    }
    if ($releaseExists) {
        Write-Host "Release $tag exists - uploading assets..." -ForegroundColor Yellow
        foreach ($asset in $releaseAssets) {
            gh release upload $tag $asset --repo "$owner/$repoName" --clobber
            if ($LASTEXITCODE -ne 0) {
                throw "gh release upload failed for $asset"
            }
            Write-Host "  uploaded: $(Split-Path $asset -Leaf)" -ForegroundColor Green
        }
    } else {
        gh release create $tag `
            --repo "$owner/$repoName" `
            --title "Report Desk $Version" `
            --notes $notes `
            $releaseAssets
        if ($LASTEXITCODE -ne 0) {
            throw 'gh release create failed'
        }
        Write-Host "Created release $tag with all assets" -ForegroundColor Green
    }
}

Write-Host ''
Write-Host '=== GitHub publish checklist ===' -ForegroundColor Cyan
Write-Host "Repo: https://github.com/$owner/$repoName"
Write-Host "Manifest: release/version.json (manifest v2, SHA256 per file)"
Write-Host ''
Write-Host '1. CHANGELOG.md - version entry ready'
if (-not $GitCommit) {
    Write-Host '2. git commit:' -ForegroundColor Yellow
    Write-Host "     .\publish_release.ps1 -Version $Version -GitCommit"
} else {
    Write-Host '2. git commit - DONE' -ForegroundColor Green
}
if (-not $Push) {
    Write-Host '3. git push:' -ForegroundColor Yellow
    Write-Host "     .\publish_release.ps1 -Version $Version -Push"
} else {
    Write-Host '3. git push origin main - DONE' -ForegroundColor Green
}
if (-not $Publish) {
    Write-Host '4. GitHub Release:' -ForegroundColor Yellow
    Write-Host "     .\publish_release.ps1 -Version $Version -Publish -Push"
    Write-Host "   Or manual: tag $tag, attach dist files (SHA256 in release\build_manifest.json)"
} else {
    Write-Host "4. GitHub Release $tag - DONE" -ForegroundColor Green
}
Write-Host '5. Admin check: /deskupdate, /deskrepair, moonloader.log'
Write-Host ''
Write-Host 'Dist artifacts (SHA256 in release\build_manifest.json):'
Write-Host "  core:       $corePath"
Write-Host "    sha256:   $($buildManifest.artifacts.core.sha256)"
Write-Host "  zip:        $zipPath"
Write-Host "    sha256:   $($buildManifest.artifacts.zip.sha256)"
Write-Host "  launcher:   $launcherPath"
Write-Host "  autoupdate: $autoupdatePath"
Write-Host "  deps:       $depsPath"
Write-Host "  runtime:    $runtimeZipPath"
Write-Host "  iconv:      $iconvPath"
Write-Host ''
Write-Host 'Note: dev version in admin_report_desk.lua (3.xx) != release stub (1.xx) - OK'
