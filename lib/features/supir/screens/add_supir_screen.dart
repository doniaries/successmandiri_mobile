import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';

class AddSupirScreen extends StatefulWidget {
  const AddSupirScreen({super.key});

  @override
  State<AddSupirScreen> createState() => _AddSupirScreenState();
}

class _AddSupirScreenState extends State<AddSupirScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _hutangController = TextEditingController();
  final _keteranganController = TextEditingController();

  @override
  void dispose() {
    _namaController.dispose();
    _hutangController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ResourceProvider>();

    // Client-side uniqueness validation
    final isDuplicate = provider.supirs.any(
      (s) =>
          s.nama.toLowerCase().trim() ==
          _namaController.text.toLowerCase().trim(),
    );

    if (isDuplicate) {
      if (mounted) {
        ErrorDialog.show(
          context,
          title: 'Nama Sudah Ada',
          message:
              'Supir dengan nama "${_namaController.text}" sudah terdaftar dalam sistem. Silakan gunakan nama lain atau periksa daftar supir.',
        );
      }
      return;
    }

    final double hutangValue = CurrencyInputFormatter.parse(_hutangController.text);

    final result = await provider.addSupir({
      'nama': _namaController.text,
      'keterangan': _keteranganController.text,
      'hutang': hutangValue > 0 ? hutangValue : 0,
      'status': 'Aktif', // Default status
    });

    if (mounted) {
      if (result != null) {
        final bool isOffline = provider.errorMessage == 'offline';
        SuccessDialog.show(
          context,
          title: 'Supir Ditambahkan!',
          message: isOffline
              ? 'Sinyal tidak stabil. Data supir ${_namaController.text} telah disimpan di antrean perangkat dan akan otomatis dikirim saat ada sinyal.'
              : 'Data supir ${_namaController.text} telah berhasil didaftarkan ke sistem.',
          isOffline: isOffline,
          onConfirm: () {
            Navigator.of(context).pop(result);
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menambahkan supir'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tambah Supir',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AppLoadingOverlay(
        isLoading: provider.isLoading,
        message: 'Menyimpan data supir...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _namaController,
                  label: 'Nama Supir',
                  icon: Icons.person_rounded,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _hutangController,
                  label: 'Hutang Awal (Opsional jika migrasi data lama)',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  prefixText: 'Rp ',
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
                  text: 'SIMPAN SUPIR',
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
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
    String? prefixText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF01579B), size: 20),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
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
