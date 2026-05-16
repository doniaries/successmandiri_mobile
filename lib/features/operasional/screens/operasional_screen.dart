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
import 'package:sawitappmobile/shared/widgets/live_date_time_widget.dart';

class OperasionalScreen extends StatefulWidget {
  const OperasionalScreen({super.key});

  @override
  State<OperasionalScreen> createState() => _OperasionalScreenState();
}

class _OperasionalScreenState extends State<OperasionalScreen> {
  final ScrollController _scrollController = ScrollController();

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
    await context.read<ResourceProvider>().fetchResources('operasional', refresh: true);
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
          MaterialPageRoute(builder: (context) => const AddOperasionalScreen())
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
        const Center(child: LiveDateTimeWidget()),
        const SizedBox(width: 8),
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
          Consumer<DashboardProvider>(
            builder: (context, dashboardProvider, child) {
              final stats = dashboardProvider.summary?.stats;
              final totalPemasukan = stats?.pemasukan.month.total ?? 0;
              final totalPengeluaran = stats?.pengeluaran.month.total ?? 0;

              return Container(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Ringkasan Operasional', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50))),
                    Text(
                      DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now()),
                      style: TextStyle(color: Colors.grey[500], fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Row(
                  children: [
                    Expanded(
                      child: _buildSummaryCard(
                        'Pemasukan', 
                        totalPemasukan, 
                        Icons.trending_up_rounded, 
                        const Color(0xFF27AE60)
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildSummaryCard(
                        'Pengeluaran', 
                        totalPengeluaran, 
                        Icons.trending_down_rounded, 
                        const Color(0xFFC0392B)
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
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFF01579B).withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ] : null,
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

  Widget _buildSummaryCard(String label, double amount, IconData icon, Color color) {
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
    return Consumer<ResourceProvider>(
      builder: (context, provider, child) {
        if (provider.isLoading && provider.operasionals.isEmpty) {
          return SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildSkeletonItem(),
              childCount: 5,
            ),
          );
        }

        var items = provider.operasionals;
        if (_currentFilter != 'Semua') {
          items = items.where((i) => i.operasional.toLowerCase() == _currentFilter.toLowerCase()).toList();
        }

        if (items.isEmpty) {
          return SliverFillRemaining(
            hasScrollBody: false,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long_rounded, size: 64, color: Colors.grey[200]),
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
              childCount: items.length + (provider.isFetchingMoreFor('operasional') ? 1 : 0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOperasionalItem(Operasional item) {
    final isPengeluaran = item.operasional.toLowerCase() == 'pengeluaran';
    final color = isPengeluaran ? const Color(0xFFC62828) : const Color(0xFF2E7D32);

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
            MaterialPageRoute(builder: (context) => OperasionalDetailScreen(operasional: item))
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
                    isPengeluaran ? Icons.trending_down_rounded : Icons.trending_up_rounded,
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
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('dd MMM yyyy, HH:mm').format(item.tanggal),
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
      child: const SkeletonLoader(height: 90, width: double.infinity, borderRadius: 16),
    );
  }
}

