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

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final activeDateStr = context
          .read<DashboardProvider>()
          .summary
          ?.systemActiveDate;
      if (activeDateStr != null) {
        setState(() {
          _selectedSingleDate = DateTime.parse(activeDateStr);
        });
      } else {
        setState(() {
          _selectedSingleDate = DateTime.now();
        });
      }
      _refreshData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Map<String, dynamic> _buildApiFilters() {
    final Map<String, dynamic> filters = {};
    
    if (_selectedFilter != 'Semua') {
      filters['jenis_transaksi'] = _selectedFilter;
    }

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
      if (!provider.isLoading && provider.hasMore('jurnal_keuangan')) {
        provider.fetchResources('jurnal_keuangan', filters: _buildApiFilters());
      }
    }
  }

  void _refreshData() {
    if (!mounted) return;
    final provider = context.read<ResourceProvider>();
    provider.fetchResources('jurnal_keuangan', refresh: true, filters: _buildApiFilters());
    context.read<DashboardProvider>().fetchSummary(); // Sync real balance from backend
  }

  @override
  Widget build(BuildContext context) {
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
              _buildFilterInfoWidget(filteredItems),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: isInitialLoading
                      ? _buildSkeletonList()
                      : filteredItems.isEmpty
                      ? _buildEmptyState()
                      : ListView.separated(
                          controller: _scrollController,
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
    final items = provider.jurnalKeuangans;
    final targetDate = _selectedSingleDate ?? _getSystemActiveDate();
    final systemActiveDate = _getSystemActiveDate();

    // Hitung statistik berdasarkan tanggal aktif
    double displayIn = 0;
    double displayOut = 0;
    int filterCount = 0;

    for (var item in items) {
      if (DateUtils.isSameDay(item.tanggal.toLocal(), targetDate)) {
        filterCount++;
        if (item.jenisTransaksi == 'Pemasukan') {
          displayIn += item.nominal;
        } else {
          displayOut += item.nominal;
        }
      }
    }

    final isFilterActive = _selectedSingleDate != null && !DateUtils.isSameDay(_selectedSingleDate!, systemActiveDate);
    final dateText = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
    final labelSuffix = DateFormat('d MMM', 'id_ID').format(targetDate);

    if (isFilterActive) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Filter Laporan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Tanggal Laporan',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      InkWell(
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
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    dateText,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  height: 40,
                  width: 1,
                  color: Colors.white24,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                ),
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Total Transaksi',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$filterCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Container(
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
          const Text(
            'Total Saldo Kas',
            style: TextStyle(color: Colors.white70, fontSize: 13),
          ),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatRupiah(provider.saldoKas),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 28,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          InkWell(
            onTap: _showFilterSheet,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white30, width: 0.5),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down_rounded, color: Colors.white, size: 16),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
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
                  _refreshData();
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
      return DateUtils.isSameDay(item.tanggal.toLocal(), targetDate);
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
    return Center(
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
    );
  }

  Widget _buildFilterInfoWidget(List<dynamic> filtered) {
    if (_selectedSingleDate == null) return const SizedBox.shrink();
    final systemActiveDate = _getSystemActiveDate();
    if (DateUtils.isSameDay(_selectedSingleDate!, systemActiveDate)) {
      return const SizedBox.shrink();
    }

    final formattedFilterDate = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedSingleDate!);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF01579B).withValues(alpha: 0.15),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF01579B).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              color: Color(0xFF01579B),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menampilkan Filter Laporan',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formattedFilterDate,
                  style: const TextStyle(
                    color: Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Jumlah: ${filtered.length} Transaksi ditemukan',
                  style: const TextStyle(
                    color: Color(0xFF2E7D32),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () {
              setState(() {
                _selectedSingleDate = null;
              });
            },
            style: TextButton.styleFrom(
              foregroundColor: Colors.red[700],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: Colors.red[50],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            icon: const Icon(Icons.close_rounded, size: 16),
            label: const Text(
              'Reset',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
