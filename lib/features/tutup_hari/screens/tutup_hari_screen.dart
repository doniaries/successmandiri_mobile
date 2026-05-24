import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/tutup_hari/providers/tutup_hari_provider.dart';

class TutupHariScreen extends StatefulWidget {
  const TutupHariScreen({super.key});

  @override
  State<TutupHariScreen> createState() => _TutupHariScreenState();
}

class _TutupHariScreenState extends State<TutupHariScreen> {
  final _formKey = GlobalKey<FormState>();
  final _saldoFisikController = TextEditingController();
  final _catatanController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkStatus();
    });
  }

  @override
  void dispose() {
    _saldoFisikController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _checkStatus() {
    final provider = Provider.of<TutupHariProvider>(context, listen: false);
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    provider.checkStatus(formattedDate);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _checkStatus();
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final provider = Provider.of<TutupHariProvider>(context, listen: false);
    final formattedDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final saldoFisik = double.tryParse(_saldoFisikController.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

    final success = await provider.performClosing(
      tanggal: formattedDate,
      saldoAkhirFisik: saldoFisik,
      catatan: _catatanController.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tutup Hari Berhasil!'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.errorMessage), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutup Hari'),
      ),
      body: Consumer<TutupHariProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.isClosed) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, size: 80, color: Colors.green),
                    const SizedBox(height: 16),
                    Text(
                      'Tanggal ${DateFormat('dd MMM yyyy').format(_selectedDate)} sudah ditutup.',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => _selectDate(context),
                      child: const Text('Pilih Tanggal Lain'),
                    )
                  ],
                ),
              ),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Card(
                    child: ListTile(
                      title: const Text('Tanggal'),
                      subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _saldoFisikController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Saldo Akhir Fisik (Di Kasir)',
                      border: OutlineInputBorder(),
                      prefixText: 'Rp ',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Saldo akhir fisik wajib diisi';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _catatanController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (Opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _submit,
                    child: const Text('Proses Tutup Hari', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
