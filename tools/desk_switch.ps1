# Переключение Report Desk: dev <-> проверка как у админа (GitHub release).
#
#   desk_switch.bat                # статус (обходит ExecutionPolicy)
#   desk_user.bat                  # тест как у админа (GitHub)
#   desk_dev.bat                   # вернуть dev
#   desk_switch.bat -Snapshot      # только сохранить dev в stash
#
# Dev-файлы всегда лежат в moonloader\_desk_dev_stash\ (не трогаются при -User).

param(
    [switch]$User,
    [switch]$Dev,
    [switch]$Snapshot,
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$ZipPath = '',
    [switch]$FreshConfig,
    [switch]$KeepPersonalConfig
)

$ErrorActionPreference = 'Stop'

$StashName = '_desk_dev_stash'
$StashRoot = Join-Path $MoonloaderRoot $StashName
$StateFile = Join-Path $StashRoot 'state.json'
$GitHubZipUrl = 'https://github.com/illusshion/report_desk_helper/releases/latest/download/report_desk_helper_main.zip'

$DevRootFiles = @(
    'admin_report_desk.lua',
    'admin_report_desk_stub.lua',
    'admin_report_desk_stub.lua.off',
    'admin_report_desk.lua.bak',
    'AdminDesk.luac',
    'AdminDesk.lua',
    'report_desk_app.lua',
    'report_desk_profanity_words.lua',
    'report_desk_autoupdate.lua'
)

$ProdRootFiles = @(
    'AdminDesk.luac',
    'AdminDesk.lua',
    'admin_report_desk.lua',
    'admin_report_desk_stub.lua',
    'report_desk_deps.lua',
    'report_desk_autoupdate.lua'
)

$PersonalConfigFiles = @(
    'config\admin_report_desk.lua',
    'config\admin_report_desk_user.lua',
    'config\admin_report_desk_user.bak.lua',
    'config\admin_report_desk_stats.lua'
)

function Write-Step([string]$Text) {
    Write-Host $Text -ForegroundColor Cyan
}

function Write-Ok([string]$Text) {
    Write-Host $Text -ForegroundColor Green
}

function Ensure-Dir([string]$Path) {
    if (-not (Test-Path $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Join-Ml([string]$Rel) {
    Join-Path $MoonloaderRoot $Rel
}

function Test-MlPath([string]$Rel) {
    Test-Path (Join-Ml $Rel)
}

function Copy-IfExists([string]$SrcRel, [string]$DstRoot, [switch]$Recurse) {
    $src = Join-Ml $SrcRel
    if (-not (Test-Path $src)) { return }
    $dst = Join-Path $DstRoot $SrcRel
    Ensure-Dir (Split-Path $Dst -Parent)
    if ($Recurse) {
        Copy-Item $src $dst -Recurse -Force
    } else {
        Copy-Item $src $dst -Force
    }
}

function Remove-Ml([string]$Rel) {
    $p = Join-Ml $Rel
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
}

function Get-DeskMode {
    $launcher = Join-Ml 'admin_report_desk.lua'
    if (-not (Test-Path $launcher)) { return 'none' }
    $content = Get-Content $launcher -Raw -Encoding UTF8
    if ($content -match 'report_desk_app') { return 'dev' }
    if ($content -match 'loadCore') { return 'user' }
    return 'unknown'
}

function Save-State([hashtable]$Data) {
    Ensure-Dir $StashRoot
    $Data | ConvertTo-Json | Set-Content $StateFile -Encoding UTF8
}

function Get-LatestBackup {
    Get-ChildItem $MoonloaderRoot -Directory -Filter '_desk_dev_backup_*' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending |
        Select-Object -First 1
}

function Stash-DevFiles {
    Write-Step "Stash dev -> $StashRoot"
    if (Test-Path $StashRoot) {
        Remove-Item $StashRoot -Recurse -Force
    }
    Ensure-Dir $StashRoot

    foreach ($rel in $DevRootFiles) { Copy-IfExists $rel $StashRoot }
    foreach ($rel in $PersonalConfigFiles) { Copy-IfExists $rel $StashRoot }

    $libDir = Join-Ml 'lib'
    if (Test-Path $libDir) {
        Get-ChildItem $libDir -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue |
            ForEach-Object { Copy-IfExists ("lib\" + $_.Name) $StashRoot }
    }

    if (Test-MlPath 'report_desk') {
        Copy-IfExists 'report_desk' $StashRoot -Recurse
    }
}

function Stash-HasDev {
    Test-MlPath (Join-Path $StashName 'report_desk_app.lua')
}

function Restore-DevFromStash {
    if (-not (Stash-HasDev)) {
        $backup = Get-LatestBackup
        if ($backup) {
            Write-Step "Stash пуст — берём $($backup.Name)"
            if (Test-Path $StashRoot) { Remove-Item $StashRoot -Recurse -Force }
            Copy-Item $backup.FullName $StashRoot -Recurse -Force
        } else {
            Write-Error "Нет stash ($StashRoot) и нет _desk_dev_backup_* — сначала поработайте в dev или укажите бэкап вручную."
        }
    }

    Write-Step 'Удаляем prod-файлы...'
    foreach ($rel in $ProdRootFiles) { Remove-Ml $rel }
    Remove-Ml 'report_desk'
    Get-ChildItem (Join-Ml 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Force }

    Write-Step 'Восстанавливаем dev из stash...'
    foreach ($rel in $DevRootFiles) {
        $src = Join-Path $StashRoot $rel
        if (Test-Path $src) {
            Ensure-Dir (Split-Path (Join-Ml $rel) -Parent)
            Copy-Item $src (Join-Ml $rel) -Force
        }
    }

    $stashLib = Join-Path $StashRoot 'lib'
    if (Test-Path $stashLib) {
        Ensure-Dir (Join-Ml 'lib')
        Get-ChildItem $stashLib -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue |
            ForEach-Object { Copy-Item $_.FullName (Join-Ml ("lib\" + $_.Name)) -Force }
    }

    foreach ($rel in $PersonalConfigFiles) {
        $src = Join-Path $StashRoot $rel
        if (Test-Path $src) {
            Ensure-Dir (Split-Path (Join-Ml $rel) -Parent)
            Copy-Item $src (Join-Ml $rel) -Force
        }
    }

    Remove-Ml 'admin_report_desk_stub.lua'

    $libCount = @(Get-ChildItem (Join-Ml 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue).Count
    Save-State @{
        mode       = 'dev'
        switchedAt = (Get-Date -Format 'o')
        libModules = $libCount
    }
}

function Remove-DevFromMoonloader {
    foreach ($rel in $DevRootFiles) { Remove-Ml $rel }
    Remove-Ml 'report_desk'
    Get-ChildItem (Join-Ml 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-Item $_.FullName -Force }
    Remove-Ml 'admin_report_desk_stub.lua'
}

function Sync-Tree([string]$Src, [string]$Dst) {
    if (-not (Test-Path $Src)) { return }
    Ensure-Dir $Dst
    & robocopy $Src $Dst /E /IS /IT /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $Src -> $Dst (code $LASTEXITCODE)" }
}

function Expand-ZipToMoonloader([string]$Zip) {
    $stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $stage = Join-Path $env:TEMP "desk_zip_$stamp"
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Expand-Archive -Path $Zip -DestinationPath $stage -Force
    Get-ChildItem $stage | ForEach-Object {
        if ($_.PSIsContainer) {
            Sync-Tree $_.FullName (Join-Ml $_.Name)
        } else {
            Copy-Item $_.FullName (Join-Ml $_.Name) -Force
        }
    }
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
}

function Resolve-ReleaseZip {
    if ($ZipPath -ne '' -and (Test-Path $ZipPath)) {
        return @{ Path = $ZipPath; Source = 'local' }
    }

    $local = Join-Ml 'dist\report_desk_helper_main.zip'
    if (Test-Path $local) {
        return @{ Path = $local; Source = 'dist' }
    }

    Write-Step "Качаем релиз: $GitHubZipUrl"
    $tmp = Join-Path $env:TEMP 'report_desk_helper_main.zip'
    Invoke-WebRequest -Uri $GitHubZipUrl -OutFile $tmp -UseBasicParsing
    return @{ Path = $tmp; Source = 'github' }
}

function Switch-ToUser {
    $mode = Get-DeskMode
    if ($mode -eq 'dev') {
        Stash-DevFiles
    } elseif (-not (Stash-HasDev)) {
        Write-Host 'Сейчас не dev и stash пуст — dev-файлы не сохранялись.' -ForegroundColor Yellow
    }

    Remove-DevFromMoonloader

    $resetConfig = $FreshConfig -or (-not $KeepPersonalConfig)
    if ($resetConfig) {
        Write-Step 'Сброс личных config (как у нового админа)...'
        foreach ($rel in $PersonalConfigFiles) { Remove-Ml $rel }
    }

    $zipInfo = Resolve-ReleaseZip
    Write-Step "Устанавливаем: $($zipInfo.Path)"
    Expand-ZipToMoonloader $zipInfo.Path
    Remove-Ml 'admin_report_desk_stub.lua'

    Save-State @{
        mode       = 'user'
        switchedAt = (Get-Date -Format 'o')
        zipSource  = $zipInfo.Source
        zipPath    = $zipInfo.Path
        freshConfig = $resetConfig
    }

    $coreLua = Join-Ml 'report_desk\admin_report_desk_core.lua'
    $skins = @(Get-ChildItem (Join-Ml 'res\report_desk_skins') -Filter '*.png' -ErrorAction SilentlyContinue).Count
    Write-Host ''
    Write-Ok '=== User mode (GitHub release) ==='
    Write-Host "Zip: $($zipInfo.Source) — $($zipInfo.Path)"
    Write-Host "Launcher: $(Test-MlPath 'admin_report_desk.lua')"
    Write-Host "Core: $(Test-Path $coreLua)"
    Write-Host "Skin previews: $skins"
    Write-Host ''
    Write-Host 'В игре: /reload или рестарт GTA, F7, смотри moonloader.log'
    Write-Host "Вернуть dev: .\desk_switch.ps1 -Dev"
}

function Switch-ToDev {
    Restore-DevFromStash
    Write-Host ''
    Write-Ok '=== Dev mode ==='
    Write-Host "Entry: $(Join-Ml 'admin_report_desk.lua')"
    $libCount = @(Get-ChildItem (Join-Ml 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue).Count
    Write-Host "lib/report_desk_*.lua: $libCount"
    Write-Host "Stash: $StashRoot"
    Write-Host ''
    Write-Host 'В игре: /reload или рестарт GTA, F7'
    Write-Host "Проверка как админ: .\desk_switch.ps1 -User"
}

function Show-Status {
    $mode = Get-DeskMode
    $stash = Stash-HasDev
    $libCount = @(Get-ChildItem (Join-Ml 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue).Count
    $hasCore = Test-MlPath 'report_desk\admin_report_desk_core.lua'
    $hasDeps = Test-MlPath 'report_desk_deps.lua'

    Write-Host 'Report Desk — режим установки' -ForegroundColor Cyan
    Write-Host "  moonloader: $MoonloaderRoot"
    Write-Host "  detected:   $mode"
    Write-Host "  stash dev:  $(if ($stash) { 'yes' } else { 'no' }) ($StashRoot)"
    Write-Host "  lib modules: $libCount"
    Write-Host "  prod core:  $(if ($hasCore) { 'yes' } else { 'no' })"
    Write-Host "  prod deps:  $(if ($hasDeps) { 'yes' } else { 'no' })"

    if (Test-Path $StateFile) {
        Write-Host ''
        Write-Host 'Последнее переключение:'
        Get-Content $StateFile -Raw -Encoding UTF8 | Write-Host
    }

    Write-Host ''
    Write-Host 'Команды:'
    Write-Host '  .\desk_switch.ps1 -User   # тест как у админа (GitHub latest)'
    Write-Host '  .\desk_switch.ps1 -Dev    # вернуть dev'
    Write-Host '  .\desk_switch.ps1 -User -ZipPath dist\report_desk_helper_main.zip'
    Write-Host '  .\desk_switch.ps1 -User -FreshConfig   # сбросить личные config'
}

if (@($User, $Dev, $Snapshot).Where({ $_ }).Count -gt 1) {
    Write-Error 'Укажите только один флаг: -User, -Dev или -Snapshot'
}

if ($Snapshot) {
    if ((Get-DeskMode) -ne 'dev') {
        Write-Error 'Snapshot: сейчас не dev-режим (нет report_desk_app в admin_report_desk.lua)'
    }
    Stash-DevFiles
    Save-State @{
        mode       = 'dev'
        switchedAt = (Get-Date -Format 'o')
        snapshot   = $true
    }
    Write-Ok "Dev сохранён в $StashRoot"
} elseif ($User) {
    Switch-ToUser
} elseif ($Dev) {
    Switch-ToDev
} else {
    Show-Status
}
