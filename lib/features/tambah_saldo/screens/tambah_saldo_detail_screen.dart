import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';

class TambahSaldoDetailScreen extends StatelessWidget {
  final TambahSaldoModel request;

  const TambahSaldoDetailScreen({super.key, required this.request});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detail Tambah Saldo', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Transaction Summary Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                color: const Color(0xFF01579B).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: const Color(0xFF01579B).withValues(alpha: 0.2)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.payments_rounded, color: Color(0xFF01579B), size: 60),
                  const SizedBox(height: 15),
                  Text(
                    CurrencyFormatter.formatRupiah(request.nominal),
                    style: const TextStyle(
                      color: Color(0xFF01579B), 
                      fontSize: 24, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    'TRANSAKSI BERHASIL',
                    style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),
            
            // Detail Info Section
            _buildInfoSection('Rincian Transaksi', [
              _buildInfoRow(Icons.calendar_today_rounded, 'Tanggal', DateFormat('dd MMMM yyyy', 'id_ID').format(request.tanggal)),
              _buildInfoRow(Icons.person_rounded, 'Diinput Oleh', request.userName ?? '-'),
              _buildInfoRow(Icons.description_rounded, 'Keterangan', request.keterangan),
            ]),
          ],
        ),
      ),
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
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.grey[400]),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
