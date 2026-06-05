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

# Zip
$distDir = Join-Path $MoonloaderRoot 'dist'
$zipName = "AdminReportDesk-$Version.zip"
$zipPath = Join-Path $distDir $zipName
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$items = @(
    (Join-Path $distDir 'admin_report_desk.lua'),
    (Join-Path $distDir 'report_desk_autoupdate.lua'),
    (Join-Path $distDir 'report_desk')
)
Compress-Archive -Path $items -DestinationPath $zipPath -Force
Write-Host "Release zip: $zipPath"
Write-Host ""
Write-Host "GitHub Release $tag upload:"
Write-Host "  - $coreAsset  (from dist\report_desk\)"
Write-Host "  - AdminReportDesk-$Version.zip"
Write-Host "  - commit release\version.json to main"
Write-Host ""
Write-Host "Quick publish: .\publish_release.ps1 -Version $Version"
