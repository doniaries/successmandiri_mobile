import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:sawitappmobile/features/profile/screens/profile_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/finance_journal_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/add_transaksi_do_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(5, (_) => GlobalKey<NavigatorState>());

  late final List<Widget> _screens = [
    _buildTabNavigator(0, const DashboardScreen()),
    _buildTabNavigator(1, const OperasionalScreen()),
    _buildTabNavigator(2, const TransaksiDoScreen()),
    _buildTabNavigator(3, const FinanceJournalScreen()),
    _buildTabNavigator(4, const ProfileScreen()),
  ];

  Widget _buildTabNavigator(int index, Widget rootPage) {
    return Navigator(
      key: _navigatorKeys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(
        builder: (context) => rootPage,
        settings: settings,
      ),
    );
  }

  void _onItemTapped(int index) {
    final navProvider = context.read<MainNavigationProvider>();
    
    if (navProvider.selectedIndex == index) {
      // Jika tab yang sama diketuk, kembali ke halaman awal navigator tersebut (pop to root)
      _navigatorKeys[index].currentState?.popUntil((route) => route.isFirst);
    } else {
      navProvider.setIndex(index);
      
      // Trigger auto-fetch if data is empty
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (index == 1) {
          // Operasional
          context.read<ResourceProvider>().fetchResources('operasional');
        } else if (index == 2) {
          // Transaksi DO
          context.read<TransaksiDoProvider>().fetchTransactions();
        } else if (index == 3) {
          // Laporan Keuangan
          context.read<ResourceProvider>().fetchJurnalByDateRange(
            DateTime.now()
                .subtract(const Duration(days: 30))
                .toString()
                .split(' ')[0],
            DateTime.now().toString().split(' ')[0],
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.watch<MainNavigationProvider>().selectedIndex;
    
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = _navigatorKeys[selectedIndex].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else if (selectedIndex != 0) {
          _onItemTapped(0);
        } else {
          // If at dashboard root, allow app to close
          if (mounted) {
            // Navigator.of(context).pop(); // This might close the app
          }
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            _buildConnectivityBanner(),
            Expanded(
              child: IndexedStack(index: selectedIndex, children: _screens),
            ),
          ],
        ),
        bottomNavigationBar: _buildBottomBar(selectedIndex),
      ),
    );
  }

  Widget _buildBottomBar(int selectedIndex) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.topCenter,
        children: [
          // Background Row
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            top: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildNavItem(0, Icons.grid_view_rounded, 'Beranda', selectedIndex),
                _buildNavItem(1, Icons.receipt_long_rounded, 'Operasional', selectedIndex),
                const SizedBox(width: 80), // Space for centered large button
                _buildNavItem(
                  3,
                  Icons.account_balance_wallet_rounded,
                  'Laporan',
                  selectedIndex,
                ),
                _buildNavItem(4, Icons.account_circle_rounded, 'Profil', selectedIndex),
              ],
            ),
          ),

          // Large Centered "DO" Button
          Positioned(
            top: -15,
            child: GestureDetector(
              onTap: () {
                _onItemTapped(2); // Go to DO List
                // Push Add screen on the nested navigator
                _navigatorKeys[2].currentState?.push(
                  MaterialPageRoute(builder: (context) => const AddTransaksiDoScreen()),
                );
              },
              child: Container(
                width: 75,
                height: 75,
                decoration: BoxDecoration(
                  color: const Color(0xFF01579B),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 5),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF01579B).withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      height: 35,
                      width: 35,
                      color: Colors.white,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.local_shipping_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const Text(
                      'DO',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, int selectedIndex) {
    final isSelected = selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => _onItemTapped(index),
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 24,
              color: isSelected
                  ? const Color(0xFF01579B)
                  : const Color(0xFF95A5A6),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF01579B)
                    : const Color(0xFF95A5A6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectivityBanner() {
    return StreamBuilder<bool>(
      stream: SyncService().connectivityStream,
      initialData: !SyncService().isOffline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (isOnline) return const SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 16),
          color: Colors.orange[800],
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, color: Colors.white, size: 14),
              SizedBox(width: 8),
              Text(
                'Mode Offline: Data akan disimpan lokal & sinkron otomatis saat ada sinyal',
                style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}

