import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';

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
  int? _selectedPihakId;

  @override
  void initState() {
    super.initState();
    final activeDateStr = context
        .read<DashboardProvider>()
        .summary
        ?.systemActiveDate;
    if (activeDateStr != null) {
      _selectedDate = DateTime.parse(activeDateStr);
    }
    if (widget.pihakType != null) {
      _selectedPihakType = widget.pihakType;
      _selectedPihakId = widget.pihakId;
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
              _selectedPihakId = pihak.id;
              // _nominalController.text = (pihak.sisaHutang ?? 0).toInt().toString(); // Disabled auto-fill
            });
          } catch (e) {
            // Silently fail if firstWhere doesn't find a match (e.g. invalid widget.pihakId)
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
    final cleanNominal = _nominalController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final nominalValue = double.tryParse(cleanNominal) ?? 0;

    final success = await provider.addOperasional({
      'tanggal': (() {
        final now = DateTime.now();
        final finalDateTime = DateTime(
          _selectedDate.year,
          _selectedDate.month,
          _selectedDate.day,
          now.hour,
          now.minute,
          now.second,
        );
        return DateFormat('yyyy-MM-dd HH:mm:ss').format(finalDateTime);
      })(),
      'operasional': 'Pemasukan',
      'kategori': 'bayar_hutang',
      'nominal': nominalValue,
      'keterangan': _keteranganController.text,
      'pihak_id': _selectedPihak.id,
      'pihak_type': _selectedPihakType,
    });

    if (mounted) {
      if (success != null) {
        final bool isOffline = provider.errorMessage == 'offline';
        SuccessDialog.show(
          context,
          title: 'Pembayaran Berhasil!',
          message: isOffline
              ? 'Sinyal tidak stabil. Data pembayaran telah disimpan di antrean perangkat.'
              : 'Pembayaran hutang telah berhasil diproses.',
          isOffline: isOffline,
          onConfirm: () =>
              Navigator.of(context).pop(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              provider.errorMessage ?? 'Gagal memproses pembayaran',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Bayar Hutang',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AppLoadingOverlay(
        isLoading: provider.isLoading,
        message: 'Memproses pembayaran...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _selectedPihakType,
                  decoration: _inputDecoration(
                    'Tipe Pembayar',
                    Icons.group_work_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'App\\Models\\Penjual',
                      child: Text('Penjual'),
                    ),
                    DropdownMenuItem(
                      value: 'App\\Models\\Supir',
                      child: Text('Supir'),
                    ),
                    DropdownMenuItem(
                      value: 'App\\Models\\Pekerja',
                      child: Text('Pekerja'),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedPihakType = val;
                      _selectedPihak = null;
                      _selectedPihakId = null;
                      _nominalController.clear();
                    });
                  },
                  validator: (val) =>
                      val == null ? 'Pilih tipe pembayar' : null,
                ),
                const SizedBox(height: 20),
                if (_selectedPihakType != null) ...[
                  Builder(builder: (context) {
                    final List<dynamic> items = (_selectedPihakType == 'App\\Models\\Penjual'
                        ? provider.penjualDebtors
                        : _selectedPihakType == 'App\\Models\\Supir'
                        ? provider.supirDebtors
                        : provider.pekerjaDebtors) as List<dynamic>;

                    final isValueInItems = items.any((e) => (e as dynamic).id == _selectedPihakId);

                    return DropdownButtonFormField<int>(
                      isExpanded: true,
                      initialValue: isValueInItems ? _selectedPihakId : null,
                      decoration: _inputDecoration(
                        'Pilih Nama Pembayar',
                        Icons.person_rounded,
                      ),
                      items: items
                          .map(
                            (e) => DropdownMenuItem<int>(
                              value: (e as dynamic).id as int,
                              child: Text(
                                '${(e as dynamic).nama} (${CurrencyFormatter.formatRupiah((e as dynamic).sisaHutang ?? 0)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (val) {
                        setState(() {
                          _selectedPihakId = val;
                          dynamic found;
                          try {
                            found = items.firstWhere((e) => (e as dynamic).id == val);
                          } catch (_) {
                            found = null;
                          }
                          _selectedPihak = found;
                          // if (found != null) {
                          //   _nominalController.text =
                          //       CurrencyFormatter.formatNumber((found as dynamic).sisaHutang ?? 0);
                          // } // Disabled auto-fill
                        });
                      },
                      validator: (val) =>
                          val == null ? 'Pilih nama pembayar' : null,
                    );
                  }),
                  const SizedBox(height: 20),
                ],
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: _inputDecoration(
                      'Tanggal Pembayaran',
                      Icons.calendar_month_rounded,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          DateFormat(
                            'dd MMMM yyyy',
                            'id_ID',
                          ).format(_selectedDate),
                        ),
                        const Icon(Icons.arrow_drop_down, color: Colors.grey),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
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
                        const Text(
                          'Total Sisa Hutang:',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1565C0),
                          ),
                        ),
                        Text(
                          CurrencyFormatter.formatRupiah(
                            _selectedPihak.sisaHutang ?? 0,
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D47A1),
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
                TextFormField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [CurrencyInputFormatter()],
                  decoration: _inputDecoration(
                    'Nominal Bayar',
                    Icons.payments_rounded,
                  ).copyWith(prefixText: 'Rp '),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Nominal wajib diisi';
                    }
                    final cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                    final nominal = double.tryParse(cleanVal) ?? 0;
                    if (nominal <= 0) {
                      return 'Nominal harus lebih dari 0';
                    }
                    if (_selectedPihak != null &&
                        nominal > (_selectedPihak.sisaHutang ?? 0)) {
                      return 'Nominal melebihi sisa hutang';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _keteranganController,
                  maxLines: 2,
                  decoration: _inputDecoration(
                    'Keterangan (Opsional)',
                    Icons.note_rounded,
                  ),
                ),
                const SizedBox(height: 40),
                AppPrimaryButton(
                  text: 'PROSES PEMBAYARAN',
                  onPressed: _submit,
                  isLoading: provider.isLoading,
                ),
              ],
            ),
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
      fillColor: Colors.grey[50],
    );
  }
}
