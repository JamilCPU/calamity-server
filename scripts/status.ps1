# Health summary of the Calamity server, plus the tail of its log.
#
# NOTE ON PROCESS COUNT: a healthy server is TWO dotnet processes, not one.
# Subworld Library (a Wrath of the Gods dependency) relaunches the server as a
# child process with -subworld to host subworlds. The child's parent is the main
# server; the main server's parent is the supervisor PowerShell. Seeing two is
# normal -- only two *main* servers would be a problem.

$Root = 'D:\terraria-server'

$all = @(Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
         Where-Object { $_.CommandLine -like '*tModLoader.dll*' })

$mainPids = @()
$subPids  = @()
foreach ($p in $all) {
    if ($p.CommandLine -like '*-subworld*') { $subPids += $p.ProcessId }
    else                                    { $mainPids += $p.ProcessId }
}

$mb = 0
foreach ($p in $all) {
    $ps = Get-Process -Id $p.ProcessId -ErrorAction SilentlyContinue
    if ($ps) { $mb += [math]::Round($ps.WS / 1MB) }
}

$listen = (Get-NetTCPConnection -LocalPort 7777 -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count
$world  = Test-Path (Join-Path $Root 'data\Worlds\Calamity.wld')

$warn = ''
if ($mainPids.Count -gt 1) { $warn = '  *** MULTIPLE MAIN SERVERS - world corruption risk ***' }

Write-Output "main=$($mainPids -join ',') subworld=$($subPids -join ',') ram_mb=$mb listening=$listen world_exists=$world$warn"

$log = Join-Path $Root 'logs\server.log'
if (Test-Path $log) {
    Write-Output "--- server.log ($((Get-Item $log).Length) bytes) ---"
    Get-Content $log -Tail 12
} else {
    Write-Output '--- no server.log ---'
}
