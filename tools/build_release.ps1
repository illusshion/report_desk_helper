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
    $luajitCheck = Resolve-DeskLuajit $MoonloaderRoot $PSScriptRoot
    if (-not $luajitCheck) {
        Write-Error 'LuaJIT 2.1 compiler required. Extract tools/luajit-compiler from luajit-210-compiler.zip (blast.hk/moonloader). Use -SkipLuac only for dev plaintext builds.'
    }
    & $bundleScript -MoonloaderRoot $MoonloaderRoot
}

$repoConfigPath = Join-Path $MoonloaderRoot 'release\repo.config.json'
if (-not (Test-Path $repoConfigPath)) {
    Write-Error 'Missing release\repo.config.json — set github_owner and github_repo'
}
$repo = Get-Content $repoConfigPath -Raw | ConvertFrom-Json
$owner = $repo.github_owner
$repoName = $repo.github_repo
$tag = Get-DeskReleaseTag -Version $Version -Prefix $repo.release_tag_prefix

$coreLuac = Join-Path $MoonloaderRoot 'dist\report_desk\AdminDeskCore.luac'
$coreLua = Join-Path $MoonloaderRoot 'dist\report_desk\AdminDeskCore.lua'
$coreAsset = 'AdminDeskCore.luac'
$bootstrapLuac = Join-Path $MoonloaderRoot 'dist\AdminDesk.luac'
$bootstrapLua = Join-Path $MoonloaderRoot 'dist\AdminDesk.lua'
$bootstrapAsset = 'AdminDesk.luac'
if (-not (Test-Path $coreLuac) -or $SkipLuac) {
    if (Test-Path $coreLua) {
        $coreAsset = 'AdminDeskCore.lua'
        Write-Warning "Shipping $coreAsset (luac missing or -SkipLuac)"
    } else {
        Write-Error 'Bundle produced no core file in dist\report_desk\'
    }
}
if (-not (Test-Path $bootstrapLuac) -or $SkipLuac) {
    if (Test-Path $bootstrapLua) {
        $bootstrapAsset = 'AdminDesk.lua'
        Write-Warning "Shipping $bootstrapAsset (bootstrap luac missing or -SkipLuac)"
    } else {
        Write-Error 'Bundle produced no AdminDesk bootstrap in dist\'
    }
}
if ($Changelog -eq '') {
    $Changelog = "Report Desk $Version"
}

$zipName = 'report_desk_helper_main.zip'
$runtimeLibsName = 'report_desk_runtime_libs.zip'

# Синхронизация ядра в repo (raw fallback = plaintext AdminDeskCore.lua)
Clear-DeskGitIndexFlags $MoonloaderRoot @('report_desk/AdminDeskCore.lua', 'report_desk/admin_report_desk_core.lua')
$repoCoreDir = Join-Path $MoonloaderRoot 'report_desk'
New-Item -ItemType Directory -Force -Path $repoCoreDir | Out-Null
Copy-Item $coreLua (Join-Path $repoCoreDir 'AdminDeskCore.lua') -Force
Copy-Item $coreLua (Join-Path $repoCoreDir 'admin_report_desk_core.lua') -Force
$gitAttr = Join-Path $MoonloaderRoot '.gitattributes'
if (-not (Test-Path $gitAttr)) {
    Write-Warning '.gitattributes missing — git may alter core line endings (raw fallback != Release)'
} elseif ((Get-Content $gitAttr -Raw) -notlike '*AdminDeskCore.lua binary*' -and (Get-Content $gitAttr -Raw) -notlike '*admin_report_desk_core.lua binary*') {
    Write-Warning '.gitattributes must mark AdminDeskCore.lua as binary'
}
Write-Host "Synced report_desk\AdminDeskCore.lua (fallback on main)"

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

# Версия bootstrap + legacy stub
$bootstrapSrc = Join-Path $PSScriptRoot 'admin_desk_bootstrap.lua'
$bootstrapDistLua = Join-Path $MoonloaderRoot 'dist\AdminDesk.lua'
Set-DeskStubVersion $bootstrapSrc $Version
if (Test-Path $bootstrapDistLua) { Set-DeskStubVersion $bootstrapDistLua $Version }
if (Test-Path $bootstrapDistLua) {
    $luajitExe = Resolve-DeskLuajit $MoonloaderRoot $PSScriptRoot
    if ($luajitExe) {
        Invoke-DeskLuajitCompile $luajitExe $bootstrapDistLua $bootstrapLuac
    }
}
$stubSrc = Join-Path $PSScriptRoot 'admin_report_desk_stub.lua'
if (Test-Path $stubSrc) {
    $stubDist = Join-Path $MoonloaderRoot 'dist\admin_report_desk.lua'
    Set-DeskStubVersion $stubSrc $Version
    if (Test-Path $stubDist) { Set-DeskStubVersion $stubDist $Version }
}
Write-Host "Bootstrap version -> $Version"

# Zip (launcher + autoupdate + deps + core + configs + preview assets)
$distDir = Join-Path $MoonloaderRoot 'dist'
$zipPath = Join-Path $distDir $zipName
$stage = Join-Path $distDir '_zip_stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
New-Item -ItemType Directory -Path $stage | Out-Null

if (Test-Path (Join-Path $distDir $bootstrapAsset)) {
    Copy-Item (Join-Path $distDir $bootstrapAsset) $stage
}
if (Test-Path (Join-Path $distDir 'admin_report_desk.lua')) {
    Copy-Item (Join-Path $distDir 'admin_report_desk.lua') $stage
}
Copy-Item (Join-Path $distDir 'report_desk') (Join-Path $stage 'report_desk') -Recurse
$libStage = Join-Path $stage 'lib'
New-Item -ItemType Directory -Path $libStage -Force | Out-Null
Copy-Item (Join-Path $distDir 'report_desk_autoupdate.lua') (Join-Path $libStage 'report_desk_autoupdate.lua') -Force
foreach ($aux in @('report_desk_deps.lua', 'report_desk_sha256.lua', 'report_desk_zip.lua', 'report_desk_fs.lua', 'report_desk_update_overlay.lua')) {
    $src = Join-Path $MoonloaderRoot "lib\$aux"
    if (-not (Test-Path $src)) { Write-Error "Missing lib\$aux" }
    Copy-Item $src (Join-Path $libStage $aux) -Force
    Copy-Item $src (Join-Path $distDir $aux) -Force
}
$depsSrc = Join-Path $MoonloaderRoot 'lib\report_desk_deps.lua'
if (-not (Test-Path $depsSrc)) {
    $depsSrc = Join-Path $MoonloaderRoot 'report_desk_deps.lua'
}
if (-not (Test-Path $depsSrc)) {
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
Copy-Item $userDefault (Join-Path $configDir 'admin_report_desk_user.default.lua')
foreach ($intentCfg in @(
    'report_desk_intents.lua',
    'intent_trigger_extensions.lua',
    'intent_stem_blocklist.lua'
)) {
    $src = Join-Path $MoonloaderRoot "config\$intentCfg"
    if (-not (Test-Path $src)) {
        Write-Error "Missing intent config for release zip: config\$intentCfg"
    }
    Copy-Item $src (Join-Path $configDir $intentCfg) -Force
}

function Copy-PreviewAssets($srcSub, $dstSub) {
    $src = Resolve-DeskPreviewAssetsRoot $MoonloaderRoot $srcSub
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

function Copy-RuntimeLib($rel) {
    $src = Join-Path $MoonloaderRoot ($rel -replace '/', '\')
    if (-not (Test-Path $src)) {
        Write-Error "Missing runtime lib for zip: $rel"
    }
    $dst = Join-Path $stage ($rel -replace '/', '\')
    $parent = Split-Path $dst -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ((Get-Item $src).PSIsContainer) {
        Copy-Item $src $dst -Recurse -Force
    } else {
        Copy-Item $src $dst -Force
    }
}

$runtimeLibs = @(
    'lib\samp',
    'lib\vkeys.lua',
    'lib\encoding.lua',
    'lib\iconv.dll',
    'lib\vector3d.lua'
)
foreach ($rel in $runtimeLibs) { Copy-RuntimeLib $rel }

$skinN = Copy-PreviewAssets 'res\report_desk_skins' 'res\report_desk_skins'
$vehN = Copy-PreviewAssets 'res\report_desk_vehicles' 'res\report_desk_vehicles'
$mimguiN = Copy-PreviewAssets 'lib\mimgui' 'lib\mimgui'
Write-Host "Zip assets: skins=$skinN veh=$vehN mimgui=$mimguiN runtime=$($runtimeLibs.Count)"

$items = Get-ChildItem $stage | ForEach-Object { $_.FullName }
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Write-DeskStoreZip -SourceDir $stage -OutPath $zipPath
Remove-Item $stage -Recurse -Force
$zipMb = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Host "Release zip: $zipPath ($zipMb MB)"

# Малый runtime pack для autoupdate (lib/samp, encoding, vkeys, iconv, vector3d)
$runtimeStage = Join-Path $distDir '_runtime_stage'
if (Test-Path $runtimeStage) { Remove-Item $runtimeStage -Recurse -Force }
New-Item -ItemType Directory -Path (Join-Path $runtimeStage 'lib') -Force | Out-Null
foreach ($rel in $runtimeLibs) {
    $src = Join-Path $MoonloaderRoot ($rel -replace '/', '\')
    $dst = Join-Path $runtimeStage ($rel -replace '/', '\')
    $parent = Split-Path $dst -Parent
    if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
    if ((Get-Item $src).PSIsContainer) {
        Copy-Item $src $dst -Recurse -Force
    } else {
        Copy-Item $src $dst -Force
    }
}
$runtimeZipPath = Join-Path $distDir $runtimeLibsName
if (Test-Path $runtimeZipPath) { Remove-Item $runtimeZipPath -Force }
Write-DeskStoreZip -SourceDir $runtimeStage -OutPath $runtimeZipPath
Remove-Item $runtimeStage -Recurse -Force
Copy-Item (Join-Path $MoonloaderRoot 'lib\iconv.dll') (Join-Path $distDir 'iconv.dll') -Force
$runtimeKb = [math]::Round((Get-Item $runtimeZipPath).Length / 1KB, 1)
Write-Host "Runtime libs zip: $runtimeZipPath ($runtimeKb KB)"

$assetsZipPath = Join-Path $distDir 'report_desk_assets.zip'
Build-DeskAssetsZip -MoonloaderRoot $MoonloaderRoot -OutPath $assetsZipPath | Out-Null

$mimguiZipPath = Join-Path $distDir 'mimgui-v1.7.1.zip'
$mimguiStage = Join-Path $distDir '_mimgui_stage'
if (Test-Path $mimguiStage) { Remove-Item $mimguiStage -Recurse -Force }
New-Item -ItemType Directory -Path $mimguiStage -Force | Out-Null
$mimguiSrcZip = Join-Path $mimguiStage 'upstream.zip'
$mimguiUrl = 'https://github.com/THE-FYP/mimgui/releases/download/v1.7.1/mimgui-v1.7.1.zip'
Write-Host "Downloading mimgui repack source..."
Invoke-WebRequest -Uri $mimguiUrl -OutFile $mimguiSrcZip -UseBasicParsing
Add-Type -AssemblyName System.IO.Compression.FileSystem
$extractTmp = Join-Path $mimguiStage 'extract'
New-Item -ItemType Directory -Path $extractTmp -Force | Out-Null
[System.IO.Compression.ZipFile]::ExtractToDirectory($mimguiSrcZip, $extractTmp)
if (-not (Test-Path (Join-Path $extractTmp 'mimgui'))) {
    Write-Error 'mimgui upstream zip missing mimgui/ folder'
}
Write-DeskStoreZip -SourceDir $extractTmp -OutPath $mimguiZipPath
Remove-Item $mimguiStage -Recurse -Force
Write-Host "mimgui store zip: $mimguiZipPath"

$versionObj = Build-DeskVersionJson -MoonloaderRoot $MoonloaderRoot -Version $Version -Tag $tag `
    -Owner $owner -RepoName $repoName -CoreAssetName $coreAsset -BootstrapAssetName $bootstrapAsset `
    -Changelog $Changelog -ZipName $zipName
$releaseDir = Join-Path $MoonloaderRoot 'release'
$versionPath = Join-Path $releaseDir 'version.json'
$versionJson = $versionObj | ConvertTo-Json -Depth 6
[System.IO.File]::WriteAllText($versionPath, $versionJson + "`n", $Utf8NoBom)
Write-Host "version.json manifest v2 with SHA256 for all release files"

# Проверка: dist core = repo core = zip core; версии совпадают
$artifacts = Test-DeskReleaseArtifacts -MoonloaderRoot $MoonloaderRoot -Version $Version `
    -CoreAssetName $coreAsset -BootstrapAssetName $bootstrapAsset -ZipName $zipName
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
