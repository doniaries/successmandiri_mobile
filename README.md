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
