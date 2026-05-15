import os
import re

lib_dir = 'lib'
package_name = 'sawitappmobile'

# Mapping of file names to their new locations (relative to lib/)
mapping = {
    # Models
    'user_model.dart': 'features/auth/models/user_model.dart',
    'dashboard_summary_model.dart': 'features/dashboard/models/dashboard_summary_model.dart',
    'operasional_model.dart': 'features/operasional/models/operasional_model.dart',
    'transaksi_do_model.dart': 'features/transaksi_do/models/transaksi_do_model.dart',
    'penjual_model.dart': 'features/penjual/models/penjual_model.dart',
    'supir_model.dart': 'features/supir/models/supir_model.dart',
    'pekerja_model.dart': 'features/pekerja/models/pekerja_model.dart',
    'kendaraan_model.dart': 'features/kendaraan/models/kendaraan_model.dart',
    'mutasi_hutang_model.dart': 'shared/models/mutasi_hutang_model.dart',
    'jurnal_keuangan_model.dart': 'features/jurnal_keuangan/models/jurnal_keuangan_model.dart',
    'tambah_saldo_model.dart': 'features/tambah_saldo/models/tambah_saldo_model.dart',

    # Providers
    'auth_provider.dart': 'features/auth/providers/auth_provider.dart',
    'dashboard_provider.dart': 'features/dashboard/providers/dashboard_provider.dart',
    'resource_provider.dart': 'shared/providers/resource_provider.dart',
    'tambah_saldo_provider.dart': 'features/tambah_saldo/providers/tambah_saldo_provider.dart',
    'transaksi_do_provider.dart': 'features/transaksi_do/providers/transaksi_do_provider.dart',

    # Repositories
    'resource_repository.dart': 'shared/repositories/resource_repository.dart',
    'auth_repository.dart': 'shared/repositories/auth_repository.dart',
    'dashboard_repository.dart': 'shared/repositories/dashboard_repository.dart',
    'tambah_saldo_repository.dart': 'shared/repositories/tambah_saldo_repository.dart',
    'transaksi_do_repository.dart': 'shared/repositories/transaksi_do_repository.dart',
}

# Add screens and widgets to mapping dynamically if needed, 
# but mostly models/providers are the ones being imported.

def update_imports(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()

    # Find all imports
    imports = re.findall(r"import\s+['\"](.+?)['\"];", content)
    new_content = content

    for imp in imports:
        # Check if it's a relative import we care about
        filename = os.path.basename(imp)
        if filename in mapping:
            new_imp = f"package:{package_name}/{mapping[filename]}"
            new_content = new_content.replace(f"import '{imp}';", f"import '{new_imp}';")
            new_content = new_content.replace(f'import "{imp}";', f'import "{new_imp}";')
        
        # Handle widgets and services and utils which moved to shared/core
        elif 'widgets/' in imp:
            new_imp = f"package:{package_name}/shared/widgets/{filename}"
            new_content = new_content.replace(f"import '{imp}';", f"import '{new_imp}';")
        elif 'services/' in imp:
            new_imp = f"package:{package_name}/core/services/{filename}"
            new_content = new_content.replace(f"import '{imp}';", f"import '{new_imp}';")
        elif 'utils/' in imp:
            new_imp = f"package:{package_name}/core/utils/{filename}"
            new_content = new_content.replace(f"import '{imp}';", f"import '{new_imp}';")
        elif 'screens/' in imp:
            # Screens are harder because they are in features/F/screens
            # But most imports are relative and now broken.
            # We'll try to guess based on folder name if it was screens/F/
            parts = imp.split('/')
            if 'screens' in parts:
                idx = parts.index('screens')
                if idx + 1 < len(parts):
                    f_name = parts[idx+1]
                    s_name = parts[-1]
                    if s_name.endswith('.dart'):
                        new_imp = f"package:{package_name}/features/{f_name}/screens/{s_name}"
                        # Special cases
                        if f_name == 'common': new_imp = f"package:{package_name}/shared/screens/{s_name}"
                        if f_name == 'finance': new_imp = f"package:{package_name}/features/operasional/screens/{s_name}"
                        new_content = new_content.replace(f"import '{imp}';", f"import '{new_imp}';")

    if new_content != content:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(new_content)
        return True
    return False

# Walk through lib directory
count = 0
for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith('.dart'):
            if update_imports(os.path.join(root, file)):
                count += 1

print(f"Updated {count} files.")
