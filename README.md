# MySawit Mobile App

Aplikasi mobile untuk manajemen kelapa sawit terintegrasi (multi-tenancy, offline sync, dan real-time transaction recording).

---

## 🚀 Memulai (Getting Started)

Aplikasi ini dibangun menggunakan **Flutter Stable** dan terintegrasi langsung dengan backend Laravel melalui REST API.

### Prasyarat:
- Flutter SDK (Stable Channel)
- Android SDK / Xcode (untuk iOS)
- Koneksi ke Backend Laravel (Gunakan `adb reverse tcp:8000 tcp:8000` jika menggunakan emulator/perangkat fisik dengan Laravel localhost)

---

## 🛠️ Perintah Reset Data Aplikasi (Command Line)

Untuk keperluan testing, debugging, atau membersihkan data lokal yang tersimpan di perangkat tanpa perlu melakukan uninstall aplikasi, Anda bisa menggunakan perintah-perintah berikut:

### 1. Reset Storage & Database Lokal Aplikasi (Android)
Perintah ini akan langsung menghapus database SQLite lokal (`successmandiri.db`), data autentikasi (Secure Storage), dan preference cache secara instan:

```bash
# Bersihkan seluruh data lokal aplikasi via ADB
adb shell pm clear com.example.sawitappmobile
```

> [!TIP]
> Pastikan perangkat android fisik atau emulator Anda sudah terhubung (verifikasi dengan `adb devices`) sebelum menjalankan perintah di atas.

### 2. Reset Build Cache & Dependensi Project
Jika Anda menemui kendala caching aset atau dependensi yang tidak sinkron setelah melakukan pull update terbaru, jalankan rangkaian perintah pembersihan ini:

```bash
# Bersihkan build cache Flutter
flutter clean

# Ambil ulang seluruh dependensi project
flutter pub get
```

---

## 📱 Dokumen Terkait
- [PROGRESS.md](file:///c:/laragon/www/successmandiri_mobile/PROGRESS.md) - Laporan riwayat implementasi multi-tenancy & autentikasi.

---

## 📋 Checklist Sebelum Build / Debug Flutter

Agar semua perubahan dapat diterapkan pada APK baru atau saat proses debugging berjalan dengan lancar, pastikan Anda melakukan hal-hal berikut:

### 1. Bersihkan Cache Flutter
Wajib dilakukan setelah perubahan signifikan pada dependencies atau widget struktur.
```bash
flutter clean
```

### 2. Install Ulang Dependencies
Pastikan semua package ter-install dengan benar setelah melakukan `flutter clean`.
```bash
flutter pub get
```

### 3. Jalankan Code Generation (Opsional)
Jika ada model yang menggunakan `@JsonSerializable` atau `@freezed`.
```bash
dart run build_runner build --delete-conflicting-outputs
```

### 4. Untuk Build APK
File APK akan berada di: `build/app/outputs/flutter-apk/`

**APK Debug** (ukuran besar, untuk testing internal):
```bash
flutter build apk --debug
```

**APK Release** (ukuran kecil, untuk distribusi):
```bash
flutter build apk --release
```

**APK per ABI** (lebih kecil, pilih sesuai arsitektur CPU device):
```bash
flutter build apk --release --split-per-abi
```

### 5. Pastikan Backend Laravel Siap
Lakukan ini di folder backend (`successmandiri_laravel`):
```bash
php artisan optimize:clear
php artisan config:cache
php artisan route:cache
```

> **Catatan:** Setelah melakukan `flutter clean` + `flutter pub get`, pastikan melakukan **Hot Restart** (bukan Hot Reload) saat debugging agar semua perubahan pada provider atau state ter-apply dengan benar.
