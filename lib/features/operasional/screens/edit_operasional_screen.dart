import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/features/penjual/screens/add_penjual_screen.dart';
import 'package:sawitappmobile/features/supir/screens/add_supir_screen.dart';
import 'package:sawitappmobile/features/pekerja/screens/add_pekerja_screen.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';

class EditOperasionalScreen extends StatefulWidget {
  final Operasional operasional;

  const EditOperasionalScreen({super.key, required this.operasional});

  @override
  State<EditOperasionalScreen> createState() => _EditOperasionalScreenState();
}

class _EditOperasionalScreenState extends State<EditOperasionalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nominalController;
  late final TextEditingController _keteranganController;

  late DateTime _selectedDate;
  late String _selectedOperasional;
  String? _selectedKategori;
  int? _selectedPihakId;
  String? _selectedPihakType;
  dynamic _selectedPihak;

  final Map<String, String> _kategoriMap = {
    'Tambah Hutang': 'pinjaman',
    'Bayar Hutang': 'bayar_hutang',
    'Pijak Gas': 'pijakan_gas',
    'Uang Jalan': 'uang_jalan',
    'Bahan Bakar': 'bahan_bakar',
    'Perawatan': 'perawatan',
    'Lain-lain': 'lain_lain',
    'Tambah Saldo': 'tambah_saldo',
  };

  String _getOperasionalType(String kategoriLabel) {
    if (kategoriLabel == 'Tambah Saldo' || kategoriLabel == 'Bayar Hutang') {
      return 'Pemasukan';
    }
    return 'Pengeluaran';
  }

  @override
  void initState() {
    super.initState();
    _nominalController = TextEditingController(
      text: widget.operasional.nominal.toInt().toString(),
    );
    _keteranganController = TextEditingController(text: widget.operasional.keterangan);
    _selectedDate = widget.operasional.tanggal;
    _selectedOperasional = widget.operasional.operasional;
    
    // Find category label from slug
    _selectedKategori = _kategoriMap.entries.firstWhere(
      (entry) => entry.value == widget.operasional.kategori,
      orElse: () => const MapEntry('Lain-lain', 'lain_lain'),
    ).key;

    _selectedPihakType = widget.operasional.pihakType;
    _selectedPihakId = widget.operasional.pihakId;

    // Load resources to populate the dropdowns
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ResourceProvider>().fetchAllResources();
    });
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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final provider = context.read<ResourceProvider>();
    final cleanNominal = _nominalController.text.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );
    final nominalValue = double.tryParse(cleanNominal) ?? 0;

    // Validasi Saldo Perusahaan
    if (_selectedOperasional == 'Pengeluaran') {
      final double saldoPerusahaan =
          context.read<DashboardProvider>().summary?.saldo ?? 0;
      // Adjust with the previous nominal to avoid false balance limit error
      final double adjustedSaldo = saldoPerusahaan + widget.operasional.nominal;
      if (nominalValue > adjustedSaldo) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saldo perusahaan tidak mencukupi (Maks: ${CurrencyFormatter.formatRupiah(adjustedSaldo)})',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
    }

    final success = await provider.updateOperasional(widget.operasional.id, {
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
      'operasional': _selectedOperasional,
      'kategori': _kategoriMap[_selectedKategori],
      'nominal': nominalValue,
      'keterangan': _keteranganController.text,
      'pihak_id': _selectedPihakId,
      'pihak_type': _selectedPihakType,
    });

    if (mounted) {
      if (success) {
        context.read<DashboardProvider>().fetchSummary();
        SuccessDialog.show(
          context,
          title: 'Ubah Berhasil!',
          message:
              'Transaksi operasional sebesar ${CurrencyFormatter.formatRupiah(nominalValue)} telah diperbarui.',
          onConfirm: () =>
              Navigator.of(context).popUntil((route) => route.isFirst),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.errorMessage ?? 'Gagal memperbarui transaksi operasional'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResourceProvider>();

    return AppLoadingOverlay(
      isLoading: provider.isLoading,
      message: 'Menyimpan perubahan...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Ubah Operasional',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF01579B),
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Tanggal
                InkWell(
                  onTap: () => _selectDate(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 15,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          color: Color(0xFF01579B),
                          size: 20,
                        ),
                        const SizedBox(width: 15),
                        Text(
                          DateFormat(
                            'dd MMMM yyyy',
                            'id_ID',
                          ).format(_selectedDate),
                          style: const TextStyle(fontSize: 15),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Kategori
                DropdownButtonFormField<String>(
                  initialValue: _selectedKategori,
                  decoration: _inputDecoration(
                    'Kategori',
                    Icons.category_rounded,
                  ),
                  items: _kategoriMap.keys
                      .map(
                        (cat) => DropdownMenuItem(value: cat, child: Text(cat)),
                      )
                      .toList(),
                  onChanged: (val) {
                    if (val != null) {
                      setState(() {
                        _selectedKategori = val;
                        _selectedOperasional = _getOperasionalType(val);
                        _selectedPihak = null;
                        _selectedPihakId = null;
                      });
                    }
                  },
                  validator: (val) => val == null ? 'Pilih kategori' : null,
                ),
                const SizedBox(height: 20),

                // Operasional (Type)
                TextFormField(
                  initialValue: _selectedOperasional,
                  key: ValueKey(_selectedOperasional),
                  readOnly: true,
                  decoration: _inputDecoration(
                    'Tipe Operasional',
                    Icons.swap_vert_rounded,
                  ).copyWith(filled: true, fillColor: Colors.grey[200]),
                ),
                const SizedBox(height: 20),

                // Pihak Type
                DropdownButtonFormField<String>(
                  initialValue: _selectedPihakType,
                  decoration: _inputDecoration(
                    'Tipe Pihak (Opsional)',
                    Icons.group_rounded,
                  ),
                  items: const [
                    DropdownMenuItem(value: null, child: Text('Tidak Ada')),
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
                    });
                  },
                ),
                const SizedBox(height: 20),

                // Pihak Id
                if (_selectedPihakType != null) ...[
                  Consumer<ResourceProvider>(
                    builder: (context, provider, child) {
                      List<dynamic> parties = [];

                      final bool isBayarHutang =
                          _selectedKategori == 'Bayar Hutang';

                      if (_selectedPihakType == 'App\\Models\\Penjual') {
                        parties = isBayarHutang
                            ? provider.penjualDebtors
                            : provider.penjuals;
                      } else if (_selectedPihakType == 'App\\Models\\Supir') {
                        parties = isBayarHutang
                            ? provider.supirDebtors
                            : provider.supirs;
                      } else if (_selectedPihakType == 'App\\Models\\Pekerja') {
                        parties = isBayarHutang
                            ? provider.pekerjaDebtors
                            : provider.pekerjas;
                      }

                      // Dynamic pre-fill of full object based on selected pihak ID
                      if (_selectedPihak == null && _selectedPihakId != null && parties.isNotEmpty) {
                        try {
                          _selectedPihak = parties.firstWhere(
                            (e) => e.id == _selectedPihakId,
                            orElse: () => null,
                          );
                        } catch (_) {}
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<dynamic>(
                              key: ValueKey(
                                'pihak_${_selectedPihakType}_${_selectedKategori}_${_selectedPihak?.id}',
                              ),
                              isExpanded: true,
                              initialValue: _selectedPihak,
                              decoration: _inputDecoration(
                                'Pilih Pihak',
                                Icons.person_rounded,
                              ),
                              items: parties.map((e) {
                                final double sisaHutang =
                                    double.tryParse(
                                      e.sisaHutang?.toString() ?? '0',
                                    ) ??
                                    0;
                                return DropdownMenuItem<dynamic>(
                                  value: e,
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        e.nama.toString().toUpperCase(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (sisaHutang > 0)
                                        Text(
                                          'Hutang: ${CurrencyFormatter.formatRupiah(sisaHutang)}',
                                          style: TextStyle(
                                            fontSize: 9,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                    ],
                                  ),
                                );
                              }).toList(),
                              selectedItemBuilder: (BuildContext context) {
                                return parties.map<Widget>((e) {
                                  return Text(
                                    e.nama.toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }).toList();
                              },
                              onChanged: (val) {
                                setState(() {
                                  _selectedPihak = val;
                                  _selectedPihakId = val?.id;
                                });
                              },
                              validator: (val) =>
                                  _selectedPihakType != null && val == null
                                  ? 'Pilih pihak'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: const Color(
                                0xFF01579B,
                              ).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF01579B),
                              ),
                              onPressed: () async {
                                Widget? screen;
                                if (_selectedPihakType ==
                                    'App\\Models\\Penjual') {
                                  screen = const AddPenjualScreen();
                                } else if (_selectedPihakType ==
                                    'App\\Models\\Supir') {
                                  screen = const AddSupirScreen();
                                } else if (_selectedPihakType ==
                                    'App\\Models\\Pekerja') {
                                  screen = const AddPekerjaScreen();
                                }

                                if (screen != null) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => screen!,
                                    ),
                                  );
                                  if (mounted) {
                                    provider.fetchAllResources();
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                ],

                // Nominal
                TextFormField(
                  controller: _nominalController,
                  keyboardType: TextInputType.number,
                  decoration: _inputDecoration(
                    'Nominal',
                    Icons.payments_rounded,
                  ).copyWith(prefixText: 'Rp ', hintText: '0'),
                  validator: (val) {
                    if (val == null || val.isEmpty) {
                      return 'Nominal wajib diisi';
                    }
                    final cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                    final nominal = double.tryParse(cleanVal) ?? 0;
                    if (nominal <= 0) return 'Nominal harus lebih dari 0';

                    if (_selectedKategori == 'Bayar Hutang' &&
                        _selectedPihak != null) {
                      final double sisaHutang =
                          double.tryParse(
                            _selectedPihak.sisaHutang?.toString() ?? '0',
                          ) ??
                          0;
                      // When editing, adjust the limit with the previous payment nominal
                      final double previousNominal = widget.operasional.kategori == 'bayar_hutang' 
                          ? widget.operasional.nominal 
                          : 0;
                      final double adjustedSisaHutang = sisaHutang + previousNominal;
                      if (nominal > adjustedSisaHutang) {
                        return 'Nominal melebihi sisa hutang (${CurrencyFormatter.formatRupiah(adjustedSisaHutang)})';
                      }
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // Keterangan
                TextFormField(
                  controller: _keteranganController,
                  maxLines: 3,
                  decoration: _inputDecoration(
                    'Keterangan',
                    Icons.note_rounded,
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Keterangan wajib diisi';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 40),

                AppPrimaryButton(
                  text: 'SIMPAN PERUBAHAN',
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
