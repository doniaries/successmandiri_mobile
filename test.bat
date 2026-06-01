@echo off
set /p BUILD_NAME="1. Masukkan Versi Aplikasi (contoh: 1.0.5): "
for /f "tokens=1,2,3 delims=." %%a in ("%BUILD_NAME%") do (
    set BUILD_NUMBER=%%c
)
echo BUILD_NUMBER IS %BUILD_NUMBER%
