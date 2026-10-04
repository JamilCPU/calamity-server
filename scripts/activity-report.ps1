# Read-only activity summary for the running server: uptime, players, logins,
# chat, notices, saves, and how much scanner noise the port is attracting.

$Root = 'D:\terraria-server'
$Log  = Join-Path $Root 'logs\server.log'
$Port = 25564

$proc = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*tModLoader.dll*' -and $_.CommandLine -notlike '*subworld*' }

Write-Output '===== SERVER ====='
if ($proc) {
    $ps = Get-Process -Id $proc.ProcessId -ErrorAction SilentlyContinue
    $up = (Get-Date) - $proc.CreationDate
    Write-Output ("up since   : {0}  ({1}h {2}m)" -f $proc.CreationDate, [int]$up.TotalHours, $up.Minutes)
    Write-Output ("ram_mb     : {0}" -f [math]::Round($ps.WS / 1MB))
} else {
    Write-Output 'NOT RUNNING'
}
Write-Output ("listening  : {0}" -f (Get-NetTCPConnection -LocalPort $Port -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count)
Write-Output ("players now: {0}" -f (Get-NetTCPConnection -LocalPort $Port -State Established -ErrorAction SilentlyContinue | Measure-Object).Count)
Write-Output ("world saved: {0}" -f (Get-Item (Join-Path $Root 'data\Worlds\Calamity.wld')).LastWriteTime)

$start = (Select-String -Path $Log -Pattern '=== started' | Select-Object -Last 1).LineNumber
$l = Get-Content $Log | Select-Object -Skip $start

Write-Output ''
Write-Output '===== PLAYER ACTIVITY (this run) ====='
$joins = @($l | Select-String 'has joined')
$lefts = @($l | Select-String 'has left')
Write-Output ("joins: {0}   leaves: {1}" -f $joins.Count, $lefts.Count)
$joins | Select-Object -Last 15 | ForEach-Object { '  + ' + $_.Line }
Write-Output '  --- most recent leaves ---'
$lefts | Select-Object -Last 8 | ForEach-Object { '  - ' + $_.Line }

Write-Output ''
Write-Output '===== CHAT / BROADCASTS ====='
$chat = @($l | Select-String -Pattern '^<' )
if ($chat) { $chat | Select-Object -Last 25 | ForEach-Object { '  ' + $_.Line } } else { '  (none captured)' }

Write-Output ''
Write-Output '===== BOOTS / REFUSALS ====='
$boot = @($l | Select-String 'was booted')
Write-Output ("total: {0}" -f $boot.Count)
$boot | Select-Object -Last 12 | ForEach-Object { '  ' + $_.Line }

Write-Output ''
Write-Output '===== NOTICES / ERRORS ====='
Write-Output ("watchdog hangs : {0}" -f @($l | Select-String 'Server hung').Count)
Write-Output ("save cycles    : {0}" -f @($l | Select-String 'Backing up world file').Count)
$err = @($l | Select-String 'Exception|Missing mod|Disabling|invalid')
Write-Output ("error-ish lines: {0}" -f $err.Count)
$err | Select-Object -Last 6 | ForEach-Object { '  ' + $_.Line }

Write-Output ''
Write-Output '===== SCAN NOISE (distinct source IPs attempting to connect) ====='
$ips = $l | Select-String 'is connecting' | ForEach-Object { ($_.Line -split ':')[0] }
$grp = $ips | Group-Object | Sort-Object Count -Descending
Write-Output ("distinct IPs: {0}   total attempts: {1}" -f @($grp).Count, @($ips).Count)
$grp | Select-Object -First 12 | ForEach-Object { ('  {0,4}  {1}' -f $_.Count, $_.Name) }

Write-Output ''
Write-Output '===== LAST 15 LOG LINES ====='
$l | Select-Object -Last 15 | ForEach-Object { '  ' + $_ }
