# Recovery and Correct Refactor
$features = @("auth", "dashboard", "operasional", "transaksi_do", "penjual", "supir", "pekerja", "user", "jurnal_keuangan", "kendaraan", "tambah_saldo", "profile", "splash")

foreach ($f in $features) {
    $path = "lib/features/$f"
    if (Test-Path "$path/models") {
        if (!(Test-Path "$path/models" -PathType Container)) {
            # It's a file!
            $ext = ".dart"
            # We need to know the original name. 
            # I'll just rename to [feature]_model.dart for now if unknown, 
            # but I have the mapping from my previous script.
        }
    }
}

# Proper mapping based on previous move script:
# Auth: models=user_model.dart, providers=auth_provider.dart
Rename-Item lib/features/auth/models user_model.dart
Rename-Item lib/features/auth/providers auth_provider.dart

# Dashboard: models=dashboard_summary_model.dart, providers=dashboard_provider.dart
Rename-Item lib/features/dashboard/models dashboard_summary_model.dart
Rename-Item lib/features/dashboard/providers dashboard_provider.dart

# Operasional: models=operasional_model.dart
Rename-Item lib/features/operasional/models operasional_model.dart

# Transaksi DO: models=transaksi_do_model.dart, providers=transaksi_do_provider.dart
Rename-Item lib/features/transaksi_do/models transaksi_do_model.dart
Rename-Item lib/features/transaksi_do/providers transaksi_do_provider.dart

# Penjual: models=penjual_model.dart
Rename-Item lib/features/penjual/models penjual_model.dart

# Supir: models=supir_model.dart
Rename-Item lib/features/supir/models supir_model.dart

# Pekerja: models=pekerja_model.dart
Rename-Item lib/features/pekerja/models pekerja_model.dart

# Kendaraan: models=kendaraan_model.dart
Rename-Item lib/features/kendaraan/models kendaraan_model.dart

# Jurnal Keuangan: models=jurnal_keuangan_model.dart
Rename-Item lib/features/jurnal_keuangan/models jurnal_keuangan_model.dart

# Tambah Saldo: models=tambah_saldo_model.dart, providers=tambah_saldo_provider.dart
Rename-Item lib/features/tambah_saldo/models tambah_saldo_model.dart
Rename-Item lib/features/tambah_saldo/providers tambah_saldo_provider.dart

# Shared
Rename-Item lib/shared/models mutasi_hutang_model.dart
Rename-Item lib/shared/providers resource_provider.dart

# Now move them into directories
foreach ($f in $features) {
    mkdir "lib/features/$f/models" -Force
    mkdir "lib/features/$f/providers" -Force
    mkdir "lib/features/$f/screens" -Force
    mkdir "lib/features/$f/widgets" -Force
    
    Get-ChildItem "lib/features/$f/*.dart" | Move-Item -Destination "lib/features/$f/models/" -ErrorAction SilentlyContinue
    # Wait, some are providers. 
    Get-ChildItem "lib/features/$f/*_provider.dart" | Move-Item -Destination "lib/features/$f/providers/" -ErrorAction SilentlyContinue
}

mkdir lib/shared/models -Force
mkdir lib/shared/providers -Force
Move-Item lib/shared/mutasi_hutang_model.dart lib/shared/models/
Move-Item lib/shared/resource_provider.dart lib/shared/providers/
