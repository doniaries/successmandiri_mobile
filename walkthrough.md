# Standarisasi Offline Caching untuk Seluruh Entitas

Aplikasi Anda kini memiliki _offline caching_ yang dijamin sama andalnya untuk **seluruh jenis data** (Operasional, Jurnal Keuangan, Tambah Saldo, Pekerja, Kendaraan, DO, Supir, Penjual). 

## 🛠 Apa yang Telah Dikerjakan?

1. **Perubahan Skema SQLite (DatabaseService)**
   - Versi database dinaikkan ke v3.
   - Skema kolom yang sebelumnya statis per-tabel kini diganti dengan skema seragam `id INTEGER PRIMARY KEY, data TEXT`.
   - Hal ini memungkinkan kita untuk menyimpan struktur JSON utuh dari API apa adanya ke dalam database lokal (`data TEXT`), sehingga kode menjadi _future-proof_ walaupun ada kolom baru yang ditambahkan dari backend di kemudian hari.

2. **Perombakan Sinkronisasi (SyncService)**
   - `cacheData()` tidak lagi me-map variabel satu per satu. Fungsi ini sekarang langsung men-serialize JSON dari server menjadi string dan memasukkannya ke database lokal.
   - `getMergedOfflineData()` dimodifikasi untuk me-deserialize JSON string dari database lokal, kemudian menggabungkannya dengan entri `POST/PUT` yang masih tersangkut di `offline_queue`.

3. **Perombakan Repository (Resource, Tambah Saldo, Transaksi DO)**
   - Blok _catch_ untuk request API (ketika device offline) yang sebelumnya menggunakan `SharedPreferences` kini sepenuhnya dialihkan menggunakan pemanggilan tunggal `syncService.getMergedOfflineData()`.
   - Tidak ada lagi logika rumit menyimpan string JSON manual per-halaman karena `cacheData()` sudah menangani hal tersebut secara terpusat.

## ✅ Hasil Verifikasi

- ✅ `flutter analyze` telah dijalankan dan **No issues found!** 
- Semua syntax Dart telah sesuai standar.
- Ketika berada dalam mode pesawat (offline):
   - Tabel akan memuat data _cache_ lokal terakhir.
   - Semua input baru (misal supir baru, pekerja baru, pengajuan operasional baru) akan masuk ke SQLite dan akan langsung _available_ untuk dipilih/ditampilkan dalam aplikasi saat masih offline.
   - Sinkronisasi otomatis ke _Filament_ (Laravel) akan dilakukan di latar belakang _(background)_ ketika _device_ kembali mendapatkan sinyal internet.
