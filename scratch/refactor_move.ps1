# 1. Move Models
Move-Item lib/models/user_model.dart lib/features/auth/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/dashboard_summary_model.dart lib/features/dashboard/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/operasional_model.dart lib/features/operasional/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/transaksi_do_model.dart lib/features/transaksi_do/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/penjual_model.dart lib/features/penjual/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/supir_model.dart lib/features/supir/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/pekerja_model.dart lib/features/pekerja/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/kendaraan_model.dart lib/features/kendaraan/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/mutasi_hutang_model.dart lib/shared/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/jurnal_keuangan_model.dart lib/features/jurnal_keuangan/models/ -ErrorAction SilentlyContinue
Move-Item lib/models/tambah_saldo_model.dart lib/features/tambah_saldo/models/ -ErrorAction SilentlyContinue

# 2. Move Providers
Move-Item lib/providers/auth_provider.dart lib/features/auth/providers/ -ErrorAction SilentlyContinue
Move-Item lib/providers/dashboard_provider.dart lib/features/dashboard/providers/ -ErrorAction SilentlyContinue
Move-Item lib/providers/resource_provider.dart lib/shared/providers/ -ErrorAction SilentlyContinue
Move-Item lib/providers/tambah_saldo_provider.dart lib/features/tambah_saldo/providers/ -ErrorAction SilentlyContinue
Move-Item lib/providers/transaksi_do_provider.dart lib/features/transaksi_do/providers/ -ErrorAction SilentlyContinue

# 3. Move Screens
$screenDirs = Get-ChildItem lib/screens -Directory
foreach ($dir in $screenDirs) {
    if (Test-Path "lib/features/$($dir.Name)/screens") {
        Move-Item "lib/screens/$($dir.Name)/*" "lib/features/$($dir.Name)/screens/" -ErrorAction SilentlyContinue
    }
}
Move-Item lib/screens/*.dart lib/shared/screens/ -ErrorAction SilentlyContinue # main_navigation_screen.dart etc to shared? 
# Better move specific ones
Move-Item lib/screens/main_navigation_screen.dart lib/shared/screens/ -ErrorAction SilentlyContinue
Move-Item lib/screens/permission_wizard_screen.dart lib/shared/screens/ -ErrorAction SilentlyContinue

# 4. Move Services
mkdir lib/core/services -Force
Move-Item lib/services/* lib/core/services/ -ErrorAction SilentlyContinue

# 5. Move Widgets
Move-Item lib/widgets/* lib/shared/widgets/ -ErrorAction SilentlyContinue

# 6. Cleanup empty dirs
Remove-Item lib/models -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item lib/providers -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item lib/screens -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item lib/services -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item lib/widgets -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item lib/repositories -Recurse -Force -ErrorAction SilentlyContinue # If empty
