import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/screens/edit_transaksi_do_screen.dart';

class TransaksiDoDetailScreen extends StatelessWidget {
  final TransaksiDo transaction;

  const TransaksiDoDetailScreen({super.key, required this.transaction});

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Transaksi'),
          content: const Text('Apakah Anda yakin ingin menghapus transaksi DO ini? Seluruh jurnal keuangan, sisa bayar, dan mutasi hutang terkait akan dikoreksi otomatis.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                final success = await context.read<TransaksiDoProvider>().deleteTransaction(transaction.id);
                if (context.mounted) {
                  if (success) {
                    context.read<DashboardProvider>().fetchSummary();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Transaksi DO berhasil dihapus'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    Navigator.pop(context); // Pop detail screen
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(context.read<TransaksiDoProvider>().errorMessage ?? 'Gagal menghapus transaksi DO'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              child: const Text('Hapus', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Detail Transaksi DO',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditTransaksiDoScreen(transaction: transaction),
                  ),
                );
              } else if (value == 'delete') {
                _showDeleteConfirmation(context);
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Ubah'),
                  ],
                ),
              ),
              const PopupMenuItem<String>(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Hapus'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF01579B),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Text(
                    transaction.nomor,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    dateFormat.format(transaction.tanggal),
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 15),
                    child: Divider(color: Colors.white24),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildHeaderInfo('Tonase', '${transaction.tonase} kg'),
                      _buildHeaderInfo(
                        'Harga',
                        CurrencyFormatter.formatRupiah(transaction.hargaSatuan),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Details
            _buildInfoSection('Pihak Terkait', [
              _buildInfoRow(
                Icons.store,
                'Penjual',
                transaction.penjualNama ?? 'N/A',
              ),
              _buildInfoRow(
                Icons.person,
                'Supir',
                transaction.displaySupirNama,
              ),
              _buildInfoRow(
                Icons.directions_car,
                'No. Polisi',
                transaction.noPolisi ?? 'N/A',
              ),
            ]),

            const SizedBox(height: 20),

            _buildInfoSection('Rincian Pembayaran', [
              _buildInfoRow(
                Icons.calculate,
                'Sub Total',
                CurrencyFormatter.formatRupiah(transaction.subTotal),
              ),
              _buildInfoRow(
                Icons.hourglass_empty,
                'Upah Bongkar',
                CurrencyFormatter.formatRupiah(transaction.upahBongkar),
              ),
              _buildInfoRow(
                Icons.add_circle_outline,
                'Biaya Lain/Pengambilan',
                CurrencyFormatter.formatRupiah(transaction.biayaLain),
              ),
              if (transaction.keteranganBiayaLain != null)
                Padding(
                  padding: const EdgeInsets.only(left: 40, bottom: 8),
                  child: Text(
                    '(${transaction.keteranganBiayaLain})',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              const Divider(),
              _buildInfoRow(
                Icons.history,
                'Hutang Awal',
                CurrencyFormatter.formatRupiah(transaction.hutangAwal),
              ),
              _buildInfoRow(
                Icons.payments_outlined,
                'Bayar Hutang',
                CurrencyFormatter.formatRupiah(transaction.pembayaranHutang),
              ),
              const Divider(),
              _buildInfoRow(
                Icons.account_balance_wallet_rounded,
                'Total Bersih',
                CurrencyFormatter.formatRupiah(transaction.sisaBayar),
                isBold: true,
                color: const Color(0xFF01579B),
              ),
            ]),

            const SizedBox(height: 20),

            _buildInfoSection('Status & Pembayaran', [
              _buildInfoRow(
                Icons.payment,
                'Cara Bayar',
                (transaction.caraBayar ?? 'N/A').toUpperCase(),
                isBold: true,
                color: (transaction.caraBayar?.toLowerCase() == 'tunai'
                    ? Colors.green[700]
                    : transaction.caraBayar?.toLowerCase() == 'transfer'
                    ? Colors.blue[700]
                    : transaction.caraBayar?.toLowerCase() == 'cair di luar'
                    ? Colors.amber[800]
                    : transaction.caraBayar?.toLowerCase() == 'belum dibayar'
                    ? Colors.red[700]
                    : const Color(0xFF01579B)),
              ),
              _buildInfoRow(
                Icons.account_balance,
                'Sisa Hutang Penjual',
                CurrencyFormatter.formatRupiah(transaction.sisaHutangPenjual),
              ),
              if (transaction.keteranganPembayaran != null &&
                  transaction.keteranganPembayaran!.isNotEmpty) ...[
                const Divider(),
                _buildInfoRow(
                  Icons.description_outlined,
                  'Keterangan',
                  transaction.keteranganPembayaran!,
                ),
              ],
              if (transaction.buktiTransfer != null &&
                  transaction.buktiTransfer!.isNotEmpty) ...[
                const Divider(),
                const SizedBox(height: 10),
                const Row(
                  children: [
                    Icon(Icons.image_outlined, size: 20, color: Colors.grey),
                    SizedBox(width: 15),
                    Text(
                      'Bukti Transfer:',
                      style: TextStyle(color: Colors.grey, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${ApiConstants.storageUrl}/${transaction.buktiTransfer}',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      padding: const EdgeInsets.all(20),
                      color: Colors.grey[200],
                      child: const Column(
                        children: [
                          Icon(Icons.broken_image_outlined, color: Colors.grey),
                          SizedBox(height: 8),
                          Text(
                            'Gambar tidak dapat dimuat',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[400]),
          const SizedBox(width: 15),
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
