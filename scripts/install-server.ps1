# Installs the standalone tModLoader dedicated server on this host.
# Idempotent: re-running re-extracts the server binaries but leaves data/ and backups/ alone.

$ErrorActionPreference = 'Stop'

# Must match what Steam ships to clients, or they are refused with "You are not using
# the same version as this server." Steam auto-updates clients to current stable and
# offers no beta branch for individual 1.4.4 point releases, so the server follows.
$Version = 'v2026.08.3.0'
$Root    = 'D:\terraria-server'
$Data    = Join-Path $Root 'data'
$Backups = Join-Path $Root 'backups'
# Version-keyed on purpose: a fixed filename meant a version bump silently reused the
# previously cached zip and re-extracted the OLD build with no download and no error.
$Zip     = Join-Path $env:TEMP "tModLoader-$Version.zip"
$Url     = "https://github.com/tModLoader/tModLoader/releases/download/$Version/tModLoader.zip"

foreach ($d in @($Root, $Data, $Backups, (Join-Path $Data 'Mods'))) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

if (-not (Test-Path $Zip)) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Output "Downloading tModLoader $Version ..."
    Invoke-WebRequest -Uri $Url -OutFile $Zip -UseBasicParsing
}
Write-Output ("zip size MB: " + [math]::Round((Get-Item $Zip).Length / 1MB, 1))

# The release zip ships its own stock serverconfig.txt, and -Force overwrites ours --
# silently wiping port, password, world and player-cap settings with no warning.
# Preserve it across the extract.
$cfg    = Join-Path $Root 'serverconfig.txt'
$cfgBak = $null
if (Test-Path $cfg) {
    $cfgBak = Join-Path $env:TEMP "serverconfig.preserve.$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    Copy-Item $cfg $cfgBak -Force
    Write-Output "preserved existing serverconfig.txt -> $cfgBak"
}

Write-Output "Extracting to $Root ..."
Expand-Archive -Path $Zip -DestinationPath $Root -Force

if ($cfgBak) {
    Copy-Item $cfgBak $cfg -Force
    Write-Output 'restored existing serverconfig.txt over the stock one from the zip'
}

Write-Output "--- server entrypoints ---"
Get-ChildItem $Root -Filter '*Server*' | Select-Object -ExpandProperty Name

Write-Output "--- installed build ---"
(Get-Item (Join-Path $Root 'tModLoader.dll')).VersionInfo.ProductVersion

Write-Output "--- dotnet required by this build ---"
(Get-Content (Join-Path $Root 'tModLoader.runtimeconfig.json') -Raw |
    ConvertFrom-Json).runtimeOptions.framework.version

Write-Output "--- dotnet runtimes present ---"
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnet) { & dotnet --list-runtimes } else { Write-Output 'dotnet NOT on PATH' }

Write-Output "--- bundled dotnet dir ---"
if (Test-Path (Join-Path $Root 'dotnet')) { Write-Output 'bundled dotnet present' } else { Write-Output 'no bundled dotnet' }

Write-Output 'DONE'
