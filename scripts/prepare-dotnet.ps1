# Pre-delivers the .NET 8.0.0 runtime zip that tModLoader's launcher expects.
#
# Why: tModLoader's InstallDotNet.sh downloads the runtime through busybox, and that
# download stalls on this host (froze at exactly 16 MB). The launcher supports a
# pre-delivered archive named dotnet-runtime-<version>-win-x64.zip, which it extracts
# itself -- so we fetch it with Invoke-WebRequest instead and let the launcher take over.
#
# The version must be exactly 8.0.0: InstallDotNet.sh deletes any runtime whose
# shared/Microsoft.NETCore.App subfolder does not literally equal the version from
# tModLoader.runtimeconfig.json, so a newer patch release would be wiped on next launch.

$ErrorActionPreference = 'Stop'

$Root    = 'D:\terraria-server'
$Version = '8.0.0'
$Name    = "dotnet-runtime-$Version-win-x64.zip"
$Url     = "https://builds.dotnet.microsoft.com/dotnet/Runtime/$Version/$Name"

# Clear the stalled partial download so the launcher does not reuse it.
$partial = Join-Path $Root "dotnet\$Version.zip"
if (Test-Path $partial) { Remove-Item $partial -Force; Write-Output "removed stalled partial: $partial" }

$staged = Join-Path $env:TEMP $Name
if (-not (Test-Path $staged) -or (Get-Item $staged).Length -lt 20MB) {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Write-Output "downloading $Name ..."
    Invoke-WebRequest -Uri $Url -OutFile $staged -UseBasicParsing
}
Write-Output ("downloaded MB: " + [math]::Round((Get-Item $staged).Length / 1MB, 1))

# ScriptCaller.sh cd's into LaunchUtils before sourcing InstallDotNet.sh, so the
# relative lookup resolves there. Place a copy in the root too, matching the comment
# in InstallDotNet.sh, so either resolution finds it.
foreach ($dir in @((Join-Path $Root 'LaunchUtils'), $Root)) {
    Copy-Item $staged -Destination (Join-Path $dir $Name) -Force
    Write-Output "staged -> $(Join-Path $dir $Name)"
}

Write-Output 'DONE'
