import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sawitappmobile/core/navigation/navigation_service.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';
import 'package:sawitappmobile/shared/repositories/auth_repository.dart';
import 'package:sawitappmobile/shared/repositories/transaksi_do_repository.dart';
import 'package:sawitappmobile/shared/repositories/tambah_saldo_repository.dart';
import 'package:sawitappmobile/shared/repositories/resource_repository.dart';
import 'package:sawitappmobile/features/splash/screens/splash_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/core/services/notification_service.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/features/auth/screens/login_screen.dart';
import 'package:sawitappmobile/shared/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Inisialisasi cepat di level main
  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final wizardCompleted = prefs.getBool('permission_wizard_completed') ?? false;
  
  Widget initialScreen;
  
  // 2. Tentukan halaman awal secara cerdas
  if (token != null && wizardCompleted) {
    initialScreen = const MainNavigationScreen();
  } else if (!wizardCompleted) {
    initialScreen = const SplashScreen(); // Splash akan handle wizard
  } else {
    initialScreen = const LoginScreen();
  }

  // 3. Lakukan inisialisasi WAJIB sebelum UI berjalan
  try {
    await initializeDateFormatting('id_ID', null);
  } catch (e) {
    debugPrint('Locale init error: $e');
  }

  // Jalankan aplikasi dengan initialScreen
  runApp(MyApp(initialScreen: initialScreen));

  // 4. Lakukan inisialisasi non-kritis di latar belakang
  Future.delayed(const Duration(milliseconds: 100), () async {
    try {
      SyncService(); 
      await NotificationService().init();
    } catch (e) {
      debugPrint('Background init error: $e');
    }
  });
}

class MyApp extends StatelessWidget {
  final Widget initialScreen;
  const MyApp({super.key, required this.initialScreen});

  @override
  Widget build(BuildContext context) {
    final apiClient = ApiClient();
    final authRepository = AuthRepository(apiClient);
    final transaksiRepository = TransaksiDoRepository(apiClient);
    final tambahSaldoRepository = TambahSaldoRepository(apiClient);
    final resourceRepository = ResourceRepository(apiClient);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) {
            final provider = AuthProvider(authRepository);
            // Tetap lakukan checkAuthStatus untuk mengisi data User di provider
            // karena initialScreen hanya visual, state provider harus sinkron.
            provider.checkAuthStatus();
            return provider;
          },
        ),
        ChangeNotifierProvider(create: (_) => TransaksiDoProvider(transaksiRepository)),
        ChangeNotifierProvider(create: (_) => TambahSaldoProvider(tambahSaldoRepository)),
        ChangeNotifierProvider(create: (_) => ResourceProvider(resourceRepository)),
        ChangeNotifierProvider(create: (_) => DashboardProvider()),
        ChangeNotifierProvider(create: (_) => MainNavigationProvider()),
      ],
      child: MaterialApp(
        navigatorKey: NavigationService.navigatorKey,
        title: 'Sawit App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF01579B), // Deep Bank Blue
            primary: const Color(0xFF01579B),
          ),
          useMaterial3: true,
        ),
        home: initialScreen,
      ),
    );
  }
}

