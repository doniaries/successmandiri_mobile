import 'package:flutter/material.dart';

class RoleMenuSettingsScreen extends StatefulWidget {
  final String roleName;
  final String roleSlug;

  const RoleMenuSettingsScreen({
    super.key,
    required this.roleName,
    required this.roleSlug,
  });

  @override
  State<RoleMenuSettingsScreen> createState() => _RoleMenuSettingsScreenState();
}

class _RoleMenuSettingsScreenState extends State<RoleMenuSettingsScreen> {
  final Map<String, bool> _menuItems = {
    'Transaksi DO': true,
    'Pengajuan Dana': true,
    'Laporan Penjual': true,
    'Data Supir': true,

    'Operasional': true,
    'Laporan Keuangan': true,
    'Manajemen User': false,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Menu: ${widget.roleName}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          TextButton(
            onPressed: () {
              // Simpan perubahan
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Pengaturan menu berhasil disimpan')),
              );
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF01579B))),
          ),
        ],
      ),
      body: ListView(
        children: _menuItems.keys.map((key) {
          return SwitchListTile(
            title: Text(key),
            value: _menuItems[key]!,
            onChanged: (val) {
              setState(() {
                _menuItems[key] = val;
              });
            },
            activeThumbColor: Colors.white,
            activeTrackColor: const Color(0xFF01579B),
          );
        }).toList(),
      ),
    );
  }
}

