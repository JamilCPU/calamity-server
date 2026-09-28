# Timestamped world backup with rotation.
# Copies both .wld (vanilla world) and .twld (tModLoader mod data) -- restoring
# without the .twld loses all modded state, so they are always taken together.

$ErrorActionPreference = 'Stop'

$Worlds  = 'D:\terraria-server\data\Worlds'
$Backups = 'D:\terraria-server\backups'
$Keep    = 48
$Stamp   = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $Backups)) { New-Item -ItemType Directory -Path $Backups -Force | Out-Null }

$files = Get-ChildItem $Worlds -Include '*.wld', '*.twld' -File -ErrorAction SilentlyContinue
if (-not $files) {
    Write-Output "$Stamp no world files found in $Worlds - nothing to back up"
    exit 0
}

$dest = Join-Path $Backups $Stamp
New-Item -ItemType Directory -Path $dest -Force | Out-Null
foreach ($f in $files) { Copy-Item $f.FullName -Destination $dest }

$sizeMB = [math]::Round((Get-ChildItem $dest | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Output "$Stamp backed up $($files.Count) files ($sizeMB MB) to $dest"

# Rotate: keep only the newest $Keep snapshot directories.
$old = Get-ChildItem $Backups -Directory |
       Where-Object { $_.Name -match '^\d{8}-\d{6}$' } |
       Sort-Object Name -Descending |
       Select-Object -Skip $Keep
foreach ($d in $old) {
    Remove-Item $d.FullName -Recurse -Force
    Write-Output "  pruned $($d.Name)"
}
