# Launches the Calamity tModLoader dedicated server detached, logging to D:\terraria-server\logs.
# Used both for manual starts and by the boot scheduled task.

$ErrorActionPreference = 'Stop'

$Root = 'D:\terraria-server'
$Logs = Join-Path $Root 'logs'
if (-not (Test-Path $Logs)) { New-Item -ItemType Directory -Path $Logs -Force | Out-Null }

$Log = Join-Path $Logs 'server.log'
if (Test-Path $Log) { Move-Item $Log (Join-Path $Logs 'server.prev.log') -Force }

# Refuse to start a second instance.
$existing = Get-CimInstance Win32_Process -Filter "Name='tModLoader.exe' OR Name='dotnet.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like '*tModLoader*' }
if ($existing) {
    Write-Output "already running (PID $($existing.ProcessId -join ','))"
    exit 0
}

# -nosteam is required: without it start-tModLoaderServer.sh blocks on an
# interactive "Use steam server (y/n):" prompt and never starts.
$args = @(
    '-nosteam',
    '-config', (Join-Path $Root 'serverconfig.txt'),
    '-tmlsavedirectory', (Join-Path $Root 'data')
)

Start-Process -FilePath (Join-Path $Root 'start-tModLoaderServer.bat') `
              -ArgumentList $args `
              -WorkingDirectory $Root `
              -RedirectStandardOutput $Log `
              -RedirectStandardError (Join-Path $Logs 'server.err.log') `
              -WindowStyle Hidden

Start-Sleep -Seconds 3
Write-Output "launched, log: $Log"
