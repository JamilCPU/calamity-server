# Runs the Calamity tModLoader dedicated server and stays alive for its lifetime.
#
# WHY A SUPERVISOR: the server reads console commands from stdin. Launched detached
# (scheduled task, Start-Process) it gets no stdin, immediately reads EOF and exits
# cleanly with code 0 partway through mod loading -- which looks like a crash but is
# not. This script holds the stdin pipe open so the server never sees EOF.
#
# COMMAND CHANNEL: write lines to D:\terraria-server\command.txt and they are sent to
# the server's console, then the file is deleted. That makes `say`, `save` and a
# graceful `exit` possible from outside -- previously there was no way to talk to the
# running server at all, so every restart was a force-kill that discarded everything
# since the last autosave.
#
# stdout is pumped asynchronously via an event handler rather than a blocking
# ReadLine, so the main loop stays free to watch for commands.

$ErrorActionPreference = 'Stop'

$Root    = 'D:\terraria-server'
$Logs    = Join-Path $Root 'logs'
$Log     = Join-Path $Logs 'server.log'
$CmdFile = Join-Path $Root 'command.txt'

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

# A stale command file from a previous run must not be replayed into the new server.
if (Test-Path $CmdFile) { Remove-Item $CmdFile -Force -ErrorAction SilentlyContinue }

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName               = Join-Path $Root 'dotnet\dotnet.exe'
$psi.Arguments              = 'tModLoader.dll -server -config serverconfig.txt -tmlsavedirectory data'
$psi.WorkingDirectory       = $Root
$psi.UseShellExecute        = $false
$psi.RedirectStandardInput  = $true
$psi.RedirectStandardOutput = $true

$writer = [System.IO.StreamWriter]::new($Log, $true)
$writer.AutoFlush = $true

$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $psi
$proc.EnableRaisingEvents = $true

# Pump stdout asynchronously. If this handler ever fails we lose logging but the
# server keeps running, which is the right way round.
$sub = Register-ObjectEvent -InputObject $proc -EventName OutputDataReceived -MessageData $writer -Action {
    if ($null -ne $EventArgs.Data) {
        try { $Event.MessageData.WriteLine($EventArgs.Data) } catch { }
    }
}

$proc.Start() | Out-Null
$proc.BeginOutputReadLine()
$proc.StandardInput.AutoFlush = $true

$writer.WriteLine("=== started $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') PID $($proc.Id) ===")
Write-Output "started PID $($proc.Id), logging to $Log, commands via $CmdFile"

while (-not $proc.HasExited) {
    if (Test-Path $CmdFile) {
        try {
            $cmds = Get-Content $CmdFile -ErrorAction Stop
            Remove-Item $CmdFile -Force -ErrorAction SilentlyContinue
            foreach ($c in $cmds) {
                $line = $c.Trim()
                if ($line) {
                    $writer.WriteLine("=== console command: $line ===")
                    $proc.StandardInput.WriteLine($line)
                }
            }
        } catch {
            # File was probably still being written; try again next tick.
        }
    }
    Start-Sleep -Milliseconds 500
}

$proc.WaitForExit()
try { Unregister-Event -SubscriptionId $sub.Id -ErrorAction SilentlyContinue } catch { }
$writer.WriteLine("=== exited $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') code $($proc.ExitCode) ===")
$writer.Close()
Write-Output "server exited with code $($proc.ExitCode)"
