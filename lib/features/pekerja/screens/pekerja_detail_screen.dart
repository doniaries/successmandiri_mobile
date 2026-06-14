import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/pekerja/models/pekerja_model.dart';
import 'package:sawitappmobile/shared/models/mutasi_hutang_model.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/operasional/screens/pay_debt_screen.dart';
import 'package:sawitappmobile/shared/widgets/error_dialog.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';

class PekerjaDetailScreen extends StatefulWidget {
  final Pekerja pekerja;

  const PekerjaDetailScreen({super.key, required this.pekerja});

  @override
  State<PekerjaDetailScreen> createState() => _PekerjaDetailScreenState();
}

class _PekerjaDetailScreenState extends State<PekerjaDetailScreen> {
  late Pekerja _currentPekerja;
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _currentPekerja = widget.pekerja;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final detail = await context.read<ResourceProvider>().getPekerjaDetail(
        widget.pekerja.id,
      );
      if (mounted) {
        setState(() {
          _currentPekerja = detail;
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
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(String phoneNumber) async {
    // bersihkan prefix dan format menjadi 628...
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '62${cleanPhone.substring(1)}';
    } else if (cleanPhone.startsWith('8')) {
      cleanPhone = '62$cleanPhone';
    }
    final Uri waUri = Uri.parse('https://wa.me/$cleanPhone');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _handleToggleStatus() async {
    final bool isCurrentlyActive = _currentPekerja.isActive;
    final String actionText = isCurrentlyActive
        ? 'menonaktifkan'
        : 'mengaktifkan';
    final String titleText = isCurrentlyActive
        ? 'Nonaktifkan Pekerja'
        : 'Aktifkan Pekerja';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(titleText),
        content: Text(
          'Apakah Anda yakin ingin $actionText pekerja ${_currentPekerja.nama}?',
        ),
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
      setState(() => _isProcessing = true);
      try {
        final success = await context
            .read<ResourceProvider>()
            .updateResourceStatus(
              'pekerja',
              _currentPekerja.id,
              !isCurrentlyActive,
            );

        if (mounted) {
          setState(() => _isProcessing = false);
          if (success) {
            SuccessDialog.show(
              context,
              title: 'Berhasil',
              message: 'Status pekerja berhasil diperbarui.',
            );
            _fetchDetail(); // Refresh data
          } else {
            ErrorDialog.show(
              context,
              title: 'Gagal',
              message:
                  context.read<ResourceProvider>().errorMessage ??
                  'Gagal memperbarui status.',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ErrorDialog.show(context, title: 'Error', message: e.toString());
        }
      }
    }
  }

  Future<void> _handleDelete() async {
    final double sisaHutang = _currentPekerja.sisaHutang;
    if (sisaHutang > 0) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Tidak Bisa Dihapus'),
          content: Text(
            'Data ${_currentPekerja.nama} tidak bisa dihapus karena masih memiliki sisa hutang. Anda hanya dapat menonaktifkannya.\n\nIngin menonaktifkan sekarang?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Nonaktifkan'),
            ),
          ],
        ),
      );
      if (confirmed == true && _currentPekerja.isActive) {
        _handleToggleStatus();
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Pekerja'),
        content: Text(
          'Apakah Anda yakin ingin menghapus ${_currentPekerja.nama} secara permanen?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      setState(() => _isProcessing = true);
      try {
        final success = await context.read<ResourceProvider>().deleteResource(
          'pekerja',
          _currentPekerja.id,
        );
        if (mounted) {
          setState(() => _isProcessing = false);
          if (success) {
            SuccessDialog.show(
              context,
              title: 'Berhasil',
              message: 'Data Pekerja berhasil dihapus.',
            );
            Navigator.pop(context);
          } else {
            // Server menolak (ada transaksi terhubung) — tawarkan nonaktif
            final errMsg =
                context.read<ResourceProvider>().errorMessage ??
                'Gagal menghapus data.';
            final offerDeactivate = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Hapus Gagal'),
                content: Text(
                  '$errMsg\n\nApakah Anda ingin menonaktifkan data ini sebagai gantinya?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Tidak'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.orange),
                    child: const Text('Nonaktifkan'),
                  ),
                ],
              ),
            );
            if (offerDeactivate == true && _currentPekerja.isActive) {
              _handleToggleStatus();
            }
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isProcessing = false);
          ErrorDialog.show(context, title: 'Error', message: e.toString());
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
        return _PekerjaEditBottomSheet(
          pekerja: _currentPekerja,
          onSuccess: _fetchDetail,
        );
      },
    );
  }

  void _showTambahHutangDialog(String type, int id) {
    final TextEditingController nominalController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Tambah Hutang Awal'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Masukkan nominal hutang awal yang terlewat atau baru untuk pekerja ini.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: nominalController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Nominal Hutang (Rp)',
                        border: OutlineInputBorder(),
                        prefixText: 'Rp ',
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Wajib diisi';
                        }
                        if (double.tryParse(val) == null) {
                          return 'Angka tidak valid';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (!formKey.currentState!.validate()) return;
                          setStateDialog(() => isSubmitting = true);

                          final success = await context
                              .read<ResourceProvider>()
                              .tambahHutang(
                                type,
                                id,
                                double.parse(nominalController.text),
                                'Penambahan hutang awal manual',
                              );

                          if (!context.mounted) return;
                          setStateDialog(() => isSubmitting = false);
                          if (success) {
                            Navigator.pop(context);
                            _fetchDetail();
                            SuccessDialog.show(
                              context,
                              title: 'Berhasil',
                              message: 'Hutang awal berhasil ditambahkan.',
                            );
                          } else {
                            final err =
                                context.read<ResourceProvider>().errorMessage ??
                                'Gagal menambahkan hutang.';
                            ErrorDialog.show(
                              context,
                              title: 'Gagal',
                              message: err,
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange[800],
                    foregroundColor: Colors.white,
                  ),
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'Detail Pekerja',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
              _currentPekerja.isActive
                  ? Icons.power_settings_new_rounded
                  : Icons.power_rounded,
              color: _currentPekerja.isActive ? Colors.red : Colors.green,
            ),
            tooltip: _currentPekerja.isActive ? 'Nonaktifkan' : 'Aktifkan',
            onPressed: _isProcessing ? null : _handleToggleStatus,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
            tooltip: 'Hapus Pekerja',
            onPressed: _isProcessing ? null : _handleDelete,
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
                  colors: [Color(0xFF8E44AD), Color(0xFF7D3C98)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8E44AD).withValues(alpha: 0.3),
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
                    child: const Icon(
                      Icons.person_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentPekerja.nama.toUpperCase(),
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
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
                            color: _currentPekerja.isActive
                                ? Colors.greenAccent
                                : Colors.redAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _currentPekerja.isActive ? 'AKTIF' : 'NONAKTIF',
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
                    _currentPekerja.posisi.toUpperCase(),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1,
                    ),
                  ),
                  if (_currentPekerja.sisaHutang > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.orange,
                            size: 14,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'MEMILIKI HUTANG',
                            style: TextStyle(
                              color: Colors.orange[100],
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
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
            // Info Sections
            _buildInfoSection('Informasi Lengkap', [
              const Text(
                'Informasi Kontak & Posisi',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.phone_android_rounded,
                'Telepon',
                _currentPekerja.telepon ?? '-',
                trailing: _currentPekerja.telepon != null && _currentPekerja.telepon!.isNotEmpty
                    ? Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const FaIcon(
                              FontAwesomeIcons.whatsapp,
                              color: Color(0xFF25D366),
                            ),
                            onPressed: () => _openWhatsApp(_currentPekerja.telepon!),
                          ),
                          IconButton(
                            icon: const Icon(Icons.call, color: Color(0xFF8E44AD)),
                            onPressed: () => _makePhoneCall(_currentPekerja.telepon!),
                          ),
                        ],
                      )
                    : null,
              ),
              _buildInfoRow(
                Icons.info_outline_rounded,
                'Posisi',
                _currentPekerja.posisi,
              ),
              _buildInfoRow(
                Icons.location_on_rounded,
                'Alamat',
                _currentPekerja.alamat ?? '-',
                isMultiLine: true,
              ),

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(),
              ),

              const Text(
                'Posisi Keuangan',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 10),
              _buildInfoRow(
                Icons.account_balance_wallet_rounded,
                'Total Hutang',
                CurrencyFormatter.formatRupiah(_currentPekerja.sisaHutang),
                textColor: _currentPekerja.sisaHutang > 0
                    ? Colors.orange[800]
                    : Colors.green[700],
              ),
              const SizedBox(height: 12),
              if (_currentPekerja.sisaHutang > 0)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PayDebtScreen(
                            pihakType: 'App\\Models\\Pekerja',
                            pihakId: _currentPekerja.id,
                          ),
                        ),
                      );
                      _fetchDetail();
                    },
                    icon: const Icon(Icons.payment_rounded, size: 20),
                    label: const Text('Bayar Hutang'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF8E44AD),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        _showTambahHutangDialog('pekerja', _currentPekerja.id),
                    icon: const Icon(
                      Icons.add_circle_outline_rounded,
                      size: 20,
                    ),
                    label: const Text('Tambah Hutang Awal'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.orange[800],
                      side: BorderSide(color: Colors.orange[800]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
            ], onTap: _showEditBottomSheet),

            const SizedBox(height: 24),
            _buildHistorySection(),
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection() {
    if (_isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final List<MutasiHutang> history = _currentPekerja.mutasiHutang ?? [];

    return _buildInfoSection('Riwayat Hutang & Pembayaran', [
      if (history.isEmpty)
        const Center(
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Belum ada riwayat transaksi.',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        )
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
              Container(width: 2, height: 40, color: Colors.grey[200]),
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
                        letterSpacing: 1.1,
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '${isPayment ? '- ' : '+ '}${CurrencyFormatter.formatRupiah(item.nominal)}',
                      style: TextStyle(
                        color: isPayment
                            ? Colors.green[700]
                            : Colors.orange[800],
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      'Saldo: ${CurrencyFormatter.formatRupiah(item.saldoAkhir)}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
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

  Widget _buildInfoSection(
    String title,
    List<Widget> children, {
    VoidCallback? onTap,
  }) {
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
                ? const Color(0xFF8E44AD).withValues(alpha: 0.3)
                : Colors.grey[200]!,
            width: onTap != null ? 1.5 : 1,
          ),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: const Color(0xFF8E44AD).withValues(alpha: 0.05),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
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
                        color: const Color(0xFF8E44AD),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF2C3E50),
                      ),
                    ),
                  ],
                ),
                if (onTap != null)
                  const Icon(
                    Icons.edit_outlined,
                    size: 18,
                    color: Color(0xFF8E44AD),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    IconData icon,
    String label,
    String value, {
    bool isMultiLine = false,
    Widget? trailing,
    Color? textColor,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: isMultiLine
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: const Color(0xFF8E44AD)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
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

class _PekerjaEditBottomSheet extends StatefulWidget {
  final Pekerja pekerja;
  final VoidCallback onSuccess;

  const _PekerjaEditBottomSheet({
    required this.pekerja,
    required this.onSuccess,
  });

  @override
  State<_PekerjaEditBottomSheet> createState() =>
      _PekerjaEditBottomSheetState();
}

class _PekerjaEditBottomSheetState extends State<_PekerjaEditBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _namaController;
  late TextEditingController _teleponController;
  late TextEditingController _alamatController;
  late TextEditingController _posisiController;
  bool _isLoading = false;

  static const List<String> _posisiOptions = [
    'Staff',
    'Kasir',
    'Supir Lansir',
    'Anggota Lansir',
  ];

  @override
  void initState() {
    super.initState();
    _namaController = TextEditingController(text: widget.pekerja.nama);
    _teleponController = TextEditingController(text: widget.pekerja.telepon);
    _alamatController = TextEditingController(text: widget.pekerja.alamat);
    _posisiController = TextEditingController(text: widget.pekerja.posisi);
  }

  @override
  void dispose() {
    _namaController.dispose();
    _teleponController.dispose();
    _alamatController.dispose();
    _posisiController.dispose();
    super.dispose();
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final provider = context.read<ResourceProvider>();
      final success = await provider.updatePekerja(widget.pekerja.id, {
        'nama': _namaController.text,
        'telepon': _teleponController.text,
        'alamat': _alamatController.text,
        'posisi': _posisiController.text.isNotEmpty ? _posisiController.text : 'Staff',
      });

      if (mounted) {
        if (success) {
          Navigator.pop(context); // Close bottom sheet
          widget.onSuccess(); // Trigger refresh
          SuccessDialog.show(
            context,
            title: 'Data Diperbarui!',
            message:
                'Informasi Pekerja ${_namaController.text} telah berhasil diperbarui.',
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal memperbarui data Pekerja')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
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
                  Icon(Icons.edit_outlined, color: Color(0xFF8E44AD)),
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
                label: 'Nama Pekerja',
                icon: Icons.person_outline,
                validator: (val) =>
                    val == null || val.isEmpty ? 'Nama wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                controller: _teleponController,
                label: 'Nomor Telepon (WhatsApp) *',
                icon: FontAwesomeIcons.whatsapp,
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (val) =>
                    val == null || val.isEmpty ? 'Nomor telepon wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              _buildAutocompleteField(
                controller: _posisiController,
                label: 'Posisi Pekerja',
                icon: Icons.work_outline,
                options: _posisiOptions,
                helperText: 'Contoh: Supir Lansir, Anggota, Kasir',
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Posisi wajib diisi';
                  }
                  return null;
                },
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
                  backgroundColor: const Color(0xFF8E44AD),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'SIMPAN PERUBAHAN',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
              ),
            ],
          ),
        ),
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
        prefixIcon: Icon(icon, color: const Color(0xFF8E44AD)),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF8E44AD), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
    );
  }

  Widget _buildAutocompleteField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required List<String> options,
    String? helperText,
    String? Function(String?)? validator,
  }) {
    return RawAutocomplete<String>(
      textEditingController: controller,
      focusNode: FocusNode(),
      optionsBuilder: (TextEditingValue textEditingValue) {
        if (textEditingValue.text.isEmpty) {
          return options;
        }
        return options.where((String option) {
          return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
        });
      },
      onSelected: (String selection) {
        controller.text = selection;
      },
      fieldViewBuilder: (BuildContext context, TextEditingController fieldTextEditingController, FocusNode fieldFocusNode, VoidCallback onFieldSubmitted) {

        return TextFormField(
          controller: fieldTextEditingController,
          focusNode: fieldFocusNode,
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            helperText: helperText,
            helperMaxLines: 2,
            helperStyle: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            prefixIcon: Icon(icon, color: const Color(0xFF8E44AD), size: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF8E44AD), width: 2),
            ),
            filled: true,
            fillColor: Colors.grey[50],
          ),
        );
      },
      optionsViewBuilder: (BuildContext context, AutocompleteOnSelected<String> onSelected, Iterable<String> options) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: SizedBox(
              width: MediaQuery.of(context).size.width - 48,
              height: 200.0,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: options.length,
                itemBuilder: (BuildContext context, int index) {
                  final String option = options.elementAt(index);
                  return ListTile(
                    title: Text(option),
                    onTap: () {
                      onSelected(option);
                    },
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
