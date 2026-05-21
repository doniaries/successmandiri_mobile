import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/add_transaksi_do_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/edit_transaksi_do_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/shared/widgets/active_company_header.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';

class TransaksiDoScreen extends StatefulWidget {
  const TransaksiDoScreen({super.key});

  @override
  State<TransaksiDoScreen> createState() => _TransaksiDoScreenState();
}

class _TransaksiDoScreenState extends State<TransaksiDoScreen> {
  final ScrollController _scrollController = ScrollController();
  DateTime? _selectedSingleDate;
  bool _isManualSyncing = false;
  DateTime? _lastDashboardFilterDate;
  bool _hasInitializedFilterDate = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final txProvider = context.read<TransaksiDoProvider>();
      final dashboardProvider = context.read<DashboardProvider>();

      if (txProvider.transactions.isEmpty) {
        txProvider.fetchTransactions();
      }
      if (dashboardProvider.summary == null) {
        dashboardProvider.fetchSummary();
      }
      txProvider.markAsSeen();
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
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _manualSync() async {
    if (_isManualSyncing) return;
    
    final txProvider = context.read<TransaksiDoProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final resourceProvider = context.read<ResourceProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() => _isManualSyncing = true);
    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Memulai Sinkronisasi DO...'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
    
    try {
      // 1. Process offline queue
      await SyncService().syncNow();
      
      // 2. Fetch latest master data from web
      await resourceProvider.syncMasterData();
      
      // 3. Fetch latest DO transactions
      await txProvider.fetchTransactions();
      
      // 4. Fetch latest dashboard summary
      await dashboardProvider.fetchSummary();
      
      scaffoldMessenger.showSnackBar(
        const SnackBar(
          content: Text('Sinkronisasi DO Selesai'),
          backgroundColor: Color(0xFF0D47A1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Gagal sinkron: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isManualSyncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dashboardProvider = context.watch<DashboardProvider>();
    final dashboardFilterDate = dashboardProvider.filterDate;
    
    if (!_hasInitializedFilterDate || _lastDashboardFilterDate != dashboardFilterDate) {
      _hasInitializedFilterDate = true;
      _lastDashboardFilterDate = dashboardFilterDate;
      
      final activeDateStr = dashboardProvider.summary?.systemActiveDate;
      final systemActiveDate = activeDateStr != null
          ? DateTime.parse(activeDateStr)
          : DateTime.now();
          
      _selectedSingleDate = dashboardFilterDate ?? systemActiveDate;
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: RefreshIndicator(
        onRefresh: () async {
          if (!mounted) return;
          final txProvider = context.read<TransaksiDoProvider>();
          final dashboardProvider = context.read<DashboardProvider>();
          final resourceProvider = context.read<ResourceProvider>();
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          
          scaffoldMessenger.showSnackBar(
            const SnackBar(
              content: Text('Memulai Sinkronisasi DO...'),
              duration: Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
          
          try {
            // 1. Process offline queue
            await SyncService().syncNow();
            
            // 2. Fetch latest master data from web
            await resourceProvider.syncMasterData();
            
            // 3. Fetch latest DO transactions
            await txProvider.fetchTransactions();
            
            // 4. Fetch latest dashboard summary
            await dashboardProvider.fetchSummary();
            
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Sinkronisasi DO Selesai'),
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
        },
        child: CustomScrollView(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const ActiveCompanyHeader(),
                  _buildSummaryHeader(),
                ],
              ),
            ),
            _buildPendingSyncBanner(),
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
    if (_isSearching) {
      return SliverAppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
        pinned: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            setState(() {
              _isSearching = false;
              _searchQuery = '';
              _searchController.clear();
            });
          },
        ),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Cari nomor DO, penjual, atau supir...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        actions: [
          if (_searchQuery.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded),
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            ),
          const SizedBox(width: 8),
        ],
      );
    }

    return SliverAppBar(
      backgroundColor: Colors.white,
      foregroundColor: const Color(0xFF1E293B),
      elevation: 0,
      pinned: true,
      centerTitle: false,
      title: const Text(
        'Transaksi DO',
        style: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w800,
          fontSize: 20,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search_rounded),
          onPressed: () {
            setState(() {
              _isSearching = true;
            });
          },
        ),
        IconButton(
          icon: const Icon(Icons.calendar_month_rounded),
          onPressed: _showFilterSheet,
          tooltip: 'Filter Tanggal',
        ),
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




  Widget _buildSummaryHeader() {
    return Consumer2<DashboardProvider, TransaksiDoProvider>(
      builder: (context, dashboardProvider, txProvider, _) {
        final transactions = txProvider.transactions;
        final activeDateStr = dashboardProvider.summary?.systemActiveDate;
        final systemActiveDate = activeDateStr != null 
            ? DateTime.parse(activeDateStr) 
            : DateTime.now();
        
        final targetDate = _selectedSingleDate ?? systemActiveDate;
        final activeCount = transactions.where((t) => DateUtils.isSameDay(t.tanggal.toLocal(), targetDate)).length;
        
        final dateText = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
        
        final isFilterActive = _selectedSingleDate != null && !DateUtils.isSameDay(_selectedSingleDate!, systemActiveDate);

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
                  Text(
                    isFilterActive ? 'Filter Transaksi' : 'Ringkasan Transaksi',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                  ),
                ],
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
                        const SizedBox(height: 4),
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
                            '$activeCount',
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
      },
    );
  }

  Widget _buildTransactionList() {
    return Consumer2<TransaksiDoProvider, DashboardProvider>(
      builder: (context, provider, dashboardProvider, _) {
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

        final activeDateStr = dashboardProvider.summary?.systemActiveDate;
        final systemActiveDate = activeDateStr != null 
            ? DateTime.parse(activeDateStr) 
            : DateTime.now();

        final targetDate = _selectedSingleDate ?? systemActiveDate;

        final filteredTransactions = provider.transactions.where((t) {
          // 1. Search Filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            final matchesSearch = t.nomor.toLowerCase().contains(query) ||
                (t.penjualNama?.toLowerCase().contains(query) ?? false) ||
                (t.displaySupirNama.toLowerCase().contains(query));
            if (!matchesSearch) return false;
          }

          // 2. Date Filter
          return DateUtils.isSameDay(t.tanggal.toLocal(), targetDate);
        }).toList();

        if (filteredTransactions.isEmpty) {
          return const SliverFillRemaining(
            hasScrollBody: false,
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
                return _buildTransactionCard(filteredTransactions[index]);
              },
              childCount: filteredTransactions.length,
            ),
          ),
        );
      },
    );
  }

  void _showFilterSheet() async {
    final dashboardProvider = context.read<DashboardProvider>();
    final activeDateStr = dashboardProvider.summary?.systemActiveDate;
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
              primary: Color(0xFF0D47A1),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
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

  Future<void> _confirmDelete(dynamic tx) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            const Text(
              'Hapus Transaksi',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus transaksi DO #${tx.nomor} senilai ${CurrencyFormatter.formatRupiah(tx.subTotal)}?',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final provider = context.read<TransaksiDoProvider>();
      final scaffoldMessenger = ScaffoldMessenger.of(context);
      final success = await provider.deleteTransaction(tx.id);
      
      if (mounted) {
        if (success) {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Transaksi DO #${tx.nomor} berhasil dihapus'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
          context.read<DashboardProvider>().fetchSummary();
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text(provider.errorMessage ?? 'Gagal menghapus transaksi'),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }

  Widget _buildTransactionCard(dynamic tx) {
    final isTunai = tx.caraBayar?.toLowerCase() == 'tunai';
    
    return Dismissible(
      key: Key('dismiss_do_${tx.id}'),
      direction: DismissDirection.endToStart, // Hanya geser ke kiri
      confirmDismiss: (direction) async {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'Hapus Transaksi',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            content: Text(
              'Apakah Anda yakin ingin menghapus transaksi DO #${tx.nomor} senilai ${CurrencyFormatter.formatRupiah(tx.subTotal)}?',
              style: const TextStyle(fontSize: 14),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Batal', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Hapus', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
        return confirmed ?? false;
      },
      onDismissed: (direction) async {
        final provider = context.read<TransaksiDoProvider>();
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final success = await provider.deleteTransaction(tx.id);
        
        if (mounted) {
          if (success) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Transaksi DO #${tx.nomor} berhasil dihapus'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.read<DashboardProvider>().fetchSummary();
          } else {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text(provider.errorMessage ?? 'Gagal menghapus transaksi'),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      },
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.redAccent,
          borderRadius: BorderRadius.circular(20),
        ),
        alignment: Alignment.centerRight,
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Geser untuk Hapus',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_sweep_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: Container(
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
            onTap: () async {
              final txProvider = context.read<TransaksiDoProvider>();
              final dashProvider = context.read<DashboardProvider>();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditTransaksiDoScreen(transaction: tx, popParent: false),
                ),
              );
              if (mounted) {
                txProvider.fetchTransactions();
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
                      // Sisi Kiri: Icon + Nomor DO
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isTunai ? Colors.green : Colors.blue).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                isTunai ? Icons.payments_rounded : Icons.account_balance_rounded,
                                color: isTunai ? Colors.green[700] : Colors.blue[700],
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tx.nomor,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E293B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                              color: isTunai ? Colors.green[700] : Colors.blue[700],
                            ),
                          ),
                          Text(
                            'Sub: ${CurrencyFormatter.formatRupiah(tx.subTotal)}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[500],
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
                              children: [
                                Icon(Icons.access_time_rounded, size: 12, color: Colors.grey[400]),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(tx.tanggal),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Tombol Aksi (Edit & Hapus) dengan Desain Compact Chips
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Material(
                            color: Colors.blueAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () async {
                                final txProvider = context.read<TransaksiDoProvider>();
                                final dashProvider = context.read<DashboardProvider>();
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => EditTransaksiDoScreen(transaction: tx, popParent: false),
                                  ),
                                );
                                if (mounted) {
                                  txProvider.fetchTransactions();
                                  dashProvider.fetchSummary();
                                }
                              },
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.edit_rounded,
                                  color: Colors.blueAccent,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Material(
                            color: Colors.redAccent.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            child: InkWell(
                              onTap: () => _confirmDelete(tx),
                              borderRadius: BorderRadius.circular(10),
                              child: const Padding(
                                padding: EdgeInsets.all(8),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  color: Colors.redAccent,
                                  size: 18,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// _CategoryFilterDelegate dihapus — diganti SliverToBoxAdapter

