import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';

class CompanySettingsScreen extends StatefulWidget {
  const CompanySettingsScreen({super.key});

  @override
  State<CompanySettingsScreen> createState() => _CompanySettingsScreenState();
}

class _CompanySettingsScreenState extends State<CompanySettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _alamatController = TextEditingController();
  
  int? _selectedKasirId;
  List<dynamic> _users = [];
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final authProvider = context.read<AuthProvider>();
    
    // Set initial values
    if (authProvider.user != null) {
      _nameController.text = authProvider.user!.perusahaanName ?? '';
      
      // Attempt to find the user's company and kasir_id from perusahaans list if available
      final currentPerusahaan = authProvider.user!.perusahaans.firstWhere(
        (p) => p.id == authProvider.user!.perusahaanId,
        orElse: () => UserCompany(id: 0, name: ''),
      );
      // Not storing alamat in user model, so it's empty by default unless we fetch the exact Perusahaan.
      // But we can just leave it empty if not available in current context.
    }

    try {
      final usersList = await authProvider.getUsers();
      setState(() {
        _users = usersList;
        _isLoading = false;
        
        // Find matching kasir if possible
        if (authProvider.user?.perusahaanKasir != null) {
          try {
            final kasir = _users.firstWhere((u) => 
                u['name'] == authProvider.user!.perusahaanKasir || 
                u['nama_kasir'] == authProvider.user!.perusahaanKasir);
            _selectedKasirId = kasir['id'];
          } catch (e) {
            // Not found
          }
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memuat daftar kasir: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isSaving = true;
    });

    final authProvider = context.read<AuthProvider>();
    
    final success = await authProvider.updateCompanyDetails(
      _nameController.text.isNotEmpty ? _nameController.text : null,
      _alamatController.text.isNotEmpty ? _alamatController.text : null,
      _selectedKasirId,
    );

    setState(() {
      _isSaving = false;
    });

    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan perusahaan berhasil disimpan'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(authProvider.errorMessage ?? 'Terjadi kesalahan'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Pengaturan Perusahaan', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informasi Unit Bisnis',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF01579B),
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Nama Perusahaan',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.business_rounded, color: Color(0xFF01579B)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Nama perusahaan tidak boleh kosong';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 15),
                  TextFormField(
                    controller: _alamatController,
                    decoration: InputDecoration(
                      labelText: 'Alamat (Opsional)',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.location_on_outlined, color: Color(0xFF01579B)),
                    ),
                    maxLines: 2,
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    'Pengaturan Kasir',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF01579B),
                    ),
                  ),
                  const SizedBox(height: 15),
                  DropdownButtonFormField<int>(
                    value: _selectedKasirId,
                    decoration: InputDecoration(
                      labelText: 'Pilih Kasir',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF01579B)),
                    ),
                    items: _users.map((u) {
                      return DropdownMenuItem<int>(
                        value: u['id'],
                        child: Text('${u['name']} (${u['email']})'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedKasirId = value;
                      });
                    },
                    hint: const Text('Pilih akun kasir untuk unit ini'),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : _saveSettings,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF01579B),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text('Simpan Perubahan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
