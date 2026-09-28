# Installs the standalone tModLoader dedicated server on this host.
# Idempotent: re-running re-extracts the server binaries but leaves data/ and backups/ alone.

$ErrorActionPreference = 'Stop'

$Version = 'v2026.07.3.0'
$Root    = 'D:\terraria-server'
$Data    = Join-Path $Root 'data'
$Backups = Join-Path $Root 'backups'
$Zip     = Join-Path $env:TEMP 'tModLoader.zip'
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

Write-Output "Extracting to $Root ..."
Expand-Archive -Path $Zip -DestinationPath $Root -Force

Write-Output "--- server entrypoints ---"
Get-ChildItem $Root -Filter '*Server*' | Select-Object -ExpandProperty Name

Write-Output "--- dotnet runtimes present ---"
$dotnet = Get-Command dotnet -ErrorAction SilentlyContinue
if ($dotnet) { & dotnet --list-runtimes } else { Write-Output 'dotnet NOT on PATH' }

Write-Output "--- bundled dotnet dir ---"
if (Test-Path (Join-Path $Root 'dotnet')) { Write-Output 'bundled dotnet present' } else { Write-Output 'no bundled dotnet' }

Write-Output 'DONE'
