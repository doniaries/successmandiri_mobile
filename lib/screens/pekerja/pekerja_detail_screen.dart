import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/pekerja_model.dart';
import '../../models/mutasi_hutang_model.dart';
import '../../core/utils/currency_formatter.dart';
import '../../providers/resource_provider.dart';
import 'edit_pekerja_screen.dart';

class PekerjaDetailScreen extends StatefulWidget {
  final Pekerja pekerja;

  const PekerjaDetailScreen({super.key, required this.pekerja});

  @override
  State<PekerjaDetailScreen> createState() => _PekerjaDetailScreenState();
}

class _PekerjaDetailScreenState extends State<PekerjaDetailScreen> {
  late Pekerja _currentPekerja;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentPekerja = widget.pekerja;
    _fetchDetail();
  }

  Future<void> _fetchDetail() async {
    try {
      final detail = await context.read<ResourceProvider>().getPekerjaDetail(widget.pekerja.id);
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
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Detail Pekerja', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => EditPekerjaScreen(pekerja: _currentPekerja)),
              );
              _fetchDetail();
            },
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
                    child: const Icon(Icons.person_rounded, size: 40, color: Colors.white),
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      _currentPekerja.posisi.toUpperCase(),
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (_currentPekerja.hutang > 0) ...[
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
            _buildInfoSection('Informasi Kontak & Posisi', [
              _buildInfoRow(
                Icons.phone_android_rounded, 
                'Telepon', 
                _currentPekerja.telepon ?? '-',
                trailing: _currentPekerja.telepon != null ? IconButton(
                  icon: const Icon(Icons.call, color: Color(0xFF01579B)),
                  onPressed: () => _makePhoneCall(_currentPekerja.telepon!),
                ) : null,
              ),
              _buildInfoRow(Icons.info_outline_rounded, 'Posisi', _currentPekerja.posisi),
              _buildInfoRow(Icons.location_on_rounded, 'Alamat', _currentPekerja.alamat ?? '-', isMultiLine: true),
            ]),

            const SizedBox(height: 24),
            _buildInfoSection('Posisi Keuangan', [
              _buildInfoRow(
                Icons.account_balance_wallet_rounded, 
                'Total Hutang', 
                CurrencyFormatter.formatRupiah(_currentPekerja.hutang),
                textColor: _currentPekerja.hutang > 0 ? Colors.orange[800] : Colors.green[700],
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

    final List<MutasiHutang> history = _currentPekerja.mutasiHutang ?? [];

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

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          const SizedBox(height: 20),
          ...children,
        ],
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

