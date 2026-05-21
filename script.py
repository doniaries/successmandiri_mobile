import re

file_path = 'lib/shared/repositories/resource_repository.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Remove SharedPreferences caching on page 1
content = re.sub(
    r'if\s*\(\s*page\s*==\s*1\s*\)\s*\{\s*final\s*prefs\s*=\s*await\s*SharedPreferences\.getInstance\(\);\s*await\s*prefs\.setString\([^\)]+\);\s*\}',
    '',
    content
)

# 2. Fix the catch blocks for get*Paginated
entities = [
    ('Penjual', 'ApiConstants.penjual', "'penjual'"),
    ('Supir', 'ApiConstants.supir', "'supir'"),
    ('Pekerja', 'ApiConstants.pekerja', "'pekerja'"),
    ('Kendaraan', 'ApiConstants.kendaraan', "'kendaraan'"),
    ('Operasional', 'ApiConstants.operasional', "'operasional'"),
]

for name, api, table in entities:
    pattern = r'catch\s*\(\s*e\s*\)\s*\{\s*try\s*\{\s*final\s*prefs\s*=\s*await\s*SharedPreferences\.getInstance\(\);.*?rethrow;\s*\}'
    replacement = f'''catch (e) {{
      try {{
        final pendingData = await syncService.getMergedOfflineData(
          {table},
          {api},
        );
        return {{
          'data': pendingData,
          'current_page': 1,
          'last_page': 1,
          'total': pendingData.length,
        }};
      }} catch (_) {{}}
      rethrow;
    }}'''
    content = re.sub(pattern, replacement, content, flags=re.DOTALL)

    # 3. Add cacheData to getXYZs()
    # A simpler replace just for cacheData
    cache_pattern = f'(Future<List<{name}>> get{name}s(?:[^\\}}]+?)final List<dynamic> data = _extractListData\\(response\\.data\\);\\s*)(return data\\.map\\(\\(e\\) => {name}\\.fromJson\\(e\\)\\)\\.toList\\(\\);)'
    
    # only replace if not already replaced
    if 'syncService.cacheData' not in re.search(cache_pattern, content).group(1) if re.search(cache_pattern, content) else True:
        content = re.sub(cache_pattern, f'\\1syncService.cacheData({table}, data);\\n      \\2', content)

# 4. Handle getJurnalPaginated separately because it has cacheKey logic
# Remove cacheKey setString
content = re.sub(
    r'if\s*\(\s*page\s*==\s*1\s*\)\s*\{\s*final\s*cacheKey[^}]+await\s*prefs\.setString\(cacheKey,\s*jsonEncode\(response\.data\)\);\s*\}',
    '',
    content
)

jurnal_catch = r'catch\s*\(\s*e\s*\)\s*\{\s*try\s*\{\s*final\s*cacheKey[^}]+final\s*prefs\s*=\s*await\s*SharedPreferences\.getInstance\(\);.*?rethrow;\s*\}'
jurnal_replacement = '''catch (e) {
      try {
        final pendingData = await syncService.getMergedOfflineData(
          'jurnal_keuangan',
          ApiConstants.jurnalKeuangan,
        );
        final filteredPending = pendingData.where((item) {
          if (jenisTransaksi != null && item['jenis_transaksi'] != jenisTransaksi) return false;
          return true;
        }).toList();
        return {
          'data': filteredPending,
          'current_page': 1,
          'last_page': 1,
          'total': filteredPending.length,
        };
      } catch (_) {}
      rethrow;
    }'''
content = re.sub(jurnal_catch, jurnal_replacement, content, flags=re.DOTALL)

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(content)
print('Done!')
