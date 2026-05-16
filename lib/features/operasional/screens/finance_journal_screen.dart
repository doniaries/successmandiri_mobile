import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/auth/providers/auth_provider.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/screens/jurnal_keuangan_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shimmer/shimmer.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/shared/widgets/live_date_time_widget.dart';

class FinanceJournalScreen extends StatefulWidget {
  const FinanceJournalScreen({super.key});

  @override
  State<FinanceJournalScreen> createState() => _FinanceJournalScreenState();
}

class _FinanceJournalScreenState extends State<FinanceJournalScreen> {
  String _selectedFilter = 'Semua';
  String _selectedDateFilter = 'Hari Ini';
  final List<String> _filters = ['Semua', 'Pemasukan', 'Pengeluaran'];
  final List<String> _dateFilters = ['Hari Ini', 'Semua'];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      final provider = context.read<ResourceProvider>();
      if (!provider.isLoading && provider.hasMore('jurnal_keuangan')) {
        final Map<String, dynamic> filters = {};
        if (_selectedFilter != 'Semua') {
          filters['jenis_transaksi'] = _selectedFilter;
        }
        provider.fetchResources('jurnal_keuangan', filters: filters);
      }
    }
  }

  void _refreshData() {
    if (!mounted) return;
    final provider = context.read<ResourceProvider>();
    final Map<String, dynamic> filters = {};
    if (_selectedFilter != 'Semua') {
      filters['jenis_transaksi'] = _selectedFilter;
    }
    provider.fetchResources('jurnal_keuangan', refresh: true, filters: filters);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Row(
          children: [
            const Text('Laporan Keuangan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(width: 4),
            const Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: LiveDateTimeWidget(),
              ),
            ),
          ],
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.print_rounded),
            onPressed: _handlePrint,
            tooltip: 'Cetak Laporan',
          ),
          IconButton(
            icon: const Icon(Icons.filter_list_rounded),
            onPressed: () {
              // Future: Date Range Picker
            },
          ),
        ],
      ),
      body: Consumer<ResourceProvider>(
        builder: (context, provider, child) {
          final bool isInitialLoading = provider.isLoading && provider.jurnalKeuangans.isEmpty;

          final items = provider.jurnalKeuangans;
          final filteredItems = _getFilteredItems(items);

          return Column(
            children: [
              isInitialLoading ? _buildSkeletonHeader() : _buildSummaryHeader(provider),
              _buildDateTabs(),
              _buildFilterChips(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async => _refreshData(),
                  child: isInitialLoading
                      ? _buildSkeletonList()
                      : filteredItems.isEmpty
                          ? _buildEmptyState()
                          : ListView.separated(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredItems.length + (provider.hasMore('jurnal_keuangan') ? 1 : 0),
                              separatorBuilder: (context, index) => const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                if (index == filteredItems.length) {
                                  return const Center(child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ));
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
    final now = DateTime.now();

    // Hitung statistik hari ini
    double todayIn = 0;
    double todayOut = 0;
    for (var item in items) {
      if (DateUtils.isSameDay(item.tanggal.toLocal(), now)) {
        if (item.jenisTransaksi == 'Pemasukan') todayIn += item.nominal;
        else todayOut += item.nominal;
      }
    }

    final double displayIn = _selectedDateFilter == 'Hari Ini' ? todayIn : provider.totalPemasukan;
    final double displayOut = _selectedDateFilter == 'Hari Ini' ? todayOut : provider.totalPengeluaran;
    final String labelSuffix = _selectedDateFilter == 'Hari Ini' ? 'Hari Ini' : 'Bulan Ini';

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
          const Text('Total Saldo Kas', style: TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 4),
          Text(
            CurrencyFormatter.formatRupiah(provider.saldoKas),
            style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildSummaryItem(
                  'Masuk $labelSuffix',
                  displayIn,
                  Icons.arrow_downward_rounded,
                  Colors.greenAccent,
                ),
              ),
              Container(width: 1, height: 40, color: Colors.white24),
              Expanded(
                child: _buildSummaryItem(
                  'Keluar $labelSuffix',
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

  Widget _buildSummaryItem(String label, double amount, IconData icon, Color color) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          CurrencyFormatter.formatRupiah(amount),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
        ),
      ],
    );
  }

  Widget _buildDateTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _dateFilters.map((tab) {
          final isSelected = _selectedDateFilter == tab;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tab),
              selected: isSelected,
              onSelected: (val) {
                if (val) setState(() => _selectedDateFilter = tab);
              },
              selectedColor: const Color(0xFF01579B),
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: FontWeight.bold,
              ),
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              showCheckmark: false,
            ),
          );
        }).toList(),
      ),
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
                side: BorderSide(color: isSelected ? const Color(0xFF01579B) : Colors.grey[300]!),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildJournalItem(JurnalKeuangan item) {
    final isIncome = item.jenisTransaksi == 'Pemasukan';
    final iconColor = isIncome ? const Color(0xFF27AE60) : const Color(0xFFE74C3C);
    final bgColor = isIncome ? const Color(0xFFE8F5E9) : const Color(0xFFFFEBEE);

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
          MaterialPageRoute(builder: (context) => JurnalKeuanganDetailScreen(jurnal: item)),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            isIncome ? Icons.add_circle_outline_rounded : Icons.remove_circle_outline_rounded,
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
    return items.where((item) {
      if (_selectedDateFilter == 'Hari Ini') {
        return DateUtils.isSameDay(item.tanggal.toLocal(), DateTime.now());
      }
      return true;
    }).toList();
  }

  Future<void> _handlePrint() async {
    final authProvider = context.read<AuthProvider>();
    final token = await authProvider.getAuthToken(); // We need to add this to AuthProvider if not exists

    final url = Uri.parse(
      '${ApiConstants.baseUrl.replaceAll('/api', '')}/jurnal-keuangan/rekap?token=${Uri.encodeComponent(token!)}&download=1',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal membuka link print')));
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
          Icon(Icons.account_balance_wallet_rounded, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('Belum ada transaksi di periode ini', style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }
}

