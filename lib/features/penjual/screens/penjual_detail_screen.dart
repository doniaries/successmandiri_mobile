import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/penjual/models/penjual_model.dart';
import 'package:sawitappmobile/shared/models/mutasi_hutang_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/operasional/screens/pay_debt_screen.dart';
import 'package:sawitappmobile/features/operasional/screens/add_debt_screen.dart';
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';

class PenjualDetailScreen extends StatefulWidget {
  final Penjual penjual;

  const PenjualDetailScreen({super.key, required this.penjual});

  @override
  State<PenjualDetailScreen> createState() => _PenjualDetailScreenState();
}

class _PenjualDetailScreenState extends State<PenjualDetailScreen> {
  late Penjual _currentPenjual;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPenjual = widget.penjual;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final detail = await context.read<ResourceProvider>().getPenjualDetail(widget.penjual.id);
      if (mounted) {
        setState(() {
          _currentPenjual = detail;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _handleToggleStatus() async {
    final bool isCurrentlyActive = _currentPenjual.isActive;
    final String actionText = isCurrentlyActive ? 'menonaktifkan' : 'mengaktifkan';
    final String titleText = isCurrentlyActive ? 'Nonaktifkan Penjual' : 'Aktifkan Penjual';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titleText),
        content: Text('Apakah Anda yakin ingin $actionText penjual ${_currentPenjual.nama}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: isCurrentlyActive ? Colors.red : Colors.green,
            ),
            child: Text(isCurrentlyActive ? 'Nonaktifkan' : 'Aktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isLoading = true);
      try {
        final success = await context.read<ResourceProvider>().updateResourceStatus(
              'penjual',
              _currentPenjual.id,
              !isCurrentlyActive,
            );

        if (mounted) {
          setState(() => _isLoading = false);
          if (success) {
            SuccessDialog.show(
              context,
              title: 'Berhasil',
              message: 'Status penjual berhasil diperbarui.',
            );
            _fetchDetail(); // Refresh data
          } else {
            ErrorDialog.show(
              context,
              title: 'Gagal',
              message: context.read<ResourceProvider>().errorMessage ?? 'Gagal memperbarui status.',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoading = false);
          ErrorDialog.show(
            context,
            title: 'Error',
            message: e.toString(),
          );
        }
      }
    }
  }

  void _showEditBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return _PenjualEditBottomSheet(
          penjual: _currentPenjual,
          onSuccess: _fetchDetail,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detail Penjual', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: _showEditBottomSheet,
          ),
          IconButton(
            icon: Icon(
              _currentPenjual.isActive ? Icons.power_settings_new_rounded : Icons.power_rounded,
              color: _currentPenjual.isActive ? Colors.red : Colors.green,
            ),
            tooltip: _currentPenjual.isActive ? 'Nonaktifkan' : 'Aktifkan',
            onPressed: _isLoading ? null : _handleToggleStatus,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Header Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF01579B), Color(0xFF0D47A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF01579B).withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    child: const Icon(Icons.store_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentPenjual.nama.toUpperCase(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentPenjual.isActive ? Colors.greenAccent : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentPenjual.isActive ? 'AKTIF' : 'NONAKTIF',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'MITRA PENJUAL',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  if (_currentPenjual.hutang != null && _currentPenjual.hutang! > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 14),
                          const SizedBox(width: 6),
                          Text(
                            'MEMILIKI HUTANG',
                            style: TextStyle(color: Colors.orange[100], fontSize: 10, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // Info Sections
            _buildInfoSection(
              'Informasi Kontak',
              [
                _buildInfoRow(
                  Icons.phone_android_rounded, 
                  'Telepon', 
                  _currentPenjual.telepon ?? '-',
                  trailing: _currentPenjual.telepon != null ? IconButton(
                    icon: const Icon(Icons.call, color: Color(0xFF01579B)),
                    onPressed: () => _makePhoneCall(_currentPenjual.telepon!),
                  ) : null,
                ),
                _buildInfoRow(Icons.location_on_rounded, 'Alamat', _currentPenjual.alamat ?? '-', isMultiLine: true),
              ],
              onTap: _showEditBottomSheet,
            ),
            
            const SizedBox(height: 24),
            _buildInfoSection('Status Keuangan', [
              _buildInfoRow(
                Icons.account_balance_wallet_rounded, 
                'Total Hutang', 
                CurrencyFormatter.formatRupiah(_currentPenjual.hutang ?? 0),
                textColor: (_currentPenjual.hutang ?? 0) > 0 ? Colors.orange[800] : Colors.green[700],
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      onPressed: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => AddDebtScreen(
                              pihakType: 'App\\Models\\Penjual',
                              pihakId: _currentPenjual.id,
                            ),
                          ),
                        );
                        _fetchDetail();
                      },
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Tambah'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.orange[800],
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                    ),
                    if ((_currentPenjual.hutang ?? 0) > 0)
                      TextButton.icon(
                        onPressed: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PayDebtScreen(
                                pihakType: 'App\\Models\\Penjual',
                                pihakId: _currentPenjual.id,
                              ),
                            ),
                          );
                          _fetchDetail();
                        },
                        icon: const Icon(Icons.payment_rounded, size: 18),
                        label: const Text('Bayar'),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF01579B),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                  ],
                ),
              ),
            ]),

            const SizedBox(height: 24),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_isLoading) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(20),
        child: CircularProgressIndicator(),
      ));
    }

    final List<MutasiHutang> history = _currentPenjual.mutasiHutang ?? [];

    // No need to sort if backend already returns latest(), but safety check
    // combinedHistory.sort((a, b) => (b['tanggal'] as DateTime).compareTo(a['tanggal'] as DateTime));

    return _buildInfoSection('Riwayat Hutang & Pembayaran', [
      if (history.isEmpty)
        const Center(child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Belum ada riwayat transaksi.', style: TextStyle(color: Colors.grey)),
        ))
      else
        ...history.map((item) => _buildMutasiRow(item)),
    ]);
  }

  Widget _buildMutasiRow(MutasiHutang item) {
    final DateTime tanggal = DateTime.parse(item.createdAt);
    final bool isPayment = item.isKeluar;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: isPayment ? Colors.green : Colors.orange,
                  shape: BoxShape.circle,
                ),
              ),
              Container(
                width: 2,
                height: 40,
                color: Colors.grey[200],
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isPayment ? 'PENGURANGAN' : 'PENAMBAHAN',
                      style: TextStyle(
                        fontWeight: FontWeight.bold, 
                        fontSize: 10,
                        color: isPayment ? Colors.green : Colors.orange,
                        letterSpacing: 1.1
                      ),
                    ),
                    Text(
                      DateFormat('dd MMM yyyy HH:mm').format(tanggal),
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  item.keterangan ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${isPayment ? '- ' : '+ '}${CurrencyFormatter.formatRupiah(item.nominal)}',
                      style: TextStyle(
                        color: isPayment ? Colors.green[700] : Colors.orange[800],
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Saldo: ${CurrencyFormatter.formatRupiah(item.saldoAkhir)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11, fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoSection(String title, List<Widget> children, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: onTap != null 
              ? const Color(0xFF01579B).withValues(alpha: 0.3) 
              : Colors.grey[200]!,
            width: onTap != null ? 1.5 : 1,
          ),
          boxShadow: onTap != null ? [
            BoxShadow(
              color: const Color(0xFF01579B).withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, 4),
            )
          ] : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 16,
                      decoration: BoxDecoration(
                        color: const Color(0xFF01579B),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF2C3E50)),
                    ),
                  ],
                ),
                if (onTap != null)
                  const Icon(Icons.edit_outlined, size: 18, color: Color(0xFF01579B)),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool isMultiLine = false, Widget? trailing, Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: isMultiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF01579B)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: textColor ?? const Color(0xFF1A1A1A),
                  ),
                ),
              ],
            ),
          ),
          trailing ?? const SizedBox.shrink(),
        ],
      ),
    );
  }
}

class _PenjualEditBottomSheet extends StatefulWidget {
  final Penjual penjual;
  final VoidCallback onSuccess;

  const _PenjualEditBottomSheet({
    required this.penjual,
    required this.onSuccess,
  });

  @override
  State<_PenjualEditBottomSheet> createState() => _PenjualEditBottomSheetState();
}

class _PenjualEditBottomSheetState extends State<_PenjualEditBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _teleponController;
  late TextEditingController _alamatController;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.penjual.nama);
    _teleponController = TextEditingController(text: widget.penjual.telepon);
    _alamatController = TextEditingController(text: widget.penjual.alamat);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ResourceProvider>();
      final success = await provider.updatePenjual(widget.penjual.id, {
        'nama': _namaController.text,
        'telepon': _teleponController.text,
        'alamat': _alamatController.text,
      });

      if (mounted) {
        if (success) {
          Navigator.pop(context); // Close bottom sheet
          widget.onSuccess(); // Trigger refresh
          SuccessDialog.show(
            context,
            title: 'Data Diperbarui!',
            message: 'Informasi Penjual ${_namaController.text} telah berhasil diperbarui.',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui data Penjual')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: MediaQuery.of(context).viewInsets,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Row(
                children: [
                  Icon(Icons.edit_outlined, color: Color(0xFF01579B)),
                  SizedBox(width: 8),
                  Text(
                    'Edit Informasi Kontak',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF2C3E50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _namaController,
                label: 'Nama Penjual',
                icon: Icons.person_outline,
                validator: (val) => val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _teleponController,
                label: 'Nomor Telepon',
                icon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _alamatController,
                label: 'Alamat',
                icon: Icons.location_on_outlined,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01579B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('SIMPAN PERUBAHAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFF01579B)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF01579B), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }
}

