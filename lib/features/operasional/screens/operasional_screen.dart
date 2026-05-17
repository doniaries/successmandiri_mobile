import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';
import 'package:sawitappmobile/features/operasional/screens/add_operasional_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/operasional_detail_screen.dart';

class OperasionalScreen extends StatefulWidget {
  const OperasionalScreen({super.key});

  @override
  State<OperasionalScreen> createState() => _OperasionalScreenState();
}

class _OperasionalScreenState extends State<OperasionalScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedTab = 'Hari Ini';
  final List<String> _tabs = ['Hari Ini', 'Semua'];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      context.read<DashboardProvider>().fetchSummary();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<ResourceProvider>().fetchResources('operasional');
    }
  }

  Future<void> _refreshData() async {
    await context.read<ResourceProvider>().fetchResources(
      'operasional',
      refresh: true,
    );
  }

  List<Operasional> _getFilteredDateItems(List<Operasional> allItems, DateTime systemActiveDate) {
    return allItems.where((item) {
      if (_selectedDateRange != null) {
        final d = item.tanggal.toLocal();
        return d.isAfter(
              _selectedDateRange!.start.subtract(
                const Duration(seconds: 1),
              ),
            ) &&
            d.isBefore(
              _selectedDateRange!.end.add(const Duration(days: 1)),
            );
      }
      if (_selectedTab == 'Hari Ini') {
        return DateUtils.isSameDay(item.tanggal.toLocal(), systemActiveDate);
      }
      return true;
    }).toList();
  }

  List<Operasional> _getFilteredItems(List<Operasional> allItems, DateTime systemActiveDate) {
    List<Operasional> items = _getFilteredDateItems(allItems, systemActiveDate);
    if (_currentFilter != 'Semua') {
      items = items
          .where(
            (i) => i.operasional.toLowerCase() == _currentFilter.toLowerCase(),
          )
          .toList();
    }
    return items;
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Filter Riwayat Operasional',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(
                  Icons.date_range_rounded,
                  color: Color(0xFF01579B),
                ),
                title: const Text('Pilih Rentang Tanggal'),
                onTap: () async {
                  Navigator.pop(context);
                  final picked = await showDateRangePicker(
                    context: this.context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: _selectedDateRange,
                  );
                  if (picked != null) {
                    setState(() {
                      _selectedDateRange = picked;
                      _selectedTab = 'Semua';
                    });
                  }
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_view_month_rounded,
                  color: Color(0xFF01579B),
                ),
                title: const Text('Pilih Bulan Ini'),
                onTap: () {
                  Navigator.pop(context);
                  final now = DateTime.now();
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: DateTime(now.year, now.month, 1),
                      end: now,
                    );
                    _selectedTab = 'Semua';
                  });
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.calendar_month_rounded,
                  color: Color(0xFF01579B),
                ),
                title: const Text('Pilih Bulan Lalu'),
                onTap: () {
                  Navigator.pop(context);
                  final now = DateTime.now();
                  final lastMonth = DateTime(now.year, now.month - 1, 1);
                  final lastDayOfLastMonth = DateTime(now.year, now.month, 0);
                  setState(() {
                    _selectedDateRange = DateTimeRange(
                      start: lastMonth,
                      end: lastDayOfLastMonth,
                    );
                    _selectedTab = 'Semua';
                  });
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        color: const Color(0xFF01579B),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [_buildAppBar(), _buildSummaryHeader(), _buildListSection()],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_operasional',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddOperasionalScreen()),
        ),
        backgroundColor: const Color(0xFF01579B),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
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

  Widget _buildSummaryHeader() {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Consumer2<ResourceProvider, DashboardProvider>(
            builder: (context, resourceProvider, dashboardProvider, child) {
              final activeDateStr = dashboardProvider.summary?.systemActiveDate;
              final systemActiveDate = activeDateStr != null
                  ? DateTime.parse(activeDateStr)
                  : DateTime.now();

              final filteredDateItems = _getFilteredDateItems(resourceProvider.operasionals, systemActiveDate);
              double totalPemasukan = 0;
              double totalPengeluaran = 0;
              for (var item in filteredDateItems) {
                if (item.operasional.toLowerCase() == 'pemasukan') {
                  totalPemasukan += item.nominal;
                } else if (item.operasional.toLowerCase() == 'pengeluaran') {
                  totalPengeluaran += item.nominal;
                }
              }

              String dateText;
              if (_selectedDateRange != null) {
                dateText = '${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDateRange!.start)} - ${DateFormat('d MMMM yyyy', 'id_ID').format(_selectedDateRange!.end)}';
              } else if (_selectedTab == 'Hari Ini') {
                dateText = DateFormat('d MMMM yyyy', 'id_ID').format(systemActiveDate);
              } else {
                dateText = 'Semua Transaksi';
              }

              return Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Ringkasan Operasional',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                    Text(
                      dateText,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Pemasukan',
                            totalPemasukan,
                            Icons.trending_up_rounded,
                            const Color(0xFF27AE60),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Pengeluaran',
                            totalPengeluaran,
                            Icons.trending_down_rounded,
                            const Color(0xFFC0392B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          _buildDateTabs(),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildDateTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          ..._tabs.map((tab) {
            final isSelected =
                _selectedTab == tab && _selectedDateRange == null;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(tab),
                selected: isSelected,
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedTab = tab;
                      _selectedDateRange = null;
                    });
                  }
                },
                selectedColor: const Color(0xFF01579B),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isSelected ? const Color(0xFF01579B) : Colors.grey[300]!,
                  ),
                ),
                showCheckmark: false,
              ),
            );
          }),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}',
                ),
                selected: true,
                onSelected: (_) => setState(() => _selectedDateRange = null),
                selectedColor: const Color(0xFF01579B),
                labelStyle: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFF01579B)),
                ),
                showCheckmark: true,
              ),
            ),
        ],
      ),
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

  String _currentFilter = 'Semua';

  Widget _buildChip(String label) {
    bool isSelected = _currentFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _currentFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF01579B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF01579B) : Colors.grey[300]!,
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

  Widget _buildSummaryCard(
    String label,
    double amount,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.formatCompactRupiah(amount),
              style: const TextStyle(
                color: Color(0xFF2C3E50),
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListSection() {
    return Consumer2<ResourceProvider, DashboardProvider>(
      builder: (context, provider, dashboardProvider, child) {
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

        final items = _getFilteredItems(provider.operasionals, systemActiveDate);

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
              childCount:
                  items.length +
                  (provider.isFetchingMoreFor('operasional') ? 1 : 0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperasionalItem(Operasional item) {
    final isPengeluaran = item.operasional.toLowerCase() == 'pengeluaran';
    final color = isPengeluaran
        ? const Color(0xFFC62828)
        : const Color(0xFF2E7D32);

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
              builder: (context) => OperasionalDetailScreen(operasional: item),
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
                        item.keterangan ?? '-',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),
                      if (item.userName != null && item.userName!.isNotEmpty && item.userName != '-') ...[
                        const SizedBox(height: 2),
                        Text(
                          'Pencatat: ${item.userName}',
                          style: TextStyle(fontSize: 11, color: Colors.grey[500], fontWeight: FontWeight.w500),
                        ),
                      ],
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(item.tanggal),
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
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
