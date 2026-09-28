# Launches the Calamity tModLoader dedicated server detached, logging to D:\terraria-server\logs.
# Used both for manual starts and by the boot scheduled task.
#
# Starts scripts\start-server.bat, which calls dotnet directly rather than going
# through start-tModLoaderServer.bat -- see that file for why.

$ErrorActionPreference = 'Stop'

$Root = 'D:\terraria-server'
$Logs = Join-Path $Root 'logs'
$Bat  = Join-Path $Root 'scripts\start-server.bat'

if (-not (Test-Path $Logs)) { New-Item -ItemType Directory -Path $Logs -Force | Out-Null }

# Refuse to start a second instance -- two servers on one world corrupts it.
$existing = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
if ($existing) {
    Write-Output "already running (PID $($existing.ProcessId -join ','))"
    exit 0
}

$log = Join-Path $Logs 'server.log'
if ((Test-Path $log) -and (Get-Item $log).Length -gt 20MB) {
    Move-Item $log (Join-Path $Logs 'server.prev.log') -Force
}

Start-Process -FilePath $Bat -WorkingDirectory $Root -WindowStyle Hidden

Start-Sleep -Seconds 5
$now = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
       Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
if ($now) { Write-Output "started (PID $($now.ProcessId -join ','))" }
else      { Write-Output "FAILED to start - check $log" }
