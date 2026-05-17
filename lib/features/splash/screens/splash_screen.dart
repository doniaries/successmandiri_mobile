import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';

import 'package:sawitappmobile/features/auth/screens/login_screen.dart';
import 'package:sawitappmobile/shared/screens/main_navigation_screen.dart';
import 'package:sawitappmobile/shared/screens/permission_wizard_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  
  bool _isLoading = true;
  String _statusMessage = 'Memulai inisialisasi...';

  @override
  void initState() {
    super.initState();
    
    // Animasi logo
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _controller.forward();

    _startTimers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialization();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startTimers() {
    // Safety timeout total 15 detik
    Future.delayed(const Duration(seconds: 15), () {
      if (mounted && _isLoading) {
        _navigateTo(const LoginScreen());
      }
    });
  }

  Future<void> _performInitialization() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final resourceProvider = Provider.of<ResourceProvider>(context, listen: false);

    try {
      if (!mounted) return;
      
      // 1. Cek status auth SANGAT CEPAT (menggunakan cache)
      await authProvider.checkAuthStatus();
      
      // 2. Jika sudah login, coba langsung gas ke Dashboard
      if (authProvider.isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        final wizardCompleted = prefs.getBool('permission_wizard_completed') ?? false;
        
        if (wizardCompleted) {
          // Trigger fetch settings di background (non-blocking)
          resourceProvider.fetchAppSettings().catchError((_) => null);
          
          if (mounted) {
            _navigateTo(const MainNavigationScreen());
            return;
          }
        }
      }

      // 3. Alur normal untuk user baru/belum login
      setState(() => _statusMessage = 'Memeriksa lokasi database & preferensi...');
      final prefs = await SharedPreferences.getInstance();
      final wizardCompleted = prefs.getBool('permission_wizard_completed') ?? false;

      setState(() => _statusMessage = 'Memeriksa izin perangkat...');
      bool storageGranted = false;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          if (androidInfo.version.sdkInt >= 33) {
            storageGranted = await Permission.photos.isGranted || await Permission.videos.isGranted;
          } else {
            storageGranted = await Permission.storage.isGranted;
          }
        } catch (e) {
          // Abaikan error device info
        }
      }

      if (!kIsWeb && (!wizardCompleted || !storageGranted)) {
        setState(() => _statusMessage = 'Mengarahkan ke Wizard Izin...');
        await prefs.setBool('permission_wizard_completed', false);
        _navigateTo(const PermissionWizardScreen());
        return;
      }

      setState(() => _statusMessage = 'Terhubung ke server...');
      
      // Ambil pengaturan aplikasi (versi & pembuat)
      try {
        await resourceProvider.fetchAppSettings();
      } catch (_) {
        // Abaikan jika gagal, gunakan default
      }

      // Berikan waktu animasi sedikit jika belum navigasi
      await Future.delayed(const Duration(milliseconds: 300));

      if (mounted) {
        _navigateTo(authProvider.isAuthenticated ? const MainNavigationScreen() : const LoginScreen());
      }
    } catch (e) {
      debugPrint('SplashScreen Error: $e');
      if (mounted) {
        setState(() => _statusMessage = 'Terjadi kendala, membuka login...');
        await Future.delayed(const Duration(seconds: 1));
        _navigateTo(const LoginScreen());
      }
    }
  }

  void _navigateTo(Widget screen) {
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF01579B), // Bank Blue Primary
              Color(0xFF1565C0), // Medium Blue
              Color(0xFF0D47A1), // Navy Blue
            ],
          ),
        ),
        child: Stack(
          children: [
            // Background Ornaments
            Positioned(
              top: -100,
              right: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  // Static Logo (No Animation)
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: Consumer<ResourceProvider>(
                            builder: (context, res, child) {
                              final logoUrl = res.appLogoUrl;
                              if (logoUrl != null && logoUrl.isNotEmpty) {
                                return CachedNetworkImage(
                                  imageUrl: logoUrl,
                                  height: 110,
                                  width: 110,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => Image.asset('assets/images/logo.png', height: 110),
                                  errorWidget: (context, url, error) => Image.asset('assets/images/logo.png', height: 110),
                                );
                              }
                              return Image.asset(
                                'assets/images/logo.png',
                                height: 110,
                                errorBuilder: (context, error, stackTrace) => const Icon(
                                  Icons.business_rounded,
                                  size: 110,
                                  color: Color(0xFF01579B),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "SUCCESS MANDIRI",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                          shadows: [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                      ),
                      const Text(
                        "Aplikasi Transaksi Sawit",
                        style: TextStyle(
                          color: Color(0xFFB3E5FC),
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  
                  // Loading & Status Diagnostic
                  if (_isLoading) ...[
                    const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                    ),
                  ),
                    const SizedBox(height: 20),
                    Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],

                  const Spacer(flex: 1),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

