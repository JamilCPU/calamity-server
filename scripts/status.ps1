# One-line health summary of the Calamity server, plus the tail of its log.

$Root = 'D:\terraria-server'

$proc = Get-CimInstance Win32_Process -Filter "Name='dotnet.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like '*tModLoader.dll*' }
$listen = (Get-NetTCPConnection -LocalPort 7777 -State Listen -ErrorAction SilentlyContinue | Measure-Object).Count
$world  = Test-Path (Join-Path $Root 'data\Worlds\Calamity.wld')

$pids = @($proc | ForEach-Object { $_.ProcessId })
$mb = 0
foreach ($p in $pids) {
    $ps = Get-Process -Id $p -ErrorAction SilentlyContinue
    if ($ps) { $mb += [math]::Round($ps.WS / 1MB) }
}

Write-Output "instances=$($pids.Count) pids=$($pids -join ',') ram_mb=$mb listening=$listen world_exists=$world"

$log = Join-Path $Root 'logs\server.log'
if (Test-Path $log) {
    Write-Output "--- server.log ($((Get-Item $log).Length) bytes) ---"
    Get-Content $log -Tail 20
} else {
    Write-Output '--- no server.log ---'
}
