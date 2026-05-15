import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';

class JurnalKeuanganDetailScreen extends StatelessWidget {
  final JurnalKeuangan jurnal;

  const JurnalKeuanganDetailScreen({super.key, required this.jurnal});

  @override
  Widget build(BuildContext context) {
    final isPemasukan = jurnal.jenisTransaksi == 'Pemasukan';
    final accentColor = isPemasukan ? Colors.green : const Color(0xFF0D47A1);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detail Laporan Keuangan', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Amount Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isPemasukan 
                    ? [const Color(0xFF27AE60), const Color(0xFF2ECC71)]
                    : [const Color(0xFF01579B), const Color(0xFF0D47A1)],
                ),
                borderRadius: BorderRadius.circular(30),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    isPemasukan ? 'PEMASUKAN' : 'PENGELUARAN',
                    style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    CurrencyFormatter.formatRupiah(jurnal.nominal),
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      DateFormat('dd MMMM yyyy', 'id_ID').format(jurnal.tanggal),
                      style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            
            // Detail Information
            _buildInfoSection('Informasi Transaksi', [
              _buildInfoRow(Icons.category_rounded, 'Kategori', jurnal.kategori),
              _buildInfoRow(Icons.account_tree_rounded, 'Sub Kategori', jurnal.subKategori),
              _buildInfoRow(Icons.person_pin_rounded, 'Pihak Terkait', jurnal.pihakTerkait ?? '-'),
              _buildInfoRow(Icons.payment_rounded, 'Cara Bayar', jurnal.caraPembayaran.toUpperCase()),
            ]),
            
            const SizedBox(height: 20),
            
            _buildInfoSection('Keterangan', [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text(
                  jurnal.keterangan ?? 'Tidak ada keterangan tambahan.',
                  style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5),
                ),
              ),
            ]),
            
            const SizedBox(height: 20),
            
            if (jurnal.nomorReferensi != null)
              _buildInfoSection('Referensi', [
                _buildInfoRow(Icons.receipt_rounded, 'Nomor Referensi', jurnal.nomorReferensi!),
                _buildInfoRow(Icons.source_rounded, 'Sumber Data', jurnal.sumberTransaksi),
              ]),
              
            const SizedBox(height: 30),
            
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Tutup', style: TextStyle(color: accentColor, fontWeight: FontWeight.bold)),
              ),
            ),
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
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.black)),
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
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.grey[600]),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 11, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

