# Registers the boot-autostart and hourly-backup scheduled tasks.
# Runs as SYSTEM so the server comes up after a reboot with nobody logged in.
# Idempotent: existing tasks with these names are replaced.

$ErrorActionPreference = 'Stop'

$ScriptDir = 'D:\terraria-server\scripts'
$Ps        = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"

function Register-Task {
    param($Name, $ScriptPath, $Trigger, $Description)
    if (Get-ScheduledTask -TaskName $Name -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $Name -Confirm:$false
    }
    $action = New-ScheduledTaskAction -Execute $Ps `
              -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$ScriptPath`""
    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settings  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                 -StartWhenAvailable -ExecutionTimeLimit ([TimeSpan]::Zero)
    Register-ScheduledTask -TaskName $Name -Action $action -Trigger $Trigger `
        -Principal $principal -Settings $settings -Description $Description | Out-Null
    Write-Output "registered: $Name"
}

Register-Task -Name 'TerrariaCalamityServer' `
    -ScriptPath (Join-Path $ScriptDir 'run-server.ps1') `
    -Trigger (New-ScheduledTaskTrigger -AtStartup) `
    -Description 'Starts the Calamity tModLoader dedicated server at boot.'

# Hourly, forever, starting 5 minutes from registration.
$bt = New-ScheduledTaskTrigger -Once -At ((Get-Date).AddMinutes(5)) `
      -RepetitionInterval (New-TimeSpan -Hours 1)
Register-Task -Name 'TerrariaCalamityBackup' `
    -ScriptPath (Join-Path $ScriptDir 'backup-world.ps1') `
    -Trigger $bt `
    -Description 'Hourly rotating backup of the Calamity world (.wld + .twld).'

Get-ScheduledTask -TaskName 'TerrariaCalamity*' |
    Select-Object TaskName, State | Format-Table -AutoSize
