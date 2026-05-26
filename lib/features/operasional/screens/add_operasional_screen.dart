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
import 'package:sawitappmobile/shared/widgets/searchable_selection_modal.dart';
import package:sawitappmobile/core/utils/app_time.dart;

class AddOperasionalScreen extends StatefulWidget {
  const AddOperasionalScreen({super.key});

  @override
  State<AddOperasionalScreen> createState() => _AddOperasionalScreenState();
}

class _AddOperasionalScreenState extends State<AddOperasionalScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nominalController = TextEditingController();
  final _keteranganController = TextEditingController();

  DateTime _selectedDate = AppTime.now();
  String _selectedOperasional = 'Pengeluaran';
  String? _selectedKategori;
  int? _selectedPihakId;
  String? _selectedPihakType;
  dynamic _selectedPihak; // Added to store full object for debt info

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
    final activeDateStr = context
        .read<DashboardProvider>()
        .summary
        ?.systemActiveDate;
    if (activeDateStr != null) {
      _selectedDate = DateTime.parse(activeDateStr);
    }

    // Fetch resources if empty to populate the dropdowns
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resourceProvider = context.read<ResourceProvider>();
      if (resourceProvider.penjuals.isEmpty) {
        resourceProvider.fetchResources('penjual');
      }
      if (resourceProvider.supirs.isEmpty) {
        resourceProvider.fetchResources('supir');
      }
      if (resourceProvider.pekerjas.isEmpty) {
        resourceProvider.fetchResources('pekerja');
      }
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
    if (picked != null) setState(() => _selectedDate = picked);
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
      if (nominalValue > saldoPerusahaan) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saldo perusahaan tidak mencukupi (Saldo: ${CurrencyFormatter.formatRupiah(saldoPerusahaan)})',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
    }

    final success = await provider.addOperasional({
      'tanggal': (() {
        final now = AppTime.now();
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
      if (success != null) {
        context.read<DashboardProvider>().fetchSummary();
        SuccessDialog.show(
          context,
          title: 'Simpan Berhasil!',
          message:
              'Transaksi operasional $_selectedOperasional sebesar ${CurrencyFormatter.formatRupiah(nominalValue)} telah disimpan.',
          onConfirm: () =>
              Navigator.of(context).pop(),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal menyimpan transaksi operasional'),
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
      message: 'Menyimpan transaksi...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tambah Operasional',
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
                        Icon(
                          Icons.calendar_today_rounded,
                          color: const Color(0xFF01579B),
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
                        // Reset pihak selection when category changes as it might affect debtor list
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
                             ? provider.penjuals
                                 .where((e) => (e.sisaHutang ?? 0) > 0)
                                 .toList()
                             : provider.penjuals
                                 .where((e) => e.isActive)
                                 .toList();
                       } else if (_selectedPihakType == 'App\\Models\\Supir') {
                         parties = isBayarHutang
                             ? provider.supirs
                                 .where((e) => (e.sisaHutang ?? 0) > 0)
                                 .toList()
                             : provider.supirs
                                 .where((e) => e.isActive)
                                 .toList();
                       } else if (_selectedPihakType == 'App\\Models\\Pekerja') {
                         parties = isBayarHutang
                             ? provider.pekerjas
                                 .where((e) => e.sisaHutang > 0)
                                 .toList()
                             : provider.pekerjas
                                 .where((e) => e.isActive)
                                 .toList();
                       }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                Widget Function(String)? addNewBuilder;
                                String addNewLabel = 'TAMBAH BARU';
                                if (_selectedPihakType == 'App\\Models\\Penjual') {
                                  addNewBuilder = (query) => AddPenjualScreen(initialName: query);
                                  addNewLabel = 'TAMBAH PENJUAL BARU';
                                } else if (_selectedPihakType == 'App\\Models\\Supir') {
                                  addNewBuilder = (query) => AddSupirScreen(initialName: query);
                                  addNewLabel = 'TAMBAH SUPIR BARU';
                                } else if (_selectedPihakType == 'App\\Models\\Pekerja') {
                                  addNewBuilder = (query) => AddPekerjaScreen(initialName: query);
                                  addNewLabel = 'TAMBAH PEKERJA BARU';
                                }

                                final result = await SearchableSelectionModal.show(
                                  context: context,
                                  title: 'Pilih Pihak',
                                  items: parties,
                                  selectedId: _selectedPihakId,
                                  labelKey: 'nama',
                                  subLabelKey: 'sisa_hutang',
                                  hint: 'Cari nama...',
                                  addNewScreenBuilder: addNewBuilder,
                                  addNewLabel: addNewLabel,
                                );
                                if (result != null) {
                                  setState(() {
                                    _selectedPihakId = result;
                                    dynamic found;
                                    for (var e in parties) {
                                      if (e.id == result) {
                                        found = e;
                                        break;
                                      }
                                    }
                                    _selectedPihak = found;
                                  });
                                }
                              },
                              child: IgnorePointer(
                                child: TextFormField(
                                  key: ValueKey('pihak_${_selectedPihakType}_${_selectedKategori}_${_selectedPihakId}_${parties.length}'),
                                  initialValue: _selectedPihak?.nama?.toString().toUpperCase(),
                                  decoration: _inputDecoration(
                                    'Pilih Pihak',
                                    Icons.person_rounded,
                                  ).copyWith(
                                    hintText: 'Cari pihak...',
                                    suffixIcon: const Icon(Icons.search, size: 20, color: Colors.grey),
                                  ),
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  validator: (val) => _selectedPihakType != null && _selectedPihakId == null ? 'Pilih pihak' : null,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF01579B).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.add,
                                color: Color(0xFF01579B),
                              ),
                              onPressed: () async {
                                Widget? screen;
                                if (_selectedPihakType == 'App\\Models\\Penjual') {
                                  screen = const AddPenjualScreen();
                                } else if (_selectedPihakType == 'App\\Models\\Supir') {
                                  screen = const AddSupirScreen();
                                } else if (_selectedPihakType == 'App\\Models\\Pekerja') {
                                  screen = const AddPekerjaScreen();
                                }

                                if (screen != null) {
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => screen!),
                                  );
                                  if (mounted) provider.fetchAllResources();
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
                  inputFormatters: [CurrencyInputFormatter()],
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
                    if (nominal <= 0) {
                      return 'Nominal harus lebih dari 0';
                    }

                    if (_selectedKategori == 'Bayar Hutang' &&
                        _selectedPihak != null) {
                      final double sisaHutang =
                          double.tryParse(
                            _selectedPihak.sisaHutang?.toString() ?? '0',
                          ) ??
                          0;
                      if (nominal > sisaHutang) {
                        return 'Nominal melebihi sisa hutang (${CurrencyFormatter.formatRupiah(sisaHutang)})';
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
                ),
                const SizedBox(height: 40),

                AppPrimaryButton(
                  text: 'SIMPAN TRANSAKSI',
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
