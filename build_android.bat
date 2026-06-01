@echo off
cd /d "%~dp0"
title Sukses Mandiri - Build Android APK
echo =============================================================
echo =============================================================
echo               MEMULAI PROSES BUILD ANDROID APK
echo =============================================================
echo.

:: Ambil versi saat ini dari pubspec.yaml
for /f "tokens=2" %%v in ('findstr /b "version:" pubspec.yaml') do set CURRENT_VER=%%v

:: Pisahkan dari build number jika ada (hilangkan tanda +)
for /f "tokens=1 delims=+" %%a in ("%CURRENT_VER%") do set BASE_VER=%%a

:: Pisahkan menjadi Major, Minor, Patch
for /f "tokens=1,2,3 delims=." %%a in ("%BASE_VER%") do (
    set V_MAJ=%%a
    set V_MIN=%%b
    set V_PAT=%%c
)

:: Tambah angka ketiga (Patch) otomatis
set /a NEW_PAT=V_PAT+1
set DEFAULT_VER=%V_MAJ%.%V_MIN%.%NEW_PAT%

set BUILD_NAME=
set /p BUILD_NAME="1. Masukkan Versi Aplikasi (Tekan Enter untuk otomatis versi %DEFAULT_VER%): "
if "%BUILD_NAME%"=="" set BUILD_NAME=%DEFAULT_VER%

for /f "tokens=1,2,3 delims=." %%a in ("%BUILD_NAME%") do (
    set BUILD_NUMBER=%%c
)
if "%BUILD_NUMBER%"=="" (
    echo [ERROR] Format versi harus memiliki 3 angka, dipisahkan titik ^(contoh: 1.0.5^)
    goto END
)
echo 2. Build Number otomatis: %BUILD_NUMBER%
echo.

echo 3. Memperbarui versi di pubspec.yaml ke %BUILD_NAME%+%BUILD_NUMBER%...
powershell -Command "(Get-Content pubspec.yaml) -replace '^version:.*', 'version: %BUILD_NAME%+%BUILD_NUMBER%' | Set-Content pubspec.yaml"
echo.

echo 4. Membersihkan cache build (flutter clean)...
call flutter clean
if %ERRORLEVEL% NEQ 0 goto GAGAL

echo 5. Mengambil dependensi Flutter...
call flutter pub get
if %ERRORLEVEL% NEQ 0 goto GAGAL

echo.
echo 6. Memulai kompilasi Release APK (Versi %BUILD_NAME%_%BUILD_NUMBER%)...
call flutter build apk --release --build-name=%BUILD_NAME% --build-number=%BUILD_NUMBER%
if %ERRORLEVEL% NEQ 0 goto GAGAL

echo.
echo 7. Menyalin dan mengubah nama APK...
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
