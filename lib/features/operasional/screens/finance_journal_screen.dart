import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/screens/jurnal_keuangan_detail_screen.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/screens/jurnal_keuangan_pdf_preview_screen.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';
import 'package:sawitappmobile/shared/providers/global_filter_provider.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';

class FinanceJournalScreen extends StatefulWidget {
  const FinanceJournalScreen({super.key});

  @override
  State<FinanceJournalScreen> createState() => _FinanceJournalScreenState();
}

class _FinanceJournalScreenState extends State<FinanceJournalScreen> {
  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'Pemasukan', 'Pengeluaran'];
  final ScrollController _scrollController = ScrollController();
  DateTime? _lastGlobalDate;
  bool _hasInitializedGlobalDate = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      
      // Fetch data sesuai tanggal yang sudah ditentukan (tanpa memaksa dari API)
      context.read<ResourceProvider>().fetchResources(
        'jurnal_keuangan',
        refresh: false,
        filters: _buildApiFilters(),
      );
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildApiFilters() {
    final Map<String, dynamic> filters = {};

    final globalFilter = context.read<GlobalFilterProvider>();
    final targetDate = globalFilter.selectedDate ?? _getSystemActiveDate();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    filters['start_date'] = dateStr;
    filters['end_date'] = dateStr;
    
    return filters;
  }

  DateTime _getSystemActiveDate() {
    final activeDateStr = context
        .read<DashboardProvider>()
        .summary
        ?.systemActiveDate;
    return activeDateStr != null
        ? DateTime.parse(activeDateStr)
        : DateTime.now();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<ResourceProvider>();
      if (!provider.isLoading &&
          !provider.isFetchingMore('jurnal_keuangan') &&
          !provider.isRefreshingFor('jurnal_keuangan') &&
          provider.hasMore('jurnal_keuangan')) {
        provider.fetchResources('jurnal_keuangan', filters: _buildApiFilters());
      }
    }
  }

  Future<void> _refreshData() async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final provider = context.read<ResourceProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Memulai Sinkronisasi Laporan...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    try {
      // 1. Process offline queue
      await SyncService().syncNow();
      
      // 2. Fetch latest master data from web
      await provider.syncMasterData();
      
      // 3. Fetch latest financial journal data
      await provider.fetchResources('jurnal_keuangan', refresh: true, filters: _buildApiFilters());
      
      // 4. Fetch latest dashboard summary
      await dashboardProvider.fetchSummary();
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi Laporan Selesai'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Gagal sinkron: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final navProvider = context.watch<MainNavigationProvider>();
    final globalFilter = context.watch<GlobalFilterProvider>();
    
    if (navProvider.journalFilter != null) {
      final newFilter = navProvider.journalFilter!;
      if (_filters.contains(newFilter)) {
        _selectedFilter = newFilter;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<MainNavigationProvider>().clearJournalFilter();
      });
    }

    if (_hasInitializedGlobalDate && _lastGlobalDate != globalFilter.selectedDate) {
      _lastGlobalDate = globalFilter.selectedDate;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ResourceProvider>().fetchResources(
          'jurnal_keuangan',
          refresh: true,
          filters: _buildApiFilters(),
        );
      });
    } else if (!_hasInitializedGlobalDate) {
      _lastGlobalDate = globalFilter.selectedDate;
      _hasInitializedGlobalDate = true;
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Laporan Keuangan',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _handleDownloadPdf,
            tooltip: 'Download PDF',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _showFilterSheet,
            tooltip: 'Filter Tanggal',
          ),
        ],
      ),
      body: Consumer<ResourceProvider>(
        builder: (context, provider, child) {
          final bool isInitialLoading =
              provider.isLoading && provider.jurnalKeuangans.isEmpty;

          final items = provider.jurnalKeuangans;
          final filteredItems = _getFilteredItems(items, globalFilter.selectedDate);

          return Column(
            children: [
              isInitialLoading
                  ? _buildSkeletonHeader()
                  : _buildSummaryHeader(globalFilter.selectedDate),
              _buildFilterChips(),
              Expanded(
                child: RefreshIndicator(
                  notificationPredicate: (notification) => !SyncService().isOffline && defaultScrollNotificationPredicate(notification),
                  onRefresh: () async => _refreshData(),
                  child: isInitialLoading
                      ? _buildSkeletonList()
                      : filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          itemCount:
                              filteredItems.length +
                              (provider.hasMore('jurnal_keuangan') ? 1 : 0),
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            if (index == filteredItems.length) {
                              return const Center(
                                child: Padding(
                                  padding: EdgeInsets.all(16.0),
                                  child: CircularProgressIndicator(),
                                ),
                              );
                            }
                            return _buildJournalItem(filteredItems[index]);
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryHeader(DateTime? selectedDate) {
    final targetDate = selectedDate ?? _getSystemActiveDate();
    final systemActiveDate = _getSystemActiveDate();
    final isFilterActive = selectedDate != null &&
        !DateUtils.isSameDay(selectedDate, systemActiveDate);
    final dateText = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
    final labelSuffix = DateFormat('d MMM', 'id_ID').format(targetDate);

    return Consumer<DashboardProvider>(
      builder: (context, dashboardProvider, _) {
        // Data pemasukan/pengeluaran dari dashboard stats — sama persis dengan widget dashboard
        final double displayIn =
            dashboardProvider.summary?.stats.pemasukan.today.total ?? 0.0;
        final double displayOut =
            dashboardProvider.summary?.stats.pengeluaran.today.total ?? 0.0;
        final double currentSaldo =
            dashboardProvider.summary?.saldo ?? 0.0;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF01579B), Color(0xFF0288D1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF01579B).withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            children: [
              // Saldo Kas
              Text(
                isFilterActive ? 'Laporan Keuangan' : 'Total Saldo Kas',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                isFilterActive
                    ? dateText
                    : CurrencyFormatter.formatRupiah(currentSaldo),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 10),
              InkWell(
                onTap: _showFilterSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white30, width: 0.5),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_month_rounded,
                          color: Colors.white, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('dd MMMM yyyy', 'id_ID')
                            .format(targetDate),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_drop_down_rounded,
                          color: Colors.white, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Pemasukan & Pengeluaran dari dashboard stats
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Masuk ($labelSuffix)',
                      displayIn,
                      Icons.arrow_downward_rounded,
                      Colors.greenAccent,
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _buildSummaryItem(
                      'Keluar ($labelSuffix)',
                      displayOut,
                      Icons.arrow_upward_rounded,
                      Colors.orangeAccent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSummaryItem(
    String label,
    double amount,
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
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: _filters.map((filter) {
          final isSelected = _selectedFilter == filter;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(filter),
              selected: isSelected,
              onSelected: (val) {
                if (val) {
                  setState(() => _selectedFilter = filter);
                }
              },
              selectedColor: const Color(0xFF01579B).withValues(alpha: 0.1),
              checkmarkColor: const Color(0xFF01579B),
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFF01579B) : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected
                      ? const Color(0xFF01579B)
                      : Colors.grey[300]!,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJournalItem(JurnalKeuangan item) {
    final isIncome = item.jenisTransaksi == 'Pemasukan';
    final iconColor = isIncome
        ? const Color(0xFF27AE60)
        : const Color(0xFFE74C3C);
    final bgColor = isIncome
        ? const Color(0xFFE8F5E9)
        : const Color(0xFFFFEBEE);

    return Container(
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
      child: ListTile(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => JurnalKeuanganDetailScreen(jurnal: item),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isIncome
                ? Icons.add_circle_outline_rounded
                : Icons.remove_circle_outline_rounded,
            color: iconColor,
            size: 24,
          ),
        ),
        title: Text(
          item.kategori == 'Operasional' ? item.subKategori : item.kategori,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              item.keterangan ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 4),
            Text(
              DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(item.tanggal),
            ),
          ],
        ),
        trailing: Text(
          '${isIncome ? '+' : '-'} ${CurrencyFormatter.formatRupiah(item.nominal)}',
          style: TextStyle(
            color: iconColor,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ),
    );
  }

  List<JurnalKeuangan> _getFilteredItems(List<JurnalKeuangan> items, DateTime? selectedDate) {
    final targetDate = selectedDate ?? _getSystemActiveDate();
    return items.where((item) {
      final matchesDate = DateUtils.isSameDay(item.tanggal.toLocal(), targetDate);
      if (!matchesDate) return false;

      if (_selectedFilter == 'Semua') return true;
      return item.jenisTransaksi.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();
  }

  void _showFilterSheet() async {
    final globalFilter = context.read<GlobalFilterProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: globalFilter.selectedDate ?? _getSystemActiveDate(),
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
      globalFilter.setDate(picked);
      dashboardProvider.fetchSummary(filterDate: picked);
      _refreshData();
    }
  }

  Future<void> _handleDownloadPdf() async {
    final globalFilter = context.read<GlobalFilterProvider>();
    final targetDate = globalFilter.selectedDate ?? _getSystemActiveDate();
    
    if (!mounted) return;
    
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => JurnalKeuanganPdfPreviewScreen(
          targetDate: targetDate,
        ),
      ),
    );
  }

  Widget _buildSkeletonHeader() {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: 160,
        margin: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 6,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            height: 80,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  'Belum ada transaksi di periode ini',
                  style: TextStyle(color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }


}
