import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/penjual/models/penjual_model.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';

class EditPenjualScreen extends StatefulWidget {
  final Penjual penjual;
  const EditPenjualScreen({super.key, required this.penjual});

  @override
  State<EditPenjualScreen> createState() => _EditPenjualScreenState();
}

class _EditPenjualScreenState extends State<EditPenjualScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _teleponController;
  late TextEditingController _namaBankController;
  late TextEditingController _nomorRekeningController;
  late TextEditingController _alamatController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.penjual.nama);
    _teleponController = TextEditingController(text: widget.penjual.telepon);
    _namaBankController = TextEditingController(text: widget.penjual.namaBank);
    _nomorRekeningController = TextEditingController(text: widget.penjual.nomorRekening);
    _alamatController = TextEditingController(text: widget.penjual.alamat);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _namaBankController.dispose();
    _nomorRekeningController.dispose();
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
      final success = await provider.updatePenjual(widget.penjual.id, {
        'nama': _namaController.text,
        'telepon': phone,
        'nama_bank': _namaBankController.text,
        'nomor_rekening': _nomorRekeningController.text,
        'alamat': _alamatController.text,
      });

      if (mounted) {
        if (success) {
          SuccessDialog.show(
            context,
            title: 'Data Diperbarui!',
            message: 'Informasi penjual ${_namaController.text} telah berhasil diperbarui.',
            onConfirm: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Return to detail
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui data penjual')),
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
        title: const Text('Edit Penjual', style: TextStyle(fontWeight: FontWeight.bold)),
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
              Autocomplete<String>(
                initialValue: TextEditingValue(text: _namaBankController.text),
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
                    label: 'Nama Bank',
                    icon: Icons.account_balance_outlined,
                    placeholder: 'Pilih atau ketik nama bank baru...',
                    hintText: 'Pilih atau ketik nama bank baru...',
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
                textInputAction: TextInputAction.done,
                maxLines: 3,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27AE60),
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
    String? placeholder,
    String? hintText,
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
        hintText: hintText ?? placeholder,
        prefixIcon: Icon(icon, color: const Color(0xFF27AE60)),
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

