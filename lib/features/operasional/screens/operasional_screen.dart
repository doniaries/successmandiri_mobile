import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';

import 'package:sawitappmobile/features/operasional/screens/add_operasional_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_detail_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/shared/providers/global_filter_provider.dart';

class OperasionalScreen extends StatefulWidget {
  const OperasionalScreen({super.key});

  @override
  State<OperasionalScreen> createState() => _OperasionalScreenState();
}

class _OperasionalScreenState extends State<OperasionalScreen> {
  final ScrollController _scrollController = ScrollController();
  String _currentFilter = 'Semua';
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<ResourceProvider>();
      final globalFilter = context.read<GlobalFilterProvider>();
      final dashboardProvider = context.read<DashboardProvider>();
      
      final targetDate = globalFilter.selectedDate ??
          (dashboardProvider.summary?.systemActiveDate != null
              ? DateTime.parse(dashboardProvider.summary!.systemActiveDate)
              : DateTime.now());
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      // Selalu tarik data terbaru untuk tanggal aktif saat halaman dibuka
      provider.fetchResources('operasional', refresh: true, filters: {'tanggal': dateStr});

      if (dashboardProvider.summary == null) {
        dashboardProvider.fetchSummary();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
      if (_isFabExtended) setState(() => _isFabExtended = false);
    } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
      if (!_isFabExtended) setState(() => _isFabExtended = true);
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<ResourceProvider>();
      if (!provider.isLoading &&
          !provider.isFetchingMore('operasional') &&
          !provider.isRefreshingFor('operasional') &&
          provider.hasMore('operasional')) {
        provider.fetchResources('operasional');
      }
    }
  }

  Future<void> _refreshData() async {
    if (SyncService().isOffline) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<ResourceProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final globalFilter = context.read<GlobalFilterProvider>();

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Memulai Sinkronisasi Operasional...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );

    try {
      final targetDate = globalFilter.selectedDate ??
          (dashboardProvider.summary?.systemActiveDate != null
              ? DateTime.parse(dashboardProvider.summary!.systemActiveDate)
              : DateTime.now());
      final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);

      await SyncService().syncNow();
      await provider.syncMasterData();
      await provider.fetchResources('operasional', refresh: true, filters: {'tanggal': dateStr});
      await dashboardProvider.fetchSummary(filterDate: globalFilter.selectedDate);

      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi Operasional Selesai'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal sinkron: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Operasional> _getFilteredDateItems(
    List<Operasional> allItems,
    DateTime systemActiveDate,
    DateTime? filterDate,
  ) {
    // Backend sudah memfilter data berdasarkan tanggal.
    // Kita langsung kembalikan semua data agar tidak tersembunyi karena perbedaan zona waktu lokal,
    // sambil tetap memastikan item offline antrean juga muncul.
    return allItems;
  }

  List<Operasional> _getFilteredItems(
    List<Operasional> allItems,
    DateTime systemActiveDate,
    DateTime? filterDate,
  ) {
    List<Operasional> items =
        _getFilteredDateItems(allItems, systemActiveDate, filterDate);
    if (_currentFilter != 'Semua') {
      items = items
          .where(
            (i) => i.operasional.toLowerCase() == _currentFilter.toLowerCase(),
          )
          .toList();
    }
    return items;
  }

  void _showFilterSheet() async {
    final dashboardProvider = context.read<DashboardProvider>();
    final globalFilter = context.read<GlobalFilterProvider>();
    final activeDateStr = dashboardProvider.summary?.systemActiveDate;
    final systemActiveDate = activeDateStr != null
        ? DateTime.parse(activeDateStr)
        : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: globalFilter.selectedDate ?? systemActiveDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.day,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF01579B),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2C3E50),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      if (!mounted) return;
      globalFilter.setDate(picked);
      dashboardProvider.fetchSummary(filterDate: picked);
      
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      context.read<ResourceProvider>().fetchResources('operasional', refresh: true, filters: {'tanggal': dateStr});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        notificationPredicate: (notification) =>
            !SyncService().isOffline &&
            defaultScrollNotificationPredicate(notification),
        onRefresh: _refreshData,
        color: const Color(0xFF01579B),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            _buildSummaryHeader(),
            SliverToBoxAdapter(child: _buildFilterChips()),
            _buildListSection(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        isExtended: _isFabExtended,
        heroTag: 'operasional_fab',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddOperasionalScreen()),
        ),
        backgroundColor: const Color(0xFF01579B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Data', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF2C3E50),
      centerTitle: false,
      title: const Text(
        'Operasional',
        style: TextStyle(
          fontWeight: FontWeight.w900,
          fontSize: 22,
          color: Color(0xFF2C3E50),
        ),
      ),
      actions: [
        IconButton(
          onPressed: _showFilterSheet,
          icon: const Icon(Icons.calendar_month_rounded),
          tooltip: 'Filter Tanggal',
        ),
        IconButton(
          onPressed: _refreshData,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }

  /// Widget summary — pemasukan & pengeluaran dihitung dari data operasional
  /// lokal yang difilter berdasarkan tanggal aktif (bukan dari dashboard stats).
  Widget _buildSummaryHeader() {
    return SliverToBoxAdapter(
      child: Consumer2<ResourceProvider, GlobalFilterProvider>(
        builder: (context, resourceProvider, globalFilter, _) {
          final dashboardProvider = context.read<DashboardProvider>();
          final activeDateStr = dashboardProvider.summary?.systemActiveDate;
          final systemActiveDate = activeDateStr != null
              ? DateTime.parse(activeDateStr)
              : DateTime.now();

          final targetDate = globalFilter.selectedDate ?? systemActiveDate;
          final dateText =
              DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
          final isFilterActive = globalFilter.selectedDate != null &&
              !DateUtils.isSameDay(
                  globalFilter.selectedDate!, systemActiveDate);

          // Hitung dari data operasional lokal filtered by tanggal
          final filteredDateItems = _getFilteredDateItems(
            resourceProvider.operasionals,
            systemActiveDate,
            globalFilter.selectedDate,
          );
          double totalPemasukan = 0;
          double totalPengeluaran = 0;
          int countPemasukan = 0;
          int countPengeluaran = 0;
          for (final item in filteredDateItems) {
            if (item.operasional.toLowerCase() == 'pemasukan') {
              totalPemasukan += item.nominal;
              countPemasukan++;
            } else if (item.operasional.toLowerCase() == 'pengeluaran') {
              totalPengeluaran += item.nominal;
              countPengeluaran++;
            }
          }

          return Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF01579B), Color(0xFF0288D1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF01579B).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Label + tombol filter tanggal
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        isFilterActive
                            ? 'Filter Operasional'
                            : 'Ringkasan Operasional',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    InkWell(
                      onTap: _showFilterSheet,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 0.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.calendar_month_rounded,
                                color: Colors.white, size: 14),
                            const SizedBox(width: 6),
                            Text(
                              dateText,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.arrow_drop_down_rounded,
                                color: Colors.white, size: 16),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Pemasukan & Pengeluaran dari data operasional lokal
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        'Pemasukan',
                        totalPemasukan,
                        countPemasukan,
                        Icons.trending_up_rounded,
                        Colors.greenAccent,
                      ),
                    ),
                    Container(width: 1, height: 40, color: Colors.white24),
                    Expanded(
                      child: _buildStatItem(
                        'Pengeluaran',
                        totalPengeluaran,
                        countPengeluaran,
                        Icons.trending_down_rounded,
                        Colors.orangeAccent,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    double amount,
    int count,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatRupiah(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count transaksi',
          style: const TextStyle(
            color: Colors.white54,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          _buildChip('Semua'),
          const SizedBox(width: 8),
          _buildChip('Pemasukan'),
          const SizedBox(width: 8),
          _buildChip('Pengeluaran'),
        ],
      ),
    );
  }

  Widget _buildChip(String label) {
    final bool isSelected = _currentFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _currentFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF01579B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isSelected ? const Color(0xFF01579B) : Colors.grey[300]!,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF01579B).withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey[600],
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildListSection() {
    return Consumer3<ResourceProvider, DashboardProvider, GlobalFilterProvider>(
      builder: (context, provider, dashboardProvider, globalFilter, child) {
        if (provider.isLoading && provider.operasionals.isEmpty) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSkeletonItem(),
              childCount: 5,
            ),
          );
        }

        final activeDateStr = dashboardProvider.summary?.systemActiveDate;
        final systemActiveDate = activeDateStr != null
            ? DateTime.parse(activeDateStr)
            : DateTime.now();

        final items = _getFilteredItems(
          provider.operasionals,
          systemActiveDate,
          globalFilter.selectedDate,
        );

        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.receipt_long_rounded,
                    size: 64,
                    color: Colors.grey[200],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Belum ada data ${_currentFilter != 'Semua' ? _currentFilter : 'operasional'}',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                ],
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < items.length) {
                  return _buildOperasionalItem(items[index]);
                } else if (provider.isFetchingMoreFor('operasional')) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return null;
              },
              childCount: items.length +
                  (provider.isFetchingMoreFor('operasional') ? 1 : 0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperasionalItem(Operasional item) {
    final isPengeluaran = item.operasional.toLowerCase() == 'pengeluaran';
    final color =
        isPengeluaran ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  OperasionalDetailScreen(operasional: item),
            ),
          ),
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
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
                          fontSize: 15,
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
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey[600]),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm', 'id_ID')
                            .format(item.tanggal),
                        style: TextStyle(
                            fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
                Text(
                  CurrencyFormatter.formatRupiah(item.nominal),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonItem() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: const SkeletonLoader(
        height: 90,
        width: double.infinity,
        borderRadius: 16,
      ),
    );
  }
}
