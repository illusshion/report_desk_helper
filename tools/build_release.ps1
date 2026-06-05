# Полный релиз Report Desk: bundle + version.json + zip для GitHub Releases.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Changelog = '',
    [switch]$SkipLuac
)

$ErrorActionPreference = 'Stop'
$bundleScript = Join-Path $PSScriptRoot 'bundle_report_desk.ps1'
if ($SkipLuac) {
    & $bundleScript -MoonloaderRoot $MoonloaderRoot -SkipLuac
} else {
    & $bundleScript -MoonloaderRoot $MoonloaderRoot
}

$repoConfigPath = Join-Path $MoonloaderRoot 'release\repo.config.json'
if (-not (Test-Path $repoConfigPath)) {
    Write-Error 'Missing release\repo.config.json — set github_owner and github_repo'
}
$repo = Get-Content $repoConfigPath -Raw | ConvertFrom-Json
$owner = $repo.github_owner
$repoName = $repo.github_repo
$tag = ($repo.release_tag_prefix) + $Version
if ($tag -notmatch '^v') { $tag = 'v' + $Version }

$coreLuac = Join-Path $MoonloaderRoot 'dist\report_desk\admin_report_desk_core.luac'
$coreLua = Join-Path $MoonloaderRoot 'dist\report_desk\admin_report_desk_core.lua'
$coreAsset = 'admin_report_desk_core.luac'
if (-not (Test-Path $coreLuac) -or $SkipLuac) {
    if (Test-Path $coreLua) {
        $coreAsset = 'admin_report_desk_core.lua'
        Write-Warning "Shipping $coreAsset (luac missing or -SkipLuac)"
    }
}
if ($Changelog -eq '') {
    $Changelog = "Report Desk $Version"
}
$versionJson = @{
    version   = $Version
    core_url  = "https://github.com/$owner/$repoName/releases/download/$tag/$coreAsset"
    changelog = $Changelog
} | ConvertTo-Json -Depth 3

$releaseDir = Join-Path $MoonloaderRoot 'release'
$versionPath = Join-Path $releaseDir 'version.json'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($versionPath, $versionJson + "`n", $Utf8NoBom)

$manifestUrl = "https://raw.githubusercontent.com/$owner/$repoName/main/release/version.json"
$updaterSrc = Join-Path $MoonloaderRoot 'report_desk_autoupdate.lua'
$updaterDist = Join-Path $MoonloaderRoot 'dist\report_desk_autoupdate.lua'
$updater = [System.IO.File]::ReadAllText($updaterSrc, $Utf8NoBom)
$updater = $updater -replace "M\.VERSION_JSON_URL = '[^']*'", "M.VERSION_JSON_URL = '$manifestUrl'"
[System.IO.File]::WriteAllText($updaterDist, $updater, $Utf8NoBom)
Write-Host "version.json + dist autoupdate URL -> $manifestUrl"

# Patch stub version
$stubPath = Join-Path $MoonloaderRoot 'dist\admin_report_desk.lua'
$stub = [System.IO.File]::ReadAllText($stubPath, $Utf8NoBom)
$stub = $stub -replace "script_version\('[^']*'\)", "script_version('$Version')"
[System.IO.File]::WriteAllText($stubPath, $stub, $Utf8NoBom)

# Zip (launcher + configs + preview assets)
$distDir = Join-Path $MoonloaderRoot 'dist'
$zipName = 'report_desk_helper_main.zip'
$zipPath = Join-Path $distDir $zipName
$stage = Join-Path $distDir '_zip_stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

Copy-Item (Join-Path $distDir 'admin_report_desk.lua') $stage
Copy-Item (Join-Path $distDir 'report_desk_autoupdate.lua') $stage
Copy-Item (Join-Path $distDir 'report_desk') (Join-Path $stage 'report_desk') -Recurse
$depsSrc = Join-Path $MoonloaderRoot 'report_desk_deps.lua'
if (Test-Path $depsSrc) {
    Copy-Item $depsSrc (Join-Path $stage 'report_desk_deps.lua') -Force
}

$configDir = Join-Path $stage 'config'
New-Item -ItemType Directory -Path $configDir | Out-Null
$userDefault = Join-Path $MoonloaderRoot 'config\admin_report_desk_user.default.lua'
$mainDefault = Join-Path $MoonloaderRoot 'config\admin_report_desk.default.lua'
if (-not (Test-Path $userDefault)) { Write-Error "Missing $userDefault" }
if (-not (Test-Path $mainDefault)) { Write-Error "Missing $mainDefault" }
Copy-Item $mainDefault (Join-Path $configDir 'admin_report_desk.lua')
Copy-Item $userDefault (Join-Path $configDir 'admin_report_desk_user.lua')

function Copy-PreviewAssets($srcSub, $dstSub) {
    $src = Join-Path $MoonloaderRoot $srcSub
    $dst = Join-Path $stage $dstSub
    if (-not (Test-Path $src)) {
        Write-Warning "Skip missing assets: $srcSub"
        return 0
    }
    New-Item -ItemType Directory -Path $dst -Force | Out-Null
    $n = 0
    Get-ChildItem $src -Recurse -File | Where-Object {
        $_.Extension -in '.png', '.jpg', '.jpeg', '.lua', '.csv', '.txt', '.dll'
    } | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length).TrimStart('\')
        $target = Join-Path $dst $rel
        $parent = Split-Path $target -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $_.FullName $target -Force
        $n++
    }
    return $n
}

$skinN = Copy-PreviewAssets 'res\report_desk_skins' 'res\report_desk_skins'
$vehN = Copy-PreviewAssets 'res\report_desk_vehicles' 'res\report_desk_vehicles'
$mimguiN = Copy-PreviewAssets 'lib\mimgui' 'lib\mimgui'
Write-Host "Zip assets: skins=$skinN veh=$vehN mimgui=$mimguiN"

$items = Get-ChildItem $stage | ForEach-Object { $_.FullName }
Compress-Archive -Path $items -DestinationPath $zipPath -Force
Remove-Item $stage -Recurse -Force
$zipMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "Release zip: $zipPath ($zipMb MB)"
Write-Host ""
Write-Host "GitHub Release $tag upload:"
Write-Host "  - $coreAsset  (from dist\report_desk\)"
Write-Host "  - report_desk_helper_main.zip"
Write-Host "  - commit release\version.json to main"
Write-Host ""
Write-Host "Quick publish: .\publish_release.ps1 -Version $Version"
