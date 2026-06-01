import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/shared/providers/global_filter_provider.dart';

import 'package:sawitappmobile/shared/screens/resource_list_screen.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';
import 'package:sawitappmobile/shared/widgets/balance_validation_modal.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';
import 'package:sawitappmobile/features/auth/screens/login_screen.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/tambah_saldo_list_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_detail_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_screen.dart';
import 'package:sawitappmobile/features/profile/screens/profile_screen.dart';
import 'package:sawitappmobile/features/profile/screens/app_version_setting_screen.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_detail_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/finance_journal_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/features/penjual/models/penjual_model.dart';
import 'package:sawitappmobile/features/supir/models/supir_model.dart';

import 'package:shared_preferences/shared_preferences.dart';

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

      // Sync master data in background only if local list is empty
      if (resourceProvider.penjuals.isEmpty) {
        resourceProvider.syncMasterData();
      }

      if (dashboardProvider.summary == null) {
        await dashboardProvider.fetchSummary();
      }

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
        ? (summary?.transactions ?? []).take(5).toList()
        : (summary?.latestOperasional ?? []).take(5).toList();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: RefreshIndicator(
        notificationPredicate: (notification) =>
            !SyncService().isOffline &&
            defaultScrollNotificationPredicate(notification),
        onRefresh: () async {
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          final dashboardProvider = context.read<DashboardProvider>();
          final resourceProvider = context.read<ResourceProvider>();
          final authProvider = context.read<AuthProvider>();

          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Memulai Sinkronisasi Data...'),
              duration: Duration(seconds: 1),
            ),
          );

          try {
            // 1. Process offline queue (background)
            SyncService().syncNow();

            // 2. Fetch latest user & company details from server
            await authProvider.checkAuthStatus();

            // 3. Fetch latest master data from web
            await resourceProvider.syncMasterData();

            // 4. Fetch latest summary for dashboard
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

            if (!mounted) return;
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Sinkronisasi Data Selesai'),
                backgroundColor: Colors.green,
              ),
            );
          } catch (e) {
            if (mounted) {
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Text('Gagal sinkronisasi: $e'),
                  backgroundColor: Colors.redAccent,
                ),
              );
            }
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
                    _buildSectionHeader(
                      'Layanan Utama',
                      'Akses cepat layanan dan transaksi Anda',
                    ),
                    const SizedBox(height: 8),
                    const _MenuGrid(),
                    const SizedBox(height: 16),
                    _buildTransactionHeader(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildTabButton(
                          0,
                          'DO Sawit',
                          Icons.local_shipping_rounded,
                        ),
                        const SizedBox(width: 12),
                        _buildTabButton(
                          1,
                          'Operasional',
                          Icons.payments_rounded,
                        ),
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
          width: 4,
          height: 18,
          decoration: BoxDecoration(
            color: const Color(0xFF01579B),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.5,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTransactionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Transaksi Terkini',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.black87,
          ),
        ),
        TextButton(
          onPressed: () {
            context.read<MainNavigationProvider>().setIndex(
              _selectedTransactionTab == 0 ? 1 : 2,
            );
          },
          child: const Text(
            'Lihat Semua',
            style: TextStyle(
              color: Color(0xFF01579B),
              fontWeight: FontWeight.w600,
            ),
          ),
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
          border: Border.all(
            color: isActive ? const Color(0xFF01579B) : Colors.grey[300]!,
          ),
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: const Color(0xFF01579B).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: isActive ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive ? Colors.white : Colors.grey[600],
              ),
            ),
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
            child: SkeletonLoader(
              height: 80,
              width: double.infinity,
              borderRadius: 16,
            ),
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
              _selectedTransactionTab == 0
                  ? 'Tidak ada transaksi DO'
                  : 'Tidak ada transaksi operasional',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        ),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        if (_selectedTransactionTab == 0 && item is TransaksiDo) {
          return _buildPremiumTransactionItem(item);
        }
        if (_selectedTransactionTab == 1 && item is Operasional) {
          return _buildOperasionalItem(item);
        }
        return const SizedBox.shrink();
      }, childCount: items.length),
    );
  }

  Widget _buildPremiumTransactionItem(TransaksiDo tx) {
    final String caraBayarStr = tx.caraBayar?.toLowerCase() ?? 'tunai';
    
    MaterialColor statusColor;
    IconData statusIcon;
    
    if (caraBayarStr == 'belum dibayar') {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
    } else if (caraBayarStr == 'tunai') {
      statusColor = Colors.green;
      statusIcon = Icons.payments_rounded;
    } else if (caraBayarStr == 'cair di luar' || caraBayarStr == 'cair diluar') {
      statusColor = Colors.orange;
      statusIcon = Icons.outbound_rounded;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.account_balance_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final dashProvider = context.read<DashboardProvider>();
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TransaksiDoDetailScreen(transaction: tx),
              ),
            );
            if (mounted) {
              dashProvider.fetchSummary();
            }
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Baris 1: Status Pembayaran, Nomor DO & Subtotal Nominal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sisi Kiri: Icon + Nomor DO + Cara Bayar
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Icon(
                              statusIcon,
                              color: statusColor[700],
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getShortDoNumber(tx.nomor),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  (tx.caraBayar ?? 'Tunai').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Sisi Kanan: Nominal Sisa Bayar
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          CurrencyFormatter.formatRupiah(tx.sisaBayar),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            color: statusColor[700],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Divider Halus Pemisah Konten
                Container(
                  height: 1,
                  color: Colors.grey[100],
                ),
                const SizedBox(height: 10),
                // Baris 2: Nama Penjual/Supir, Tanggal & Tombol Aksi Mandiri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Info Nama & Tanggal
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${tx.penjualNama} • ${tx.displaySupirNama}',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.access_time_rounded, size: 14, color: Colors.blueGrey[400]),
                                  const SizedBox(width: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(tx.tanggal),
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blueGrey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                children: [
                                  Icon(Icons.scale_rounded, size: 15, color: Colors.blue[600]),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${NumberFormat.decimalPattern('id').format(tx.tonase)} kg',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getShortDoNumber(String nomor) {
    if (nomor.startsWith('DO-')) {
      final parts = nomor.split('-');
      if (parts.length >= 4) {
        // format: DO-P3-20260525-001 -> DO-001
        return 'DO-${parts.last}';
      }
    }
    return nomor;
  }

  Widget _buildOperasionalItem(Operasional item) {
    final bool isPengeluaran = item.operasional.toLowerCase() == 'pengeluaran';
    final Color color = isPengeluaran
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OperasionalDetailScreen(operasional: item),
          ),
        ),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPengeluaran
                      ? Icons.trending_down_rounded
                      : Icons.trending_up_rounded,
                  color: color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.kategoriLabel ?? item.kategori,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.namaPihak != null &&
                              item.namaPihak!.isNotEmpty &&
                              item.namaPihak != '-'
                          ? (item.keterangan != null &&
                                    item.keterangan!.isNotEmpty &&
                                    item.keterangan != '-'
                                ? '${item.namaPihak} (${item.keterangan})'
                                : item.namaPihak!)
                          : (item.keterangan ?? '-'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        if (item.id < 0) ...[
                          const Icon(
                            Icons.access_time_rounded,
                            size: 10,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          DateFormat(
                            'dd MMM yyyy • HH:mm',
                            'id_ID',
                          ).format(item.tanggal),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey[400],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    CurrencyFormatter.formatRupiah(item.nominal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      item.operasional,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
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
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: FutureBuilder<List<dynamic>>(
          future: authProvider.getAvailableCompanies(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF01579B),
                  ),
                ),
              );
            }
            final companies = snapshot.data ?? [];
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ganti Perusahaan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 20),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: companies.length,
                    itemBuilder: (context, index) {
                      final company = companies[index];
                      final bool isSelected =
                          authProvider.user?.perusahaanId == company['id'];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 25,
                          vertical: 4,
                        ),
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? Colors.blue[900]?.withValues(alpha: 0.1)
                                : Colors.grey[50],
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: company['logo_url'] != null
                              ? CachedNetworkImage(
                                  imageUrl:
                                      ApiConstants.normalizeUrl(
                                        company['logo_url'],
                                      ) ??
                                      '',
                                  width: 24,
                                  height: 24,
                                  fit: BoxFit.contain,
                                )
                              : Icon(
                                  Icons.business_rounded,
                                  color: isSelected
                                      ? const Color(0xFF01579B)
                                      : Colors.grey[400],
                                ),
                        ),
                        title: Text(
                          company['name'] ?? 'Tanpa Nama',
                          style: TextStyle(
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isSelected
                                ? const Color(0xFF01579B)
                                : Colors.black87,
                          ),
                        ),
                        subtitle: Text(
                          'Kasir: ${company['nama_kasir'] ?? 'Kasir Utama'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: Color(0xFF01579B),
                              )
                            : null,
                        onTap: () async {
                          final dashboardProvider = context
                              .read<DashboardProvider>();
                          final txProvider = context
                              .read<TransaksiDoProvider>();
                          final saldoProvider = context
                              .read<TambahSaldoProvider>();
                          final resProvider = context.read<ResourceProvider>();

                          Navigator.pop(context);
                          final success = await authProvider.switchCompany(
                            company['id'],
                          );

                          if (success) {
                            // clearAndFetch() → reset summary dulu agar nama perusahaan lama tidak tampil
                            await dashboardProvider.clearAndFetch();
                            txProvider.fetchTransactions();
                            saldoProvider.fetchData(isRefresh: true, useCache: false);
                            resProvider.fetchAllResources();
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
    final bool isLeader =
        role == 'admin' || role == 'super_admin' || role == 'pimpinan';

    final txProvider = context.read<TransaksiDoProvider>();
    final resProvider = context.read<ResourceProvider>();

    // Ambil seen state dari cache secara sinkron (tidak menunggu)
    final prefs = SharedPreferences.getInstance();

    // Fetch di background — panel langsung terbuka dari cache
    Future.microtask(() async {
      final List<Future> fetches = [];
      if (txProvider.unreadCount > 0 || txProvider.transactions.isEmpty) {
        fetches.add(txProvider.fetchTransactions().catchError((e) => null));
      }
      if (resProvider.getUnreadCountFor('operasional') > 0 || resProvider.operasionals.isEmpty) {
        fetches.add(resProvider.fetchResources('operasional', refresh: true).catchError((e) => null));
      }
      if (isLeader) {
        if (resProvider.getUnreadCountFor('penjual') > 0 || resProvider.penjuals.isEmpty) {
          fetches.add(resProvider.fetchResources('penjual', refresh: true).catchError((e) => null));
        }
        if (resProvider.getUnreadCountFor('supir') > 0 || resProvider.supirs.isEmpty) {
          fetches.add(resProvider.fetchResources('supir', refresh: true).catchError((e) => null));
        }
      }
      if (fetches.isNotEmpty) await Future.wait(fetches);
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => FutureBuilder<SharedPreferences>(
        future: prefs,
        builder: (context, snapshot) {
          // Tampilkan langsung dari cache provider tanpa tunggu API
          final sp = snapshot.data;
          final lastSeenDoId =
              int.tryParse(sp?.getString('seen_state_transaksi_do') ?? '0') ?? 0;
          final lastSeenOperasionalId =
              int.tryParse(sp?.getString('seen_state_operasional') ?? '0') ?? 0;
          final lastSeenPenjualId =
              int.tryParse(sp?.getString('seen_state_penjual') ?? '0') ?? 0;
          final lastSeenSupirId =
              int.tryParse(sp?.getString('seen_state_supir') ?? '0') ?? 0;

          final transactions = txProvider.transactions;
          final latestOperasional = resProvider.operasionals;
          final penjuals = isLeader ? resProvider.penjuals : <Penjual>[];
          final supirs = isLeader ? resProvider.supirs : <Supir>[];

          final filteredTransactions = transactions
              .where((t) => t.id > lastSeenDoId)
              .toList();
          final filteredOperasional = latestOperasional
              .where((o) => o.id > lastSeenOperasionalId)
              .toList();
          final filteredPenjuals = penjuals
              .where((p) => p.id > lastSeenPenjualId)
              .toList();
          final filteredSupirs = supirs
              .where((s) => s.id > lastSeenSupirId)
              .toList();

          final allNotifications = [
            ...filteredTransactions.map((t) => {
              'type': 'do',
              'data': t,
              'id': 'do_${t.id}',
              'time': t.tanggal,
            }),
            ...filteredOperasional.map((o) => {
              'type': 'operasional',
              'data': o,
              'id': 'operasional_${o.id}',
              'time': o.tanggal,
            }),
            ...filteredPenjuals.map((p) => {
              'type': 'penjual',
              'data': p,
              'id': 'penjual_${p.id}',
              'time': p.createdAt ?? DateTime.now(),
            }),
            ...filteredSupirs.map((s) => {
              'type': 'supir',
              'data': s,
              'id': 'supir_${s.id}',
              'time': s.createdAt ?? DateTime.now(),
            }),
          ]..sort(
            (a, b) =>
                (b['time'] as DateTime).compareTo(a['time'] as DateTime),
          );

          return Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Informasi Terbaru',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2C3E50),
                        ),
                      ),
                      if (allNotifications.isNotEmpty)
                        TextButton.icon(
                          onPressed: () async {
                            final txProv = context.read<TransaksiDoProvider>();
                            final saldoProv = context.read<TambahSaldoProvider>();
                            final resProv = context.read<ResourceProvider>();
                            await txProv.markAsSeen();
                            await saldoProv.markAsSeen();
                            await resProv.markAllAsSeen();
                            if (context.mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Notifikasi telah dibersihkan'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Color(0xFF01579B),
                                ),
                              );
                            }
                          },
                          icon: const Icon(
                            Icons.done_all_rounded,
                            size: 18,
                            color: Colors.redAccent,
                          ),
                          label: const Text(
                            'Bersihkan',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: allNotifications.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle_outline_rounded,
                                  size: 48, color: Colors.grey[300]),
                              const SizedBox(height: 12),
                              Text(
                                'Semua sudah terbaca',
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: allNotifications.length.clamp(0, 15),
                          itemBuilder: (context, index) {
                            final notif = allNotifications[index];
                            final String type = notif['type'] as String;
                            final dynamic data = notif['data'];
                            return _buildNotificationItem(context, type, data);
                          },
                        ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      // Auto-mark semua sebagai sudah dibaca saat panel ditutup
      if (mounted) {
        txProvider.markAsSeen();
        resProvider.markAllAsSeen();
      }
    });
  }

  Widget _buildNotificationItem(
    BuildContext context,
    String type,
    dynamic data,
  ) {
    final bool isDo = type == 'do';
    final bool isOperasional = type == 'operasional';
    final bool isPenjual = type == 'penjual';
    final bool isSupir = type == 'supir';

    Widget iconWidget;
    String titleText = '';
    String bodyText = '';
    double amount = 0;
    DateTime date = DateTime.now();
    Widget? detailScreen;

    if (isDo) {
      iconWidget = const Icon(
        Icons.local_shipping_rounded,
        color: Color(0xFF01579B),
        size: 20,
      );
      titleText = data.nomor;
      bodyText = data.penjualNama ?? '-';
      amount = data.subTotal;
      date = data.tanggal;
      detailScreen = TransaksiDoDetailScreen(transaction: data);
    } else if (isOperasional) {
      final bool isPengeluaran =
          data.operasional.toLowerCase() == 'pengeluaran';
      iconWidget = Icon(
        isPengeluaran ? Icons.trending_down_rounded : Icons.trending_up_rounded,
        color: isPengeluaran
            ? const Color(0xFFC62828)
            : const Color(0xFF2E7D32),
        size: 20,
      );
      titleText = data.kategoriLabel ?? data.kategori;

      final creator =
          data.userName != null &&
              data.userName!.isNotEmpty &&
              data.userName != '-'
          ? 'Oleh: ${data.userName}'
          : 'Oleh: -';
      final pihak =
          data.namaPihak != null &&
              data.namaPihak!.isNotEmpty &&
              data.namaPihak != '-'
          ? ' • Pihak: ${data.namaPihak}'
          : '';
      final ket =
          data.keterangan != null &&
              data.keterangan!.isNotEmpty &&
              data.keterangan != '-'
          ? ' (${data.keterangan})'
          : '';
      bodyText = '$creator$pihak$ket';

      amount = data.nominal;
      date = data.tanggal;
      detailScreen = OperasionalDetailScreen(operasional: data);
    } else if (isPenjual) {
      iconWidget = const Icon(
        Icons.store_rounded,
        color: Color(0xFF0288D1),
        size: 20,
      );
      titleText = 'Pendaftaran Penjual';
      bodyText = 'Penjual baru: ${data.nama} (${data.telepon ?? 'No Telp -'})';
      amount = 0;
      date = data.createdAt ?? DateTime.now();
      detailScreen = const ResourceListScreen(
        title: 'Master Penjual',
        resourceType: 'penjual',
      );
    } else if (isSupir) {
      iconWidget = const Icon(
        Icons.person_rounded,
        color: Color(0xFF00897B),
        size: 20,
      );
      titleText = 'Pendaftaran Supir';
      bodyText = 'Supir baru: ${data.nama} (${data.telepon ?? 'No Telp -'})';
      amount = 0;
      date = data.createdAt ?? DateTime.now();
      detailScreen = const ResourceListScreen(
        title: 'Master Supir',
        resourceType: 'supir',
      );
    } else {
      iconWidget = const SizedBox.shrink();
    }

    String? perusahaanNama;
    try {
      perusahaanNama = data.perusahaanNama;
    } catch (_) {}

    if (perusahaanNama == null || perusahaanNama.isEmpty) {
      try {
        perusahaanNama = context.read<AuthProvider>().user?.perusahaanName;
      } catch (_) {}
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: InkWell(
        onTap: () {
          Navigator.pop(context);
          if (detailScreen != null) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => detailScreen!),
            );
          }
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDo
                      ? const Color(0xFFE3F2FD)
                      : isPenjual
                      ? const Color(0xFFE3F2FD)
                      : isSupir
                      ? const Color(0xFFE0F2F1)
                      : (data.operasional.toLowerCase() == 'pengeluaran'
                            ? const Color(0xFFFFEBEE)
                            : const Color(0xFFE8F5E9)),
                  shape: BoxShape.circle,
                ),
                child: iconWidget,
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            titleText,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                              color: Color(0xFF2C3E50),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd MMM, HH:mm', 'id_ID').format(date),
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    if (perusahaanNama != null &&
                        perusahaanNama.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFC8E6C9)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.business_rounded,
                              size: 10,
                              color: Color(0xFF2E7D32),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              perusahaanNama,
                              style: const TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      bodyText,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                    if (amount > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isDo
                                  ? const Color(0xFFE3F2FD)
                                  : (data.operasional.toLowerCase() ==
                                            'pengeluaran'
                                        ? const Color(0xFFFFEBEE)
                                        : const Color(0xFFE8F5E9)),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              CurrencyFormatter.formatRupiah(amount),
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: isDo
                                    ? const Color(0xFF01579B)
                                    : (data.operasional.toLowerCase() ==
                                              'pengeluaran'
                                          ? const Color(0xFFC62828)
                                          : const Color(0xFF2E7D32)),
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE3F2FD),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              'BARU',
                              style: TextStyle(
                                color: Color(0xFF01579B),
                                fontWeight: FontWeight.w800,
                                fontSize: 9,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleLogout(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Konfirmasi Logout'),
        content: const Text('Apakah Anda yakin ingin keluar dari aplikasi?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Ya, Keluar',
              style: TextStyle(color: Color(0xFF01579B)),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await authProvider.logout();
      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
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
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF01579B), Color(0xFF0D47A1), Color(0xFF002F6C)],
        ),
      ),
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -50,
            child: IgnorePointer(
              child: Container(
                width: 250,
                height: 250,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -30,
            child: IgnorePointer(
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF01579B).withValues(alpha: 0.08),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _HeaderTopRow(),
                const SizedBox(height: 24),
                const _CompanySelector(),
                const SizedBox(height: 12),
                const _BalanceCard(),
                const SizedBox(height: 12),
                const _StatCardsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// _OfflineIndicator removed - replaced by wifi icon in _SyncButton

class _BalanceCard extends StatelessWidget {
  const _BalanceCard();

  @override
  Widget build(BuildContext context) {
    final double saldo = context.select<DashboardProvider, double>(
      (p) => p.summary?.saldo ?? 0,
    );
    final bool isLow = saldo < 500000;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isLow
                  ? Colors.redAccent.withValues(alpha: 0.2)
                  : Colors.amberAccent.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isLow
                  ? Icons.warning_amber_rounded
                  : Icons.account_balance_wallet_rounded,
              color: isLow ? Colors.redAccent : Colors.amberAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Saldo Perusahaan',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.7),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    CurrencyFormatter.formatRupiah(saldo),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (isLow)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.redAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'RENDAH',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
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
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileScreen(),
                  ),
                ),
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
    final photoUrl = context.select<AuthProvider, String?>(
      (a) => a.user?.fullPhotoUrl,
    );
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.3),
          width: 2,
        ),
      ),
      child: photoUrl != null
          ? ClipOval(
              child: Image.network(
                photoUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.person_rounded,
                  color: Colors.white,
                  size: 30,
                ),
              ),
            )
          : const Icon(Icons.person_rounded, color: Colors.white, size: 30),
    );
  }
}

class _WelcomeSection extends StatelessWidget {
  const _WelcomeSection();
  @override
  Widget build(BuildContext context) {
    final name = context.select<AuthProvider, String>(
      (a) => a.user?.name ?? 'User',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Selamat Datang,',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          name,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

class _SyncButton extends StatelessWidget {
  const _SyncButton();
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<bool>(
      stream: SyncService().connectivityStream,
      initialData: !SyncService().isOffline,
      builder: (context, connectivitySnapshot) {
        final isOnline = connectivitySnapshot.data ?? true;

        return ValueListenableBuilder<int>(
          valueListenable: SyncService().pendingSyncCount,
          builder: (context, count, _) {
            // Tentukan icon, warna, dan tooltip berdasarkan status
            final IconData wifiIcon;
            final Color iconColor;
            final String tooltipMsg;

            if (!isOnline) {
              wifiIcon = Icons.wifi_off_rounded;
              iconColor = Colors.white54;
              tooltipMsg = count > 0
                  ? '$count data tersimpan lokal.\nAkan sinkron saat online.'
                  : 'Mode Offline';
            } else {
              if (count > 0) {
                wifiIcon = Icons.sync_rounded;
                iconColor = Colors.orangeAccent;
                tooltipMsg = 'Sedang menyinkronkan $count data ke server...';
              } else {
                wifiIcon = Icons.wifi_rounded;
                iconColor = Colors.greenAccent;
                tooltipMsg = 'Terhubung ke server.\nSemua data sudah sinkron.';
              }
            }

            return Stack(
              clipBehavior: Clip.none,
              children: [
                Tooltip(
                  message: tooltipMsg,
                  preferBelow: false,
                  textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _CircleIconBtn(
                    icon: wifiIcon,
                    color: iconColor,
                    onTap: () async {
                      final scaffoldMessenger = ScaffoldMessenger.of(context);

                      if (!isOnline) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(
                            content: Text(
                              count > 0
                                  ? '$count data tersimpan lokal.'
                                  : 'Mode Offline.',
                            ),
                            backgroundColor: Colors.grey[800],
                            duration: const Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      scaffoldMessenger.showSnackBar(
                        const SnackBar(
                          content: Text('Memulai sinkronisasi data...'),
                          duration: Duration(seconds: 1),
                        ),
                      );

                      // 1. Process offline queue (run in background)
                      SyncService().syncNow();

                      // 2. Fetch latest master data from web
                      if (context.mounted) {
                        await context.read<ResourceProvider>().syncMasterData();
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            content: Text('Sinkronisasi data selesai ✓'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                ),
                if (count > 0 && isOnline)
                  Positioned(
                    top: -2,
                    right: -2,
                    child: _CountBadge(count: count, color: Colors.orange),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

class _NotificationButton extends StatelessWidget {
  const _NotificationButton();
  @override
  Widget build(BuildContext context) {
    return Selector5<
      AuthProvider,
      TransaksiDoProvider,
      TambahSaldoProvider,
      ResourceProvider,
      DashboardProvider,
      Map<String, dynamic>
    >(
      selector: (_, auth, p1, p2, p3, p4) {
        final role = auth.user?.role?.toLowerCase();
        final bool isLeader =
            role == 'admin' || role == 'super_admin' || role == 'pimpinan';

        int total = 0;
        // Transaksi DO & Operasional are visible to both
        total += p1.unreadCount;
        total += p3.getUnreadCountFor('operasional');

        if (isLeader) {
          // Hanya Penjual dan Supir yang ditampilkan untuk Leaders
          total += p3.getUnreadCountFor('penjual');
          total += p3.getUnreadCountFor('supir');
        }
        return {'total': total};
      },
      builder: (context, data, _) => Stack(
        clipBehavior: Clip.none,
        children: [
          _CircleIconBtn(
            icon: Icons.notifications_none_rounded,
            onTap: () => context
                .findAncestorStateOfType<DashboardScreenState>()
                ?._showNotifications(context),
          ),
          if (data['total'] > 0)
            Positioned(
              top: -6,
              right: -6,
              child: _CountBadge(count: data['total'], color: Colors.red),
            ),
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
      onTap: () => context
          .findAncestorStateOfType<DashboardScreenState>()
          ?._handleLogout(context, context.read<AuthProvider>()),
    );
  }
}

class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;
  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.color = Colors.white,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 36,
      width: 36,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white10),
      ),
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(icon, color: color, size: 20),
        onPressed: onTap,
      ),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w900,
          height: 1.1,
        ),
      ),
    );
  }
}

class _CompanySelector extends StatelessWidget {
  const _CompanySelector();
  @override
  Widget build(BuildContext context) {
    final bool isSwitching = context.select<AuthProvider, bool>(
      (a) => a.isSwitchingCompany,
    );
    final String name = context.select<AuthProvider, String>(
      (a) => a.user?.perusahaanName ?? 'Pilih Unit Bisnis',
    );
    final String? logo = context.select<AuthProvider, String?>(
      (a) => a.user?.perusahaanLogoUrl,
    );
    final String cashier = context.select<AuthProvider, String>(
      (a) => a.user?.perusahaanKasir ?? 'Kasir Utama',
    );

    return GestureDetector(
      onTap: isSwitching
          ? null
          : () => context
                .findAncestorStateOfType<DashboardScreenState>()
                ?._showCompanySelector(context, context.read<AuthProvider>()),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: isSwitching ? 0.1 : 0.2),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: Colors.white.withValues(alpha: isSwitching ? 0.05 : 0.15),
          ),
        ),
        child: Row(
          children: [
            if (logo != null)
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: ApiConstants.normalizeUrl(logo) ?? '',
                    fit: BoxFit.contain,
                  ),
                ),
              )
            else
              const Icon(
                Icons.business_rounded,
                color: Colors.amberAccent,
                size: 20,
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Unit Bisnis Aktif',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Text(
                          'Kasir: $cashier',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            if (isSwitching)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            else
              const Icon(
                Icons.unfold_more_rounded,
                color: Colors.white70,
                size: 20,
              ),
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
    final isLoading = context.select<DashboardProvider, bool>(
      (p) => p.isLoading,
    );
    final error = context.select<DashboardProvider, String?>((p) => p.error);
    if (isLoading) return const _SkeletonStats();
    if (error != null) {
      bool isOfflineError =
          error.toLowerCase().contains('dioexception') ||
          error.toLowerCase().contains('socketexception') ||
          error.toLowerCase().contains('connection');
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            isOfflineError
                ? 'Data tetap masuk saat offline.'
                : 'Gagal memuat data: $error',
            style: const TextStyle(color: Colors.white, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return const _StatCards();
  }
}

class _StatCards extends StatefulWidget {
  const _StatCards();

  @override
  State<_StatCards> createState() => _StatCardsState();
}

class _StatCardsState extends State<_StatCards> {
  void _onPeriodTap(int index, DateTime? currentDate) async {
    final globalFilter = context.read<GlobalFilterProvider>();
    final dashboardProvider = context.read<DashboardProvider>();

    if (index == 0) {
      globalFilter.clearDate();
      dashboardProvider.fetchSummary(filterDate: null);
    } else {
      final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: currentDate ?? DateTime.now(),
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 365)),
        builder: (context, child) {
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: Color(0xFF01579B),
                onPrimary: Colors.white,
                onSurface: Colors.black87,
              ),
              dialogTheme: const DialogThemeData(backgroundColor: Colors.white),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF01579B),
                ),
              ),
            ),
            child: child!,
          );
        },
      );
      if (picked != null) {
        if (mounted) {
          globalFilter.setDate(picked);
          dashboardProvider.fetchSummary(filterDate: picked);
        }
      }
    }
  }

  Widget _buildGridItem({
    required VoidCallback onTap,
    required IconData icon,
    required Color color,
    required String title,
    required String value,
    required String subtitleStr,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: color,
                  letterSpacing: -0.3,
                ),
                maxLines: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitleStr,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = context.select<DashboardProvider, DashboardSummary?>(
      (p) => p.summary,
    );
    final filterDate = context.watch<GlobalFilterProvider>().selectedDate;

    if (summary == null) return const SizedBox.shrink();

    final isToday = filterDate == null;
    final stats = summary.stats;

    final subtitleStr = isToday
        ? 'Hari ini'
        : DateFormat('dd MMM yyyy', 'id_ID').format(filterDate);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Consumer<DashboardProvider>(
              builder: (context, provider, _) {
                final activeDateStr = provider.summary?.systemActiveDate;
                if (activeDateStr != null) {
                  final activeDate = DateTime.parse(activeDateStr);
                  final formatted = DateFormat(
                    'dd MMM yyyy',
                    'id_ID',
                  ).format(activeDate);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(
                            255,
                            255,
                            255,
                            255,
                          ).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.amber.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.event_available,
                              color: Color.fromARGB(255, 255, 255, 255),
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formatted,
                              style: const TextStyle(
                                color: Color.fromARGB(255, 237, 240, 240),
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            _buildPeriodToggle(filterDate),
          ],
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ringkasan ($subtitleStr)',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1A1A1A),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildGridItem(
                      onTap: () =>
                          context.read<MainNavigationProvider>().setIndex(1),
                      icon: Icons.local_shipping_rounded,
                      color: const Color(0xFF01579B),
                      title: 'Jumlah Transaksi',
                      value: '${stats.transaksi.today.count}',
                      subtitleStr: 'Transaksi DO $subtitleStr',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildGridItem(
                      onTap: () =>
                          context.read<MainNavigationProvider>().setIndex(1),
                      icon: Icons.scale_rounded,
                      color: const Color(0xFFE67E22),
                      title: 'Total Tonase',
                      value:
                          '${NumberFormat('#,###', 'id_ID').format(stats.transaksi.today.tonase)} Kg',
                      subtitleStr: 'Total Tonase DO',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: _buildGridItem(
                      onTap: () => context
                          .read<MainNavigationProvider>()
                          .setIndex(3, journalFilter: 'Pemasukan'),
                      icon: Icons.trending_up_rounded,
                      color: const Color(0xFF2E7D32),
                      title: 'Uang Masuk',
                      value: CurrencyFormatter.formatRupiah(
                        stats.pemasukan.today.total,
                      ),
                      subtitleStr: 'Total Pemasukan Kas',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildGridItem(
                      onTap: () => context
                          .read<MainNavigationProvider>()
                          .setIndex(3, journalFilter: 'Pengeluaran'),
                      icon: Icons.trending_down_rounded,
                      color: const Color(0xFFC62828),
                      title: 'Pengeluaran',
                      value: CurrencyFormatter.formatRupiah(
                        stats.pengeluaran.today.total,
                      ),
                      subtitleStr: 'Total Pengeluaran Kas',
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPeriodToggle(DateTime? currentFilterDate) {
    final bool isToday = currentFilterDate == null;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleItem(0, 'Hari Ini', isToday, currentFilterDate),
          _toggleItem(
            1,
            !isToday
                ? DateFormat('dd MMM yyyy', 'id_ID').format(currentFilterDate)
                : 'Pilih Tanggal',
            !isToday,
            currentFilterDate,
          ),
        ],
      ),
    );
  }

  Widget _toggleItem(
    int index,
    String label,
    bool active,
    DateTime? currentDate,
  ) {
    return GestureDetector(
      onTap: () => _onPeriodTap(index, currentDate),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (index == 1) ...[
              Icon(
                Icons.calendar_month_rounded,
                size: 12,
                color: active ? const Color(0xFF01579B) : Colors.white70,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: active ? const Color(0xFF01579B) : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
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
      shrinkWrap: true,
      clipBehavior: Clip.none,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      padding: EdgeInsets.zero,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        _MenuItem(
          label: 'Transaksi DO',
          icon: Icons.local_shipping_rounded,
          color: const Color(0xFF01579B),
          onTap: () async {
            context.read<TransaksiDoProvider>().markAsSeen();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TransaksiDoScreen()),
            );
            if (context.mounted) {
              final picked = context.read<GlobalFilterProvider>().selectedDate;
              context.read<DashboardProvider>().fetchSummary(filterDate: picked);
            }
          },
          badgeSelector: (c) => c.select<DashboardProvider, int>(
            (p) => p.summary?.stats.transaksi.today.count ?? 0,
          ),
        ),
        _MenuItem(
          label: 'Tambah Saldo',
          icon: Icons.add_to_photos_rounded,
          color: const Color(0xFFF39C12),
          onTap: () async {
            context.read<TambahSaldoProvider>().markAsSeen();
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TambahSaldoListScreen()),
            );
            if (context.mounted) {
              final picked = context.read<GlobalFilterProvider>().selectedDate;
              context.read<DashboardProvider>().fetchSummary(filterDate: picked);
            }
          },
          badgeSelector: (c) => c.select<DashboardProvider, int>(
            (p) => p.summary?.tambahSaldoTodayCount ?? 0,
          ),
        ),
        _MenuItem(
          label: 'Operasional',
          icon: Icons.payments_rounded,
          color: const Color(0xFFE74C3C),
          onTap: () async {
            context.read<ResourceProvider>().markAsSeen('operasional');
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const OperasionalScreen()),
            );
            if (context.mounted) {
              final picked = context.read<GlobalFilterProvider>().selectedDate;
              context.read<DashboardProvider>().fetchSummary(filterDate: picked);
            }
          },
          badgeSelector: (c) => c.select<DashboardProvider, int>(
            (p) => p.summary?.operasionalTodayCount ?? 0,
          ),
        ),
        _MenuItem(
          label: 'Penjual',
          icon: Icons.storefront_rounded,
          color: const Color(0xFF27AE60),
          onTap: () {
            context.read<ResourceProvider>().markAsSeen('penjual');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResourceListScreen(
                  title: 'Penjual',
                  resourceType: 'penjual',
                ),
              ),
            );
          },
          badgeSelector: (c) =>
              c.select<ResourceProvider, int>((p) => p.penjualCount),
        ),
        _MenuItem(
          label: 'Supir',
          icon: Icons.person_rounded,
          color: const Color(0xFFE67E22),
          onTap: () {
            context.read<ResourceProvider>().markAsSeen('supir');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResourceListScreen(
                  title: 'Supir',
                  resourceType: 'supir',
                ),
              ),
            );
          },
          badgeSelector: (c) =>
              c.select<ResourceProvider, int>((p) => p.supirCount),
        ),
        _MenuItem(
          label: 'Pekerja',
          icon: Icons.engineering_rounded,
          color: const Color(0xFF8E44AD),
          onTap: () {
            context.read<ResourceProvider>().markAsSeen('pekerja');
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ResourceListScreen(
                  title: 'Pekerja',
                  resourceType: 'pekerja',
                ),
              ),
            );
          },
          badgeSelector: (c) =>
              c.select<ResourceProvider, int>((p) => p.pekerjaCount),
        ),
        _MenuItem(
          label: 'Laporan',
          icon: Icons.auto_stories_rounded,
          color: const Color(0xFF2980B9),
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const FinanceJournalScreen()),
            );
            if (context.mounted) {
              final picked = context.read<GlobalFilterProvider>().selectedDate;
              context.read<DashboardProvider>().fetchSummary(filterDate: picked);
            }
          },
          badgeSelector: (c) => c.select<DashboardProvider, int>(
            (p) => p.summary?.jurnalTodayCount ?? 0,
          ),
        ),
        if (user.isSuperAdmin)
          _MenuItem(
            label: 'Pengaturan',
            icon: Icons.settings_rounded,
            color: const Color(0xFF7F8C8D),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const AppVersionSettingScreen(),
                ),
              );
            },
            badgeSelector: (c) => 0,
          ),
      ],
    );
  }
}

class _MenuItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int Function(BuildContext) badgeSelector;

  const _MenuItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.badgeSelector,
  });

  @override
  Widget build(BuildContext context) {
    final int count = badgeSelector(context);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 26, color: color),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: const TextStyle(
                      color: Color(0xFF263238),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
          if (count > 0)
            Positioned(
              top: 8,
              right: 8,
              child: _CountBadge(count: count, color: color),
            ),
        ],
      ),
    );
  }
}

class _SkeletonStats extends StatelessWidget {
  const _SkeletonStats();
  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        SkeletonLoader(width: double.infinity, height: 80, borderRadius: 16),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: SkeletonLoader(
                width: double.infinity,
                height: 105,
                borderRadius: 16,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: SkeletonLoader(
                width: double.infinity,
                height: 105,
                borderRadius: 16,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
