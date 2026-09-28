# Zips the current Mods folder + enabled.json so a mod update that breaks the
# save can be rolled back to a known-good set. Run before changing any mod.

$ErrorActionPreference = 'Stop'

$Mods  = 'D:\terraria-server\data\Mods'
$Dest  = 'D:\terraria-server\backups\mod-snapshots'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }

$zip = Join-Path $Dest "mods-$Stamp.zip"
Compress-Archive -Path (Join-Path $Mods '*') -DestinationPath $zip -CompressionLevel Fastest

$sizeMB = [math]::Round((Get-Item $zip).Length / 1MB, 1)
Write-Output "snapshot: $zip ($sizeMB MB)"
