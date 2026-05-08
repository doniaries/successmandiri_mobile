import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/tambah_saldo_provider.dart';
import '../../providers/auth_provider.dart';
import '../../core/utils/currency_formatter.dart';
import '../../widgets/success_dialog.dart';

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
    final user = context.watch<AuthProvider>().user;
    final role = user?.role?.toLowerCase();
    final isDirect = ['admin', 'pimpinan', 'super_admin'].contains(role);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDirect ? 'Tambah Saldo Langsung' : 'Pengajuan Tambah Saldo',
        ),
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
                  keyboardType: TextInputType.text,
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
                    decoration: InputDecoration(
                      labelText: isDirect
                          ? 'Tanggal Transaksi'
                          : 'Tanggal Pengajuan',
                      border: const OutlineInputBorder(),
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
                    labelText: 'Keperluan / Keterangan',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Mohon masukkan keperluan top up';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      // Bersihkan format titik ribuan sebelum dikirim
                      final nominalClean = _nominalController.text.replaceAll(
                        '.',
                        '',
                      );
                      final success = await context
                          .read<TambahSaldoProvider>()
                          .createRequest(
                            nominal: double.parse(nominalClean),
                            tanggal: DateFormat(
                              'yyyy-MM-dd',
                            ).format(_selectedDate),
                            keterangan: _keteranganController.text,
                          );

                      if (!context.mounted) return;

                      if (success) {
                        SuccessDialog.show(
                          context,
                          title: isDirect
                              ? 'Saldo Bertambah!'
                              : 'Permintaan Terkirim!',
                          message: isDirect
                              ? 'Berhasil menambah saldo sebesar ${CurrencyFormatter.formatRupiah(double.parse(nominalClean))}.'
                              : 'Permintaan tambah saldo sebesar ${CurrencyFormatter.formatRupiah(double.parse(nominalClean))} berhasil dikirim.',
                          onConfirm: () {
                            Navigator.pop(context); // Tutup dialog
                            if (mounted) {
                              Navigator.pop(context); // Tutup halaman
                            }
                          },
                        );
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              context
                                      .read<TambahSaldoProvider>()
                                      .errorMessage ??
                                  'Gagal membuat permintaan',
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
                      : Text(
                          isDirect
                              ? 'Tambah Saldo Sekarang'
                              : 'Kirim Permintaan',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

