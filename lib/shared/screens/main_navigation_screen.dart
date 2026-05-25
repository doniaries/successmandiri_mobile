import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/screens/dashboard_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/finance_journal_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/add_transaksi_do_screen.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {

  final List<GlobalKey<NavigatorState>> _navigatorKeys = List.generate(4, (_) => GlobalKey<NavigatorState>());

  late final List<Widget> _screens = [
    _buildTabNavigator(0, const DashboardScreen()),
    _buildTabNavigator(1, const TransaksiDoScreen()),
    _buildTabNavigator(2, const OperasionalScreen()),
    _buildTabNavigator(3, const FinanceJournalScreen()),
  ];

  Widget _buildTabNavigator(int index, Widget rootPage) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        
        final navProvider = context.read<MainNavigationProvider>();
        if (navProvider.selectedIndex != index) {
          return;
        }

        final navigator = _navigatorKeys[index].currentState;
        if (navigator != null && navigator.canPop()) {
          navigator.pop();
        } else if (index != 0) {
          _onItemTapped(0);
        } else {
          final shouldExit = await _showExitConfirmationDialog();
          if (shouldExit) {
            SystemNavigator.pop();
          }
        }
      },
      child: Navigator(
        key: _navigatorKeys[index],
        onGenerateRoute: (settings) => MaterialPageRoute(
          builder: (context) => rootPage,
          settings: settings,
        ),
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
      
      // Pastikan ketika pindah ke tab Transaksi DO (index 1), navigator selalu direset ke root (halaman index/list)
      if (index == 1) {
        _navigatorKeys[1].currentState?.popUntil((route) => route.isFirst);
      }
      
      // Trigger auto-fetch if data is empty
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (index == 1) {
          // Transaksi DO
          context.read<TransaksiDoProvider>().fetchTransactions();
        } else if (index == 2) {
          // Operasional
          context.read<ResourceProvider>().fetchResources('operasional');
        }
      });
    }
  }

  Future<bool> _showExitConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.exit_to_app_rounded, color: Color(0xFF01579B)),
            SizedBox(width: 8),
            Text('Keluar Aplikasi', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Text(
          'Apakah Anda yakin ingin keluar dari aplikasi Success Mandiri?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Keluar',
              style: TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final selectedIndex = context.watch<MainNavigationProvider>().selectedIndex;
    
    return Scaffold(
      body: IndexedStack(index: selectedIndex, children: _screens),
      bottomNavigationBar: _buildBottomBar(selectedIndex),
    );
  }

  Widget _buildBottomBar(int selectedIndex) {
    return Container(
      height: 70,
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildNavItem(0, Icons.grid_view_rounded, 'Beranda', selectedIndex),
          _buildNavItem(1, Icons.local_shipping_rounded, 'Transaksi DO', selectedIndex),
          
          // Tombol + (Tambah DO) Sejajar di dalam Navbar
          Expanded(
            child: InkWell(
              onTap: () {
                _onItemTapped(1); // Go to DO List
                // Push Add screen on the nested navigator
                _navigatorKeys[1].currentState?.push(
                  MaterialPageRoute(
                      builder: (context) => const AddTransaksiDoScreen()),
                );
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF01579B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF01579B).withValues(alpha: 0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Buat DO',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF01579B),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          _buildNavItem(2, Icons.receipt_long_rounded, 'Operasional', selectedIndex),
          _buildNavItem(3, Icons.account_balance_wallet_rounded, 'Laporan', selectedIndex),
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
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
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

}

