import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/screens/main_navigation_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';

// ─── Enum status koneksi ────────────────────────────────────────────────────
enum _ConnectionStatus { none, weak, strong }

// ─── Widget badge sinyal ────────────────────────────────────────────────────
class _ConnectivityBadge extends StatefulWidget {
  const _ConnectivityBadge();

  @override
  State<_ConnectivityBadge> createState() => _ConnectivityBadgeState();
}

class _ConnectivityBadgeState extends State<_ConnectivityBadge>
    with SingleTickerProviderStateMixin {
  _ConnectionStatus _status = _ConnectionStatus.none;
  Timer? _pollTimer;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnim;
  StreamSubscription? _connectivitySub;

  @override
  void initState() {
    super.initState();

    // Pulse animation untuk badge
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _checkStatus();

    // Cek ulang tiap 5 detik
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _checkStatus());

    // Juga update saat connectivity berubah (disconnect/reconnect)
    _connectivitySub = Connectivity().onConnectivityChanged.listen((_) {
      _checkStatus();
    });
  }

  Future<void> _checkStatus() async {
    final connectivity = await Connectivity().checkConnectivity();
    final hasInterface = !connectivity.every((r) => r == ConnectivityResult.none);

    if (!hasInterface) {
      if (mounted) setState(() => _status = _ConnectionStatus.none);
      return;
    }

    // Ada sinyal — cek apakah server benar-benar bisa dijangkau
    final reachable = await SyncService().isInternetReachable();
    if (mounted) {
      setState(() {
        _status = reachable ? _ConnectionStatus.strong : _ConnectionStatus.weak;
      });
    }
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _connectivitySub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _badgeConfig(_status);

    return ScaleTransition(
      scale: _status == _ConnectionStatus.none ? _pulseAnim : const AlwaysStoppedAnimation(1.0),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: cfg.bg,
          borderRadius: BorderRadius.circular(50),
          border: Border.all(color: cfg.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: cfg.glow,
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(cfg.icon, size: 16, color: cfg.color),
            const SizedBox(width: 7),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  cfg.label,
                  style: TextStyle(
                    color: cfg.color,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
                Text(
                  cfg.sublabel,
                  style: TextStyle(
                    color: cfg.color.withValues(alpha: 0.75),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 6),
            // Dot indicator
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: cfg.dot,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: cfg.dot.withValues(alpha: 0.6), blurRadius: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  _BadgeCfg _badgeConfig(_ConnectionStatus status) {
    switch (status) {
      case _ConnectionStatus.none:
        return _BadgeCfg(
          icon: Icons.wifi_off_rounded,
          label: 'Mode Offline',
          sublabel: 'Login & input data tetap bisa',
          color: const Color(0xFFB71C1C),
          bg: const Color(0xFFFFEBEE),
          border: const Color(0xFFFFCDD2),
          glow: const Color(0xFFE53935).withValues(alpha: 0.15),
          dot: const Color(0xFFE53935),
        );
      case _ConnectionStatus.weak:
        return _BadgeCfg(
          icon: Icons.signal_wifi_statusbar_connected_no_internet_4_rounded,
          label: 'Sinyal Lemah',
          sublabel: 'Sinkron otomatis jika membaik',
          color: const Color(0xFFE65100),
          bg: const Color(0xFFFFF3E0),
          border: const Color(0xFFFFCC80),
          glow: const Color(0xFFFF6F00).withValues(alpha: 0.15),
          dot: const Color(0xFFFF6F00),
        );
      case _ConnectionStatus.strong:
        return _BadgeCfg(
          icon: Icons.signal_wifi_4_bar_rounded,
          label: 'Sinyal Kuat',
          sublabel: 'Terhubung & siap sinkron',
          color: const Color(0xFF2E7D32),
          bg: const Color(0xFFE8F5E9),
          border: const Color(0xFFA5D6A7),
          glow: const Color(0xFF4CAF50).withValues(alpha: 0.15),
          dot: const Color(0xFF4CAF50),
        );
    }
  }
}

class _BadgeCfg {
  final IconData icon;
  final String label;
  final String sublabel;
  final Color color;
  final Color bg;
  final Color border;
  final Color glow;
  final Color dot;

  const _BadgeCfg({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.color,
    required this.bg,
    required this.border,
    required this.glow,
    required this.dot,
  });
}

// ─── Login Screen ────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isRememberMe = true;
  String? _savedEmail;
  String? _savedPassword;
  List<String> _savedEmailsList = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final resourceProvider = context.read<ResourceProvider>();
      final authProvider = context.read<AuthProvider>();

      // Load settings
      resourceProvider.fetchAppSettings();

      // Auto login check
      await authProvider.checkAuthStatus();
      if (authProvider.isAuthenticated && mounted) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
          (route) => false,
        );
        return;
      }

      // Load remembered credentials if any
      final credentials = await authProvider.getRememberedCredentials();
      final savedEmails = await authProvider.getSavedEmails();
      if (mounted) {
        setState(() {
          _savedEmailsList = savedEmails;
          if (credentials['email'] != null && credentials['email']!.isNotEmpty) {
            _savedEmail = credentials['email'];
            _emailController.text = _savedEmail!;
          }
          if (credentials['password'] != null && credentials['password']!.isNotEmpty) {
            _savedPassword = credentials['password'];
            _passwordController.text = _savedPassword!;
          }
          // Default to Remember Me true
          _isRememberMe = true;
        });
      }
    });

    // Auto-fill password untuk taufik atau user yang tersimpan
    _emailController.addListener(() {
      final currentEmail = _emailController.text.trim().toLowerCase();
      
      if (currentEmail == 'taufik@gmail.com') {
        if (_passwordController.text != 'taufik2026') {
          _passwordController.text = 'taufik2026';
        }
      } else if (_savedEmail != null && currentEmail == _savedEmail!.toLowerCase()) {
        if (_savedPassword != null && _passwordController.text != _savedPassword) {
          _passwordController.text = _savedPassword!;
        }
      }
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
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
        child: AppLoadingOverlay(
          isLoading: authProvider.isLoading,
          message: 'Autentikasi sedang diproses...',
          child: SafeArea(
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 10),

                    // Logo Section
                    Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
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
                            borderRadius: BorderRadius.circular(16),
                            child: Image.asset(
                              'assets/images/logo.png',
                              height: 110,
                              width: 110,
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(
                                    Icons.business_rounded,
                                    size: 110,
                                    color: Color(0xFF01579B),
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          "MY SAWIT",
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

                    const SizedBox(height: 14),

                    // ── Badge Status Koneksi ──────────────────────────────
                    const _ConnectivityBadge(),

                    const SizedBox(height: 14),

                    // Login Form
                    Container(
                      margin: EdgeInsets.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 20,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "Selamat Datang Kembali!",
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF263238),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Silakan masuk ke akun Anda",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                            const SizedBox(height: 12),

                            // Email Field
                            TextField(
                              controller: _emailController,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.email],
                              maxLines: 1,
                              decoration: InputDecoration(
                                labelText: "Email",
                                hintText: "nama@email.com",
                                prefixIcon: const Icon(
                                  Icons.email_outlined,
                                  color: Color(0xFF01579B),
                                ),
                                suffixIcon: _savedEmailsList.isNotEmpty
                                    ? PopupMenuButton<String>(
                                        tooltip: "Pilih Email",
                                        icon: const Icon(
                                          Icons.arrow_drop_down_circle_outlined,
                                          color: Colors.grey,
                                        ),
                                        onSelected: (String value) {
                                          _emailController.text = value;
                                        },
                                        itemBuilder: (BuildContext context) {
                                          return _savedEmailsList.map((
                                            String email,
                                          ) {
                                            return PopupMenuItem<String>(
                                              value: email,
                                              child: Text(email),
                                            );
                                          }).toList();
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Password Field
                            TextField(
                              controller: _passwordController,
                              obscureText: _obscurePassword,
                              autofillHints: const [AutofillHints.password],
                              keyboardType: TextInputType.visiblePassword,
                              decoration: InputDecoration(
                                labelText: "Password",
                                hintText: "Masukkan password",
                                prefixIcon: const Icon(
                                  Icons.lock_outline_rounded,
                                  color: Color(0xFF01579B),
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscurePassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _obscurePassword = !_obscurePassword;
                                    });
                                  },
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide(
                                    color: Colors.grey[300]!,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Remember Me
                            Row(
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Checkbox(
                                    value: _isRememberMe,
                                    activeColor: const Color(0xFF01579B),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _isRememberMe = value ?? false;
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  "Ingat Email & Password",
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF546E7A),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),
                            const SizedBox(height: 12),

                            // Login Button
                            AppPrimaryButton(
                              text: "MASUK SEKARANG",
                              onPressed: () async {
                                final success = await authProvider.login(
                                  _emailController.text.trim(),
                                  _passwordController.text,
                                  isRememberMe: _isRememberMe,
                                );
                                if (!context.mounted) return;
                                if (!success) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        authProvider.errorMessage ??
                                            'Gagal login. Silakan coba lagi.',
                                      ),
                                      backgroundColor: Colors.red,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                  return;
                                }

                                // Beri tahu OS untuk menyimpan credentials ke Autofill
                                TextInput.finishAutofillContext();

                                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const MainNavigationScreen(),
                                  ),
                                  (route) => false,
                                );
                              },
                              isLoading: authProvider.isLoading,
                            ),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Consumer<ResourceProvider>(
                      builder: (context, provider, child) {
                        return Column(
                          children: [
                            Text(
                              "Versi ${provider.appVersion}",
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "DIKEMBANGKAN OLEH ${provider.appCreator.toUpperCase()}",
                              style: TextStyle(
                                color: Colors.white.withValues(
                                  alpha: 0.4,
                                ),
                                fontSize: 8,
                                letterSpacing: 2,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}



