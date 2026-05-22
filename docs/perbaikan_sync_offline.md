# Perbaikan Logika dan Performa Sinkronisasi Offline

Berdasarkan permintaan Anda, kita perlu menyelesaikan beberapa masalah terkait sinkronisasi data offline, performa, dan perilaku UI pada aplikasi Flutter.

## Perubahan yang Diusulkan

### 1. `lib/core/services/sync_service.dart`

**[MODIFIKASI]** `lib/core/services/sync_service.dart`
- **Isu 1 & 5: Lag saat Offline dan Sinkronisasi yang Terlalu Sering**: Memperbarui metode `addToQueue` untuk mengecek `if (!_isOffline)` sebelum memanggil `syncNow()`. Memeriksa koneksi pada `syncNow()` ternyata memakan waktu dan menyebabkan aplikasi terasa lambat (*lag*) saat Anda menambahkan data berkali-kali di mode offline.
- **Isu 3: Menghilangkan Notifikasi Peringatan Offline**: Menghapus metode `_notifyOfflineIfHasPending()` beserta seluruh panggilannya. Peringatan offline tidak akan muncul lagi sebagai notifikasi layar penuh; informasi hanya akan tampil di *header* aplikasi.
- **Isu 4: Kecepatan dan Performa Sinkronisasi**: Mengubah eksekusi paralel `Future.wait(syncTasks)` di dalam `syncNow()` menjadi perulangan `for` secara sekuensial (satu per satu). Hal ini mencegah aplikasi "membombardir" server dengan banyak *request* sekaligus, yang sering gagal saat sinyal internet sedang lemah.
- **Isu 6 & 7: Prioritas Sinkronisasi dan Data yang Hilang**: 
  - Menyusun ulang urutan proses `syncNow()`: Pertama, kirim semua antrean data satu per satu. Kedua, **tunggu (await)** proses pengambilan data baru dari server (`fetchAllResources`, `fetchSummary`, dan khususnya `TambahSaldoProvider.fetchRequests()`). Ketiga, barulah tampilkan notifikasi sukses dan hapus antrean.
  - Penambahan `TambahSaldoProvider.fetchRequests()` dan `TransaksiDoProvider.fetchRequests()` memastikan bahwa data "Saldo" dan "Transaksi DO" benar-benar diperbarui dari server setelah sinkronisasi. Ini memperbaiki *bug* di mana data tersebut seolah hilang (karena dihapus dari memori antrean lokal namun tidak pernah di-*refresh* dari server).

### 2. `lib/shared/providers/resource_provider.dart`

**[MODIFIKASI]** `lib/shared/providers/resource_provider.dart`
- Memastikan `fetchAllResources()` mampu menangani *error* jaringan dengan aman tanpa menghapus daftar yang sudah ada. Jadi, jika sinkronisasi berhasil tetapi *request* berikutnya gagal karena sinyal mendadak lemah, Anda tetap akan melihat sisa data yang masih tersimpan secara lokal (Isu 2).

## Status

Semua perbaikan tersebut telah sukses diterapkan di dalam kode proyek. Anda bisa langsung mencoba perubahannya.
