import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:provider/provider.dart';
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

class _SplashScreenState extends State<SplashScreen> {
  bool _isLoading = true;
  String _statusMessage = 'Memulai inisialisasi...';

  @override
  void initState() {
    super.initState();
    _startTimers();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _performInitialization();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _startTimers() {
    // Safety timeout: 5 detik di debug, 15 detik di production
    final timeout = kDebugMode ? 5 : 15;
    Future.delayed(Duration(seconds: timeout), () {
      if (mounted && _isLoading) {
        debugPrint('[Splash] Safety timeout! Navigating to LoginScreen.');
        _navigateTo(const LoginScreen());
      }
    });
  }

  Future<void> _performInitialization() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final resourceProvider = Provider.of<ResourceProvider>(
      context,
      listen: false,
    );

    try {
      if (!mounted) return;

      // 1. Cek status auth dengan timeout agar tidak hang jika token lama invalid
      debugPrint('[Splash] Step 1: Checking auth status...');
      await authProvider.checkAuthStatus().timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('[Splash] checkAuthStatus timeout! Skipping...');
        },
      );

      // 2. Jika sudah login, coba langsung gas ke Dashboard
      if (authProvider.isAuthenticated) {
        final prefs = await SharedPreferences.getInstance();
        final wizardCompleted =
            prefs.getBool('permission_wizard_completed') ?? false;

        if (wizardCompleted) {
          // Trigger fetch settings di background (non-blocking)
          resourceProvider.fetchAppSettings().catchError((_) => null);

          // Berikan waktu jeda sedikit agar animasi splash screen terlihat penuh
          await Future.delayed(const Duration(milliseconds: 2000));

          if (mounted) {
            _navigateTo(const MainNavigationScreen());
            return;
          }
        }
      }

      debugPrint('[Splash] isAuthenticated: ${authProvider.isAuthenticated}');

      // 3. Alur normal untuk user baru/belum login
      debugPrint('[Splash] Step 3: Loading prefs...');
      setState(
        () => _statusMessage = 'Memeriksa lokasi database & preferensi...',
      );
      final prefs = await SharedPreferences.getInstance();
      final wizardCompleted =
          prefs.getBool('permission_wizard_completed') ?? false;

      setState(() => _statusMessage = 'Memeriksa izin perangkat...');
      bool storageGranted = false;
      if (!kIsWeb && Platform.isAndroid) {
        try {
          final deviceInfo = DeviceInfoPlugin();
          final androidInfo = await deviceInfo.androidInfo;
          if (androidInfo.version.sdkInt >= 33) {
            storageGranted =
                await Permission.photos.isGranted ||
                await Permission.videos.isGranted;
          } else {
            storageGranted = await Permission.storage.isGranted;
          }
        } catch (e) {
          // Abaikan error device info
        }
      }

      // Di mode DEBUG: langsung lewati wizard izin untuk mempercepat development
      if (kDebugMode) {
        debugPrint('[Splash] DEBUG mode: skipping permission wizard.');
        await prefs.setBool('permission_wizard_completed', true);
      } else if (!kIsWeb && (!wizardCompleted || !storageGranted)) {
        setState(() => _statusMessage = 'Mengarahkan ke Wizard Izin...');
        await prefs.setBool('permission_wizard_completed', false);
        _navigateTo(const PermissionWizardScreen());
        return;
      }

      setState(() => _statusMessage = 'Terhubung ke server...');

      debugPrint('[Splash] Step 4: Loading app settings in background...');
      resourceProvider.fetchAppSettings().catchError((_) => null);

      // Berikan waktu jeda sedikit agar UI tidak kedip dan animasi selesai
      await Future.delayed(const Duration(milliseconds: 2000));

      if (mounted) {
        _navigateTo(
          authProvider.isAuthenticated
              ? const MainNavigationScreen()
              : const LoginScreen(),
        );
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
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => screen,
        transitionDuration: const Duration(milliseconds: 800),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
      ),
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
              Color(0xFF0D47A1), // Navy Blue
              Color(0xFF002F6C), // Deep Navy
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(flex: 3),
                  // Animated Logo (Scale, Fade, and Bounce)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1800),
                    curve: Curves.elasticOut,
                    builder: (context, value, child) {
                      // Terbang masuk dari atas (luar layar) ke posisi awal
                      return Transform.translate(
                        offset: Offset(
                          0,
                          -MediaQuery.of(context).size.height * (1 - value),
                        ),
                        child: Opacity(
                          // Agar saat awal di luar layar, tampil pelan-pelan
                          opacity: value.clamp(0.0, 1.0),
                          child: child,
                        ),
                      );
                    },
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(20),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 180,
                              width: 180,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.business_rounded,
                                    size: 200,
                                    color: Color(0xFF01579B),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "SUCCESS MOBILE",
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
                  ),
                  const Spacer(flex: 2),

                  // Loading & Status Diagnostic
                  if (_isLoading) ...[
                    const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white70,
                        ),
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
