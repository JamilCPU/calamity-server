# Sends a console command to the running server via the supervisor's command channel.
# Examples:
#   .\send-command.ps1 save
#   .\send-command.ps1 'say Server restarting in 60 seconds'
#   .\send-command.ps1 exit        # graceful shutdown: saves the world first
#
# The supervisor polls command.txt twice a second, sends each line to the server's
# console, then deletes the file.

param([Parameter(Mandatory = $true, ValueFromRemainingArguments = $true)][string[]]$Command)

$ErrorActionPreference = 'Stop'

$CmdFile = 'D:\terraria-server\command.txt'
$line    = ($Command -join ' ').Trim()

$running = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
           Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
if (-not $running) { Write-Output 'server is not running - nothing to send'; exit 1 }

Add-Content -Path $CmdFile -Value $line -Encoding ascii
Write-Output "queued: $line"

# The supervisor deletes the file once it has consumed it, so its disappearance
# confirms delivery rather than just that we wrote it.
for ($i = 0; $i -lt 20; $i++) {
    Start-Sleep -Milliseconds 300
    if (-not (Test-Path $CmdFile)) { Write-Output 'delivered'; exit 0 }
}
Write-Output 'WARNING: command.txt still present - supervisor may not be reading it'
exit 2
