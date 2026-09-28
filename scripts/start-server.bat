@echo off
REM Launches tModLoader's dedicated server directly via the locally installed .NET.
REM
REM Deliberately bypasses start-tModLoaderServer.bat (busybox -> ScriptCaller.sh):
REM that chain prompts interactively for steam mode, and its stdout does not
REM propagate to a redirected parent handle, so logs came back empty. Calling
REM dotnet directly gives reliable output capture and no prompts. The .NET runtime
REM is already installed at dotnet\ by prepare-dotnet.ps1 + the launcher's extract.

cd /D "%~dp0.."
if not exist logs mkdir logs
dotnet\dotnet.exe tModLoader.dll -server -config serverconfig.txt -tmlsavedirectory data >> logs\server.log 2>&1
