import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:sawitappmobile/features/auth/screens/login_screen.dart';

class PermissionWizardScreen extends StatefulWidget {
  const PermissionWizardScreen({super.key});

  @override
  State<PermissionWizardScreen> createState() => _PermissionWizardScreenState();
}

class _PermissionWizardScreenState extends State<PermissionWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<PermissionItem> _permissions = [
    PermissionItem(
      icon: Icons.notifications_active_outlined,
      title: 'Notifikasi',
      description: 'Dapatkan informasi terbaru mengenai transaksi dan pengajuan dana Anda secara real-time.',
      permission: Permission.notification,
    ),
    PermissionItem(
      icon: Icons.folder_open_outlined,
      title: 'Akses File',
      description: 'Diperlukan untuk mengunggah dokumen pendukung dan foto bukti transaksi.',
      permission: Permission.storage,
    ),
    PermissionItem(
      icon: Icons.location_on_outlined,
      title: 'Lokasi GPS',
      description: 'Digunakan untuk memverifikasi lokasi saat melakukan pengajuan atau transaksi di lapangan.',
      permission: Permission.location,
    ),
  ];

  Future<PermissionStatus> _getEffectiveStatus(PermissionItem item) async {
    if (item.permission == Permission.storage && Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      if (androidInfo.version.sdkInt >= 33) {
        final photosStatus = await Permission.photos.status;
        final videosStatus = await Permission.videos.status;
        if (photosStatus.isGranted || videosStatus.isGranted) {
          return PermissionStatus.granted;
        }
        if (photosStatus.isPermanentlyDenied || videosStatus.isPermanentlyDenied) {
          return PermissionStatus.permanentlyDenied;
        }
        return photosStatus;
      }
    }
    return await item.permission.status;
  }

  void _skipStep() {
    if (_currentPage < _permissions.length) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _requestPermission(PermissionItem item) async {
    PermissionStatus status;
    
    if (item.permission == Permission.storage && Platform.isAndroid) {
      final deviceInfo = DeviceInfoPlugin();
      final androidInfo = await deviceInfo.androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      
      if (sdkInt >= 33) {
        final results = await [
          Permission.photos,
          Permission.videos,
        ].request();
        
        status = results.values.any((s) => s.isGranted) 
            ? PermissionStatus.granted 
            : results.values.every((s) => s.isPermanentlyDenied)
                ? PermissionStatus.permanentlyDenied
                : PermissionStatus.denied;
      } else {
        status = await item.permission.request();
      }
    } else {
      status = await item.permission.request();
    }
    
    if (status.isPermanentlyDenied) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Izin Diperlukan'),
            content: const Text('Izin ini telah dinonaktifkan secara permanen. Silakan aktifkan melalui pengaturan aplikasi.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Batal'),
              ),
              TextButton(
                onPressed: () {
                  openAppSettings();
                  Navigator.pop(context);
                },
                child: const Text('Buka Pengaturan'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (status.isGranted) {
      _skipStep();
    }
  }

  Future<void> _finishWizard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('permission_wizard_completed', true);
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isCompletionPage = _currentPage == _permissions.length;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF01579B), // Bank Blue Primary
              Color(0xFF0D47A1), // Navy Blue
              Color(0xFF002F6C), // Deep Navy
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(), // Paksa lewat tombol
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemCount: _permissions.length + 1,
                  itemBuilder: (context, index) {
                    if (index == _permissions.length) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(30),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.check_circle_outline,
                                size: 100,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 40),
                            const Text(
                              'Siap Digunakan!',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Pengaturan izin selesai. Anda sekarang dapat mulai menggunakan layanan Success Mandiri.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white.withValues(alpha: 0.9),
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final item = _permissions[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(30),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: FutureBuilder<PermissionStatus>(
                              future: _getEffectiveStatus(item),
                              builder: (context, snapshot) {
                                final isGranted = snapshot.data?.isGranted ?? false;
                                return Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Icon(
                                      item.icon,
                                      size: 100,
                                      color: Colors.white,
                                    ),
                                    if (isGranted)
                                      Positioned(
                                        right: 0,
                                        bottom: 0,
                                        child: Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: const BoxDecoration(
                                            color: Colors.green,
                                            shape: BoxShape.circle,
                                          ),
                                          child: const Icon(
                                            Icons.check,
                                            size: 30,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 40),
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          FutureBuilder<PermissionStatus>(
                            future: _getEffectiveStatus(item),
                            builder: (context, snapshot) {
                              final isGranted = snapshot.data?.isGranted ?? false;
                              return Text(
                                isGranted 
                                    ? 'Izin ini sudah aktif. Silakan lanjukan.' 
                                    : item.description,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white.withValues(alpha: 0.9),
                                  height: 1.5,
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        _permissions.length + 1,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _currentPage == index ? 24 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _currentPage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: FutureBuilder<PermissionStatus>(
                        future: !isCompletionPage 
                            ? _getEffectiveStatus(_permissions[_currentPage]) 
                            : Future.value(PermissionStatus.granted),
                        builder: (context, snapshot) {
                          final isGranted = snapshot.data?.isGranted ?? false;
                          
                          return ElevatedButton(
                            onPressed: isCompletionPage
                                ? () => _finishWizard()
                                : (isGranted ? () => _skipStep() : () => _requestPermission(_permissions[_currentPage])),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isGranted ? const Color(0xFF01579B) : Colors.white,
                              foregroundColor: isGranted ? Colors.white : const Color(0xFF01579B),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                              elevation: 5,
                            ),
                            child: Text(
                              isCompletionPage 
                                  ? 'Mulai Aplikasi' 
                                  : (isGranted ? 'Lanjutkan' : 'Berikan Izin'),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }
                      ),
                    ),
                    if (!isCompletionPage)
                      TextButton(
                        onPressed: _skipStep,
                        child: Text(
                          'Lewati',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    if (isCompletionPage)
                      const SizedBox(height: 48),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PermissionItem {
  final IconData icon;
  final String title;
  final String description;
  final Permission permission;

  PermissionItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.permission,
  });
}

