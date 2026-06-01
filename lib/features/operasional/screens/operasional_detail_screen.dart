import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/operasional/screens/edit_operasional_screen.dart';

class OperasionalDetailScreen extends StatefulWidget {
  final Operasional operasional;
  final VoidCallback? onDeleted;

  const OperasionalDetailScreen({
    super.key,
    required this.operasional,
    this.onDeleted,
  });

  @override
  State<OperasionalDetailScreen> createState() =>
      _OperasionalDetailScreenState();
}

class _OperasionalDetailScreenState extends State<OperasionalDetailScreen> {
  @override
  void dispose() {
    super.dispose();
  }

  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Hapus Transaksi'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus transaksi ini?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                Navigator.pop(dialogContext);
                final success = await context
                    .read<ResourceProvider>()
                    .deleteResource('operasional', widget.operasional.id);
                if (context.mounted) {
                  if (success) {
                    context.read<DashboardProvider>().fetchSummary();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Operasional berhasil dihapus'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    widget.onDeleted?.call();
                    Navigator.pop(context);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          context.read<ResourceProvider>().errorMessage ??
                              'Gagal menghapus operasional',
                        ),
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
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMMM yyyy HH:mm', 'id_ID');

    final bool isPengeluaran =
        widget.operasional.operasional.toLowerCase() == 'pengeluaran';

    String labelPihak = 'Pihak Terkait';
    if (widget.operasional.pihakType != null) {
      final type = widget.operasional.pihakType!.toLowerCase();
      if (type.contains('penjual')) {
        labelPihak = 'Penjual';
      } else if (type.contains('supir')) {
        labelPihak = 'Supir';
      } else if (type.contains('pekerja')) {
        labelPihak = 'Pekerja';
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Detail Operasional',
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
                    builder: (context) =>
                        EditOperasionalScreen(operasional: widget.operasional),
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
                      ? [const Color(0xFF01579B), const Color(0xFF0D47A1), const Color(0xFF002F6C)]
                      : [const Color(0xFF2ECC71), const Color(0xFF27AE60)],
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color:
                        (isPengeluaran ? const Color(0xFF0D47A1) : Colors.green)
                            .withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    widget.operasional.kategoriLabel ??
                        widget.operasional.kategori,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    currencyFormat.format(widget.operasional.nominal),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.operasional.operasional.toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),

            // Details
            // Details
            _buildInfoSection('Informasi Lengkap', [
              _buildInfoRow(
                Icons.calendar_today_rounded,
                'Tanggal',
                dateFormat.format(widget.operasional.tanggal),
              ),
              _buildInfoRow(
                Icons.category_rounded,
                'Kategori',
                widget.operasional.kategoriLabel ?? widget.operasional.kategori,
              ),
              if (widget.operasional.namaPihak != null)
                _buildInfoRow(
                  Icons.person_rounded,
                  labelPihak,
                  widget.operasional.namaPihak!,
                ),
              if (widget.operasional.userName != null &&
                  widget.operasional.userName!.isNotEmpty &&
                  widget.operasional.userName != '-')
                _buildInfoRow(
                  Icons.account_circle_rounded,
                  'Pencatat',
                  widget.operasional.userName!,
                ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(),
              ),

              const Row(
                children: [
                  Icon(Icons.description_outlined, size: 18, color: Color(0xFF01579B)),
                  SizedBox(width: 15),
                  Text('Keterangan', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                widget.operasional.keterangan ??
                    'Tidak ada keterangan tambahan.',
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ]),

            const SizedBox(height: 30),

            // Subtle footer info
            Text(
              'ID Transaksi: #${widget.operasional.id}',
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
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF2C3E50),
            ),
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
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF2C3E50),
            ),
          ),
        ],
      ),
    );
  }
}
