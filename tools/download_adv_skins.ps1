# Downloads Advance RP skin previews from https://adv-rp.com/skins/
# Images: https://adv-rp.com/media/roulette-prizes/skin-{id}.png
param(
    [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_skins'),
    [int]$From = 1,
    [int]$To = 311,
    [switch]$Force
)

$BaseUrl = 'https://adv-rp.com/media/roulette-prizes/skin-{0}.png'
$SkipIds = @(74)

if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
}

$ids = @()
for ($i = $From; $i -le $To; $i++) {
    if ($SkipIds -contains $i) { continue }
    $ids += $i
}

Write-Host "Downloading $($ids.Count) skins to: $OutDir"

$ok = 0
$fail = 0
$skip = 0

foreach ($id in $ids) {
    $out = Join-Path $OutDir ("skin-{0}.png" -f $id)
    if ((Test-Path $out) -and -not $Force -and (Get-Item $out).Length -gt 500) {
        $skip++
        continue
    }
    $url = $BaseUrl -f $id
    try {
        curl.exe -sL --fail "$url" -o "$out"
        if ((Test-Path $out) -and (Get-Item $out).Length -gt 500) {
            $ok++
        } else {
            if (Test-Path $out) { Remove-Item $out -Force -ErrorAction SilentlyContinue }
            $fail++
            Write-Warning "Failed or empty: skin-$id.png"
        }
    } catch {
        $fail++
        Write-Warning "Error skin-$id : $_"
    }
}

# index for Lua (optional)
$indexPath = Join-Path $OutDir 'skins_index.lua'
$lines = @('return {')
foreach ($id in ($ids | Sort-Object)) {
    $lines += ('  { id = ' + $id + ", file = 'skin-" + $id + ".png' },")
}
$lines += '}'
$lines | Set-Content -Path $indexPath -Encoding UTF8

Write-Host "Done. OK=$ok skip=$skip fail=$fail index=$indexPath"
