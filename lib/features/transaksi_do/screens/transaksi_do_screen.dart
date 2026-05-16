import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/add_transaksi_do_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_detail_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/shared/widgets/live_date_time_widget.dart';

class TransaksiDoScreen extends StatefulWidget {
  const TransaksiDoScreen({super.key});

  @override
  State<TransaksiDoScreen> createState() => _TransaksiDoScreenState();
}

class _TransaksiDoScreenState extends State<TransaksiDoScreen> {
  final ScrollController _scrollController = ScrollController();
  String _selectedCategory = 'Semua';
  bool _isManualSyncing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransaksiDoProvider>().fetchTransactions();
      context.read<DashboardProvider>().fetchSummary();
      context.read<TransaksiDoProvider>().markAsSeen();
    });

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
        context.read<TransaksiDoProvider>().fetchMoreTransactions();
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _manualSync() async {
    if (_isManualSyncing) return;
    
    final txProvider = context.read<TransaksiDoProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() => _isManualSyncing = true);
    try {
      await SyncService().syncNow();
      
      await txProvider.fetchTransactions();
      await dashboardProvider.fetchSummary();
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi selesai'),
          backgroundColor: Color(0xFF0D47A1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Gagal sinkron: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!mounted) return;
          final txProvider = context.read<TransaksiDoProvider>();
          final dashboardProvider = context.read<DashboardProvider>();
          
          await SyncService().syncNow();
          await txProvider.fetchTransactions();
          await dashboardProvider.fetchSummary();
        },
        child: CustomScrollView(
          controller: _scrollController,
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: _buildSummaryHeader(),
            ),
            _buildPendingSyncBanner(),
            SliverToBoxAdapter(
              child: _buildCategoryFilter(),
            ),
            _buildTransactionList(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        heroTag: 'fab_transaksi_do',
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddTransaksiDoScreen()),
        ),
        backgroundColor: const Color(0xFF0D47A1),
        child: const Icon(Icons.add_rounded, color: Colors.white, size: 30),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      pinned: true,
      centerTitle: false,
      title: Row(
        children: [
          const Text(
            'Transaksi DO',
            style: TextStyle(
              color: Color(0xFF1E293B),
              fontWeight: FontWeight.w800,
              fontSize: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: LiveDateTimeWidget(),
            ),
          ),
        ],
      ),
      iconTheme: const IconThemeData(color: Color(0xFF1E293B)),
      actions: [
        IconButton(
          onPressed: _isManualSyncing ? null : _manualSync,
          icon: _isManualSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.sync_rounded),
          tooltip: 'Sinkron Manual',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildCategoryFilter() {
    final categories = ['Semua', 'Tunai', 'Transfer'];
    return Container(
      color: const Color(0xFFF8FAFC),
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: categories.map((cat) {
            final isSelected = _selectedCategory == cat;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(cat),
                selected: isSelected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
                backgroundColor: Colors.white,
                selectedColor: const Color(0xFF0D47A1),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : const Color(0xFF64748B),
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? Colors.transparent : Colors.grey[300]!,
                  ),
                ),
                showCheckmark: false,
                elevation: isSelected ? 4 : 0,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }


  Widget _buildSummaryHeader() {
    return Consumer<DashboardProvider>(
      builder: (context, provider, _) {
        final stats = provider.summary?.stats.transaksi.month;
        
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF1976D2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0D47A1).withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Ringkasan Bulan Ini',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now()),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Total Transaksi',
                      value: '${stats?.count ?? 0}',
                      icon: Icons.confirmation_number_rounded,
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white24,
                  ),
                  Expanded(
                    child: _buildMetricItem(
                      label: 'Total Nominal',
                      value: CurrencyFormatter.formatCompactRupiah(stats?.total ?? 0),
                      icon: Icons.account_balance_wallet_rounded,
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

  Widget _buildMetricItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildTransactionList() {
    return Consumer<TransaksiDoProvider>(
      builder: (context, provider, _) {
        if (provider.isLoading && provider.transactions.isEmpty) {
          return const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.errorMessage != null && provider.transactions.isEmpty) {
          return SliverFillRemaining(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      provider.errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => provider.fetchTransactions(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Coba Lagi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D47A1),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final filteredTransactions = provider.transactions.where((t) {
          if (_selectedCategory == 'Semua') return true;
          return t.caraBayar?.toLowerCase() == _selectedCategory.toLowerCase();
        }).toList();

        if (filteredTransactions.isEmpty) {
          return const SliverFillRemaining(
            child: Center(
              child: Text(
                'Tidak ada transaksi ditemukan',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                if (index < filteredTransactions.length) {
                  final tx = filteredTransactions[index];
                  return _buildTransactionCard(tx);
                }
                
                return provider.hasMore
                    ? const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    : const SizedBox.shrink();
              },
              childCount: filteredTransactions.length + (provider.hasMore ? 1 : 0),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingSyncBanner() {
    return ValueListenableBuilder<int>(
      valueListenable: SyncService().pendingSyncCount,
      builder: (context, count, _) {
        if (count == 0) return const SliverToBoxAdapter(child: SizedBox.shrink());
        
        return SliverToBoxAdapter(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange[200]!),
            ),
            child: Row(
              children: [
                const Icon(Icons.sync_problem_rounded, color: Colors.orange, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$count transaksi menunggu sinkronisasi',
                    style: TextStyle(
                      color: Colors.orange[900],
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => SyncService().syncNow(),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    foregroundColor: Colors.orange[900],
                  ),
                  child: const Text('Sinkron Sekarang'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTransactionCard(dynamic tx) {
    final isTunai = tx.caraBayar?.toLowerCase() == 'tunai';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
              builder: (context) => TransaksiDoDetailScreen(transaction: tx),
            ),
          ),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: (isTunai ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    isTunai ? Icons.payments_rounded : Icons.account_balance_rounded,
                    color: isTunai ? Colors.green[700] : Colors.blue[700],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tx.nomor,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${tx.penjualNama} • ${tx.supirNama}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      CurrencyFormatter.formatCompactRupiah(tx.subTotal),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(tx.tanggal),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
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
}

// _CategoryFilterDelegate dihapus — diganti SliverToBoxAdapter

