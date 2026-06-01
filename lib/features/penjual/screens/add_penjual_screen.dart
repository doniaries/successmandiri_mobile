import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';

class AddPenjualScreen extends StatefulWidget {
  final String? initialName;

  const AddPenjualScreen({super.key, this.initialName});

  @override
  State<AddPenjualScreen> createState() => _AddPenjualScreenState();
}

class _AddPenjualScreenState extends State<AddPenjualScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _teleponController = TextEditingController();
  final _alamatController = TextEditingController();
  final _keteranganController = TextEditingController();
  final _hutangController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialName != null) {
      _namaController.text = widget.initialName!;
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    _keteranganController.dispose();
    _hutangController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ResourceProvider>();

      // Client-side uniqueness validation
      final isDuplicate = provider.penjuals.any(
        (p) =>
            p.nama.toLowerCase().trim() ==
            _namaController.text.toLowerCase().trim(),
      );

      if (isDuplicate) {
        if (mounted) {
          ErrorDialog.show(
            context,
            title: 'Nama Sudah Ada',
            message:
                'Penjual dengan nama "${_namaController.text}" sudah terdaftar dalam sistem. Silakan gunakan nama lain atau periksa daftar penjual.',
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      final double hutangValue = CurrencyInputFormatter.parse(_hutangController.text);

      final penjual = await provider.addPenjual({
        'nama': _namaController.text,
        'telepon': _teleponController.text,
        'alamat': _alamatController.text,
        'keterangan': _keteranganController.text,
        'hutang': hutangValue > 0 ? hutangValue : 0,
      });

      if (mounted) {
        if (penjual != null) {
          final bool isOffline = provider.errorMessage == 'offline';
          SuccessDialog.show(
            context,
            title: 'Penjual Ditambahkan!',
            message: isOffline
                ? 'Sinyal tidak stabil. Data penjual ${_namaController.text} telah disimpan di antrean perangkat dan akan otomatis dikirim saat ada sinyal.'
                : 'Data penjual ${_namaController.text} telah berhasil didaftarkan ke sistem.',
            isOffline: isOffline,
            onConfirm: () {
              Navigator.of(context).pop(penjual);
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menambahkan penjual')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tambah Penjual',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF27AE60),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AppLoadingOverlay(
        isLoading: _isLoading,
        message: 'Menyimpan data penjual...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTextField(
                  controller: _namaController,
                  label: 'Nama Penjual',
                  icon: Icons.person_outline,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _teleponController,
                  label: 'Nomor Telepon',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _alamatController,
                  label: 'Alamat',
                  icon: Icons.location_on_outlined,
                  maxLines: 3,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _hutangController,
                  label: 'Hutang Awal (Wajib diisi, ketik 0 jika tidak ada)',
                  icon: Icons.account_balance_wallet_outlined,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  prefixText: 'Rp ',
                  helperText: '⚠️ Wajib diisi jika ada hutang awal. Jika tidak ada, isi 0.',
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Hutang awal wajib diisi (ketik 0 jika tidak ada)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _keteranganController,
                  label: 'Keterangan',
                  icon: Icons.note_outlined,
                  maxLines: 2,
                ),
                const SizedBox(height: 40),
                AppPrimaryButton(
                  text: 'SIMPAN PENJUAL',
                  onPressed: _submit,
                  isLoading: _isLoading,
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
    String? helperText,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText,
        helperMaxLines: 2,
        helperStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
        prefixIcon: Icon(icon, color: const Color(0xFF27AE60)),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF27AE60), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}
