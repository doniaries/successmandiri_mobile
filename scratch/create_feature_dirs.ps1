$features = @("auth", "dashboard", "operasional", "transaksi_do", "penjual", "supir", "pekerja", "user", "jurnal_keuangan", "kendaraan", "tambah_saldo", "profile", "splash")
foreach ($f in $features) {
    mkdir "lib/features/$f/models" -Force
    mkdir "lib/features/$f/providers" -Force
    mkdir "lib/features/$f/screens" -Force
    mkdir "lib/features/$f/widgets" -Force
}
