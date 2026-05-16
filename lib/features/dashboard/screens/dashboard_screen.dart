import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/tambah_saldo_detail_screen.dart';
import 'package:sawitappmobile/shared/screens/resource_list_screen.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';
import 'package:sawitappmobile/shared/widgets/balance_validation_modal.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';
import 'package:sawitappmobile/features/auth/screens/login_screen.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/tambah_saldo_list_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_detail_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_screen.dart';
import 'package:sawitappmobile/features/profile/screens/profile_screen.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';
import 'package:sawitappmobile/shared/widgets/custom_loading_logo.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_detail_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/finance_journal_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';
import 'package:sawitappmobile/features/dashboard/screens/widgets/digital_clock.dart';

class DashboardScreen extends StatefulWidget {
  final VoidCallback? onAddBalance;
  const DashboardScreen({super.key, this.onAddBalance});

  @override
  State<DashboardScreen> createState() => DashboardScreenState();
}

class DashboardScreenState extends State<DashboardScreen> {
  int _selectedTransactionTab = 0; // 0: DO, 1: Operasional

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final dashboardProvider = context.read<DashboardProvider>();
      final resourceProvider = context.read<ResourceProvider>();
      
      // Sync master data in background
      resourceProvider.syncMasterData();
      
      await dashboardProvider.fetchSummary();

      if (!mounted) return;
      if (dashboardProvider.summary != null) {
        final summary = dashboardProvider.summary!;
        context.read<ResourceProvider>().updateTotalCounts(
          penjual: summary.totalPenjual,
          supir: summary.totalSupir,
          pekerja: summary.totalPekerja,
          kendaraan: summary.totalKendaraan,
          operasional: summary.totalOperasional,
          jurnal: summary.totalJurnalKeuangan,
          user: summary.totalUser,
        );

        if (!mounted) return;
        if (summary.saldo < 500000 && summary.saldo > 0) {
          BalanceValidationModal.show(
            context,
            currentBalance: summary.saldo,
            requiredAmount: 500000,
            onAddBalance: () => widget.onAddBalance?.call(),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = context.watch<DashboardProvider>();
    final summary = dashboard.summary;
    final items = _selectedTransactionTab == 0
        ? summary?.transactions ?? []
        : summary?.latestOperasional ?? [];

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        onRefresh: () async {
          final dashboardProvider = context.read<DashboardProvider>();
          final resourceProvider = context.read<ResourceProvider>();
          await dashboardProvider.fetchSummary();
          if (!mounted) return;
          if (dashboardProvider.summary != null) {
            final s = dashboardProvider.summary!;
            resourceProvider.updateTotalCounts(
              penjual: s.totalPenjual,
              supir: s.totalSupir,
              pekerja: s.totalPekerja,
              kendaraan: s.totalKendaraan,
              operasional: s.totalOperasional,
              jurnal: s.totalJurnalKeuangan,
            );
          }
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverToBoxAdapter(child: _DashboardHeader()),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('Layanan Utama', 'Akses cepat layanan dan transaksi Anda'),
                    const SizedBox(height: 8),
                    const _MenuGrid(),
                    const SizedBox(height: 16),
                    _buildTransactionHeader(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTabButton(0, 'DO Sawit', Icons.local_shipping_rounded),
                        const SizedBox(width: 12),
                        _buildTabButton(1, 'Operasional', Icons.payments_rounded),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            _buildTransactionList(dashboard.isLoading, items),
            const SliverPadding(padding: EdgeInsets.only(bottom: 20)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 4, height: 18,
          decoration: BoxDecoration(color: const Color(0xFF01579B), borderRadius: BorderRadius.circular(2)),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1A1A1A), letterSpacing: -0.5)),
            Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey[600], fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Transaksi Terkini', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
        TextButton(
          onPressed: () {
            context.read<MainNavigationProvider>().setIndex(_selectedTransactionTab == 0 ? 2 : 1);
          },
          child: const Text('Lihat Semua', style: TextStyle(color: Color(0xFF01579B), fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, IconData icon) {
    final bool isActive = _selectedTransactionTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTransactionTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF01579B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? const Color(0xFF01579B) : Colors.grey[300]!),
          boxShadow: isActive ? [BoxShadow(color: const Color(0xFF01579B).withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))] : null,
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: isActive ? Colors.white : Colors.grey[600]),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.w500, color: isActive ? Colors.white : Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(bool isLoading, List<dynamic> items) {
    if (isLoading && items.isEmpty) {
      return SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) => const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: SkeletonLoader(height: 80, width: double.infinity, borderRadius: 16),
          ),
          childCount: 3,
        ),
      );
    }

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Text(
              _selectedTransactionTab == 0 ? 'Tidak ada transaksi DO' : 'Tidak ada transaksi operasional',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final item = items[index];
          if (_selectedTransactionTab == 0 && item is TransaksiDo) return _buildPremiumTransactionItem(item);
          if (_selectedTransactionTab == 1 && item is Operasional) return _buildOperasionalItem(item);
          return const SizedBox.shrink();
        },
        childCount: items.length,
      ),
    );
  }

  Widget _buildPremiumTransactionItem(TransaksiDo tx) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TransaksiDoDetailScreen(transaction: tx))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: const Color(0xFFEBF5FB), borderRadius: BorderRadius.circular(15)),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2980B9), size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx.nomor, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF1A1A1A))),
                    const SizedBox(height: 4),
                    Text(tx.penjualNama ?? 'Tanpa Nama', style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.formatRupiah(tx.subTotal), style: const TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF2980B9), fontSize: 14)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(6)),
                    child: Text(DateFormat('dd MMM, HH:mm', 'id_ID').format(tx.tanggal), style: TextStyle(fontSize: 10, color: Colors.grey[600], fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOperasionalItem(Operasional item) {
    final bool isPengeluaran = item.operasional.toLowerCase() == 'pengeluaran';
    final Color color = isPengeluaran ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white, borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => OperasionalDetailScreen(operasional: item))),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(isPengeluaran ? Icons.trending_down_rounded : Icons.trending_up_rounded, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.kategoriLabel ?? item.kategori, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C3E50))),
                    const SizedBox(height: 4),
                    Text(item.keterangan ?? '-', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                    const SizedBox(height: 2),
                    Text(DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(item.tanggal), style: TextStyle(fontSize: 10, color: Colors.grey[400])),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.formatRupiah(item.nominal), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: color)),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Text(item.operasional, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: color)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompanySelector(BuildContext context, AuthProvider authProvider) {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: FutureBuilder<List<dynamic>>(
          future: authProvider.getAvailableCompanies(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF01579B))));
            }
            final companies = snapshot.data ?? [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 20),
                const Text('Ganti Perusahaan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true, itemCount: companies.length,
                    itemBuilder: (context, index) {
                      final company = companies[index];
                      final bool isSelected = authProvider.user?.perusahaanId == company['id'];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 25, vertical: 4),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: isSelected ? Colors.blue[900]?.withValues(alpha: 0.1) : Colors.grey[50], borderRadius: BorderRadius.circular(10)),
                          child: company['logo_url'] != null ? CachedNetworkImage(imageUrl: company['logo_url'], width: 24, height: 24, fit: BoxFit.contain) : Icon(Icons.business_rounded, color: isSelected ? const Color(0xFF01579B) : Colors.grey[400]),
                        ),
                        title: Text(company['name'] ?? 'Tanpa Nama', style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? const Color(0xFF01579B) : Colors.black87)),
                        trailing: isSelected ? const Icon(Icons.check_circle_rounded, color: Color(0xFF01579B)) : null,
                        onTap: () async {
                          Navigator.pop(context);
                          final success = await authProvider.switchCompany(company['id']);
                          if (success && context.mounted) {
                            context.read<DashboardProvider>().fetchSummary();
                            context.read<TransaksiDoProvider>().fetchTransactions();
                            context.read<TambahSaldoProvider>().fetchRequests();
                            context.read<ResourceProvider>().fetchAllResources();
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role?.toLowerCase();
    final bool isLeader = role == 'admin' || role == 'super_admin';
    final transactions = context.read<TransaksiDoProvider>().transactions;
    final List<TambahSaldoModel> pengajuanRequests = isLeader 
        ? context.read<TambahSaldoProvider>().requests.where((req) => req.status.toLowerCase() == 'pending').toList() 
        : [];

    final allNotifications = [
      ...transactions.map((t) => {'type': 'do', 'data': t, 'id': 'do_${t.id}', 'time': t.tanggal}),
      ...pengajuanRequests.map((p) => {'type': 'pengajuan', 'data': p, 'id': 'pengajuan_${p.id}', 'time': p.tanggal}),
    ]..sort((a, b) => (b['time'] as DateTime).compareTo(a['time'] as DateTime));

    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30))),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Informasi Terbaru', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF2C3E50))),
                  if (allNotifications.isNotEmpty) TextButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.clear_all_rounded, size: 18), label: const Text('Tutup')),
                ],
              ),
            ),
            Expanded(
              child: allNotifications.isEmpty 
                  ? const Center(child: Text('Belum ada aktivitas terbaru'))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: allNotifications.length.clamp(0, 15),
                      itemBuilder: (context, index) {
                        final notif = allNotifications[index];
                        final bool isDo = notif['type'] == 'do';
                        final dynamic data = notif['data'];
                        return _buildNotificationItem(context, isDo, data);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, bool isDo, dynamic data) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[100]!)),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => isDo ? TransaksiDoDetailScreen(transaction: data) : TambahSaldoDetailScreen(request: data)));
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: isDo ? const Color(0xFFE3F2FD) : Colors.amber[100], shape: BoxShape.circle),
                child: Icon(isDo ? Icons.local_shipping_rounded : Icons.pending_actions_rounded, color: isDo ? const Color(0xFF01579B) : Colors.amber[900], size: 20),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(isDo ? data.nomor : 'Tambah Saldo', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                    const SizedBox(height: 4),
                    Text(isDo ? (data.penjualNama ?? '-') : (data.keterangan ?? '-'), style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(CurrencyFormatter.formatRupiah(isDo ? data.subTotal : data.nominal), style: TextStyle(fontWeight: FontWeight.w900, color: isDo ? const Color(0xFF01579B) : Colors.amber[900], fontSize: 13)),
                  const SizedBox(height: 4),
                  Text(DateFormat('dd MMM, HH:mm', 'id_ID').format(data.tanggal), style: TextStyle(color: Colors.grey[400], fontSize: 10, fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ),
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
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Ya, Keluar', style: TextStyle(color: Color(0xFF01579B)))),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (context) => const Center(child: AnimatedPulsingLogo()));
      await authProvider.logout();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }
}

// ATOMIC WIDGETS FOR PERFORMANCE
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF01579B), Color(0xFF0D47A1), Color(0xFF002F6C)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(top: -100, right: -50, child: IgnorePointer(child: Container(width: 250, height: 250, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))))),
          Positioned(bottom: -20, left: -30, child: IgnorePointer(child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF01579B).withValues(alpha: 0.08))))),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderTopRow(),
                DigitalClock(),
                SizedBox(height: 8),
                _CompanySelector(),
                SizedBox(height: 10),
                _StatCardsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderTopRow extends StatelessWidget {
  const _HeaderTopRow();
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen())),
                child: const _UserAvatar(),
              ),
              const SizedBox(width: 12),
              const Expanded(child: _WelcomeSection()),
            ],
          ),
        ),
        const Row(
          children: [
            _SyncButton(),
            SizedBox(width: 6),
            _NotificationButton(),
            SizedBox(width: 6),
            _LogoutButton(),
          ],
        ),
      ],
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();
  @override
  Widget build(BuildContext context) {
    final photoUrl = context.select<AuthProvider, String?>((a) => a.user?.fullPhotoUrl);
    return Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2),
        image: photoUrl != null 
            ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover)
            : const DecorationImage(image: AssetImage('assets/images/placeholder_avatar.png'), fit: BoxFit.cover),
      ),
      child: photoUrl == null ? const Icon(Icons.person_rounded, color: Colors.white70, size: 30) : null,
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();
  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthProvider, String>((a) => a.user?.name ?? 'User');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Selamat Datang,', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500)),
        Text(name, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
      ],
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton();
  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: SyncService().pendingSyncCount,
      builder: (context, count, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          _CircleIconBtn(
            icon: count > 0 ? Icons.recycling_rounded : Icons.cloud_done_rounded,
            color: count > 0 ? Colors.orange : Colors.white,
            onTap: () async {
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Memulai Sinkronisasi Data...'), duration: Duration(seconds: 1)));
              
              // 1. Process offline queue
              await SyncService().syncNow();
              
              // 2. Fetch latest master data from web
              if (context.mounted) {
                await context.read<ResourceProvider>().syncMasterData();
                scaffoldMessenger.showSnackBar(const SnackBar(content: Text('Sinkronisasi Data Selesai'), backgroundColor: Colors.green));
              }
            },
          ),
          if (count > 0) Positioned(top: -2, right: -2, child: _CountBadge(count: count, color: Colors.orange)),
        ],
      ),
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();
  @override
  Widget build(BuildContext context) {
    return Selector4<TransaksiDoProvider, TambahSaldoProvider, ResourceProvider, DashboardProvider, Map<String, dynamic>>(
      selector: (_, p1, p2, p3, p4) {
        bool hasDo = p1.hasNewData;
        bool hasResource = p3.hasNewDataFor('penjual') || p3.hasNewDataFor('supir') || p3.hasNewDataFor('pekerja') || p3.hasNewDataFor('jurnal_keuangan');
        int total = (hasDo ? 1 : 0) + (hasResource ? 1 : 0);
        return {'total': total, 'pulsing': total > 0};
      },
      builder: (context, data, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          _CircleIconBtn(
            icon: Icons.notifications_none_rounded,
            onTap: () => context.findAncestorStateOfType<DashboardScreenState>()?._showNotifications(context),
          ),
          if (data['total'] > 0) Positioned(top: -4, right: -4, child: _CountBadge(count: data['total'], color: const Color(0xFF01579B))),
          if (data['pulsing']) const Positioned(top: -2, right: -2, child: RepaintBoundary(child: AnimatedPulsingDot())),
        ],
      ),
    );
  }
}

class _LogoutButton extends StatelessWidget {
  const _LogoutButton();
  @override
  Widget build(BuildContext context) {
    return _CircleIconBtn(
      icon: Icons.power_settings_new_rounded,
      onTap: () => context.findAncestorStateOfType<DashboardScreenState>()?._handleLogout(context, context.read<AuthProvider>()),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _CircleIconBtn({required this.icon, required this.onTap, this.color = Colors.white});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36, width: 36,
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
      child: IconButton(padding: EdgeInsets.zero, icon: Icon(icon, color: color, size: 20), onPressed: onTap),
    );
  }
}

class _CountBadge extends StatelessWidget {
  final int count;
  final Color color;
  const _CountBadge({required this.count, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)),
    );
  }
}

class _CompanySelector extends StatelessWidget {
  const _CompanySelector();
  @override
  Widget build(BuildContext context) {
    final bool isSwitching = context.select<AuthProvider, bool>((a) => a.isSwitchingCompany);
    final String name = context.select<AuthProvider, String>((a) => a.user?.perusahaanName ?? 'Pilih Unit Bisnis');
    final String? logo = context.select<AuthProvider, String?>((a) => a.user?.perusahaanLogoUrl);

    return GestureDetector(
      onTap: isSwitching ? null : () => context.findAncestorStateOfType<DashboardScreenState>()?._showCompanySelector(context, context.read<AuthProvider>()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSwitching ? 0.1 : 0.2), borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.white.withValues(alpha: isSwitching ? 0.05 : 0.15)),
        ),
        child: Row(
          children: [
            if (logo != null) ClipOval(child: CachedNetworkImage(imageUrl: logo, width: 28, height: 28, fit: BoxFit.contain))
            else const Icon(Icons.business_rounded, color: Colors.amberAccent, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unit Bisnis Aktif', style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
                  Text(name, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900)),
                ],
              ),
            ),
            if (isSwitching) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
            else const Icon(Icons.unfold_more_rounded, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _StatCardsSection extends StatelessWidget {
  const _StatCardsSection();
  @override
  Widget build(BuildContext context) {
    final isLoading = context.select<DashboardProvider, bool>((p) => p.isLoading);
    final error = context.select<DashboardProvider, String?>((p) => p.error);
    if (isLoading) return const _SkeletonStats();
    if (error != null) return Center(child: Text('Gagal: $error', style: const TextStyle(color: Colors.white, fontSize: 11)));
    return const _StatCards();
  }
}


class _StatCards extends StatelessWidget {
  const _StatCards();
  @override
  Widget build(BuildContext context) {
    final summary = context.select<DashboardProvider, DashboardSummary?>((p) => p.summary);
    if (summary == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(child: _StatCard(label: 'Transaksi DO', value: '${summary.stats.transaksi.today.count}', icon: Icons.local_shipping_rounded, color: const Color(0xFF01579B), subtitle: 'Hari ini', onTap: () => context.read<MainNavigationProvider>().setIndex(2))),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label: 'Pemasukan', value: CurrencyFormatter.formatRupiah(summary.stats.pemasukan.today.total), icon: Icons.trending_up_rounded, color: const Color(0xFF2E7D32), subtitle: 'Hari ini', isCurrency: true, onTap: () => context.read<MainNavigationProvider>().setIndex(3))),
          const SizedBox(width: 8),
          Expanded(child: _StatCard(label: 'Pengeluaran', value: CurrencyFormatter.formatRupiah(summary.stats.pengeluaran.today.total), icon: Icons.trending_down_rounded, color: const Color(0xFFC62828), subtitle: 'Hari ini', isCurrency: true, onTap: () => context.read<MainNavigationProvider>().setIndex(3))),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, subtitle;
  final IconData icon;
  final Color color;
  final bool isCurrency;
  final VoidCallback? onTap;
  const _StatCard({required this.label, required this.value, required this.icon, required this.color, required this.subtitle, this.isCurrency = false, this.onTap});
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
              const SizedBox(height: 8),
              Text(value, style: TextStyle(fontSize: isCurrency ? 11 : 16, fontWeight: FontWeight.w900, color: const Color(0xFF1A1A1A)), maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(label, style: TextStyle(fontSize: 9, color: Colors.grey[600], fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}

class _MenuGrid extends StatelessWidget {
  const _MenuGrid();
  @override
  Widget build(BuildContext context) {
    final user = context.select<AuthProvider, User?>((a) => a.user);
    if (user == null) return const SizedBox.shrink();
    return GridView.count(
      shrinkWrap: true, clipBehavior: Clip.none, physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3, padding: EdgeInsets.zero, crossAxisSpacing: 8, mainAxisSpacing: 8,
      children: [
        _MenuItem(label: 'Transaksi DO', icon: Icons.local_shipping_rounded, color: const Color(0xFF01579B), onTap: () { context.read<TransaksiDoProvider>().markAsSeen(); Navigator.push(context, MaterialPageRoute(builder: (_) => const TransaksiDoScreen())); }, badgeSelector: (c) => c.select<DashboardProvider, int>((p) => p.summary?.stats.transaksi.today.count ?? 0), hasNewDataSelector: (c) => c.select<TransaksiDoProvider, bool>((p) => p.hasNewData)),
        _MenuItem(label: 'Tambah Saldo', icon: Icons.add_to_photos_rounded, color: const Color(0xFFF39C12), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const TambahSaldoListScreen())); }, badgeSelector: (c) => 0, hasNewDataSelector: (c) => false),
        _MenuItem(label: 'Penjual', icon: Icons.storefront_rounded, color: const Color(0xFF27AE60), onTap: () { context.read<ResourceProvider>().markAsSeen('penjual'); Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourceListScreen(title: 'Penjual', resourceType: 'penjual'))); }, badgeSelector: (c) => c.select<ResourceProvider, int>((p) => p.penjualCount), hasNewDataSelector: (c) => c.select<ResourceProvider, bool>((p) => p.hasNewDataFor('penjual'))),
        _MenuItem(label: 'Supir', icon: Icons.person_rounded, color: const Color(0xFFE67E22), onTap: () { context.read<ResourceProvider>().markAsSeen('supir'); Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourceListScreen(title: 'Supir', resourceType: 'supir'))); }, badgeSelector: (c) => c.select<ResourceProvider, int>((p) => p.supirCount), hasNewDataSelector: (c) => c.select<ResourceProvider, bool>((p) => p.hasNewDataFor('supir'))),
        _MenuItem(label: 'Pekerja', icon: Icons.engineering_rounded, color: const Color(0xFF8E44AD), onTap: () { context.read<ResourceProvider>().markAsSeen('pekerja'); Navigator.push(context, MaterialPageRoute(builder: (_) => const ResourceListScreen(title: 'Pekerja', resourceType: 'pekerja'))); }, badgeSelector: (c) => c.select<ResourceProvider, int>((p) => p.pekerjaCount), hasNewDataSelector: (c) => c.select<ResourceProvider, bool>((p) => p.hasNewDataFor('pekerja'))),
        _MenuItem(label: 'Laporan', icon: Icons.auto_stories_rounded, color: const Color(0xFF2980B9), onTap: () { Navigator.push(context, MaterialPageRoute(builder: (_) => const FinanceJournalScreen())); }, badgeSelector: (c) => c.select<ResourceProvider, int>((p) => p.jurnalCount), hasNewDataSelector: (c) => c.select<ResourceProvider, bool>((p) => p.hasNewDataFor('jurnal_keuangan'))),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label; final IconData icon; final Color color; final VoidCallback onTap;
  final int Function(BuildContext) badgeSelector; final bool Function(BuildContext) hasNewDataSelector;
  const _MenuItem({required this.label, required this.icon, required this.color, required this.onTap, required this.badgeSelector, required this.hasNewDataSelector});
  @override
  Widget build(BuildContext context) {
    final int count = badgeSelector(context);
    final bool hasNew = hasNewDataSelector(context);
    return GestureDetector(
      onTap: onTap, behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(25), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5))]),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 30, color: color)),
                  const SizedBox(height: 12),
                  Text(label, style: const TextStyle(color: Color(0xFF263238), fontSize: 12, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
          if (count > 0) Positioned(top: 8, right: 8, child: Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: const Color(0xFF01579B), shape: BoxShape.circle), child: Text(count > 9 ? '9+' : '$count', style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold)))),
          if (hasNew) const Positioned(top: 5, right: 5, child: RepaintBoundary(child: AnimatedPulsingDot())),
        ],
      ),
    );
  }
}

class AnimatedPulsingDot extends StatefulWidget {
  const AnimatedPulsingDot({super.key});
  @override
  State<AnimatedPulsingDot> createState() => _AnimatedPulsingDotState();
}

class _AnimatedPulsingDotState extends State<AnimatedPulsingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller; late Animation<double> _animation;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.7, end: 1.2).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }
  @override
  void dispose() { _controller.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return ScaleTransition(scale: _animation, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.redAccent, blurRadius: 4, spreadRadius: 2)])));
  }
}

class _SkeletonStats extends StatelessWidget {
  const _SkeletonStats();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(width: double.infinity, height: 110, borderRadius: 16),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: SkeletonLoader(width: double.infinity, height: 75, borderRadius: 14)), SizedBox(width: 8),
            Expanded(child: SkeletonLoader(width: double.infinity, height: 75, borderRadius: 14)), SizedBox(width: 8),
            Expanded(child: SkeletonLoader(width: double.infinity, height: 75, borderRadius: 14)),
          ],
        ),
      ],
    );
  }
}
