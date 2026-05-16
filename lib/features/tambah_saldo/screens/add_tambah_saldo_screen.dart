import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';

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
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tambah Saldo'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nominalController,
                  decoration: const InputDecoration(
                    labelText: 'Nominal Saldo',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
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
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Transaksi',
                      border: OutlineInputBorder(),
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
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _keteranganController,
                  decoration: const InputDecoration(
                    labelText: 'Keterangan',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mohon masukkan keterangan';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final nominalClean = _nominalController.text.replaceAll('.', '');
                      
                      final success = await context.read<TambahSaldoProvider>().createRequest(
                        nominal: double.parse(nominalClean),
                        tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
                        keterangan: _keteranganController.text,
                      );

                      if (!context.mounted) return;

                      if (success) {
                        final bool isOffline = context.read<TambahSaldoProvider>().errorMessage?.contains('offline') ?? false;
                        SuccessDialog.show(
                          context,
                          title: 'Saldo Bertambah!',
                          message: isOffline
                              ? 'Sinyal tidak stabil. Permintaan saldo sebesar ${CurrencyFormatter.formatRupiah(double.parse(nominalClean))} telah disimpan di antrean perangkat dan akan otomatis dikirim saat ada sinyal.'
                              : 'Berhasil menambah saldo sebesar ${CurrencyFormatter.formatRupiah(double.parse(nominalClean))}.',
                          isOffline: isOffline,
                          onConfirm: () => Navigator.of(context).popUntil((route) => route.isFirst),
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context.read<TambahSaldoProvider>().errorMessage ?? 'Gagal menambah saldo',
                            ),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: const Color(0xFF01579B),
                    foregroundColor: Colors.white,
                  ),
                  child: context.watch<TambahSaldoProvider>().isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Simpan Transaksi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
