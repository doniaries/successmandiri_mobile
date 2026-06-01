import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/add_tambah_saldo_screen.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/tambah_saldo_detail_screen.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/edit_tambah_saldo_screen.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/providers/global_filter_provider.dart';

class TambahSaldoListScreen extends StatefulWidget {
  const TambahSaldoListScreen({super.key});

  @override
  State<TambahSaldoListScreen> createState() => _TambahSaldoListScreenState();
}

class _TambahSaldoListScreenState extends State<TambahSaldoListScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _isFabExtended = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

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
      context.read<TambahSaldoProvider>().fetchData(useCache: true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Tambah Saldo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_month_rounded),
            onPressed: _showFilterSheet,
            tooltip: 'Filter Tanggal',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer3<TambahSaldoProvider, DashboardProvider, GlobalFilterProvider>(
              builder: (context, provider, dashboardProvider, globalFilter, child) {
                final activeDateStr =
                    dashboardProvider.summary?.systemActiveDate;
                final systemActiveDate = activeDateStr != null
                    ? DateTime.parse(activeDateStr)
                    : DateTime.now();

                final targetDate = globalFilter.selectedDate ?? systemActiveDate;

                final filteredRequests = provider.requests.where((r) {
                  return DateUtils.isSameDay(r.tanggal.toLocal(), targetDate);
                }).toList();

                if (provider.isLoading && provider.requests.isEmpty) {
                  return ListView.builder(
                    padding: const EdgeInsets.all(10),
                    itemCount: 5,
                    itemBuilder: (context, index) => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: SkeletonLoader(
                        height: 100,
                        width: double.infinity,
                        borderRadius: 12,
                      ),
                    ),
                  );
                }

                final formattedDateText = DateFormat(
                  'dd MMMM yyyy',
                  'id_ID',
                ).format(targetDate);

                return Column(
                  children: [
                    _buildSummaryHeader(
                      provider,
                      dashboardProvider,
                      filteredRequests,
                      systemActiveDate,
                      globalFilter.selectedDate,
                    ),
                    _buildFilterInfoWidget(
                      provider,
                      dashboardProvider,
                      filteredRequests,
                      systemActiveDate,
                      globalFilter.selectedDate,
                    ),
                    Expanded(
                      child: RefreshIndicator(
                        notificationPredicate: (notification) =>
                            !SyncService().isOffline &&
                            defaultScrollNotificationPredicate(notification),
                        onRefresh: () async {
                          if (SyncService().isOffline) return;
                          final scaffoldMessenger = ScaffoldMessenger.of(
                            context,
                          );
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              content: Text('Memulai Sinkronisasi Data...'),
                              duration: Duration(seconds: 1),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );

                          try {
                            // 1. Process offline queue (run in background)
                            SyncService().syncNow();

                            // 2. Fetch latest master data from web (will run immediately, sync may still be in progress)
                            if (context.mounted) {
                              await context
                                  .read<ResourceProvider>()
                                  .syncMasterData();
                            }

                            // 3. Fetch latest requests list
                            await provider.fetchData(isRefresh: true, useCache: false);

                            // 4. Fetch latest summary for dashboard
                            if (context.mounted) {
                              await context
                                  .read<DashboardProvider>()
                                  .fetchSummary();
                            }

                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                content: Text('Sinkronisasi Data Selesai'),
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
                        child: filteredRequests.isEmpty
                            ? ListView(
                                controller: _scrollController,
                                physics: const AlwaysScrollableScrollPhysics(),
                                children: [
                                  SizedBox(
                                    height:
                                        MediaQuery.of(context).size.height *
                                        0.4,
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32.0),
                                        child: Text(
                                          'Tidak ada transaksi untuk tanggal $formattedDateText.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: Colors.grey[600],
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              )
                            : ListView.builder(
                                controller: _scrollController,
                                padding: const EdgeInsets.all(10),
                                itemCount: filteredRequests.length,
                                itemBuilder: (context, index) {
                                  final request = filteredRequests[index];
                                  return _buildRequestItem(request);
                                },
                              ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        isExtended: _isFabExtended,
        heroTag: 'tambah_saldo_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTambahSaldoScreen(),
            ),
          );
        },
        backgroundColor: const Color(0xFF01579B),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Tambah Saldo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSummaryHeader(
    TambahSaldoProvider provider,
    DashboardProvider dashboardProvider,
    List<TambahSaldoModel> filtered,
    DateTime systemActiveDate,
    DateTime? selectedDate,
  ) {
    double totalNominal = 0;
    for (var r in filtered) {
      totalNominal += r.nominal;
    }

    final double currentSaldo = dashboardProvider.summary?.saldo ?? 0.0;
    final targetDate = selectedDate ?? systemActiveDate;
    final formattedDateText = DateFormat(
      'dd MMMM yyyy',
      'id_ID',
    ).format(targetDate);

    final isFilterActive =
        selectedDate != null &&
        !DateUtils.isSameDay(selectedDate, systemActiveDate);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF01579B), Color(0xFF0D47A1), Color(0xFF002F6C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE67E22).withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isFilterActive ? 'Filter Saldo' : 'Ringkasan Saldo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (!isFilterActive)
                InkWell(
                  onTap: _showFilterSheet,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
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
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          formattedDateText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_drop_down_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (isFilterActive) ...[
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
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
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
                                    formattedDateText,
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
                          '${filtered.length}',
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
          ] else ...[
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Saldo Perusahaan',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.formatRupiah(currentSaldo),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.add_circle_outline_rounded,
                            color: Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tambah Saldo',
                            style: GoogleFonts.inter(
                              color: Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          CurrencyFormatter.formatRupiah(totalNominal),
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18,
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
        ],
      ),
    );
  }

  void _showFilterSheet() async {
    final globalFilter = context.read<GlobalFilterProvider>();
    final dashboardProvider = context.read<DashboardProvider>();
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
              primary: Color(0xFFE67E22),
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
    }
  }

  Future<bool?> _showDeleteConfirmDialog(TambahSaldoModel request) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            const SizedBox(width: 8),
            Text(
              'Hapus Transaksi',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Text(
          'Apakah Anda yakin ingin menghapus transaksi tambah saldo sebesar ${CurrencyFormatter.formatRupiah(request.nominal)}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Batal', style: GoogleFonts.inter(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              'Ya, Hapus',
              style: GoogleFonts.inter(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleDelete(TambahSaldoModel request) async {
    final provider = context.read<TambahSaldoProvider>();
    final dashboardProvider = context.read<DashboardProvider>();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 12),
            Text('Menghapus tambah saldo...'),
          ],
        ),
        duration: Duration(days: 1),
      ),
    );

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    final success = await provider.deleteRequest(request.id);

    // Always hide the loading snackbar, even if widget is unmounted (e.g. user navigated back)
    scaffoldMessenger.hideCurrentSnackBar();

    if (mounted) {
      if (success) {
        dashboardProvider.fetchSummary();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Tambah saldo berhasil dihapus.'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        provider.fetchData(isRefresh: true, useCache: false); // Restore visually on error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Gagal menghapus tambah saldo.',
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildRequestItem(TambahSaldoModel request) {
    return Dismissible(
      key: ValueKey('tambah_saldo_${request.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20.0),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Hapus',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 28),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return await _showDeleteConfirmDialog(request);
      },
      onDismissed: (direction) {
        _handleDelete(request);
      },
      child: Card(
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => TambahSaldoDetailScreen(request: request),
              ),
            );
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            title: Text(
              CurrencyFormatter.formatRupiah(request.nominal),
              style: GoogleFonts.inter(fontWeight: FontWeight.w900, fontSize: 18),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Text(
                  request.keterangan,
                  style: TextStyle(color: Colors.grey[700], fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 13,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        request.userName ?? 'N/A',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 12,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        DateFormat(
                          'dd MMM yyyy • HH:mm',
                          'id_ID',
                        ).format(request.tanggal),
                        style: TextStyle(color: Colors.grey[600], fontSize: 11),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.edit_rounded,
                    color: Colors.blueAccent,
                    size: 22,
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            EditTambahSaldoScreen(request: request),
                      ),
                    );
                  },
                  tooltip: 'Ubah',
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: Colors.redAccent,
                    size: 22,
                  ),
                  onPressed: () async {
                    final confirmed = await _showDeleteConfirmDialog(request);
                    if (confirmed == true) {
                      _handleDelete(request);
                    }
                  },
                  tooltip: 'Hapus',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterInfoWidget(
    TambahSaldoProvider provider,
    DashboardProvider dashboardProvider,
    List<TambahSaldoModel> filtered,
    DateTime systemActiveDate,
    DateTime? selectedDate,
  ) {
    if (selectedDate == null) return const SizedBox.shrink();
    if (DateUtils.isSameDay(selectedDate, systemActiveDate)) {
      return const SizedBox.shrink();
    }

    final formattedFilterDate = DateFormat(
      'dd MMMM yyyy',
      'id_ID',
    ).format(selectedDate);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE67E22).withValues(alpha: 0.15),
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
              color: const Color(0xFFE67E22).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.filter_alt_rounded,
              color: Color(0xFFE67E22),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menampilkan Filter Saldo',
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
              context.read<GlobalFilterProvider>().setDate(null);
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
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
