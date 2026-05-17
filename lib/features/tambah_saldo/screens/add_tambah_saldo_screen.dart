import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';

class AddTambahSaldoScreen extends StatefulWidget {
  const AddTambahSaldoScreen({super.key});

  @override
  State<AddTambahSaldoScreen> createState() => _AddTambahSaldoScreenState();
}

class _AddTambahSaldoScreenState extends State<AddTambahSaldoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    final dashboardProvider = context.read<DashboardProvider>();
    final activeDateStr = dashboardProvider.summary?.systemActiveDate;
    if (activeDateStr != null) {
      try {
        _selectedDate = DateTime.parse(activeDateStr);
      } catch (_) {
        _selectedDate = DateTime.now();
      }
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
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF01579B),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.watch<TambahSaldoProvider>().isLoading;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Tambah Saldo',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF01579B),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: AppLoadingOverlay(
        isLoading: isLoading,
        message: 'Memproses penambahan saldo...',
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _nominalController,
                    decoration: InputDecoration(
                      labelText: 'Nominal Saldo',
                      prefixText: 'Rp ',
                      prefixIcon: const Icon(
                        Icons.account_balance_wallet_outlined,
                        color: Color(0xFF01579B),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF01579B),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Mohon masukkan nominal';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  InkWell(
                    onTap: () => _selectDate(context),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Tanggal Transaksi',
                        prefixIcon: const Icon(
                          Icons.calendar_today_outlined,
                          color: Color(0xFF01579B),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'id_ID',
                            ).format(_selectedDate),
                            style: const TextStyle(fontSize: 16),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _keteranganController,
                    decoration: InputDecoration(
                      labelText: 'Keterangan',
                      prefixIcon: const Icon(
                        Icons.note_outlined,
                        color: Color(0xFF01579B),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFF01579B),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: Colors.grey[50],
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Mohon masukkan keterangan';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  AppPrimaryButton(
                    text: 'SIMPAN TRANSAKSI',
                    onPressed: () async {
                      if (_formKey.currentState!.validate()) {
                        final nominalClean = _nominalController.text.replaceAll(
                          '.',
                          '',
                        );

                        final success = await context
                            .read<TambahSaldoProvider>()
                            .createRequest(
                              nominal: double.parse(nominalClean),
                              tanggal: (() {
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
                              keterangan: _keteranganController.text,
                            );

                        if (!context.mounted) return;

                        if (success) {
                          context.read<DashboardProvider>().fetchSummary();
                          final bool isOffline =
                              context
                                  .read<TambahSaldoProvider>()
                                  .errorMessage
                                  ?.contains('offline') ??
                              false;
                          SuccessDialog.show(
                            context,
                            title: 'Saldo Bertambah!',
                            message: isOffline
                                ? 'Sinyal tidak stabil. Permintaan saldo sebesar ${CurrencyFormatter.formatRupiah(double.parse(nominalClean))} telah disimpan di antrean perangkat dan akan otomatis dikirim saat ada sinyal.'
                                : 'Berhasil menambah saldo sebesar ${CurrencyFormatter.formatRupiah(double.parse(nominalClean))}.',
                            isOffline: isOffline,
                            onConfirm: () => Navigator.of(
                              context,
                            ).popUntil((route) => route.isFirst),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                context
                                        .read<TambahSaldoProvider>()
                                        .errorMessage ??
                                    'Gagal menambah saldo',
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    isLoading: isLoading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
