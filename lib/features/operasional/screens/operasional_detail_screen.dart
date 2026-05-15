import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';

class OperasionalDetailScreen extends StatelessWidget {
  final Operasional operasional;

  const OperasionalDetailScreen({super.key, required this.operasional});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0);
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');

    final bool isPengeluaran = operasional.operasional.toLowerCase() == 'pengeluaran';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detail Operasional', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isPengeluaran 
                    ? [const Color(0xFF01579B), const Color(0xFF0D47A1)] 
                    : [const Color(0xFF2ECC71), const Color(0xFF27AE60)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: (isPengeluaran ? const Color(0xFF0D47A1) : Colors.green).withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    operasional.kategoriLabel ?? operasional.kategori,
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currencyFormat.format(operasional.nominal),
                    style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      operasional.operasional.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            
            // Details
            _buildInfoSection('Informasi Utama', [
              _buildInfoRow(Icons.calendar_today_rounded, 'Tanggal', dateFormat.format(operasional.tanggal)),
              _buildInfoRow(Icons.category_rounded, 'Kategori', operasional.kategoriLabel ?? operasional.kategori),
              if (operasional.namaPihak != null)
                _buildInfoRow(Icons.person_rounded, 'Pihak Terkait', operasional.namaPihak!),
            ]),
            
            const SizedBox(height: 20),
            
            _buildInfoSection('Keterangan', [
              Text(
                operasional.keterangan ?? 'Tidak ada keterangan tambahan.',
                style: TextStyle(fontSize: 15, color: Colors.grey[700], height: 1.5),
              ),
            ]),
            
            const SizedBox(height: 30),
            
            // Subtle footer info
            Text(
              'ID Transaksi: #${operasional.id}',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
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
        border: Border.all(color: Colors.grey[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50)),
          ),
          const SizedBox(height: 20),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: const Color(0xFF01579B)),
          ),
          const SizedBox(width: 15),
          Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }
}

