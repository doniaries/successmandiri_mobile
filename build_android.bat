@echo off
cd /d "%~dp0"
title Sukses Mandiri - Build Android APK
echo =============================================================
echo =============================================================
echo               MEMULAI PROSES BUILD ANDROID APK
echo =============================================================
echo.

set /p BUILD_NAME="1. Masukkan Build Name (contoh: 1.0.0): "
set /p BUILD_NUMBER="2. Masukkan Build Number (contoh: 1, 2, 3): "
echo.

echo 3. Membersihkan cache build (flutter clean)...
call flutter clean
if %ERRORLEVEL% NEQ 0 goto GAGAL

echo 4. Mengambil dependensi Flutter...
call flutter pub get
if %ERRORLEVEL% NEQ 0 goto GAGAL

echo.
echo 5. Memulai kompilasi Release APK (Versi %BUILD_NAME%_%BUILD_NUMBER%)...
call flutter build apk --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%
if %ERRORLEVEL% NEQ 0 goto GAGAL

echo.
echo 6. Menyalin dan mengubah nama APK...
if exist "build\app\outputs\flutter-apk\app-release.apk" (
    copy "build\app\outputs\flutter-apk\app-release.apk" "mysawit_v%BUILD_NAME%_%BUILD_NUMBER%.apk" /Y
) else if exist "build\app\outputs\apk\release\app-release.apk" (
    copy "build\app\outputs\apk\release\app-release.apk" "mysawit_v%BUILD_NAME%_%BUILD_NUMBER%.apk" /Y
) else (
    echo [ERROR] File APK tidak ditemukan di folder build!
    goto GAGAL
)
if %ERRORLEVEL% NEQ 0 goto GAGAL

:SUKSES
echo.
echo =============================================================
echo [SUKSES] Build berhasil!
echo File APK kustom Anda kini berada di folder utama proyek:
echo -^> mysawit_v%BUILD_NAME%_%BUILD_NUMBER%.apk
echo =============================================================
goto END

:GAGAL
echo.
echo =============================================================
echo [GAGAL] Terjadi kesalahan saat mem-build APK.
echo Silakan periksa log error di atas.
echo =============================================================

:END
echo.
pause
