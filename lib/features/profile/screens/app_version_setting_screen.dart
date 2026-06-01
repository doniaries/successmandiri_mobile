import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';

class AppVersionSettingScreen extends StatefulWidget {
  const AppVersionSettingScreen({super.key});

  @override
  State<AppVersionSettingScreen> createState() =>
      _AppVersionSettingScreenState();
}

class _AppVersionSettingScreenState extends State<AppVersionSettingScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _versionController;
  late TextEditingController _creatorController;
  late TextEditingController _changelogController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final provider = context.read<ResourceProvider>();
    _versionController = TextEditingController(text: provider.appVersion);
    _creatorController = TextEditingController(text: provider.appCreator);
    
    // Set default numbering if changelog is empty or placeholder
    String initialChangelog = provider.changelog;
    if (initialChangelog.isEmpty || initialChangelog == 'Riwayat perubahan aplikasi.') {
      initialChangelog = '1. ';
    }
    _changelogController = TextEditingController(text: initialChangelog);
  }

  @override
  void dispose() {
    _versionController.dispose();
    _creatorController.dispose();
    _changelogController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    final provider = context.read<ResourceProvider>();

    final success = await provider.updateAppSettings(
      _versionController.text.trim(),
      _creatorController.text.trim(),
      changelog: _changelogController.text.trim(),
    );

    if (mounted) {
      setState(() {
        _isSaving = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pengaturan berhasil diperbarui'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memperbarui pengaturan'),
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
        title: const Text(
          'Pengaturan Aplikasi',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: const Color(0xFF01579B),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Kelola Informasi Aplikasi',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Informasi ini akan muncul di layar profil seluruh pengguna.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 32),

              _buildTextField(
                label: 'Versi Aplikasi (Otomatis)',
                controller: _versionController,
                hint: 'Akan terisi otomatis',
                icon: Icons.update_rounded,
                validator: (v) =>
                    v!.isEmpty ? 'Versi tidak boleh kosong' : null,
                enabled: false,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: 'Nama Pembuat / Pengelola',
                controller: _creatorController,
                hint: 'Contoh: IT Success Mandiri',
                icon: Icons.person_outline_rounded,
                validator: (v) =>
                    v!.isEmpty ? 'Nama pembuat tidak boleh kosong' : null,
                enabled: !_isSaving,
              ),
              const SizedBox(height: 20),

              _buildTextField(
                label: 'Riwayat Update / Changelog',
                controller: _changelogController,
                hint: '',
                icon: Icons.history_rounded,
                maxLines: 4,
                validator: (v) =>
                    v!.isEmpty ? 'Changelog tidak boleh kosong' : null,
                enabled: !_isSaving,
              ),

              const SizedBox(height: 48),

              AppPrimaryButton(
                text: 'Simpan Perubahan',
                isLoading: _isSaving,
                onPressed: _isSaving ? null : _saveSettings,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    String? Function(String?)? validator,
    bool enabled = true,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF01579B),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          enabled: enabled,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: Icon(icon, color: const Color(0xFF01579B)),
            filled: true,
            fillColor: enabled ? Colors.white : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFF01579B), width: 2),
            ),
            disabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.grey[200]!),
            ),
          ),
        ),
      ],
    );
  }
}
