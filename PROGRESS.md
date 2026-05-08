# Progress Report - Multi-Tenancy & Fixes

## 📅 Tanggal: 17 Maret 2026

### ✅ Progress Terakhir:
1.  **Multi-Tenancy (Pilih Perusahaan):**
    *   **Backend:** Selesai verifikasi method `getPerusahaans` dan `switchPerusahaan` di `AuthController`.
    *   **Frontend:** Fitur pemilihan perusahaan di Dashboard via Modal Bottom Sheet berfungsi stabil.
    *   **Data Sync:** Konfirmasi sinkronisasi ulang data (Transaksi, Pengajuan, Resources) otomatis setelah pindah perusahaan.
2.  **Authentication & Security:**
    *   **Remember Me:** Fitur "Ingat Password" menggunakan `flutter_secure_storage` berfungsi dengan benar.
    *   **Logout:** Fungsi logout menghapus token di storage dan revoke di server (Sanctum).
    *   **Null Safety:** Menambahkan fallback `??` untuk menampilkan 'Tanpa Nama' jika data perusahaan null di selector.
3.  **Lingkungan Pengembangan:**
    *   Konfigurasi `ApiClient` menggunakan `localhost:8000` dengan `adb reverse` untuk kestabilan koneksi fisik device.

### 🚀 Status Verifikasi:
- **Switch Company:** LULUS (Logic valid di Mobile & Backend).
- **Remember Me:** LULUS (Storage secure & Auto-fill valid).
- **Data Refresh:** LULUS (Trigger `fetch` terpanggil pasca-switch).

### 🛠️ Langkah Selanjutnya:
1.  Testing skenario edge-case (koneksi terputus saat switch).
2.  Persiapan deployment beta ke internal team.
