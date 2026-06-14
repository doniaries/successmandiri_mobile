import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/supir/models/supir_model.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';

class EditSupirScreen extends StatefulWidget {
  final Supir supir;
  const EditSupirScreen({super.key, required this.supir});

  @override
  State<EditSupirScreen> createState() => _EditSupirScreenState();
}

class _EditSupirScreenState extends State<EditSupirScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _teleponController;
  late TextEditingController _alamatController;
  String? _status;
  bool _isLoading = false;

  final List<String> _statusOptions = ['AKTIF', 'NONAKTIF', 'CUTI'];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.supir.nama);
    _teleponController = TextEditingController(text: widget.supir.telepon);
    _alamatController = TextEditingController(text: widget.supir.alamat);
    _status = widget.supir.status?.toUpperCase() ?? 'AKTIF';
    if (!_statusOptions.contains(_status)) {
       _status = 'AKTIF';
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      String phone = _teleponController.text.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) {
          phone = '62${phone.substring(1)}';
      } else if (phone.startsWith('8')) {
          phone = '62$phone';
      }

      final provider = context.read<ResourceProvider>();
      final success = await provider.updateSupir(widget.supir.id, {
        'nama': _namaController.text,
        'telepon': phone,
        'alamat': _alamatController.text,
        'status_supir': _status,
      });

      if (mounted) {
        if (success) {
          SuccessDialog.show(
            context,
            title: 'Data Diperbarui!',
            message: 'Informasi supir ${_namaController.text} telah berhasil diperbarui.',
            onConfirm: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to detail
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui data supir')),
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
        title: const Text('Edit Supir', style: TextStyle(fontWeight: FontWeight.bold)),
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
                label: 'Nama *',
                icon: Icons.person_outline,
                textInputAction: TextInputAction.next,
                validator: (val) => val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 20),
                _buildTextField(
                  controller: _teleponController,
                  label: 'Nomor Telepon *',
                  hintText: '08xxx',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) {
                    if (val == null || val.isEmpty) return 'Nomor telepon wajib diisi';
                    final digits = val.replaceAll(RegExp(r'\D'), '');
                    if (!digits.startsWith('08') && !digits.startsWith('628') && !digits.startsWith('8')) {
                      return 'Nomor harus diawali 08, 8, atau 628';
                    }
                    if (digits.length < 10) return 'Minimal 10 digit';
                    if (digits.length > 15) return 'Maksimal 15 digit';
                    return null;
                  },
                ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(
                  labelText: 'Status Supir',
                  prefixIcon: const Icon(Icons.info_outline, color: Color(0xFFE67E22)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  filled: true,
                  fillColor: Colors.grey[50],
                ),
                items: _statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _status = val),
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _alamatController,
                label: 'Alamat',
                icon: Icons.location_on_outlined,
                textInputAction: TextInputAction.done,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE67E22),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
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
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
    String? helperText,
    String? hintText,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        prefixIcon: Icon(icon, color: const Color(0xFFE67E22)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE67E22), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

