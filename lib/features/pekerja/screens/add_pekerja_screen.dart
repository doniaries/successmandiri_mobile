import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';

class AddPekerjaScreen extends StatefulWidget {
  final String? initialName;

  const AddPekerjaScreen({super.key, this.initialName});

  @override
  State<AddPekerjaScreen> createState() => _AddPekerjaScreenState();
}

class _AddPekerjaScreenState extends State<AddPekerjaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _namaController = TextEditingController();
  final _hutangController = TextEditingController();
  final _keteranganController = TextEditingController();
  final _posisiController = TextEditingController();
  final _teleponController = TextEditingController();

  static const List<String> _posisiOptions = [
    'Staff',
    'Kasir',
    'Supir Lansir',
    'Anggota Lansir',
  ];

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
    _hutangController.dispose();
    _keteranganController.dispose();
    _posisiController.dispose();
    _teleponController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ResourceProvider>();

    // Client-side uniqueness validation
    final isDuplicate = provider.pekerjas.any(
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
              'Pekerja dengan nama "${_namaController.text}" sudah terdaftar dalam sistem. Silakan gunakan nama lain atau periksa daftar pekerja.',
        );
      }
      return;
    }

    final double hutangValue = CurrencyInputFormatter.parse(_hutangController.text);

    final result = await provider.addPekerja({
      'nama': _namaController.text,
      'keterangan': _keteranganController.text,
      'telepon': _teleponController.text,
      'hutang': hutangValue > 0 ? hutangValue : 0,
      'posisi': _posisiController.text.isNotEmpty ? _posisiController.text : 'Staff',
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
              Navigator.of(context).pop(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal menambahkan Pekerja'),
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
          'Tambah Pekerja',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF8E44AD),
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
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _teleponController,
                  label: 'Nomor Telepon (WhatsApp) *',
                  icon: FontAwesomeIcons.whatsapp,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (val) =>
                      val == null || val.isEmpty ? 'Nomor telepon wajib diisi' : null,
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
                _buildAutocompleteField(
                  controller: _posisiController,
                  label: 'Posisi / Jabatan',
                  icon: Icons.work_outline,
                  helperText: 'Contoh: Supir Lansir, Anggota, Kasir',
                  options: _posisiOptions,
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Posisi wajib diisi';
                    }
                    return null;
                  },
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
    required dynamic icon,
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
        prefixIcon: icon.runtimeType.toString().contains('FaIcon') 
            ? Container(
                width: 48,
                alignment: Alignment.center,
                child: FaIcon(icon, color: const Color(0xFF8E44AD), size: 20),
              )
            : Icon(icon, color: const Color(0xFF8E44AD), size: 20),
        prefixText: prefixText,
        prefixStyle: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8E44AD), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> options,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return options;
        }
        return options.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (BuildContext context, TextEditingController textEditingController, FocusNode focusNode, VoidCallback onFieldSubmitted) {
        return TextFormField(
          controller: textEditingController,
          focusNode: focusNode,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            prefixIcon: Icon(icon, color: const Color(0xFF8E44AD), size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8E44AD), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );
      },
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 48,
              height: 200.0,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
