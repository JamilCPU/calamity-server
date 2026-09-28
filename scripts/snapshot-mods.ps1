# Zips the current Mods folder + enabled.json so a mod update that breaks the
# save can be rolled back to a known-good set. Run before changing any mod.
#
# Uses ZipArchive with FileShare.ReadWrite rather than Compress-Archive: the running
# server holds every .tmod open, and Compress-Archive fails outright on locked files
# ("cannot access the file ... because it is being used by another process").
# This way the snapshot works without stopping the server.

$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$Mods  = 'D:\terraria-server\data\Mods'
$Dest  = 'D:\terraria-server\backups\mod-snapshots'
$Stamp = Get-Date -Format 'yyyyMMdd-HHmmss'

if (-not (Test-Path $Dest)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }

$zipPath = Join-Path $Dest "mods-$Stamp.zip"
$files   = Get-ChildItem $Mods -File

$zipStream = [System.IO.File]::Open($zipPath, [System.IO.FileMode]::Create)
$archive   = New-Object System.IO.Compression.ZipArchive($zipStream, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($f in $files) {
        $entry  = $archive.CreateEntry($f.Name, [System.IO.Compression.CompressionLevel]::Fastest)
        $out    = $entry.Open()
        $in     = [System.IO.File]::Open($f.FullName, [System.IO.FileMode]::Open,
                                         [System.IO.FileAccess]::Read,
                                         [System.IO.FileShare]::ReadWrite)
        try   { $in.CopyTo($out) }
        finally { $in.Dispose(); $out.Dispose() }
    }
}
finally {
    $archive.Dispose()
    $zipStream.Dispose()
}

$sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 1)
Write-Output "snapshot: $zipPath ($($files.Count) files, $sizeMB MB)"
