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

function Resolve-DeskLuajit([string]$MoonloaderRoot, [string]$ScriptRoot) {
    $candidates = @(
        (Join-Path $MoonloaderRoot 'tools\luajit-compiler\luajit\luajit.exe'),
        (Join-Path $ScriptRoot 'luajit-compiler\luajit\luajit.exe'),
        (Join-Path $MoonloaderRoot 'luajit.exe')
    )
    foreach ($path in $candidates) {
        if ($path -and (Test-Path $path)) {
            return $path
        }
    }
    return $null
}

function Invoke-DeskLuajitCompile([string]$LuajitExe, [string]$Src, [string]$Dst) {
    if (-not (Test-Path $LuajitExe)) {
        throw "LuaJIT not found: $LuajitExe"
    }
    if (-not (Test-Path $Src)) {
        throw "Source not found: $Src"
    }
    $luajitDir = Split-Path $LuajitExe -Parent
    Push-Location $luajitDir
    try {
        & $LuajitExe -b $Src $Dst
        if (-not (Test-Path $Dst)) {
            throw "LuaJIT compile failed: $Src"
        }
        $head = [System.IO.File]::ReadAllBytes($Dst)
        if ($head.Length -lt 3 -or $head[0] -ne 0x1b -or $head[1] -ne 0x4c -or $head[2] -ne 0x4a) {
            throw "Not LuaJIT bytecode (expected 1b 4c 4a header): $Dst"
        }
    } finally {
        Pop-Location
    }
}

function Resolve-DeskPreviewAssetsRoot([string]$MoonloaderRoot, [string]$SubDir) {
    $primary = Join-Path $MoonloaderRoot $SubDir
    $nested = Join-Path $MoonloaderRoot ('res\' + ($SubDir -replace '^res\\', ''))
    if (Test-Path $primary) {
        $png = @(Get-ChildItem $primary -Filter '*.png' -Recurse -ErrorAction SilentlyContinue)
        if ($png.Count -gt 0) { return $primary }
    }
    if (Test-Path $nested) {
        $png = @(Get-ChildItem $nested -Filter '*.png' -Recurse -ErrorAction SilentlyContinue)
        if ($png.Count -gt 0) {
            Write-Warning "Using nested asset path: $nested (fix: move to $primary)"
            return $nested
        }
    }
    return $primary
}

function Write-DeskStoreZip {
    param(
        [Parameter(Mandatory = $true)][string]$SourceDir,
        [Parameter(Mandatory = $true)][string]$OutPath
    )
    if (-not (Test-Path $SourceDir)) {
        throw "Write-DeskStoreZip source missing: $SourceDir"
    }
    $parent = Split-Path $OutPath -Parent
    if ($parent -and -not (Test-Path $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    if (Test-Path $OutPath) { Remove-Item $OutPath -Force }

    $sourceFull = (Resolve-Path $SourceDir).Path
    $outFull = (Resolve-Path $parent).Path + '\' + (Split-Path $OutPath -Leaf)
    $py = @"
import os, zipfile
source = r'$($sourceFull.Replace("'","''"))'
out = r'$($outFull.Replace("'","''"))'
with zipfile.ZipFile(out, 'w', compression=zipfile.ZIP_STORED) as zf:
    for root, _, files in os.walk(source):
        for name in files:
            full = os.path.join(root, name)
            arc = os.path.relpath(full, source).replace('\\', '/')
            zf.write(full, arc)
"@
    $pyFile = Join-Path $env:TEMP ("desk_store_zip_" + [guid]::NewGuid().ToString('N') + '.py')
    [System.IO.File]::WriteAllText($pyFile, $py, [System.Text.UTF8Encoding]::new($false))
    try {
        & python $pyFile
        if ($LASTEXITCODE -ne 0) {
            throw "Write-DeskStoreZip python failed (exit $LASTEXITCODE)"
        }
        if (-not (Test-Path $outFull)) {
            throw "Write-DeskStoreZip missing output: $outFull"
        }
    } finally {
        if (Test-Path $pyFile) { Remove-Item $pyFile -Force }
    }
}

function Build-DeskAssetsZip {
    param(
        [string]$MoonloaderRoot,
        [string]$OutPath,
        [int]$MinSkins = 100,
        [int]$MinVehicles = 10
    )
    $skinsRoot = Resolve-DeskPreviewAssetsRoot $MoonloaderRoot 'res\report_desk_skins'
    $vehRoot = Resolve-DeskPreviewAssetsRoot $MoonloaderRoot 'res\report_desk_vehicles'
    $skinN = @(Get-ChildItem $skinsRoot -Filter 'skin-*.png' -ErrorAction SilentlyContinue).Count
    $vehN = @(Get-ChildItem $vehRoot -Filter '*.png' -ErrorAction SilentlyContinue).Count
    if ($skinN -lt $MinSkins) {
        throw "Assets build failed: skins=$skinN (need >= $MinSkins) under $skinsRoot"
    }
    if ($vehN -lt $MinVehicles) {
        throw "Assets build failed: vehicles=$vehN (need >= $MinVehicles) under $vehRoot"
    }
    $stage = Join-Path (Split-Path $OutPath -Parent) '_assets_stage'
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    New-Item -ItemType Directory -Path $stage -Force | Out-Null
    $skinsDst = Join-Path $stage 'res\report_desk_skins'
    $vehDst = Join-Path $stage 'res\report_desk_vehicles'
    New-Item -ItemType Directory -Path $skinsDst -Force | Out-Null
    New-Item -ItemType Directory -Path $vehDst -Force | Out-Null
    Copy-Item (Join-Path $skinsRoot '*') $skinsDst -Recurse -Force
    Copy-Item (Join-Path $vehRoot '*') $vehDst -Recurse -Force
    if (Test-Path $OutPath) { Remove-Item $OutPath -Force }
    Write-DeskStoreZip -SourceDir $stage -OutPath $OutPath
    Remove-Item $stage -Recurse -Force
    Write-Host "Assets zip: $OutPath (skins=$skinN veh=$vehN)"
    return @{ skins = $skinN; vehicles = $vehN; bytes = (Get-Item $OutPath).Length }
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

function Build-DeskVersionJson {
    param(
        [string]$MoonloaderRoot,
        [string]$Version,
        [string]$Tag,
        [string]$Owner,
        [string]$RepoName,
        [string]$CoreAssetName,
        [string]$BootstrapAssetName,
        [string]$Changelog,
        [string]$ZipName = 'report_desk_helper_main.zip',
        [string]$AssetsVersion = '',
        [string]$AssetsZipName = 'report_desk_assets.zip'
    )

    $base = "https://github.com/$Owner/$RepoName/releases/download/$Tag"
    $manifestUrl = "https://raw.githubusercontent.com/$Owner/$RepoName/main/release/version.json"

    $fileSpecs = @(
        @{ key = $BootstrapAssetName; dest = $BootstrapAssetName; pending = $true; path = "dist\$BootstrapAssetName" },
        @{ key = 'report_desk_autoupdate.lua'; dest = 'lib/report_desk_autoupdate.lua'; pending = $true; path = 'dist\report_desk_autoupdate.lua' },
        @{ key = 'report_desk_deps.lua'; dest = 'lib/report_desk_deps.lua'; pending = $false; path = 'dist\report_desk_deps.lua' },
        @{ key = 'report_desk_sha256.lua'; dest = 'lib/report_desk_sha256.lua'; pending = $false; path = 'dist\report_desk_sha256.lua' },
        @{ key = 'report_desk_zip.lua'; dest = 'lib/report_desk_zip.lua'; pending = $false; path = 'dist\report_desk_zip.lua' },
        @{ key = 'report_desk_fs.lua'; dest = 'lib/report_desk_fs.lua'; pending = $false; path = 'dist\report_desk_fs.lua' },
        @{ key = $CoreAssetName; dest = "report_desk/$CoreAssetName"; pending = $false; path = "dist\report_desk\$CoreAssetName" },
        @{ key = 'iconv.dll'; dest = 'lib/iconv.dll'; pending = $false; path = 'dist\iconv.dll' }
    )
    $files = @{}
    foreach ($spec in $fileSpecs) {
        $fullPath = Join-Path $MoonloaderRoot $spec.path
        if (-not (Test-Path $fullPath)) {
            throw "Build version.json failed: missing $($spec.path)"
        }
        $files[$spec.key] = @{
            dest    = $spec.dest
            sha256  = (Get-DeskFileSha256 $fullPath)
            bytes   = (Get-Item $fullPath).Length
            url     = "$base/$($spec.key)"
            pending = [bool]$spec.pending
        }
    }

    $runtimeZipPath = Join-Path $MoonloaderRoot 'dist\report_desk_runtime_libs.zip'
    if (-not (Test-Path $runtimeZipPath)) {
        throw 'Build version.json failed: missing dist\report_desk_runtime_libs.zip'
    }
    $runtimeLibsName = 'report_desk_runtime_libs.zip'

    $assetsZipPath = Join-Path $MoonloaderRoot "dist\$AssetsZipName"
    if (-not (Test-Path $assetsZipPath)) {
        throw 'Build version.json failed: missing dist\report_desk_assets.zip'
    }
    if ($AssetsVersion -eq '') { $AssetsVersion = $Version }

    $mimguiZipPath = Join-Path $MoonloaderRoot 'dist\mimgui-v1.7.1.zip'
    if (-not (Test-Path $mimguiZipPath)) {
        throw 'Build version.json failed: missing dist\mimgui-v1.7.1.zip'
    }

    return @{
        manifest_version = 3
        version          = $Version
        changelog        = $Changelog
        release_base     = $base
        files            = $files
        runtime_libs     = @{
            asset  = $runtimeLibsName
            sha256 = (Get-DeskFileSha256 $runtimeZipPath)
            bytes  = (Get-Item $runtimeZipPath).Length
            url    = "$base/$runtimeLibsName"
        }
        mimgui           = @{
            version = '1.7.1'
            asset   = 'mimgui-v1.7.1.zip'
            sha256  = (Get-DeskFileSha256 $mimguiZipPath)
            bytes   = (Get-Item $mimguiZipPath).Length
            url     = "$base/mimgui-v1.7.1.zip"
        }
        assets           = @{
            version    = $AssetsVersion
            asset      = $AssetsZipName
            sha256     = (Get-DeskFileSha256 $assetsZipPath)
            bytes      = (Get-Item $assetsZipPath).Length
            url        = "$base/$AssetsZipName"
            dest_dirs  = @(
                'res/report_desk_skins',
                'res/report_desk_vehicles'
            )
        }
        core_url          = "$base/$CoreAssetName"
        core_url_fallback = "https://raw.githubusercontent.com/$Owner/$RepoName/main/report_desk/AdminDeskCore.lua"
        zip_url           = "$base/$ZipName"
        runtime_libs_url  = "$base/$runtimeLibsName"
        iconv_url         = "$base/iconv.dll"
        manifest_url      = $manifestUrl
    }
}

function Test-DeskReleaseArtifacts {
    param(
        [string]$MoonloaderRoot,
        [string]$Version,
        [string]$CoreAssetName,
        [string]$BootstrapAssetName = 'AdminDesk.luac',
        [string]$ZipName = 'report_desk_helper_main.zip'
    )

    $distCore = Join-Path $MoonloaderRoot "dist\report_desk\$CoreAssetName"
    $distCoreLua = Join-Path $MoonloaderRoot 'dist\report_desk\AdminDeskCore.lua'
    $repoCore = Join-Path $MoonloaderRoot 'report_desk\AdminDeskCore.lua'
    $zipPath = Join-Path $MoonloaderRoot "dist\$ZipName"
    $bootstrapPath = Join-Path $MoonloaderRoot "dist\$BootstrapAssetName"
    $versionPath = Join-Path $MoonloaderRoot 'release\version.json'
    $autoupdatePath = Join-Path $MoonloaderRoot 'dist\report_desk_autoupdate.lua'
    $depsPath = Join-Path $MoonloaderRoot 'dist\report_desk_deps.lua'
    $assetsZipPath = Join-Path $MoonloaderRoot 'dist\report_desk_assets.zip'

    $sha256Path = Join-Path $MoonloaderRoot 'dist\report_desk_sha256.lua'
    $zipModPath = Join-Path $MoonloaderRoot 'dist\report_desk_zip.lua'
    $fsModPath = Join-Path $MoonloaderRoot 'dist\report_desk_fs.lua'
    $mimguiZipPath = Join-Path $MoonloaderRoot 'dist\mimgui-v1.7.1.zip'

    foreach ($p in @($distCore, $distCoreLua, $repoCore, $zipPath, $bootstrapPath, $versionPath, $autoupdatePath, $depsPath, $assetsZipPath, $sha256Path, $zipModPath, $fsModPath, $mimguiZipPath)) {
        if (-not (Test-Path $p)) {
            throw "Release verify failed: missing artifact $p"
        }
    }

    $distLuaHash = Get-DeskFileSha256 $distCoreLua
    $repoHash = Get-DeskFileSha256 $repoCore
    if ($distLuaHash -ne $repoHash) {
        throw "Release verify failed: dist AdminDeskCore.lua hash != repo core hash"
    }

    if ($CoreAssetName -like '*.luac') {
        $distCoreHash = Get-DeskFileSha256 $distCore
        if (-not $distCoreHash) {
            throw 'Release verify failed: dist AdminDeskCore.luac unreadable'
        }
    } else {
        $distCoreHash = $distLuaHash
        if ($distCore -ne $distCoreLua -and (Get-DeskFileSha256 $distCore) -ne $distLuaHash) {
            throw 'Release verify failed: dist core lua copies differ'
        }
    }

    $zipCoreEntry = "report_desk\$CoreAssetName"
    $zipCoreHash = Get-DeskZipEntrySha256 $zipPath $zipCoreEntry
    if ($zipCoreHash -ne $distCoreHash) {
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
        'lib\report_desk_sha256.lua',
        'lib\report_desk_zip.lua',
        'lib\report_desk_fs.lua',
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
    if ($coreText -notlike '*report_desk_wm_dispatch*') {
        throw 'Release verify failed: core missing wm_dispatch preload'
    }

    $manifest = Get-Content $versionPath -Raw | ConvertFrom-Json
    if (-not $manifest.runtime_libs_url) {
        throw 'Release verify failed: version.json missing runtime_libs_url'
    }
    if (-not $manifest.iconv_url) {
        throw 'Release verify failed: version.json missing iconv_url'
    }
    if ($manifest.manifest_version -lt 2) {
        throw 'Release verify failed: version.json manifest_version must be >= 2'
    }
    if (-not $manifest.assets) {
        throw 'Release verify failed: version.json missing assets block (manifest v3)'
    }
    if (-not $manifest.files) {
        throw 'Release verify failed: version.json missing files map'
    }
    if (-not $manifest.release_base) {
        throw 'Release verify failed: version.json missing release_base'
    }

    $manifest = Get-Content $versionPath -Raw | ConvertFrom-Json
    if ($manifest.version -ne $Version) {
        throw "Release verify failed: version.json has $($manifest.version), expected $Version"
    }
    if ($manifest.core_url -notlike "*$CoreAssetName*") {
        throw "Release verify failed: core_url does not reference $CoreAssetName"
    }

    $requiredKeys = @($BootstrapAssetName, 'report_desk_autoupdate.lua', 'report_desk_deps.lua', $CoreAssetName, 'iconv.dll')
    foreach ($key in $requiredKeys) {
        if (-not $manifest.files.$key) {
            throw "Release verify failed: version.json files missing $key"
        }
        $distMap = @{
            'report_desk_autoupdate.lua' = (Join-Path $MoonloaderRoot 'dist\report_desk_autoupdate.lua')
            'report_desk_deps.lua' = (Join-Path $MoonloaderRoot 'dist\report_desk_deps.lua')
            'iconv.dll' = (Join-Path $MoonloaderRoot 'dist\iconv.dll')
        }
        if ($key -eq $CoreAssetName) {
            $distMap[$key] = Join-Path $MoonloaderRoot "dist\report_desk\$CoreAssetName"
        } elseif ($key -eq $BootstrapAssetName) {
            $distMap[$key] = Join-Path $MoonloaderRoot "dist\$BootstrapAssetName"
        }
        $expected = (Get-DeskFileSha256 $distMap[$key])
        if ($manifest.files.$key.sha256 -ne $expected) {
            throw "Release verify failed: version.json sha256 mismatch for $key"
        }
    }

    $assetsHash = Get-DeskFileSha256 $assetsZipPath
    if ($manifest.assets.sha256 -ne $assetsHash) {
        throw 'Release verify failed: version.json assets sha256 mismatch'
    }

    if (-not (Test-DeskStubHasVersion $bootstrapPath $Version)) {
        if (-not (Test-DeskStubHasVersion (Join-Path $MoonloaderRoot 'dist\AdminDesk.lua') $Version)) {
            throw "Release verify failed: dist bootstrap script_version is not $Version"
        }
    }

    $autoupdateText = [System.IO.File]::ReadAllText($autoupdatePath, (Get-DeskUtf8NoBom))
    if ($autoupdateText -notlike '*raw.githubusercontent.com*') {
        throw 'Release verify failed: dist autoupdate has no VERSION_JSON_URL'
    }

    $bootstrapSrc = Join-Path $MoonloaderRoot 'tools\admin_desk_bootstrap.lua'
    if (-not (Test-DeskStubHasVersion $bootstrapSrc $Version)) {
        throw "Release verify failed: tools bootstrap script_version is not $Version"
    }

    return @{
        version    = $Version
        core_asset = $CoreAssetName
        bootstrap  = $BootstrapAssetName
        core       = @{
            dist_path = "dist\report_desk\$CoreAssetName"
            repo_path = 'report_desk\AdminDeskCore.lua'
            sha256    = $distCoreHash
            bytes     = (Get-Item $distCore).Length
        }
        zip        = @{
            path   = "dist\$ZipName"
            sha256 = (Get-DeskFileSha256 $zipPath)
            bytes  = (Get-Item $zipPath).Length
        }
        bootstrap_file = @{
            path   = "dist\$BootstrapAssetName"
            sha256 = (Get-DeskFileSha256 $bootstrapPath)
            bytes  = (Get-Item $bootstrapPath).Length
        }
        assets     = @{
            path   = 'dist\report_desk_assets.zip'
            sha256 = $assetsHash
            bytes  = (Get-Item $assetsZipPath).Length
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
        'report_desk/AdminDeskCore.lua',
        'report_desk/admin_report_desk_core.lua',
        'tools/admin_desk_bootstrap.lua',
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
