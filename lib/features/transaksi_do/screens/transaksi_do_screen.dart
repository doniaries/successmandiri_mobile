import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/shared/providers/global_filter_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/add_transaksi_do_screen.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/transaksi_do_detail_screen.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/core/utils/pdf_generator.dart';
import 'package:printing/printing.dart';
class TransaksiDoScreen extends StatefulWidget {
  const TransaksiDoScreen({super.key});

  @override
  State<TransaksiDoScreen> createState() => _TransaksiDoScreenState();
}

class _TransaksiDoScreenState extends State<TransaksiDoScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isManualSyncing = false;
  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isFabExtended = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.userScrollDirection == ScrollDirection.reverse) {
        if (_isFabExtended) setState(() => _isFabExtended = false);
      } else if (_scrollController.position.userScrollDirection == ScrollDirection.forward) {
        if (!_isFabExtended) setState(() => _isFabExtended = true);
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final txProvider = context.read<TransaksiDoProvider>();
      final dashboardProvider = context.read<DashboardProvider>();

      if (txProvider.transactions.isEmpty) {
        final activeDateStr = dashboardProvider.summary?.systemActiveDate;
        final systemActiveDate = activeDateStr != null 
            ? DateTime.parse(activeDateStr) 
            : DateTime.now();
        final globalFilter = context.read<GlobalFilterProvider>();
        final targetDate = globalFilter.selectedDate ?? systemActiveDate;
        
        txProvider.fetchTransactions(
          tanggal: DateFormat('yyyy-MM-dd').format(targetDate),
        );
      }
      if (dashboardProvider.summary == null) {
        dashboardProvider.fetchSummary();
      }
      txProvider.markAsSeen();
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _manualSync() async {
    if (SyncService().isOffline) return;
    if (_isManualSyncing) return;
    
    final txProvider = context.read<TransaksiDoProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
    final resourceProvider = context.read<ResourceProvider>();
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    setState(() => _isManualSyncing = true);
    try {
      // 1. Process offline queue
      await SyncService().syncNow();
      
      // 2. Fetch latest master data from web
      await resourceProvider.syncMasterData();
      
      // 3. Fetch latest DO transactions
      await txProvider.fetchTransactions();
      
      // 4. Fetch latest dashboard summary
      await dashboardProvider.fetchSummary();
      
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

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      floatingActionButton: FloatingActionButton.extended(
        isExtended: _isFabExtended,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransaksiDoScreen()),
          );
        },
        backgroundColor: const Color(0xFF01579B),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Tambah DO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: RefreshIndicator(
        notificationPredicate: (notification) => !SyncService().isOffline && defaultScrollNotificationPredicate(notification),
        onRefresh: () async {
          if (!mounted) return;
          if (SyncService().isOffline) return;
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
            SliverToBoxAdapter(child: _buildSummaryHeader()),
            _buildPendingSyncBanner(),
            _buildTransactionList(),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
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
    return Consumer3<TransaksiDoProvider, GlobalFilterProvider, ResourceProvider>(
      builder: (context, txProvider, globalFilter, resourceProvider, _) {
        final dashboardProvider = context.read<DashboardProvider>();
        final activeDateStr = dashboardProvider.summary?.systemActiveDate;
        final systemActiveDate = activeDateStr != null
            ? DateTime.parse(activeDateStr)
            : DateTime.now();
        final targetDate = globalFilter.selectedDate ?? systemActiveDate;
        final dateText = DateFormat('dd MMMM yyyy', 'id_ID').format(targetDate);
        final isFilterActive = globalFilter.selectedDate != null &&
            !DateUtils.isSameDay(globalFilter.selectedDate!, systemActiveDate);

        // Hitung dari transaksi DO yang sudah difilter tanggal
        final filteredTx = txProvider.transactions.where(
          (t) => DateUtils.isSameDay(t.tanggal.toLocal(), targetDate),
        ).toList();
        final totalTonase = filteredTx.fold<double>(
          0, (sum, t) => sum + t.tonase);
        final totalNilaiDo = filteredTx.fold<double>(
          0, (sum, t) => sum + t.subTotal);

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 12, 16, 20),
          padding: const EdgeInsets.all(20),
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
              // Baris atas: label + filter tanggal
              Row(
                children: [
                  const Icon(Icons.local_shipping_rounded,
                      color: Colors.white70, size: 16),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      isFilterActive
                          ? 'Filter Transaksi DO'
                          : 'Ringkasan DO Hari Ini',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: _showFilterSheet,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
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
                              color: Colors.white, size: 13),
                          const SizedBox(width: 5),
                          Text(
                            dateText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(width: 3),
                          const Icon(Icons.arrow_drop_down_rounded,
                              color: Colors.white, size: 15),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Baris stats: Tonase | Nilai DO
              Row(
                children: [
                  Expanded(
                    child: _buildDoStatItem(
                      'Total Tonase',
                      '${NumberFormat.decimalPattern('id').format(totalTonase)} kg',
                      const Icon(Icons.scale_rounded, color: Colors.lightBlueAccent, size: 18),
                    ),
                  ),
                  Container(width: 1, height: 40, color: Colors.white24),
                  Expanded(
                    child: _buildDoStatItem(
                      'Nilai DO',
                      CurrencyFormatter.formatRupiah(totalNilaiDo),
                      const Text(
                        'Rp',
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
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

  Widget _buildDoStatItem(
    String label,
    String value,
    Widget iconWidget,
  ) {
    return Column(
      children: [
        iconWidget,
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }


  Widget _buildTransactionList() {
    return Consumer3<TransaksiDoProvider, DashboardProvider, GlobalFilterProvider>(
      builder: (context, provider, dashboardProvider, globalFilter, _) {
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

        final targetDate = globalFilter.selectedDate ?? systemActiveDate;

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
      if (!mounted) return;
      globalFilter.setDate(picked);
      dashboardProvider.fetchSummary(filterDate: picked);
      
      final formattedDate = DateFormat('yyyy-MM-dd').format(picked);
      context.read<TransaksiDoProvider>().fetchTransactions(tanggal: formattedDate);
    }
  }

  Widget _buildPendingSyncBanner() {
    return const SliverToBoxAdapter(child: SizedBox.shrink());
  }

  Widget _buildTransactionCard(dynamic tx) {
    final String caraBayarStr = tx.caraBayar?.toLowerCase() ?? 'tunai';
    
    MaterialColor statusColor;
    IconData statusIcon;
    
    if (caraBayarStr == 'belum dibayar') {
      statusColor = Colors.red;
      statusIcon = Icons.warning_rounded;
    } else if (caraBayarStr == 'tunai') {
      statusColor = Colors.green;
      statusIcon = Icons.payments_rounded;
    } else if (caraBayarStr == 'cair di luar' || caraBayarStr == 'cair diluar') {
      statusColor = Colors.orange;
      statusIcon = Icons.outbound_rounded;
    } else {
      statusColor = Colors.blue;
      statusIcon = Icons.account_balance_rounded;
    }
    
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
          border: Border.all(color: Colors.grey[300]!, width: 1.5),
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
                  builder: (context) => TransaksiDoDetailScreen(transaction: tx),
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
                      // Sisi Kiri: Icon + Nomor DO + Cara Bayar
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: statusColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                statusIcon,
                                color: statusColor[700],
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _getShortDoNumber(tx.nomor),
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Color(0xFF1E293B),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    (tx.caraBayar ?? 'Tunai').toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: statusColor[600],
                                    ),
                                  ),
                                ],
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
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: statusColor[700],
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
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 14, color: Colors.blueGrey[400]),
                                    const SizedBox(width: 4),
                                    Text(
                                      DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(tx.tanggal),
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.blueGrey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.scale_rounded, size: 15, color: Colors.blue[600]),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${NumberFormat.decimalPattern('id').format(tx.tonase)} kg',
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: Colors.blue[700],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Tombol Aksi dipindah ke Detail Screen, tapi ada tombol Cetak/Share
                      IconButton(
                        icon: const Icon(Icons.share, color: Colors.blue),
                        onPressed: () async {
                          try {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Menyiapkan PDF...'), duration: Duration(seconds: 1)),
                            );
                            final pdfBytes = await PdfGenerator.generateTransaksiDoPdf(tx);
                            await Printing.sharePdf(bytes: pdfBytes, filename: 'DO_${tx.nomor}.pdf');
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Gagal membuat PDF: $e')));
                            }
                          }
                        },
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

  String _getShortDoNumber(String nomor) {
    if (nomor.startsWith('DO-')) {
      final parts = nomor.split('-');
      if (parts.length >= 4) {
        // format: DO-P3-20260525-001 -> DO-001
        return 'DO-${parts.last}';
      }
    }
    return nomor;
  }
}

// _CategoryFilterDelegate dihapus — diganti SliverToBoxAdapter

