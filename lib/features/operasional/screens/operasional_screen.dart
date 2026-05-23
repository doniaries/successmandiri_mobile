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
import 'package:sawitappmobile/core/services/sync_service.dart';

class OperasionalScreen extends StatefulWidget {
  const OperasionalScreen({super.key});

  @override
  State<OperasionalScreen> createState() => _OperasionalScreenState();
}

class _OperasionalScreenState extends State<OperasionalScreen> {
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
      
      final provider = context.read<ResourceProvider>();
      if (provider.operasionals.isEmpty) {
        _refreshData();
      } else {
        final dashboardProvider = context.read<DashboardProvider>();
        if (dashboardProvider.summary == null) {
          dashboardProvider.fetchSummary();
        }
      }
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
    
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Memulai Sinkronisasi Operasional...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    try {
      // 1. Process offline queue
      await SyncService().syncNow();
      
      // 2. Fetch latest master data from web
      await provider.syncMasterData();
      
      // 3. Fetch latest operational data
      await provider.fetchResources(
        'operasional',
        refresh: true,
      );
      
      // 4. Fetch latest dashboard summary
      await dashboardProvider.fetchSummary();
      
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

  List<Operasional> _getFilteredDateItems(List<Operasional> allItems, DateTime systemActiveDate) {
    final targetDate = _selectedSingleDate ?? systemActiveDate;
    return allItems.where((item) {
      return DateUtils.isSameDay(item.tanggal.toLocal(), targetDate);
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

  void _showFilterSheet() async {
    final activeDateStr = context
        .read<DashboardProvider>()
        .summary
        ?.systemActiveDate;
    final systemActiveDate = activeDateStr != null
        ? DateTime.parse(activeDateStr)
        : DateTime.now();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedSingleDate ?? systemActiveDate,
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: RefreshIndicator(
        notificationPredicate: (notification) => !SyncService().isOffline && defaultScrollNotificationPredicate(notification),
        onRefresh: _refreshData,
        color: const Color(0xFF01579B),
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),

            _buildSummaryHeader(),
            _buildListSection(),
          ],
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

              final targetDate = _selectedSingleDate ?? systemActiveDate;
              final dateText = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
              
              final isFilterActive = _selectedSingleDate != null && !DateUtils.isSameDay(_selectedSingleDate!, systemActiveDate);

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
                    Text(
                      isFilterActive ? 'Filter Operasional' : 'Ringkasan Operasional',
                      style: const TextStyle(
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
                                'Tanggal Transaksi',
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
                                  '${filteredDateItems.length}',
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
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryItemInsideCard(
                            'Pemasukan',
                            totalPemasukan,
                            Icons.trending_up_rounded,
                            Colors.greenAccent,
                          ),
                        ),
                        Container(width: 1, height: 40, color: Colors.white24),
                        Expanded(
                          child: _buildSummaryItemInsideCard(
                            'Pengeluaran',
                            totalPengeluaran,
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
          _buildFilterChips(),
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
                        item.namaPihak != null && item.namaPihak!.isNotEmpty && item.namaPihak != '-'
                            ? (item.keterangan != null && item.keterangan!.isNotEmpty && item.keterangan != '-'
                                ? '${item.namaPihak} (${item.keterangan})'
                                : item.namaPihak!)
                            : (item.keterangan ?? '-'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                      ),

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

  Widget _buildSummaryItemInsideCard(
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
}
