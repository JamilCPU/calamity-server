# Runs the Calamity tModLoader dedicated server and stays alive for its lifetime.
#
# WHY A SUPERVISOR: the server reads console commands from stdin. Launched detached
# (Start-Process, `start`, or a scheduled task) it gets no stdin, immediately reads
# EOF and exits cleanly with code 0 partway through mod loading -- which looked like
# a crash but was not. Verified by running the identical command over SSH, where
# stdin stays open and the server starts normally.
#
# This script keeps the stdin pipe open by holding the StreamWriter and not closing
# it, so the server never sees EOF. It must therefore outlive the server, which is
# why the scheduled task runs this rather than the server directly.

$ErrorActionPreference = 'Stop'

$Root = 'D:\terraria-server'
$Logs = Join-Path $Root 'logs'
$Log  = Join-Path $Logs 'server.log'

if (-not (Test-Path $Logs)) { New-Item -ItemType Directory -Path $Logs -Force | Out-Null }

# Never run two servers against one world -- concurrent writes corrupt the .wld.
$existing = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
            Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
if ($existing) {
    Write-Output "already running (PID $($existing.ProcessId -join ',')) - refusing to start a second instance"
    exit 0
}

if ((Test-Path $Log) -and (Get-Item $Log).Length -gt 20MB) {
    Move-Item $Log (Join-Path $Logs 'server.prev.log') -Force
}

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = Join-Path $Root 'dotnet\dotnet.exe'
$psi.Arguments              = 'tModLoader.dll -server -config serverconfig.txt -tmlsavedirectory data'
$psi.WorkingDirectory       = $Root
$psi.UseShellExecute        = $false
$psi.RedirectStandardInput  = $true   # the whole point: keep this pipe open
$psi.RedirectStandardOutput = $true
# stderr is left inherited on purpose: redirecting it too would need a second pump
# to avoid filling its buffer and deadlocking the server.

$proc = [System.Diagnostics.Process]::Start($psi)
Write-Output "started PID $($proc.Id), logging to $Log"

$writer = [System.IO.StreamWriter]::new($Log, $true)
$writer.AutoFlush = $true
$writer.WriteLine("=== started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') PID $($proc.Id) ===")

# Pump stdout until the stream closes. ReadLine blocks, which is fine here.
while ($true) {
    $line = $proc.StandardOutput.ReadLine()
    if ($null -eq $line) { break }
    $writer.WriteLine($line)
}

$proc.WaitForExit()
$writer.WriteLine("=== exited $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') code $($proc.ExitCode) ===")
$writer.Close()
Write-Output "server exited with code $($proc.ExitCode)"
