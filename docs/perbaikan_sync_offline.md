# Perbaikan Logika dan Performa Sinkronisasi Offline
*Tanggal Dokumentasi: 22 Mei 2026*

Berdasarkan permintaan Anda, berikut adalah catatan penyelesaian masalah terkait sinkronisasi data offline, performa, dan perilaku UI pada aplikasi Flutter ini.

## Perubahan yang Telah Diterapkan

### 1. `lib/core/services/sync_service.dart`

**[MODIFIKASI]** `lib/core/services/sync_service.dart`
- **Isu 1 & 5: Lag saat Offline dan Sinkronisasi yang Terlalu Sering**: Memperbarui metode `addToQueue` untuk mengecek `if (!_isOffline)` sebelum memanggil `syncNow()`. Memeriksa koneksi pada `syncNow()` memakan waktu dan menyebabkan aplikasi terasa lambat (*lag*) saat menambahkan data berkali-kali di mode offline.
- **Isu 3: Menghilangkan Notifikasi Peringatan Offline**: Menghapus metode `_notifyOfflineIfHasPending()` beserta seluruh panggilannya. Peringatan offline tidak akan muncul lagi sebagai notifikasi; informasi hanya akan tampil di *header* aplikasi sesuai kebutuhan.
- **Isu 4: Kecepatan dan Performa Sinkronisasi**: Mengubah eksekusi paralel `Future.wait(syncTasks)` di dalam `syncNow()` menjadi perulangan `for` secara sekuensial (satu per satu). Hal ini mencegah aplikasi membebani jaringan dengan banyak *request* sekaligus, yang sering gagal saat sinyal internet lemah.
- **Isu 6 & 7: Prioritas Sinkronisasi dan Data yang Hilang**: 
  - Menyusun ulang urutan proses `syncNow()`: 
    1. Kirim semua antrean data satu per satu. 
    2. **Tunggu (await)** proses pengambilan data baru dari server (`fetchAllResources`, `fetchSummary`, dan khususnya `TambahSaldoProvider.fetchRequests()`). 
    3. Tampilkan notifikasi sukses dan bersihkan antrean.
  - Penambahan pemanggilan untuk `TambahSaldoProvider.fetchRequests()` dan `TransaksiDoProvider.fetchRequests()` memastikan bahwa data "Saldo" dan "Transaksi DO" benar-benar diperbarui dari server setelah sinkronisasi. Ini memperbaiki *bug* di mana data tersebut seolah hilang karena dihapus dari memori antrean offline namun tidak pernah di-*refresh* otomatis dari server.

### 2. `lib/shared/providers/resource_provider.dart`

**[TINJAUAN]** `lib/shared/providers/resource_provider.dart`
- Memastikan metode seperti `fetchAllResources()` dan method *fetch* lainnya sudah mampu menangani *error* jaringan dengan aman tanpa menghapus daftar yang ada di layar. Dengan begitu, jika antrean sinkronisasi berhasil tetapi pengambilan ulang gagal akibat sinyal lemah, *user* tetap melihat sisa data yang tersimpan secara lokal.

## Status Penyelesaian
Semua perbaikan tersebut telah sukses diterapkan di dalam *codebase* dan sudah bisa di-commit.
