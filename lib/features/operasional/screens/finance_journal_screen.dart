import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/screens/jurnal_keuangan_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';

import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/shared/providers/navigation_provider.dart';

class FinanceJournalScreen extends StatefulWidget {
  const FinanceJournalScreen({super.key});

  @override
  State<FinanceJournalScreen> createState() => _FinanceJournalScreenState();
}

class _FinanceJournalScreenState extends State<FinanceJournalScreen> {
  String _selectedFilter = 'Semua';
  final List<String> _filters = ['Semua', 'Pemasukan', 'Pengeluaran'];
  final ScrollController _scrollController = ScrollController();
  DateTime? _selectedSingleDate;
  DateTime? _lastDashboardFilterDate;
  bool _hasInitializedFilterDate = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final dashboardProvider = context.read<DashboardProvider>();
      
      // Prioritaskan filterDate dari dashboard jika ada
      final filterDate = dashboardProvider.filterDate;
      if (filterDate != null) {
        _selectedSingleDate = filterDate;
        _lastDashboardFilterDate = filterDate;
        _hasInitializedFilterDate = true;
      } else {
        final activeDateStr = dashboardProvider.summary?.systemActiveDate;
        _selectedSingleDate = activeDateStr != null
            ? DateTime.parse(activeDateStr)
            : DateTime.now();
        _hasInitializedFilterDate = true;
        _lastDashboardFilterDate = null;
      }

      // Fetch data sesuai tanggal yang sudah ditentukan
      context.read<ResourceProvider>().fetchResources(
        'jurnal_keuangan',
        refresh: true,
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

    final targetDate = _selectedSingleDate ?? _getSystemActiveDate();
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
    final dashboardProvider = context.watch<DashboardProvider>();
    final navProvider = context.watch<MainNavigationProvider>();
    
    if (navProvider.journalFilter != null) {
      final newFilter = navProvider.journalFilter!;
      if (_filters.contains(newFilter)) {
        _selectedFilter = newFilter;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<MainNavigationProvider>().clearJournalFilter();
      });
    }

    final dashboardFilterDate = dashboardProvider.filterDate;
    
    // Deteksi perubahan filterDate dari dashboard SETELAH inisialisasi awal
    if (_hasInitializedFilterDate && _lastDashboardFilterDate != dashboardFilterDate) {
      _lastDashboardFilterDate = dashboardFilterDate;
      
      final activeDateStr = dashboardProvider.summary?.systemActiveDate;
      final systemActiveDate = activeDateStr != null
          ? DateTime.parse(activeDateStr)
          : DateTime.now();
          
      _selectedSingleDate = dashboardFilterDate ?? systemActiveDate;
      
      // Trigger fetch saat filter dashboard berubah
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        context.read<ResourceProvider>().fetchResources(
          'jurnal_keuangan',
          refresh: true,
          filters: _buildApiFilters(),
        );
      });
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
          final filteredItems = _getFilteredItems(items);

          return Column(
            children: [
              isInitialLoading
                  ? _buildSkeletonHeader()
                  : _buildSummaryHeader(provider),
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

  Widget _buildSummaryHeader(ResourceProvider provider) {
    final targetDate = _selectedSingleDate ?? _getSystemActiveDate();

    // Hitung statistik berdasarkan tanggal filter aktif menggunakan ringkasan data dari server
    final double displayIn = provider.totalPemasukan;
    final double displayOut = provider.totalPengeluaran;
    final int filterCount = provider.jurnalCount;

    final dateText = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
    final labelSuffix = DateFormat('d MMM', 'id_ID').format(targetDate);

    final dashboardProv = context.watch<DashboardProvider>();
    final double currentSaldo = dashboardProv.summary?.saldo ?? 0.0;

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
          // Bagian 1: Saldo Perusahaan (Selalu Tampil & Tidak Terpengaruh Filter Tanggal)
          const Text(
            'Saldo Perusahaan',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.formatRupiah(currentSaldo),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // Divider tipis pemisah saldo dan informasi filter
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),

          // Bagian 2: Info Tanggal Laporan & Total Transaksi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Filter Tanggal Button
              Flexible(
                flex: 3,
                child: InkWell(
                  onTap: _showFilterSheet,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
                        const Icon(
                          Icons.calendar_month_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            dateText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Total Transaksi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Transaksi: $filterCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Bagian 3: Pemasukan & Pengeluaran (Menyesuaikan dengan tanggal filter)
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
              Container(
                width: 1,
                height: 35,
                color: Colors.white.withValues(alpha: 0.15),
              ),
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

  List<JurnalKeuangan> _getFilteredItems(List<JurnalKeuangan> items) {
    final targetDate = _selectedSingleDate ?? _getSystemActiveDate();
    return items.where((item) {
      final matchesDate = DateUtils.isSameDay(item.tanggal.toLocal(), targetDate);
      if (!matchesDate) return false;

      if (_selectedFilter == 'Semua') return true;
      return item.jenisTransaksi.toLowerCase() == _selectedFilter.toLowerCase();
    }).toList();
  }

  void _showFilterSheet() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedSingleDate ?? _getSystemActiveDate(),
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
      setState(() {
        _selectedSingleDate = picked;
      });
      _refreshData();
    }
  }

  Future<void> _handleDownloadPdf() async {
    final authProvider = context.read<AuthProvider>();
    final token = await authProvider.getAuthToken();
    if (token == null) return;

    final targetDate = _selectedSingleDate ?? _getSystemActiveDate();
    final dateStr = DateFormat('yyyy-MM-dd').format(targetDate);
    final startDateStr = dateStr;
    final endDateStr = dateStr;
    const rentang = 'hari_ini';

    final url = Uri.parse(
      '${ApiConstants.baseUrl.replaceAll('/api', '')}/jurnal-keuangan/rekap?'
      'token=${Uri.encodeComponent(token)}'
      '&start_date=$startDateStr'
      '&end_date=$endDateStr'
      '&rentang=$rentang'
      '&download=1',
    );

    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal mengunduh laporan PDF')),
        );
      }
    }
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
