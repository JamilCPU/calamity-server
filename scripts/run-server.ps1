# Starts the Calamity server detached by launching supervise-server.ps1 in a hidden
# PowerShell that outlives this script. The supervisor is what holds the server's
# stdin open -- see supervise-server.ps1 for why that is required.

$ErrorActionPreference = 'Stop'

$Root       = 'D:\terraria-server'
$Supervisor = Join-Path $Root 'scripts\supervise-server.ps1'
$Ps         = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

$existing = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
if ($existing) {
    Write-Output "already running (PID $($existing.ProcessId -join ','))"
    exit 0
}

Start-Process -FilePath $Ps `
              -ArgumentList '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$Supervisor`"" `
              -WorkingDirectory $Root `
              -WindowStyle Hidden

Start-Sleep -Seconds 8
$now = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
       Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
if ($now) { Write-Output "server PID $($now.ProcessId -join ',')" }
else      { Write-Output "FAILED to start - check $Root\logs\server.log" }
