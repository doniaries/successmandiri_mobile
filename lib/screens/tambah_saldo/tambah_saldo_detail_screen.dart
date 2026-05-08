import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/tambah_saldo_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/dashboard_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../models/tambah_saldo_model.dart';
import 'package:image_picker/image_picker.dart';

class TambahSaldoDetailScreen extends StatefulWidget {
  final TambahSaldoModel request;

  const TambahSaldoDetailScreen({super.key, required this.request});

  @override
  State<TambahSaldoDetailScreen> createState() => _TambahSaldoDetailScreenState();
}

class _TambahSaldoDetailScreenState extends State<TambahSaldoDetailScreen> {
  XFile? _selectedBukti;



  @override
  Widget build(BuildContext context) {
    final request = widget.request;
    final user = context.read<AuthProvider>().user;
    final role = user?.role?.toLowerCase();
    final isAuthorized = role == 'admin' || role == 'super_admin';
    final isPending = request.status.toLowerCase() == 'pending';

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detail Tambah Saldo', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Status Card
            _buildStatusHeader(),
            const SizedBox(height: 25),
            
            // Detail Info Section
            _buildInfoSection('Informasi Saldo', [
              _buildInfoRow(Icons.payments_rounded, 'Nominal', CurrencyFormatter.formatRupiah(request.nominal), isBold: true, color: const Color(0xFF01579B)),
              _buildInfoRow(Icons.calendar_today_rounded, 'Tanggal Pengajuan', DateFormat('dd MMMM yyyy', 'id_ID').format(request.tanggal)),
              _buildInfoRow(Icons.person_rounded, 'Pemohon', request.userName ?? '-'),
              _buildInfoRow(Icons.description_rounded, 'Keperluan', request.keperluan),
            ]),
            
            const SizedBox(height: 20),
            
            if (request.status.toLowerCase() != 'pending')
              _buildInfoSection('Informasi Pemrosesan', [
                _buildInfoRow(Icons.info_outline_rounded, 'Status Akhir', request.status.toUpperCase()),
                if (request.catatanPimpinan != null)
                  _buildInfoRow(Icons.note_rounded, 'Catatan Pimpinan', request.catatanPimpinan!),
                if (request.status.toLowerCase() == 'disetujui' && request.buktiTransfer != null && request.buktiTransfer!.isNotEmpty)
                  _buildInfoRow(Icons.receipt_rounded, 'Bukti Transfer', request.buktiTransfer!),
              ]),

            const SizedBox(height: 40),
            
            if (isAuthorized && isPending)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showProcessDialog(context, isApprove: false),
                      icon: const Icon(Icons.close, color: Color(0xFF455A64)),
                      label: const Text('Tolak', style: TextStyle(color: Color(0xFF455A64))),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: Color(0xFF455A64)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _showProcessDialog(context, isApprove: true),
                      icon: const Icon(Icons.check),
                      label: const Text('Setujui'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusHeader() {
    final request = widget.request;
    Color color;
    IconData icon;
    switch (request.status.toLowerCase()) {
      case 'disetujui':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case 'ditolak':
        color = const Color(0xFF455A64);
        icon = Icons.cancel_rounded;
        break;
      default:
        color = Colors.orange;
        icon = Icons.hourglass_empty_rounded;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 60),
          const SizedBox(height: 15),
          Text(
            request.status.toUpperCase(),
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1),
          ),
          const SizedBox(height: 5),
          if (request.status.toLowerCase() != 'pending')
            Text(
              'Diproses pada ${DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(request.tanggalProses ?? request.tanggal)}',
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 13),
            ),
        ],
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

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isBold = false, Color? color}) {
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
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
                    color: color ?? Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showProcessDialog(BuildContext context, {required bool isApprove}) {
    setState(() => _selectedBukti = null);
    final catatanController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isApprove ? 'Setujui Tambah Saldo' : 'Tolak Tambah Saldo'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: catatanController,
                    decoration: InputDecoration(
                      labelText: isApprove ? 'Catatan (Opsional)' : 'Alasan Penolakan',
                      hintText: isApprove ? '' : 'Wajib diisi',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    validator: (v) => !isApprove && (v == null || v.isEmpty) ? 'Alasan penolakan wajib diisi' : null,
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Batal')),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final provider = context.read<TambahSaldoProvider>();
                  Navigator.pop(context);

                  bool success;
                  if (isApprove) {
                    success = await provider.approveRequest(
                      widget.request.id,
                      buktiTransfer: _selectedBukti,
                      catatan: catatanController.text,
                    );
                  } else {
                    success = await provider.rejectRequest(
                      widget.request.id,
                      catatan: catatanController.text,
                    );
                  }

                  if (context.mounted) {
                    if (success) {
                      // Update status locally for UI feedback
                      setState(() {
                        widget.request.status = isApprove ? 'disetujui' : 'ditolak';
                        if (isApprove) {
                          widget.request.tanggalProses = DateTime.now();
                        }
                      });

                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(isApprove ? 'Berhasil disetujui' : 'Berhasil ditolak'),
                        backgroundColor: isApprove ? Colors.green : const Color(0xFF455A64),
                        duration: const Duration(seconds: 1),
                      ));

                      // Wait a bit so user sees the status change
                      await Future.delayed(const Duration(milliseconds: 1500));
                      
                      if (context.mounted) {
                        Navigator.pop(context); // Close detail screen
                        context.read<DashboardProvider>().fetchSummary();
                      }
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(provider.errorMessage ?? 'Gagal memproses'),
                        backgroundColor: const Color(0xFF455A64),
                      ));
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: isApprove ? Colors.green : const Color(0xFF455A64),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Proses'),
            ),
          ],
        ),
      ),
    );
  }
}

