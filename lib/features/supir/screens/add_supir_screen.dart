import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';

class AddSupirScreen extends StatefulWidget {
  const AddSupirScreen({super.key});

  @override
  State<AddSupirScreen> createState() => _AddSupirScreenState();
}

class _AddSupirScreenState extends State<AddSupirScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _keteranganController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _namaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final provider = context.read<ResourceProvider>();
      final supir = await provider.addSupir({
        'nama': _namaController.text,
        'keterangan': _keteranganController.text,
        'status': 'Aktif', // Default status
      });

      if (mounted) {
        if (supir != null) {
          final bool isOffline = provider.errorMessage == 'offline';
          SuccessDialog.show(
            context,
            title: 'Supir Ditambahkan!',
            message: isOffline 
                ? 'Sinyal tidak stabil. Data supir ${_namaController.text} telah disimpan di antrean perangkat dan akan otomatis dikirim saat ada sinyal.'
                : 'Data supir ${_namaController.text} telah berhasil didaftarkan ke sistem.',
            isOffline: isOffline,
            onConfirm: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menambahkan supir')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Supir', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildTextField(
                controller: _namaController,
                label: 'Nama Supir',
                icon: Icons.person_outline,
                validator: (val) => val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _keteranganController,
                label: 'Keterangan / Catatan',
                icon: Icons.note_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01579B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const AppLoadingIndicator(size: 20)
                  : const Text('SIMPAN SUPIR', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF01579B)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF01579B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

