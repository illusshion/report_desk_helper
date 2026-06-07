# Полный релиз Report Desk: bundle + version.json + zip + verify для GitHub Releases.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Changelog = '',
    [switch]$SkipLuac
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_lib.ps1')
$Utf8NoBom = Get-DeskUtf8NoBom

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
    } else {
        Write-Error 'Bundle produced no core file in dist\report_desk\'
    }
}
if ($Changelog -eq '') {
    $Changelog = "Report Desk $Version"
}

$zipName = 'report_desk_helper_main.zip'
$versionJson = @{
    version           = $Version
    core_url          = "https://github.com/$owner/$repoName/releases/download/$tag/$coreAsset"
    core_url_fallback = "https://raw.githubusercontent.com/$owner/$repoName/main/report_desk/admin_report_desk_core.lua"
    zip_url           = "https://github.com/$owner/$repoName/releases/download/$tag/$zipName"
    changelog         = $Changelog
} | ConvertTo-Json -Depth 3

$releaseDir = Join-Path $MoonloaderRoot 'release'
$versionPath = Join-Path $releaseDir 'version.json'
[System.IO.File]::WriteAllText($versionPath, $versionJson + "`n", $Utf8NoBom)

# Синхронизация ядра в repo (raw fallback = тот же файл, что уйдёт в Release)
Clear-DeskGitIndexFlags $MoonloaderRoot @('report_desk/admin_report_desk_core.lua')
$repoCoreDir = Join-Path $MoonloaderRoot 'report_desk'
New-Item -ItemType Directory -Force -Path $repoCoreDir | Out-Null
Copy-Item $coreLua (Join-Path $repoCoreDir 'admin_report_desk_core.lua') -Force
$gitAttr = Join-Path $MoonloaderRoot '.gitattributes'
if (-not (Test-Path $gitAttr)) {
    Write-Warning '.gitattributes missing — git may alter core line endings (raw fallback != Release)'
} elseif ((Get-Content $gitAttr -Raw) -notlike '*admin_report_desk_core.lua binary*') {
    Write-Warning '.gitattributes must mark admin_report_desk_core.lua as binary'
}
Write-Host "Synced report_desk\admin_report_desk_core.lua (fallback on main)"

$manifestUrl = "https://raw.githubusercontent.com/$owner/$repoName/main/release/version.json"
$updaterSrc = Join-Path $MoonloaderRoot 'lib\report_desk_autoupdate.lua'
if (-not (Test-Path $updaterSrc)) {
    $updaterSrc = Join-Path $MoonloaderRoot 'report_desk_autoupdate.lua'
}
$updaterDist = Join-Path $MoonloaderRoot 'dist\report_desk_autoupdate.lua'
$updater = [System.IO.File]::ReadAllText($updaterSrc, $Utf8NoBom)
$updater = $updater -replace "M\.VERSION_JSON_URL = '[^']*'", "M.VERSION_JSON_URL = '$manifestUrl'"
[System.IO.File]::WriteAllText($updaterDist, $updater, $Utf8NoBom)
Write-Host "dist autoupdate URL -> $manifestUrl"

# Версия launcher: tools stub (источник) + dist (zip)
$stubSrc = Join-Path $PSScriptRoot 'admin_report_desk_stub.lua'
$stubDist = Join-Path $MoonloaderRoot 'dist\admin_report_desk.lua'
Set-DeskStubVersion $stubSrc $Version
Set-DeskStubVersion $stubDist $Version
Write-Host "Launcher version -> $Version (tools stub + dist)"

# Zip (launcher + autoupdate + deps + core + configs + preview assets)
$distDir = Join-Path $MoonloaderRoot 'dist'
$zipPath = Join-Path $distDir $zipName
$stage = Join-Path $distDir '_zip_stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

Copy-Item (Join-Path $distDir 'admin_report_desk.lua') $stage
Copy-Item (Join-Path $distDir 'report_desk_autoupdate.lua') $stage
Copy-Item (Join-Path $distDir 'report_desk') (Join-Path $stage 'report_desk') -Recurse
$depsSrc = Join-Path $MoonloaderRoot 'lib\report_desk_deps.lua'
if (-not (Test-Path $depsSrc)) {
    $depsSrc = Join-Path $MoonloaderRoot 'report_desk_deps.lua'
}
if (Test-Path $depsSrc) {
    Copy-Item $depsSrc (Join-Path $stage 'report_desk_deps.lua') -Force
} else {
    Write-Error 'Missing lib\report_desk_deps.lua'
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

# Проверка: dist core = repo core = zip core; версии совпадают
$artifacts = Test-DeskReleaseArtifacts -MoonloaderRoot $MoonloaderRoot -Version $Version -CoreAssetName $coreAsset -ZipName $zipName
$manifestPath = Write-DeskBuildManifest -MoonloaderRoot $MoonloaderRoot -Version $Version -Tag $tag -Artifacts $artifacts

Write-Host ''
Write-Host 'Release verify OK' -ForegroundColor Green
Write-Host "  core sha256: $($artifacts.core.sha256)"
Write-Host "  core bytes:  $($artifacts.core.bytes)"
Write-Host "  zip sha256:  $($artifacts.zip.sha256)"
Write-Host "  manifest:    $manifestPath"
Write-Host ''
Write-Host "Next: .\publish_release.ps1 -Version $Version -GitCommit"
Write-Host "  (commit + push main, THEN GitHub Release $tag with dist artifacts)"
