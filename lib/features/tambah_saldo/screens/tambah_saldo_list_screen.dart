import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/add_tambah_saldo_screen.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/tambah_saldo_detail_screen.dart';

class TambahSaldoListScreen extends StatefulWidget {
  const TambahSaldoListScreen({super.key});

  @override
  State<TambahSaldoListScreen> createState() => _TambahSaldoListScreenState();
}

class _TambahSaldoListScreenState extends State<TambahSaldoListScreen> {
  String _selectedTab = 'Hari Ini';
  final List<String> _tabs = ['Hari Ini', 'Semua'];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TambahSaldoProvider>().fetchRequests();
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
      body: Consumer2<TambahSaldoProvider, DashboardProvider>(
        builder: (context, provider, dashboardProvider, child) {
          final activeDateStr = dashboardProvider.summary?.systemActiveDate;
          final systemActiveDate = activeDateStr != null
              ? DateTime.parse(activeDateStr)
              : DateTime.now();

          final filteredRequests = provider.requests.where((r) {
            if (_selectedDateRange != null) {
              final d = r.tanggal.toLocal();
              return d.isAfter(_selectedDateRange!.start.subtract(const Duration(seconds: 1))) && 
                     d.isBefore(_selectedDateRange!.end.add(const Duration(days: 1)));
            }
            if (_selectedTab == 'Hari Ini') {
              return DateUtils.isSameDay(r.tanggal.toLocal(), systemActiveDate);
            }
            return true;
          }).toList();

          if (provider.isLoading && provider.requests.isEmpty) {
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SkeletonLoader(height: 100, width: double.infinity, borderRadius: 12),
              ),
            );
          }

          return Column(
            children: [
              _buildSummaryHeader(provider, filteredRequests),
              _buildDateTabs(),
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () => provider.fetchRequests(),
                  child: filteredRequests.isEmpty
                      ? Center(child: Text(_selectedTab == 'Hari Ini' ? 'Tidak ada transaksi hari ini.' : 'Belum ada transaksi tambah saldo.'))
                      : ListView.builder(
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
      floatingActionButton: FloatingActionButton(
        heroTag: 'tambah_saldo_fab',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTambahSaldoScreen()),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSummaryHeader(TambahSaldoProvider provider, List<TambahSaldoModel> filtered) {
    double totalNominal = 0;
    for (var r in filtered) {
      totalNominal += r.nominal;
    }

    String label = 'Total Nominal Tambah Saldo';
    if (_selectedDateRange != null) {
      label = 'Nominal Terfilter';
    } else if (_selectedTab == 'Hari Ini') {
      label = 'Nominal Tambah Saldo Hari Ini';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE67E22), Color(0xFFF39C12)],
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
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              CurrencyFormatter.formatRupiah(totalNominal),
              style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTabs() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ..._tabs.map((tab) {
            final isSelected = _selectedTab == tab && _selectedDateRange == null;
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
                selectedColor: const Color(0xFFE67E22),
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey[600],
                  fontWeight: FontWeight.bold,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: false,
              ),
            );
          }),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(
                  '${DateFormat('dd/MM').format(_selectedDateRange!.start)} - ${DateFormat('dd/MM').format(_selectedDateRange!.end)}'
                ),
                selected: true,
                onSelected: (_) => setState(() => _selectedDateRange = null),
                selectedColor: Colors.orange[800],
                labelStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                showCheckmark: true,
              ),
            ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter Riwayat', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.date_range_rounded, color: Color(0xFFE67E22)),
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
                leading: const Icon(Icons.calendar_view_month_rounded, color: Color(0xFFE67E22)),
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
                leading: const Icon(Icons.calendar_month_rounded, color: Color(0xFFE67E22)),
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

  Widget _buildRequestItem(TambahSaldoModel request) {
    return Card(
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
          contentPadding: const EdgeInsets.all(16),
          title: Text(
            CurrencyFormatter.formatRupiah(request.nominal),
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Text(request.keterangan, style: TextStyle(color: Colors.grey[700])),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(request.userName ?? 'N/A', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
                  const Spacer(),
                  Icon(Icons.calendar_today, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('dd MMM yyyy • HH:mm', 'id_ID').format(request.tanggal),
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
