# Удаляет все GitHub Releases кроме указанного тега (чистый старт релизов).
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$KeepTag = '',
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'
$repo = Get-Content (Join-Path $MoonloaderRoot 'release\repo.config.json') -Raw | ConvertFrom-Json
$repoSlug = "$($repo.github_owner)/$($repo.github_repo)"

$releasesJson = gh release list --repo $repoSlug --limit 200 --json tagName
if ($LASTEXITCODE -ne 0) {
    Write-Error 'gh release list failed'
}
$tags = @($releasesJson | ConvertFrom-Json | ForEach-Object { $_.tagName }) | Sort-Object -Unique
if ($KeepTag -ne '' -and $KeepTag -notin $tags) {
    Write-Host "Keep tag $KeepTag not found yet (will delete all listed tags)" -ForegroundColor Yellow
}

$toDelete = $tags | Where-Object { $_ -ne $KeepTag }
Write-Host "Repo: $repoSlug"
Write-Host "Keep: $(if ($KeepTag) { $KeepTag } else { '(none — delete ALL)' })"
Write-Host "Delete: $($toDelete.Count) release(s)"
$toDelete | ForEach-Object { Write-Host "  $_" }

if ($WhatIf) {
    Write-Host 'WhatIf — no deletions performed' -ForegroundColor Cyan
    exit 0
}

foreach ($tag in $toDelete) {
    Write-Host "Deleting $tag..." -ForegroundColor Yellow
    gh release delete $tag --repo $repoSlug --yes --cleanup-tag
    if ($LASTEXITCODE -ne 0) {
        throw "gh release delete failed for $tag"
    }
}
Write-Host 'Done.' -ForegroundColor Green
