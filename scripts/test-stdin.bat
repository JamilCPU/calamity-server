@echo off
REM Diagnostic only: does the server survive detached if stdin never reaches EOF?
cd /D "%~dp0.."
powershell -NoProfile -Command "while($true){Start-Sleep -Seconds 3600}" | dotnet\dotnet.exe tModLoader.dll -server -config serverconfig.txt -tmlsavedirectory data >> logs\stdin-test.log 2>&1
