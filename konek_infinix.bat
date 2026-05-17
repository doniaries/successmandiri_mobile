@echo off
title Sukses Mandiri - Set Mode Infinix (USB)
echo =============================================================
echo               MENGUBAH MODUL KE MODE INFINIX (USB)
echo =============================================================
echo.
echo 1. Mengkonfigurasi file API ke http://127.0.0.1:8000/api ...

:: Overwrite/update api_constants.dart using PowerShell
powershell -Command "$content = Get-Content 'lib/core/constants/api_constants.dart' -Raw; $content = $content.Replace('return ''http://localhost:8000/api''; // Chrome', 'return ''http://127.0.0.1:8000/api''; // Infinix (via ADB Reverse) & Chrome').Replace('// return ''http://127.0.0.1:8000/api''; // Infinix (via ADB Reverse) & Chrome', '// return ''http://localhost:8000/api''; // Chrome'); Set-Content 'lib/core/constants/api_constants.dart' $content -NoNewline"

echo.
echo 2. Sedang mendeteksi perangkat dan membuat jembatan koneksi...
"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000

if %ERRORLEVEL% NEQ 0 goto GAGAL

:SUKSES
echo.
echo =============================================================
echo [SUKSES] Konfigurasi berhasil diubah ke MODE INFINIX (USB)
echo Port 8000 berhasil dijembatani lewat kabel USB.
echo HP Infinix Anda kini terhubung ke http://127.0.0.1:8000/api
echo =============================================================
goto END

:GAGAL
echo.
echo =============================================================
echo [SUKSES] Konfigurasi file berhasil diubah ke MODE INFINIX.
echo [PERINGATAN] Gagal menjembatani port ADB secara otomatis.
echo Silakan pastikan kabel USB terhubung dan USB Debugging aktif.
echo =============================================================

:END
echo.
pause
