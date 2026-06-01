@echo off
set BUILD_NAME=1.0.2
set BUILD_NUMBER=2
powershell -Command "(Get-Content pubspec.yaml) -replace '^version:.*', 'version: %BUILD_NAME%+%BUILD_NUMBER%' | Set-Content pubspec.yaml"
findstr /b "version:" pubspec.yaml
