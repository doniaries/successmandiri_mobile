import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';

class AddKendaraanScreen extends StatefulWidget {
  const AddKendaraanScreen({super.key});

  @override
  State<AddKendaraanScreen> createState() => _AddKendaraanScreenState();
}

class _AddKendaraanScreenState extends State<AddKendaraanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nopolController = TextEditingController();
  final _jenisController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _nopolController.dispose();
    _jenisController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final provider = context.read<ResourceProvider>();
      final success = await provider.addKendaraan({
        'no_polisi': _nopolController.text.toUpperCase(),
        'jenis_kendaraan': _jenisController.text,
      });

      if (mounted) {
        if (success) {
          SuccessDialog.show(
            context,
            title: 'Kendaraan Ditambahkan!',
            message: 'Data kendaraan ${_nopolController.text} telah berhasil didaftarkan.',
            onConfirm: () {
              Navigator.pop(context); // Tutup Dialog
              Navigator.pop(context, success); // Kembali dengan status berhasil
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menambahkan kendaraan')),
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
        title: const Text('Tambah Kendaraan', style: TextStyle(fontWeight: FontWeight.bold)),
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
                controller: _nopolController,
                label: 'Nomor Polisi (Nopol)',
                icon: Icons.numbers,
                hint: 'B 1234 ABC',
                validator: (val) => val == null || val.isEmpty ? 'Nopol wajib diisi' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _jenisController,
                label: 'Jenis Kendaraan',
                icon: Icons.local_shipping,
                hint: 'Fuso / Colt Diesel / L300',
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
                  : const Text('SIMPAN KENDARAAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
    String? hint,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      textCapitalization: TextCapitalization.characters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
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

