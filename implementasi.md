Standardize Offline Caching for All Entities
Masalah yang terjadi saat ini adalah hanya tabel transaksi_do, penjual, dan supir yang benar-benar tersimpan ke database lokal (SQLite) saat online, dan digabungkan dengan antrean offline (offline_queue).

Sedangkan tabel-tabel lain seperti pekerja, kendaraan, operasional, jurnal_keuangan, tambah_saldo, dan pengajuan_dana mengandalkan SharedPreferences atau bahkan tidak memiliki tabel lokal sama sekali. Akibatnya, saat aplikasi berada dalam mode offline, data lamanya tidak muncul atau mengalami duplikasi.

Solusi Arsitektur
Kita akan merombak cara penyimpanan data offline lokal (cache) menjadi standar yang sama untuk SEMUA tabel agar aplikasi dapat bekerja layaknya sistem offline-first yang handal:

Update DatabaseService (SQLite): Membuat tabel lokal untuk SEMUA entitas. Untuk kemudahan maintenance (agar tidak perlu merubah skema setiap ada penambahan kolom dari backend), kita akan menyimpan 1 kolom data TEXT yang berisi JSON utuh dari backend. Tabel yang akan dibuat/diperbarui:

pekerja, kendaraan (Update kolom)
operasional, jurnal_keuangan, tambah_saldo, pengajuan_dana (Tabel baru)
Update SyncService (cacheData & getMergedOfflineData):

cacheData: Menyimpan JSON response utuh ke dalam tabel SQLite untuk setiap entitas.
getMergedOfflineData: Membaca dari tabel SQLite dan menggabungkannya dengan offline_queue.
Update Repositories: Menghapus pemakaian SharedPreferences untuk caching list data (seperti di resource_repository.dart, tambah_saldo_repository.dart), dan sepenuhnya menggunakan syncService.getMergedOfflineData() saat offline.

Open Questions
IMPORTANT

Saat ini transaksi_do, penjual, dan supir memiliki skema spesifik per kolom (seperti id, nama, telepon). Jika saya merombak tabel lain menjadi skema (id INTEGER PRIMARY KEY, data TEXT) agar lebih aman menyimpan data utuh JSON, apakah saya sebaiknya juga merombak skema tabel penjual, supir, dan transaksi_do menjadi (id INTEGER, data TEXT) agar konsisten dan menghindari field hilang saat offline?

Proposed Changes
Core Services
[MODIFY] lib/core/services/database_service.dart
Tambahkan tabel baru untuk operasional, jurnal_keuangan, tambah_saldo, pengajuan_dana.
Opsional: migrate pekerja, kendaraan (atau semua tabel) menjadi id INTEGER, data TEXT.
[MODIFY] lib/core/services/sync_service.dart
Modifikasi method cacheData() agar dapat menyimpan JSON utuh.
Modifikasi method getMergedOfflineData() agar membaca JSON utuh dari kolom data SQLite dan mereturn List yang valid digabungkan dengan offline_queue.
Repositories
[MODIFY] lib/shared/repositories/resource_repository.dart
getPekerjaPaginated, getKendaraanPaginated, getOperasionalPaginated, getJurnalPaginated: hapus cache via SharedPreferences dan alihkan ke syncService.getMergedOfflineData yang baru.
[MODIFY] lib/shared/repositories/tambah_saldo_repository.dart
getTambahSaldo: Tambahkan logika untuk membaca dari syncService.getMergedOfflineData('tambah_saldo') jika offline.
Verification Plan
Automated Tests
Menjalankan flutter analyze & flutter build apk.
Manual Verification
Matikan koneksi internet (Airplane mode).
Buka halaman Operasional, Jurnal Keuangan, Tambah Saldo, Pekerja, Kendaraan.
Pastikan list data lama muncul.
Buat data Pekerja / Tambah Saldo baru saat offline.
Pastikan data yang baru saja dibuat langsung muncul di list dan bisa dipilih di form lain (misal dropdown) tanpa perlu online dulu.
