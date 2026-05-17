@echo off
title Sukses Mandiri - Set Mode Chrome
echo =============================================================
echo               MENGUBAH MODUL KE MODE CHROME (WEB)
echo =============================================================
echo.
echo Sedang mengkonfigurasi file API ke http://localhost:8000/api ...

:: Overwrite/update api_constants.dart using PowerShell
powershell -Command "$content = Get-Content 'lib/core/constants/api_constants.dart' -Raw; $content = $content -replace 'return ''http://127.0.0.1:8000/api''; // Infinix.*', 'return ''http://localhost:8000/api''; // Chrome' -replace '// return ''http://localhost:8000/api''; // Chrome', '// return ''http://127.0.0.1:8000/api''; // Infinix (via ADB Reverse) \u0026 Chrome'; Set-Content 'lib/core/constants/api_constants.dart' $content -NoNewline"

echo.
echo =============================================================
echo [SUKSES] Konfigurasi berhasil diubah ke MODE CHROME!
echo API Base URL saat ini: http://localhost:8000/api
echo =============================================================
echo.
pause
