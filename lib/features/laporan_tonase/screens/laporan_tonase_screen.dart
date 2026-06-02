import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../models/laporan_tonase.dart';
import '../providers/laporan_tonase_provider.dart';

class LaporanTonaseScreen extends StatefulWidget {
  const LaporanTonaseScreen({super.key});

  @override
  State<LaporanTonaseScreen> createState() => _LaporanTonaseScreenState();
}

class _LaporanTonaseScreenState extends State<LaporanTonaseScreen> {
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchData();
    });
  }

  void _fetchData() {
    context.read<LaporanTonaseProvider>().fetchLaporan(
      month: _selectedMonth,
      year: _selectedYear,
    );
  }

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: '',
    decimalDigits: 0,
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Tonase Bulanan'),
        backgroundColor: const Color(0xFF27AE60),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _buildFilter(),
          Expanded(
            child: Consumer<LaporanTonaseProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (provider.error != null) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Gagal memuat data:\n${provider.error}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _fetchData,
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  );
                }

                final data = provider.data;
                if (data == null) {
                  return const Center(child: Text('Data tidak tersedia'));
                }

                return _buildReportTable(data);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilter() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Bulan',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: _selectedMonth,
              items: List.generate(12, (index) {
                return DropdownMenuItem(
                  value: index + 1,
                  child: Text(DateFormat('MMMM', 'id_ID').format(DateTime(2024, index + 1))),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedMonth = value);
                  _fetchData();
                }
              },
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: DropdownButtonFormField<int>(
              decoration: const InputDecoration(
                labelText: 'Tahun',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              initialValue: _selectedYear,
              items: List.generate(5, (index) {
                final year = DateTime.now().year - 2 + index;
                return DropdownMenuItem(
                  value: year,
                  child: Text(year.toString()),
                );
              }),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedYear = value);
                  _fetchData();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportTable(LaporanTonaseResponse data) {
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[200]),
          columnSpacing: 20,
          columns: const [
            DataColumn(label: Text('No', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tanggal', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Tonase (Kg)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Harga (Rp)', style: TextStyle(fontWeight: FontWeight.bold))),
            DataColumn(label: Text('Keterangan', style: TextStyle(fontWeight: FontWeight.bold))),
          ],
          rows: [
            ...data.report.asMap().entries.map((entry) {
              final index = entry.key;
              final row = entry.value;
              final textColor = row.isHoliday ? Colors.red : Colors.black;
              final textStyle = TextStyle(color: textColor, fontWeight: row.isHoliday ? FontWeight.bold : FontWeight.normal);
              
              return DataRow(
                color: WidgetStateProperty.all(row.isHoliday ? Colors.red[50] : Colors.white),
                cells: [
                  DataCell(Text('${index + 1}', style: textStyle)),
                  DataCell(Text(row.tanggal, style: textStyle)),
                  DataCell(Text(row.tonase > 0 ? _currencyFormat.format(row.tonase) : '-', style: textStyle)),
                  DataCell(Text(row.harga > 0 ? _currencyFormat.format(row.harga) : '-', style: textStyle)),
                  DataCell(Text(row.keterangan, style: textStyle)),
                ],
              );
            }),
            DataRow(
              color: WidgetStateProperty.all(Colors.grey[200]),
              cells: [
                const DataCell(Text('')),
                const DataCell(Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(_currencyFormat.format(data.totalTonase), style: const TextStyle(fontWeight: FontWeight.bold))),
                const DataCell(Text('')),
                const DataCell(Text('')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
