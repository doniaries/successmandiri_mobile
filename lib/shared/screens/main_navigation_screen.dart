import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'dashboard/dashboard_screen.dart';
import 'profile/profile_screen.dart';
import 'finance/finance_journal_screen.dart';
import 'operasional/operasional_screen.dart';
import 'transaksi_do/transaksi_do_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens = [
    const DashboardScreen(),
    const OperasionalScreen(),
    const TransaksiDoScreen(),
    const FinanceJournalScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  Widget _buildBottomBar() {
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
                _buildNavItem(0, Icons.grid_view_rounded, 'Beranda'),
                _buildNavItem(1, Icons.receipt_long_rounded, 'Operasional'),
                const SizedBox(width: 80), // Space for centered large button
                _buildNavItem(
                  3,
                  Icons.account_balance_wallet_rounded,
                  'Laporan',
                ),
                _buildNavItem(4, Icons.account_circle_rounded, 'Profil'),
              ],
            ),
          ),

          // Large Centered "DO" Button
          Positioned(
            top: -15,
            child: GestureDetector(
              onTap: () => _onItemTapped(2),
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

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _selectedIndex == index;
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
}

