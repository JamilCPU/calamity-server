# Runs the Calamity tModLoader dedicated server and stays alive for its lifetime.
#
# WHY A SUPERVISOR: the server reads console commands from stdin. Launched detached
# (scheduled task, Start-Process) it gets no stdin, immediately reads EOF and exits
# cleanly with code 0 partway through mod loading -- which looks like a crash but is
# not. This script holds the stdin pipe open so the server never sees EOF.
#
# COMMAND CHANNEL: write lines to D:\terraria-server\command.txt and they are sent to
# the server's console, then the file is deleted. That makes `say`, `save` and a
# graceful `exit` possible from outside.
#
# HOW STDOUT IS PUMPED -- this matters, do not "simplify" it:
#   * A blocking ReadLine loop is fast but owns the thread, leaving nothing free to
#     poll for commands.
#   * Register-ObjectEvent with a per-line action block is free-threaded but far too
#     slow: PowerShell invokes a scriptblock per line, the pipe buffer fills, and the
#     SERVER BLOCKS ON ITS OWN WRITES. Measured: startup crawled to ~34% of one core
#     and took 5+ minutes without finishing, versus 2-3 minutes normally.
#   * So: copy the raw stream with .NET's CopyToAsync, which runs off-thread with no
#     per-line scripting cost, and keep the main loop free for the command file.
#
# Supervisor events go to supervisor.log rather than server.log, because a second
# writer interleaving with CopyToAsync on the same handle is not safe.

$ErrorActionPreference = 'Stop'

$Root     = 'D:\terraria-server'
$Logs     = Join-Path $Root 'logs'
$Log      = Join-Path $Logs 'server.log'
$SupLog   = Join-Path $Logs 'supervisor.log'
$CmdFile  = Join-Path $Root 'command.txt'

if (-not (Test-Path $Logs)) { New-Item -ItemType Directory -Path $Logs -Force | Out-Null }

function Write-Sup([string]$msg) {
    Add-Content -Path $SupLog -Value "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg" -Encoding ascii
}

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

# A stale command file must not be replayed into the new server.
if (Test-Path $CmdFile) { Remove-Item $CmdFile -Force -ErrorAction SilentlyContinue }

# Run-boundary marker, written and closed BEFORE the async copy takes the handle.
[System.IO.File]::AppendAllText($Log, "=== started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') ===`r`n")

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = Join-Path $Root 'dotnet\dotnet.exe'
$psi.Arguments              = 'tModLoader.dll -server -config serverconfig.txt -tmlsavedirectory data'
$psi.WorkingDirectory       = $Root
$psi.UseShellExecute        = $false
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true

$proc = [System.Diagnostics.Process]::Start($psi)
$proc.StandardInput.AutoFlush = $true

$fs   = [System.IO.File]::Open($Log, [System.IO.FileMode]::Append, [System.IO.FileAccess]::Write, [System.IO.FileShare]::Read)
$copy = $proc.StandardOutput.BaseStream.CopyToAsync($fs)

Write-Sup "started PID $($proc.Id)"
Write-Output "started PID $($proc.Id), log $Log, commands via $CmdFile"

while (-not $proc.HasExited) {
    if (Test-Path $CmdFile) {
        try {
            $cmds = Get-Content $CmdFile -ErrorAction Stop
            Remove-Item $CmdFile -Force -ErrorAction SilentlyContinue
            foreach ($c in $cmds) {
                $line = $c.Trim()
                if ($line) {
                    $proc.StandardInput.WriteLine($line)
                    Write-Sup "console command sent: $line"
                }
            }
        } catch {
            # Probably mid-write; retry next tick.
        }
    }
    try { $fs.Flush() } catch { }
    Start-Sleep -Milliseconds 500
}

$proc.WaitForExit()
try { $copy.Wait(5000) | Out-Null } catch { }
try { $fs.Flush(); $fs.Close() } catch { }
[System.IO.File]::AppendAllText($Log, "=== exited $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') code $($proc.ExitCode) ===`r`n")
Write-Sup "exited code $($proc.ExitCode)"
Write-Output "server exited with code $($proc.ExitCode)"
