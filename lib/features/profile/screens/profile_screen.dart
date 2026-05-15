import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/custom_loading_logo.dart';
import '../auth/login_screen.dart';
import './role_menu_settings_screen.dart';
import './app_version_setting_screen.dart';
import 'package:sawitappmobile/shared/widgets/change_password_dialog.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage(BuildContext context, AuthProvider authProvider) async {
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (image != null) {
      final success = await authProvider.updateProfilePhoto(File(image.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Foto profil berhasil diperbarui' : 'Gagal memperbarui foto profil'),
            backgroundColor: success ? Colors.green : const Color(0xFF0D47A1),
          ),
        );
      }
    }
  }

  Future<void> _pickCompanyLogo(BuildContext context, AuthProvider authProvider) async {
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () async {
                final file = await _picker.pickImage(source: ImageSource.camera, imageQuality: 70);
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
          ],
        ),
      ),
    );

    if (image != null) {
      final success = await authProvider.updateCompanyLogo(File(image.path));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Logo unit bisnis berhasil diperbarui' : 'Gagal memperbarui logo unit bisnis'),
            backgroundColor: success ? Colors.green : const Color(0xFF0D47A1),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Profil Saya', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Color(0xFF01579B)),
            onPressed: () => _handleLogout(context, authProvider),
          ),
        ],
      ),
      body: authProvider.isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const SizedBox(height: 10),
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 60,
                        backgroundColor: const Color(0xFF01579B),
                        backgroundImage: user?.fullPhotoUrl != null 
                          ? NetworkImage(user!.fullPhotoUrl!) 
                          : null,
                        child: user?.fullPhotoUrl == null
                          ? Text(
                              (user != null && user.name.isNotEmpty)
                                  ? user.name.substring(0, 1).toUpperCase()
                                  : 'U',
                              style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
                            )
                          : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () => _pickImage(context, authProvider),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF01579B),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  user?.name ?? 'User Name',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
                Text(
                  user?.email ?? 'email@example.com',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 30),
                GestureDetector(
                  onTap: (user?.isAdmin == true || user?.isSuperAdmin == true)
                      ? () => _pickCompanyLogo(context, authProvider)
                      : null,
                  child: _buildInfoTile(
                    (user?.perusahaanLogoUrl != null && user!.perusahaanLogoUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.network(
                              user.perusahaanLogoUrl!,
                              width: 24,
                              height: 24,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.business_rounded, color: Color(0xFF01579B)),
                            ),
                          )
                        : const Icon(Icons.business_rounded, color: Color(0xFF01579B)),
                    'Perusahaan',
                    user?.perusahaanName ?? '-',
                    trailing: (user?.isAdmin == true || user?.isSuperAdmin == true)
                        ? const Icon(Icons.camera_alt_outlined, size: 20, color: Color(0xFF01579B))
                        : null,
                  ),
                ),
                _buildInfoTile(const Icon(Icons.badge_rounded, color: Color(0xFF01579B)), 'Role', _formatRole(user?.role)),
                
                const SizedBox(height: 10),
                _buildInfoTile(
                  const Icon(Icons.lock_outline_rounded, color: Color(0xFF01579B)), 
                  'Keamanan', 
                  'Ganti Password',
                  onTap: () => _showChangePasswordDialog(context),
                  trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFF01579B)),
                ),
                
                if (user?.isSuperAdmin == true) ...[
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Admin Panel',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildRoleMenuTile(
                    'Pengaturan Aplikasi', 
                    'Edit versi aplikasi dan nama pengembang',
                    onTap: () => Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => const AppVersionSettingScreen())
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Manajemen Menu per Role',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 15),
                  _buildRoleMenuTile(
                    'Admin', 
                    'Semua Fitur, Kelola User, Transaksi, Laporan',
                    onTap: () => _openRoleSettings(context, 'admin'),
                  ),
                  _buildRoleMenuTile(
                    'Kasir', 
                    'Transaksi DO, Penjual, Supir, Jurnal (Internal)',
                    onTap: () => _openRoleSettings(context, 'kasir'),
                  ),

                ],
                
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _handleLogout(context, authProvider),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE3F2FD),
                      foregroundColor: const Color(0xFF01579B),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text('Log Out', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(height: 30),
                
                // App Info Section
                Consumer<ResourceProvider>(
                  builder: (context, resProvider, _) {
                    return Column(
                      children: [
                        Text(
                          'Versi ${resProvider.appVersion}',
                          style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Dibuat oleh ${resProvider.appCreator}',
                          style: TextStyle(color: Colors.grey[400], fontSize: 10),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
    );
  }

  void _openRoleSettings(BuildContext context, String roleSlug) {
    String roleName = roleSlug == 'admin' ? 'Administrator' : 'Kasir';

                     
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RoleMenuSettingsScreen(
          roleName: roleName,
          roleSlug: roleSlug,
        ),
      ),
    );
  }

  String _formatRole(String? role) {
    if (role == null) return '-';
    switch (role.toLowerCase()) {
      case 'super_admin': return 'Super Admin';
      case 'admin': return 'Administrator';
      case 'kasir': return 'Kasir';
      default: return role.toUpperCase();
    }
  }

  Widget _buildRoleMenuTile(String role, String description, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(color: Color(0xFFE3F2FD), shape: BoxShape.circle),
            child: const Icon(Icons.visibility_rounded, color: Color(0xFF01579B), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(role, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                Text(description, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
        ],
      ),
    ),
  );
}

  Widget _buildInfoTile(Widget icon, String label, String value, {Widget? trailing, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ChangePasswordDialog(),
    );
  }

  Future<void> _handleLogout(BuildContext context, AuthProvider authProvider) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Batal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ya, Keluar', style: TextStyle(color: Color(0xFF01579B))),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const AnimatedPulsingLogo(),
              const SizedBox(height: 20),
              const Text(
                'Mengakhiri sesi...',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  decoration: TextDecoration.none,
                ),
              ),
            ],
          ),
        ),
      );

      await authProvider.logout();
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }
}

