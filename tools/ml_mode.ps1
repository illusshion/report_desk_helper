# Переключение dev <-> test (moonloader-test junction). GTA должна быть закрыта.
param(
    [switch]$Test,
    [switch]$Dev,
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_test_lib.ps1')

if ($Test) {
    Invoke-DeskActivateTest $MoonloaderRoot
} elseif ($Dev) {
    Invoke-DeskActivateDev $MoonloaderRoot
} else {
    Show-DeskMlStatus $MoonloaderRoot
}
