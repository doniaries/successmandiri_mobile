# Perbaikan Logika dan Performa Sinkronisasi Offline

Berdasarkan permintaan Anda, kita perlu menyelesaikan beberapa masalah terkait sinkronisasi data offline, performa, dan perilaku UI pada aplikasi Flutter.

## Perubahan yang Diusulkan

### 1. `lib/core/services/sync_service.dart`

**[MODIFIKASI]** `lib/core/services/sync_service.dart`
- 1. [x] **Optimasi `SyncService`**
   - Mengubah `syncNow()` agar sinkronisasi dilakukan secara **berurutan (sekuensial)**, bukan paralel. Hal ini mengurangi beban jaringan dan meminimalisir risiko timeout pada sinyal lemah.
   - Menambahkan batasan (`take(10)`) agar hanya memproses 10 data offline dalam satu waktu untuk mencegah aplikasi menjadi lambat (lag).
   - Membatalkan pengecekan sinkronisasi saat offline (`syncNow` mereturn jika offline)
   - Sinkronisasi dilakukan di background dengan notifikasi yang lebih ramah pengguna

- 2. [x] **Perbaikan `RefreshIndicator` pada mode Offline**
   - Menambahkan `notificationPredicate` pada semua widget `RefreshIndicator` di layar utama (Dashboard, Operasional, Transaksi DO, Tambah Saldo, Profile).
   - `notificationPredicate: (notification) => !SyncService().isOffline && defaultScrollNotificationPredicate(notification)` mencegah user melakukan aksi *pull-to-refresh* (geser ke bawah) saat aplikasi tidak terhubung internet, sesuai dengan keinginan user.
   - Mengurangi notifikasi peringatan "data belum disinkronisasi" saat offline, cukup hanya dengan header notifikasi di UI tanpa alert popup.

- 3. [x] **Stabilitas Data Offline pada Layar Saldo dan Operasional**
   - Menambahkan pemanggilan fungsi `_syncService.getMergedOfflineData` di class Repository (seperti `TambahSaldoRepository` dan `ResourceRepository`) pada saat **online**.
   - Sebelumnya data queue offline tidak digabungkan (merge) dengan data *fetch* network, yang menyebabkan data terbaru seolah-olah "hilang" (data tidak tinggal) ketika disinkronkan, karena sinkronisasi background belum selesai saat layar memuat ulang. 
   - Kini, data yang sedang di-sync (masih ada di queue) akan terus dirender berdampingan dengan respons data dari API server, sehingga data selalu persisten di mata user.

- **Isu 4: Kecepatan dan Performa Sinkronisasi**: 
  - Mengubah eksekusi paralel `Future.wait(syncTasks)` di dalam `syncNow()` menjadi perulangan `for` secara sekuensial (satu per satu). Hal ini mencegah aplikasi "membombardir" server dengan banyak *request* sekaligus, yang sering gagal saat sinyal internet sedang lemah.
- **Isu 6 & 7: Prioritas Sinkronisasi dan Data yang Hilang**: 
  - Menyusun ulang urutan proses `syncNow()`: Pertama, kirim semua antrean data satu per satu. Kedua, **tunggu (await)** proses pengambilan data baru dari server (`fetchAllResources`, `fetchSummary`, dan khususnya `TambahSaldoProvider.fetchRequests()`). Ketiga, barulah tampilkan notifikasi sukses dan hapus antrean.
  - Penambahan `TambahSaldoProvider.fetchRequests()` dan `TransaksiDoProvider.fetchRequests()` memastikan bahwa data "Saldo" dan "Transaksi DO" benar-benar diperbarui dari server setelah sinkronisasi. Ini memperbaiki *bug* di mana data tersebut seolah hilang (karena dihapus dari memori antrean lokal namun tidak pernah di-*refresh* dari server).

### 2. `lib/shared/providers/resource_provider.dart`

**[MODIFIKASI]** `lib/shared/providers/resource_provider.dart`
- Memastikan `fetchAllResources()` mampu menangani *error* jaringan dengan aman tanpa menghapus daftar yang sudah ada. Jadi, jika sinkronisasi berhasil tetapi *request* berikutnya gagal karena sinyal mendadak lemah, Anda tetap akan melihat sisa data yang masih tersimpan secara lokal (Isu 2).

## Status

Semua perbaikan tersebut telah sukses diterapkan di dalam kode proyek. Anda bisa langsung mencoba perubahannya.
