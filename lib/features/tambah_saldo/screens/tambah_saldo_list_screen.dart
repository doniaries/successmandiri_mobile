import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/skeleton_loader.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/add_tambah_saldo_screen.dart';
import 'package:sawitappmobile/features/tambah_saldo/screens/tambah_saldo_detail_screen.dart';

class TambahSaldoListScreen extends StatefulWidget {
  const TambahSaldoListScreen({super.key});

  @override
  State<TambahSaldoListScreen> createState() => _TambahSaldoListScreenState();
}

class _TambahSaldoListScreenState extends State<TambahSaldoListScreen> {
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
      ),
      body: Consumer<TambahSaldoProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: 5,
              itemBuilder: (context, index) => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: SkeletonLoader(height: 100, width: double.infinity, borderRadius: 12),
              ),
            );
          }

          if (provider.errorMessage != null) {
            return Center(child: Text(provider.errorMessage!));
          }

          if (provider.requests.isEmpty) {
            return const Center(child: Text('Belum ada transaksi tambah saldo.'));
          }

          return RefreshIndicator(
            onRefresh: () => provider.fetchRequests(),
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: provider.requests.length,
              itemBuilder: (context, index) {
                final request = provider.requests[index];
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
                                DateFormat('dd MMM yyyy', 'id_ID').format(request.tanggal),
                                style: TextStyle(color: Colors.grey[600], fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
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
}
