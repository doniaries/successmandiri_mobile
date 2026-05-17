import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/live_date_time_widget.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';

class AddPekerjaScreen extends StatefulWidget {
  const AddPekerjaScreen({super.key});

  @override
  State<AddPekerjaScreen> createState() => _AddPekerjaScreenState();
}

class _AddPekerjaScreenState extends State<AddPekerjaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _keteranganController = TextEditingController();

  @override
  void dispose() {
    _namaController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ResourceProvider>();
    
    // Client-side uniqueness validation
    final isDuplicate = provider.pekerjas.any(
      (p) => p.nama.toLowerCase().trim() == _namaController.text.toLowerCase().trim()
    );

    if (isDuplicate) {
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Nama Sudah Ada',
          message: 'Pekerja dengan nama "${_namaController.text}" sudah terdaftar dalam sistem. Silakan gunakan nama lain atau periksa daftar pekerja.',
        );
      }
      return;
    }

    final result = await provider.addPekerja({
      'nama': _namaController.text,
      'keterangan': _keteranganController.text,
      'posisi': 'Staff', // Default Posisi
    });

    if (mounted) {
      if (result != null) {
        final bool isOffline = provider.errorMessage == 'offline';
        SuccessDialog.show(
          context,
          title: 'Pekerja Ditambahkan!',
          message: isOffline 
              ? 'Sinyal tidak stabil. Data pekerja ${_namaController.text} telah disimpan di antrean perangkat dan akan otomatis dikirim saat ada sinyal.'
              : 'Data pekerja ${_namaController.text} telah berhasil didaftarkan ke sistem.',
          isOffline: isOffline,
          onConfirm: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(provider.errorMessage ?? 'Gagal menambahkan Pekerja')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Pekerja', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AppLoadingOverlay(
        isLoading: provider.isLoading,
        message: 'Menyimpan data pekerja...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _namaController,
                  label: 'Nama Pekerja',
                  icon: Icons.person_rounded,
                  validator: (val) => val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _keteranganController,
                  label: 'Keterangan / Catatan',
                  icon: Icons.note_rounded,
                  maxLines: 3,
                ),
                const SizedBox(height: 40),
                AppPrimaryButton(
                  text: 'SIMPAN PEKERJA',
                  onPressed: _submit,
                  isLoading: provider.isLoading,
                ),
              ],
            ),
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
        prefixIcon: Icon(icon, color: const Color(0xFF01579B), size: 20),
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
