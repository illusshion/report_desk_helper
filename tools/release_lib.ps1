# Shared helpers for Report Desk release pipeline.

function Get-DeskUtf8NoBom {
    return New-Object System.Text.UTF8Encoding $false
}

function Get-DeskFileSha256([string]$Path) {
    if (-not (Test-Path $Path)) {
        throw "File not found for SHA256: $Path"
    }
    return (Get-FileHash -Algorithm SHA256 -Path $Path).Hash.ToLowerInvariant()
}

function Clear-DeskGitIndexFlags([string]$MoonloaderRoot, [string[]]$RelPaths) {
    Push-Location $MoonloaderRoot
    try {
        foreach ($rel in $RelPaths) {
            $tracked = git ls-files -- $rel 2>$null
            if (-not $tracked) { continue }
            git update-index --no-assume-unchanged $rel 2>$null | Out-Null
            git update-index --no-skip-worktree $rel 2>$null | Out-Null
        }
    } finally {
        Pop-Location
    }
}

function Set-DeskStubVersion([string]$Path, [string]$Version) {
    if (-not (Test-Path $Path)) {
        throw "Stub not found: $Path"
    }
    $enc = Get-DeskUtf8NoBom
    $text = [System.IO.File]::ReadAllText($Path, $enc)
    if ($text -notmatch "script_version\('[^']*'\)") {
        throw "script_version not found in $Path"
    }
    $patched = $text -replace "script_version\('[^']*'\)", "script_version('$Version')"
    if ($patched -ne $text) {
        [System.IO.File]::WriteAllText($Path, $patched, $enc)
    }
}

function Test-DeskStubHasVersion([string]$Path, [string]$Version) {
    $enc = Get-DeskUtf8NoBom
    $text = [System.IO.File]::ReadAllText($Path, $enc)
    $needle = "script_version('$Version')"
    return $text.Contains($needle)
}

function Test-DeskZipHasEntry([string]$ZipPath, [string]$EntryName) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipFull = (Resolve-Path $ZipPath).Path
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFull)
    try {
        $normalized = $EntryName -replace '/', '\'
        $entry = $zip.Entries | Where-Object { ($_.FullName -replace '/', '\') -eq $normalized } | Select-Object -First 1
        return [bool]$entry
    } finally {
        $zip.Dispose()
    }
}

function Get-DeskZipEntrySha256([string]$ZipPath, [string]$EntryName) {
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zipFull = (Resolve-Path $ZipPath).Path
    $zip = [System.IO.Compression.ZipFile]::OpenRead($zipFull)
    try {
        $normalized = $EntryName -replace '/', '\'
        $entry = $zip.Entries | Where-Object { ($_.FullName -replace '/', '\') -eq $normalized } | Select-Object -First 1
        if (-not $entry) {
            throw "Zip entry not found: $EntryName in $ZipPath"
        }
        $tmp = Join-Path $env:TEMP ("desk_zip_entry_" + [guid]::NewGuid().ToString('N') + '.lua')
        try {
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $tmp, $true)
            return Get-DeskFileSha256 $tmp
        } finally {
            if (Test-Path $tmp) { Remove-Item $tmp -Force }
        }
    } finally {
        $zip.Dispose()
    }
}

function Test-DeskReleaseArtifacts {
    param(
        [string]$MoonloaderRoot,
        [string]$Version,
        [string]$CoreAssetName,
        [string]$ZipName = 'report_desk_helper_main.zip'
    )

    $distCore = Join-Path $MoonloaderRoot "dist\report_desk\$CoreAssetName"
    $repoCore = Join-Path $MoonloaderRoot 'report_desk\admin_report_desk_core.lua'
    $zipPath = Join-Path $MoonloaderRoot "dist\$ZipName"
    $launcherPath = Join-Path $MoonloaderRoot 'dist\admin_report_desk.lua'
    $versionPath = Join-Path $MoonloaderRoot 'release\version.json'
    $autoupdatePath = Join-Path $MoonloaderRoot 'dist\report_desk_autoupdate.lua'
    $depsPath = Join-Path $MoonloaderRoot 'dist\report_desk_deps.lua'

    foreach ($p in @($distCore, $repoCore, $zipPath, $launcherPath, $versionPath, $autoupdatePath, $depsPath)) {
        if (-not (Test-Path $p)) {
            throw "Release verify failed: missing artifact $p"
        }
    }

    $distHash = Get-DeskFileSha256 $distCore
    $repoHash = Get-DeskFileSha256 $repoCore
    if ($distHash -ne $repoHash) {
        throw "Release verify failed: dist core hash != repo core hash"
    }

    $zipCoreEntry = "report_desk\$CoreAssetName"
    $zipCoreHash = Get-DeskZipEntrySha256 $zipPath $zipCoreEntry
    if ($zipCoreHash -ne $distHash) {
        throw "Release verify failed: zip core hash != dist core hash"
    }

    $requiredZipEntries = @(
        'lib\mimgui\init.lua',
        'lib\samp\events.lua',
        'lib\vkeys.lua',
        'lib\encoding.lua',
        'lib\iconv.dll',
        'lib\vector3d.lua',
        'lib\report_desk_deps.lua',
        'lib\report_desk_autoupdate.lua',
        'config\admin_report_desk_user.lua'
    )
    $runtimeZipPath = Join-Path $MoonloaderRoot 'dist\report_desk_runtime_libs.zip'
    $iconvDistPath = Join-Path $MoonloaderRoot 'dist\iconv.dll'
    $depsDistPath = Join-Path $MoonloaderRoot 'dist\report_desk_deps.lua'
    foreach ($p in @($runtimeZipPath, $iconvDistPath, $depsDistPath)) {
        if (-not (Test-Path $p)) {
            throw "Release verify failed: missing dist artifact $p"
        }
    }
    foreach ($entry in $requiredZipEntries) {
        if (-not (Test-DeskZipHasEntry $zipPath $entry)) {
            throw "Release verify failed: zip missing entry $entry"
        }
    }

    $coreText = [System.IO.File]::ReadAllText($repoCore, (Get-DeskUtf8NoBom))
    $embedNeedle = "package.preload['report_desk_user_defaults'] = function"
    if (-not $coreText.Contains($embedNeedle)) {
        throw 'Release verify failed: core missing embedded report_desk_user_defaults preload'
    }
    if (-not $coreText.Contains("package.preload['lib.samp.events']")) {
        throw 'Release verify failed: core missing embedded lib.samp.events preload'
    }
    if ($coreText -notlike '*ensureIconvDll*') {
        throw 'Release verify failed: core missing ensureIconvDll bootstrap'
    }

    $manifest = Get-Content $versionPath -Raw | ConvertFrom-Json
    if (-not $manifest.runtime_libs_url) {
        throw 'Release verify failed: version.json missing runtime_libs_url'
    }
    if (-not $manifest.iconv_url) {
        throw 'Release verify failed: version.json missing iconv_url'
    }

    $manifest = Get-Content $versionPath -Raw | ConvertFrom-Json
    if ($manifest.version -ne $Version) {
        throw "Release verify failed: version.json has $($manifest.version), expected $Version"
    }
    if ($manifest.core_url -notlike "*$CoreAssetName*") {
        throw "Release verify failed: core_url does not reference $CoreAssetName"
    }

    if (-not (Test-DeskStubHasVersion $launcherPath $Version)) {
        throw "Release verify failed: dist launcher script_version is not $Version"
    }

    $autoupdateText = [System.IO.File]::ReadAllText($autoupdatePath, (Get-DeskUtf8NoBom))
    if ($autoupdateText -notlike '*raw.githubusercontent.com*') {
        throw 'Release verify failed: dist autoupdate has no VERSION_JSON_URL'
    }

    $stubPath = Join-Path $MoonloaderRoot 'tools\admin_report_desk_stub.lua'
    if (-not (Test-DeskStubHasVersion $stubPath $Version)) {
        throw "Release verify failed: tools stub script_version is not $Version"
    }

    return @{
        version    = $Version
        core_asset = $CoreAssetName
        core       = @{
            dist_path = "dist\report_desk\$CoreAssetName"
            repo_path = 'report_desk\admin_report_desk_core.lua'
            sha256    = $distHash
            bytes     = (Get-Item $distCore).Length
        }
        zip        = @{
            path   = "dist\$ZipName"
            sha256 = (Get-DeskFileSha256 $zipPath)
            bytes  = (Get-Item $zipPath).Length
        }
        launcher   = @{
            path   = 'dist\admin_report_desk.lua'
            sha256 = (Get-DeskFileSha256 $launcherPath)
            bytes  = (Get-Item $launcherPath).Length
        }
        autoupdate = @{
            path   = 'dist\report_desk_autoupdate.lua'
            sha256 = (Get-DeskFileSha256 $autoupdatePath)
            bytes  = (Get-Item $autoupdatePath).Length
        }
        deps       = @{
            path   = 'dist\report_desk_deps.lua'
            sha256 = (Get-DeskFileSha256 $depsPath)
            bytes  = (Get-Item $depsPath).Length
        }
        verified   = $true
    }
}

function Write-DeskBuildManifest {
    param(
        [string]$MoonloaderRoot,
        [string]$Version,
        [string]$Tag,
        [hashtable]$Artifacts
    )

    $manifest = @{
        version    = $Version
        tag        = $Tag
        built_at   = (Get-Date).ToString('o')
        core_asset = $Artifacts.core_asset
        artifacts  = $Artifacts
        verified   = $true
        notes      = 'Upload dist artifacts to GitHub Release AFTER git push main. SHA256 must match.'
    }
    $outPath = Join-Path $MoonloaderRoot 'release\build_manifest.json'
    $json = $manifest | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($outPath, $json + "`n", (Get-DeskUtf8NoBom))
    return $outPath
}

function Add-DeskReleaseGitFiles([string]$MoonloaderRoot) {
    $paths = @(
        'release/version.json',
        'release/build_manifest.json',
        'report_desk/admin_report_desk_core.lua',
        'tools/admin_report_desk_stub.lua',
        'lib/report_desk_autoupdate.lua',
        'lib/report_desk_deps.lua',
        'lib/report_desk_bootstrap.lua',
        'CHANGELOG.md'
    )
    Clear-DeskGitIndexFlags $MoonloaderRoot $paths
    Push-Location $MoonloaderRoot
    try {
        foreach ($rel in $paths) {
            $full = Join-Path $MoonloaderRoot ($rel -replace '/', '\')
            if (-not (Test-Path $full)) {
                throw "Cannot git add: missing $rel"
            }
            git add -- $rel
            if ($LASTEXITCODE -ne 0) {
                throw "git add failed for $rel (exit $LASTEXITCODE)"
            }
        }
    } finally {
        Pop-Location
    }
}
