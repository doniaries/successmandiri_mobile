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
  final _namaBankController = TextEditingController();
  final _nomorRekeningController = TextEditingController();
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
    _namaBankController.dispose();
    _nomorRekeningController.dispose();
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

      String phone = _teleponController.text.replaceAll(RegExp(r'\D'), '');
      if (phone.startsWith('0')) {
          phone = '62${phone.substring(1)}';
      } else if (phone.startsWith('8')) {
          phone = '62$phone';
      }

      final penjual = await provider.addPenjual({
        'nama': _namaController.text,
        'telepon': phone,
        'nama_bank': _namaBankController.text,
        'nomor_rekening': _nomorRekeningController.text,
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
                  label: 'Nama *',
                  icon: Icons.person_outline,
                  textInputAction: TextInputAction.next,
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _teleponController,
                  label: 'Nomor Telepon *',
                  placeholder: '08xxx',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(13),
                  ],
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
                Autocomplete<String>(
                  optionsBuilder: (TextEditingValue textEditingValue) {
                    const defaultBanks = ['BCA', 'BRI', 'Mandiri', 'BNI', 'BSI', 'CIMB Niaga', 'BJB'];
                    final provider = context.read<ResourceProvider>();
                    final existingBanks = provider.penjuals
                        .map((p) => p.namaBank)
                        .where((b) => b != null && b.isNotEmpty)
                        .map((b) => b!)
                        .toSet();
                    final allBanks = {...defaultBanks, ...existingBanks}.toList();
                    
                    if (textEditingValue.text.isEmpty) {
                      return allBanks;
                    }
                    return allBanks.where((bank) => 
                        bank.toLowerCase().contains(textEditingValue.text.toLowerCase()));
                  },
                  onSelected: (String selection) {
                    _namaBankController.text = selection;
                  },
                  fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                    textEditingController.addListener(() {
                      _namaBankController.text = textEditingController.text;
                    });
                    return _buildTextField(
                      controller: textEditingController,
                      focusNode: focusNode,
                      label: 'Nama Bank (Opsional)',
                      icon: Icons.account_balance_outlined,
                      placeholder: 'Pilih atau ketik nama bank baru...',
                    );
                  },
                ),
                const SizedBox(height: 20),
                  _buildTextField(
                    controller: _nomorRekeningController,
                    label: 'Nomor Rekening (Opsional)',
                    icon: Icons.credit_card_outlined,
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 20),
                  _buildTextField(
                    controller: _alamatController,
                    label: 'Alamat',
                    icon: Icons.location_on_outlined,
                    textInputAction: TextInputAction.next,
                    maxLines: 3,
                  ),
                const SizedBox(height: 20),
                  _buildTextField(
                    controller: _hutangController,
                    label: 'Hutang Awal (Wajib diisi, ketik 0 jika tidak ada)',
                    icon: Icons.account_balance_wallet_outlined,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
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
                    textInputAction: TextInputAction.done,
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
    String? placeholder,
    FocusNode? focusNode,
    TextInputAction? textInputAction,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: placeholder,
        helperText: helperText,
        helperMaxLines: 2,
        errorMaxLines: 3,
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
