# Имитация установки админа: бэкап dev + конфигов, удаление dev-файлов, распаковка release zip.
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$ZipPath = '',
    [switch]$KeepPersonalConfig
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

if ($ZipPath -eq '') {
    $candidates = Get-ChildItem (Join-Path $MoonloaderRoot 'dist') -Filter 'AdminReportDesk-*.zip' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending
    if ($candidates) {
        $ZipPath = $candidates[0].FullName
    } else {
        Write-Error 'Укажите -ZipPath или соберите релиз: .\publish_release.ps1 -Version X -SkipLuac'
    }
}
if (-not (Test-Path $ZipPath)) { Write-Error "Zip not found: $ZipPath" }

$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $MoonloaderRoot "_desk_dev_backup_$stamp"
New-Item -ItemType Directory -Path $backup | Out-Null
Write-Host "Backup: $backup" -ForegroundColor Cyan

function Backup-IfExists($rel) {
    $p = Join-Path $MoonloaderRoot $rel
    if (Test-Path $p) {
        $dst = Join-Path $backup $rel
        $parent = Split-Path $dst -Parent
        if (-not (Test-Path $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        Copy-Item $p $dst -Recurse -Force
    }
}

# Личные конфиги (на случай отката)
@(
    'config\admin_report_desk.lua',
    'config\admin_report_desk_user.lua',
    'config\admin_report_desk_user.bak.lua',
    'config\admin_report_desk_stats.lua'
) | ForEach-Object { Backup-IfExists $_ }

# Dev-исходники Report Desk
@(
    'admin_report_desk.lua',
    'admin_report_desk_stub.lua',
    'admin_report_desk_stub.lua.off',
    'admin_report_desk.lua.bak',
    'report_desk_app.lua',
    'report_desk_profanity_words.lua',
    'report_desk_autoupdate.lua'
) | ForEach-Object { Backup-IfExists $_ }

Get-ChildItem (Join-Path $MoonloaderRoot 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue |
    ForEach-Object { Backup-IfExists ("lib\" + $_.Name) }

if (Test-Path (Join-Path $MoonloaderRoot 'report_desk')) {
    Backup-IfExists 'report_desk'
}

# Удаление dev (prod придёт из zip)
function Remove-IfExists($rel) {
    $p = Join-Path $MoonloaderRoot $rel
    if (Test-Path $p) { Remove-Item $p -Recurse -Force }
}

@(
    'admin_report_desk.lua',
    'admin_report_desk_stub.lua',
    'admin_report_desk_stub.lua.off',
    'admin_report_desk.lua.bak',
    'report_desk_app.lua',
    'report_desk_profanity_words.lua',
    'report_desk_autoupdate.lua',
    'report_desk'
) | ForEach-Object { Remove-IfExists $_ }

Get-ChildItem (Join-Path $MoonloaderRoot 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue |
    ForEach-Object { Remove-Item $_.FullName -Force }

if (-not $KeepPersonalConfig) {
    @(
        'config\admin_report_desk.lua',
        'config\admin_report_desk_user.lua',
        'config\admin_report_desk_user.bak.lua',
        'config\admin_report_desk_stats.lua'
    ) | ForEach-Object { Remove-IfExists $_ }
}

# Распаковка релиза в корень moonloader
$stage = Join-Path $env:TEMP "desk_zip_$stamp"
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
Expand-Archive -Path $ZipPath -DestinationPath $stage -Force

function Sync-Tree($src, $dst) {
    if (-not (Test-Path $src)) { return }
    if (-not (Test-Path $dst)) { New-Item -ItemType Directory -Path $dst -Force | Out-Null }
    & robocopy $src $dst /E /IS /IT /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
    if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $src -> $dst (code $LASTEXITCODE)" }
}
Get-ChildItem $stage | ForEach-Object {
    if ($_.PSIsContainer) {
        Sync-Tree $_.FullName (Join-Path $MoonloaderRoot $_.Name)
    } else {
        Copy-Item $_.FullName (Join-Path $MoonloaderRoot $_.Name) -Force
    }
}

# stub только в tools/, не должен грузиться MoonLoader
Remove-IfExists 'admin_report_desk_stub.lua'

Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue

$launcher = Join-Path $MoonloaderRoot 'admin_report_desk.lua'
$coreLua = Join-Path $MoonloaderRoot 'report_desk\admin_report_desk_core.lua'
$userCfg = Join-Path $MoonloaderRoot 'config\admin_report_desk_user.lua'
$skins = @(Get-ChildItem (Join-Path $MoonloaderRoot 'res\report_desk_skins') -Filter '*.png' -ErrorAction SilentlyContinue).Count

Write-Host ''
Write-Host '=== Prod install ready ===' -ForegroundColor Green
Write-Host "Zip: $ZipPath"
Write-Host "Launcher: $(Test-Path $launcher)"
Write-Host "Core: $(Test-Path $coreLua)"
Write-Host "User scenarios: $(Test-Path $userCfg)"
Write-Host "Skin previews: $skins"
Write-Host ''
Write-Host 'Проверка в игре:'
Write-Host '  1. /reload или перезапуск GTA'
Write-Host '  2. moonloader.log — [Report Desk] update: up to date'
Write-Host '  3. F7 — окно репортов, сценарии в чате, скины/ТС'
Write-Host ''
Write-Host "Откат dev: скопируйте из $backup обратно в moonloader"
