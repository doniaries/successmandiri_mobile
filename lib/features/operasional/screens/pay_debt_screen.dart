import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';

class PayDebtScreen extends StatefulWidget {
  final String? pihakType;
  final int? pihakId;

  const PayDebtScreen({super.key, this.pihakType, this.pihakId});

  @override
  State<PayDebtScreen> createState() => _PayDebtScreenState();
}

class _PayDebtScreenState extends State<PayDebtScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
  String? _selectedPihakType;
  dynamic _selectedPihak;

  @override
  void initState() {
    super.initState();
    if (widget.pihakType != null) {
      _selectedPihakType = widget.pihakType;
      
      // We need to wait for providers to be ready if they haven't fetched data yet
      // But usually they are already in memory.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final provider = context.read<ResourceProvider>();
        List<dynamic> debtors = [];
        if (_selectedPihakType == 'App\\Models\\Penjual') {
          debtors = provider.penjualDebtors;
        } else if (_selectedPihakType == 'App\\Models\\Supir') {
          debtors = provider.supirDebtors;
        } else if (_selectedPihakType == 'App\\Models\\Pekerja') {
          debtors = provider.pekerjaDebtors;
        }

        if (widget.pihakId != null && debtors.isNotEmpty) {
          try {
            final pihak = debtors.firstWhere((e) => e.id == widget.pihakId);
            setState(() {
              _selectedPihak = pihak;
              _nominalController.text = CurrencyFormatter.formatNumber(pihak.sisaHutang ?? 0);
            });
          } catch (e) {
            // Pihak not found in debtors list (maybe 0 debt?)
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _nominalController.dispose();
    _keteranganController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPihak == null) return;

    final provider = context.read<ResourceProvider>();
    // Clean nominal from "Rp " and "." before parsing
    final cleanNominal = _nominalController.text.replaceAll(RegExp(r'[^0-9]'), '');
    final nominalValue = double.tryParse(cleanNominal) ?? 0;

    final success = await provider.addOperasional({
      'tanggal': DateFormat('yyyy-MM-dd').format(_selectedDate),
      'operasional': 'Pemasukan',
      'kategori': 'bayar_hutang',
      'nominal': nominalValue,
      'keterangan': _keteranganController.text,
      'pihak_id': _selectedPihak.id,
      'pihak_type': _selectedPihakType,
    });

    if (mounted) {
      if (success) {
        SuccessDialog.show(
          context,
          title: 'Pembayaran Berhasil!',
          message: 'Pembayaran hutang dari ${_selectedPihak.nama} sebesar ${CurrencyFormatter.formatRupiah(nominalValue)} telah berhasil dicatat.',
          onConfirm: () => Navigator.pop(context),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal menyimpan pembayaran hutang')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Bayar Hutang', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Info Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF01579B), Color(0xFF0288D1)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF01579B).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Pencatatan Pembayaran',
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Pilih pihak yang akan membayar hutang',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Tanggal
              InkWell(
                onTap: () => _selectDate(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5, spreadRadius: 1),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded, color: Color(0xFF01579B), size: 20),
                      const SizedBox(width: 15),
                      Text(DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                      const Spacer(),
                      const Icon(Icons.edit_calendar_rounded, color: Colors.grey, size: 18),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tipe Pihak
              DropdownButtonFormField<String>(
                initialValue: _selectedPihakType,
                decoration: _inputDecoration('Tipe Pembayar', Icons.group_work_rounded),
                items: const [
                  DropdownMenuItem(value: 'App\\Models\\Penjual', child: Text('Penjual')),
                  DropdownMenuItem(value: 'App\\Models\\Supir', child: Text('Supir')),
                  DropdownMenuItem(value: 'App\\Models\\Pekerja', child: Text('Pekerja')),
                ],
                onChanged: (val) {
                  setState(() {
                    _selectedPihakType = val;
                    _selectedPihak = null;
                    _nominalController.clear();
                  });
                },
                validator: (val) => val == null ? 'Pilih tipe pembayar' : null,
              ),
              const SizedBox(height: 20),

              // Pilih Nama (Filtered by Debt)
              if (_selectedPihakType != null) ...[
                Consumer<ResourceProvider>(
                  builder: (context, provider, child) {
                    List<dynamic> debtors = [];
                    if (_selectedPihakType == 'App\\Models\\Penjual') {
                      debtors = provider.penjualDebtors;
                    } else if (_selectedPihakType == 'App\\Models\\Supir') {
                      debtors = provider.supirDebtors;
                    } else if (_selectedPihakType == 'App\\Models\\Pekerja') {
                      debtors = provider.pekerjaDebtors;
                    }

                    if (debtors.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.orange[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange[200]!),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.orange),
                            SizedBox(width: 12),
                            Expanded(child: Text('Tidak ada data yang memiliki hutang pada kategori ini.', style: TextStyle(fontSize: 13, color: Colors.orange))),
                          ],
                        ),
                      );
                    }

                    return DropdownButtonFormField<dynamic>(
                      isExpanded: true,
                      initialValue: _selectedPihak,
                      decoration: _inputDecoration('Pilih Nama Pembayar', Icons.person_rounded),
                      items: debtors.map((e) => DropdownMenuItem(
                        value: e,
                        child: Text(
                          '${e.nama} (${CurrencyFormatter.formatRupiah(e.sisaHutang ?? 0)})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      )).toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPihak = val;
                          if (val != null) {
                            _nominalController.text = CurrencyFormatter.formatNumber(val.sisaHutang ?? 0);
                          }
                        });
                      },
                      validator: (val) => val == null ? 'Pilih nama pembayar' : null,
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Sisa Hutang Info
              if (_selectedPihak != null) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE3F2FD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF90CAF9)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Total Sisa Hutang:', style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1565C0))),
                      Text(
                        CurrencyFormatter.formatRupiah(_selectedPihak.sisaHutang ?? 0),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0D47A1), fontSize: 18),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Nominal
              TextFormField(
                controller: _nominalController,
                keyboardType: TextInputType.text,
                inputFormatters: [CurrencyInputFormatter()],
                decoration: _inputDecoration('Nominal Bayar', Icons.payments_rounded).copyWith(
                  prefixText: 'Rp ',
                  hintText: '0',
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Nominal wajib diisi';
                  final cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                  final nominal = double.tryParse(cleanVal) ?? 0;
                  if (nominal <= 0) return 'Nominal harus lebih dari 0';
                  if (_selectedPihak != null && nominal > (_selectedPihak.sisaHutang ?? 0)) {
                    return 'Nominal melebihi sisa hutang';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 20),

              // Keterangan
              TextFormField(
                controller: _keteranganController,
                maxLines: 2,
                decoration: _inputDecoration('Keterangan (Opsional)', Icons.note_rounded),
              ),
              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF01579B),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                  shadowColor: const Color(0xFF01579B).withValues(alpha: 0.5),
                ),
                child: const Text('PROSES PEMBAYARAN', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF01579B), size: 20),
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
      fillColor: Colors.white,
    );
  }
}

