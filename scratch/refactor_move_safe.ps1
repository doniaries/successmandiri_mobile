# Safe Refactor Move Script
function Move-Safe {
    param($src, $dest)
    if (Test-Path $src) {
        if (!(Test-Path $dest)) { mkdir $dest -Force }
        Move-Item $src $dest -Force -ErrorAction Continue
        Write-Host "Moved $src to $dest"
    } else {
        Write-Warning "Source $src not found"
    }
}

# 1. Models
Move-Safe "lib/models/user_model.dart" "lib/features/auth/models/"
Move-Safe "lib/models/dashboard_summary_model.dart" "lib/features/dashboard/models/"
Move-Safe "lib/models/operasional_model.dart" "lib/features/operasional/models/"
Move-Safe "lib/models/transaksi_do_model.dart" "lib/features/transaksi_do/models/"
Move-Safe "lib/models/penjual_model.dart" "lib/features/penjual/models/"
Move-Safe "lib/models/supir_model.dart" "lib/features/supir/models/"
Move-Safe "lib/models/pekerja_model.dart" "lib/features/pekerja/models/"
Move-Safe "lib/models/kendaraan_model.dart" "lib/features/kendaraan/models/"
Move-Safe "lib/models/mutasi_hutang_model.dart" "lib/shared/models/"
Move-Safe "lib/models/jurnal_keuangan_model.dart" "lib/features/jurnal_keuangan/models/"
Move-Safe "lib/models/tambah_saldo_model.dart" "lib/features/tambah_saldo/models/"

# 2. Providers
Move-Safe "lib/providers/auth_provider.dart" "lib/features/auth/providers/"
Move-Safe "lib/providers/dashboard_provider.dart" "lib/features/dashboard/providers/"
Move-Safe "lib/providers/resource_provider.dart" "lib/shared/providers/"
Move-Safe "lib/providers/tambah_saldo_provider.dart" "lib/features/tambah_saldo/providers/"
Move-Safe "lib/providers/transaksi_do_provider.dart" "lib/features/transaksi_do/providers/"

# 3. Screens
$features = @("auth", "dashboard", "operasional", "transaksi_do", "penjual", "supir", "pekerja", "user", "jurnal_keuangan", "kendaraan", "tambah_saldo", "profile", "splash", "common", "finance")
foreach ($f in $features) {
    if (Test-Path "lib/screens/$f") {
        # Check if we should map finance/common to something else or keep in features
        $targetF = $f
        if ($f -eq "finance") { $targetF = "operasional" } # Or keep as finance feature
        if ($f -eq "common") { 
            Move-Safe "lib/screens/common/*" "lib/shared/screens/"
        } else {
            Move-Safe "lib/screens/$f/*" "lib/features/$targetF/screens/"
        }
    }
}
Move-Safe "lib/screens/main_navigation_screen.dart" "lib/shared/screens/"
Move-Safe "lib/screens/permission_wizard_screen.dart" "lib/shared/screens/"

# 4. Services
Move-Safe "lib/services/*" "lib/core/services/"

# 5. Widgets
Move-Safe "lib/widgets/*" "lib/shared/widgets/"

# 6. Repositories (Shared for now, or feature based)
mkdir lib/shared/repositories -Force
Move-Safe "lib/repositories/*" "lib/shared/repositories/"
