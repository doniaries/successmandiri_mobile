import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';

import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/searchable_selection_modal.dart';
import 'package:sawitappmobile/features/penjual/screens/add_penjual_screen.dart';
import 'package:sawitappmobile/features/supir/screens/add_supir_screen.dart';
import 'package:sawitappmobile/shared/widgets/balance_validation_modal.dart';

class AddTransaksiDoScreen extends StatefulWidget {
  const AddTransaksiDoScreen({super.key});

  @override
  State<AddTransaksiDoScreen> createState() => _AddTransaksiDoScreenState();
}

class _AddTransaksiDoScreenState extends State<AddTransaksiDoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noPolisiController = TextEditingController();
  final _tonaseController = TextEditingController();
  final _hargaSatuanController = TextEditingController();
  final _upahBongkarController = TextEditingController();
  final _biayaLainController = TextEditingController();
  final _pembayaranHutangController = TextEditingController();
  final _keteranganPembayaranController = TextEditingController();
  final _nominalTransferController = TextEditingController();
  final _nomorDoController = TextEditingController(text: 'OTOMATIS (SISTEM)');

  final _hargaSatuanFocus = FocusNode();
  final _tonaseFocus = FocusNode();
  final _upahBongkarFocus = FocusNode();
  final _biayaLainFocus = FocusNode();
  final _potongHutangFocus = FocusNode();
  final _caraBayarFocus = FocusNode();

  DateTime _selectedDate = DateTime.now();
  int? _selectedPenjualId;
  int? _selectedSupirId;
  String _selectedCaraBayar = 'tunai';
  double _currentSellerDebt = 0;
  bool _penjualSebagaiSupir = false;

  // Controller tambahan untuk field read-only
  final _subTotalController = TextEditingController();
  final _sisaHutangController = TextEditingController();
  final _sisaBayarController = TextEditingController();

  // Harga satuan tersimpan untuk hari ini (dari transaksi sebelumnya)
  double? _savedHargaHariIni;
  bool _gunakanHargaSama = false;

  List<String> get _currentCaraBayarOptions {
    final double saldoPerusahaan =
        context.read<DashboardProvider>().summary?.saldo ?? 0;
    if (_sisaBayar > saldoPerusahaan) {
      return ['transfer', 'cair di luar', 'belum dibayar'];
    }
    return ['tunai', 'transfer', 'cair di luar', 'belum dibayar'];
  }

  @override
  void initState() {
    super.initState();
    _tonaseController.addListener(_onFieldChanged);
    _hargaSatuanController.addListener(_onFieldChanged);
    _upahBongkarController.addListener(_onFieldChanged);
    _biayaLainController.addListener(_onFieldChanged);
    _pembayaranHutangController.addListener(_onFieldChanged);

    final activeDateStr = context
        .read<DashboardProvider>()
        .summary
        ?.systemActiveDate;
    if (activeDateStr != null) {
      _selectedDate = DateTime.parse(activeDateStr);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      context.read<TransaksiDoProvider>().fetchFormData();
      _updateNomorDo();

      // Load harga tersimpan (tanpa auto-fill — user yang memutuskan pakai atau tidak)
      final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final provider = context.read<TransaksiDoProvider>();
      final savedHarga = await provider.getLastHargaSatuan(tanggalStr);
      if (mounted && savedHarga != null && savedHarga > 0) {
        setState(() {
          _savedHargaHariIni = savedHarga;
        });
      }
    });
  }

  Future<void> _updateNomorDo() async {
    final provider = context.read<TransaksiDoProvider>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    final nextNumber = await provider.getNextDoNumber(tanggal: dateStr);
    if (mounted) {
      setState(() {
        _nomorDoController.text = nextNumber;
      });
    }
  }

  void _onFieldChanged() {
    final subTotal = _subTotal;
    final totalDeductions =
        CurrencyInputFormatter.parse(_upahBongkarController.text) +
        CurrencyInputFormatter.parse(_biayaLainController.text) +
        CurrencyInputFormatter.parse(_pembayaranHutangController.text);

    // Match Filament: sisa_bayar = max(0, sub_total - deductions)
    final sisaBayar = max(0.0, subTotal - totalDeductions);
    final sisaHutang = _sisaHutangPenjual;

    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    _subTotalController.text = currencyFormat.format(subTotal).trim();
    _sisaHutangController.text = currencyFormat.format(sisaHutang).trim();
    _sisaBayarController.text = currencyFormat.format(sisaBayar).trim();

    // Validasi saldo otomatis
    final options = _currentCaraBayarOptions;
    if (!options.contains(_selectedCaraBayar)) {
      _selectedCaraBayar = 'cair di luar';

      // Tampilkan modal jika baru saja menjadi tidak cukup
      final double saldoPerusahaan =
          context.read<DashboardProvider>().summary?.saldo ?? 0;
      if (sisaBayar > saldoPerusahaan) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            BalanceValidationModal.show(
              context,
              currentBalance: saldoPerusahaan,
              requiredAmount: sisaBayar,
              onAddBalance: () {},
            );
          }
        });
      }
    }

    if (mounted) {
      setState(() {});
    }
  }

  void _onPenjualChanged(int? val, TransaksiDoProvider provider) {
    setState(() {
      _selectedPenjualId = val;
      if (val != null) {
        final penjual = provider.penjuals.firstWhere(
          (p) => p['id'] == val,
          orElse: () => {'sisa_hutang': 0},
        );
        _currentSellerDebt =
            double.tryParse(penjual['sisa_hutang']?.toString() ?? '0') ?? 0;
      } else {
        _currentSellerDebt = 0;
      }
    });
    _onFieldChanged();
  }

  @override
  void dispose() {
    _noPolisiController.dispose();
    _tonaseController.dispose();
    _hargaSatuanController.dispose();
    _upahBongkarController.dispose();
    _biayaLainController.dispose();
    _pembayaranHutangController.dispose();
    _keteranganPembayaranController.dispose();

    _nominalTransferController.dispose();
    _subTotalController.dispose();
    _sisaHutangController.dispose();
    _sisaBayarController.dispose();
    _nomorDoController.dispose();

    _hargaSatuanFocus.dispose();
    _tonaseFocus.dispose();
    _upahBongkarFocus.dispose();
    _biayaLainFocus.dispose();
    _potongHutangFocus.dispose();
    _caraBayarFocus.dispose();

    super.dispose();
  }

  double get _subTotal =>
      CurrencyInputFormatter.parse(_tonaseController.text) *
      CurrencyInputFormatter.parse(_hargaSatuanController.text);

  double get _totalPotongan =>
      CurrencyInputFormatter.parse(_upahBongkarController.text) +
      CurrencyInputFormatter.parse(_biayaLainController.text) +
      CurrencyInputFormatter.parse(_pembayaranHutangController.text);

  double get _sisaBayar => max(0.0, _subTotal - _totalPotongan);

  double get _sisaHutangPenjual => max(
    0.0,
    _currentSellerDebt -
        CurrencyInputFormatter.parse(_pembayaranHutangController.text),
  );

  Future<void> _selectDate(BuildContext context) async {
    // Simpan provider sebelum await agar tidak ada BuildContext across async gap
    final provider = context.read<TransaksiDoProvider>();

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        // Reset checkbox dan harga tersimpan saat tanggal berubah
        _gunakanHargaSama = false;
        _savedHargaHariIni = null;
        _hargaSatuanController.clear();
      });
      _updateNomorDo();

      // Load harga tersimpan untuk tanggal baru
      final tanggalStr = DateFormat('yyyy-MM-dd').format(picked);
      final savedHarga = await provider.getLastHargaSatuan(tanggalStr);
      if (mounted && savedHarga != null && savedHarga > 0) {
        setState(() {
          _savedHargaHariIni = savedHarga;
        });
      }
    }
  }

  InputDecoration _getInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    Color? fillColor,
    String? helperText,
    TextStyle? prefixStyle,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helperText,
      helperStyle: const TextStyle(
        color: Color(0xFF0D47A1),
        fontWeight: FontWeight.bold,
      ),
      prefixIcon: icon != null
          ? Icon(icon, color: const Color(0xFF01579B), size: 20)
          : null,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: fillColor ?? Colors.blue[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF01579B), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1),
      ),
      labelStyle: TextStyle(
        color: Colors.grey[700],
        fontWeight: FontWeight.w600,
        fontSize: 14,
      ),
      floatingLabelStyle: const TextStyle(
        color: Color(0xFF01579B),
        fontWeight: FontWeight.w700,
      ),
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixText:
          (label.contains('Harga') ||
                  label.contains('Bongkar') ||
                  label.contains('Biaya') ||
                  label.contains('Bayar') ||
                  label.contains('Potongan') ||
                  label.contains('Sub Total')) &&
              !label.contains('Keterangan') &&
              !label.contains('Cara')
          ? 'Rp '
          : null,
      prefixStyle:
          prefixStyle ??
          const TextStyle(
            color: Color(0xFF01579B),
            fontWeight: FontWeight.bold,
          ),
      errorStyle: const TextStyle(color: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransaksiDoProvider>(context);

    return AppLoadingOverlay(
      isLoading: provider.isSaving,
      message: 'Menyimpan transaksi...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Tambah Transaksi DO',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
        ),
        bottomNavigationBar: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.of(context).padding.bottom + 8),
          child: AppPrimaryButton(
            text: 'SIMPAN TRANSAKSI',
            onPressed: provider.isLoading || provider.isSaving ? null : _submitForm,
            isLoading: provider.isLoading || provider.isSaving,
          ),
        ),
        body: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nomor DO (Read Only - Match Filament)
                      TextFormField(
                        controller: _nomorDoController,
                        readOnly: true,
                        decoration: _getInputDecoration(
                          label: 'Nomor DO',
                          icon: Icons.tag_rounded,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF01579B),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tanggal
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: _getInputDecoration(
                            label: 'Tanggal',
                            icon: Icons.calendar_today_rounded,
                          ),
                          child: Text(
                            DateFormat(
                              'dd MMMM yyyy',
                              'id_ID',
                            ).format(_selectedDate),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Penjual (Searchable)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                final result =
                                    await SearchableSelectionModal.show(
                                      context: context,
                                      title: 'Pilih Penjual',
                                      items: provider.penjuals.where((p) => p['is_active'] == null || p['is_active'] == 1 || p['is_active'] == true || p['is_active'] == '1').toList(),
                                      selectedId: _selectedPenjualId,
                                      labelKey: 'nama',
                                      subLabelKey: 'sisa_hutang',
                                      hint: 'Cari nama penjual...',
                                      addNewScreenBuilder: (query) => AddPenjualScreen(initialName: query),
                                      addNewLabel: 'TAMBAH PENJUAL BARU',
                                    );
                                if (result != null) {
                                  final isNew = !provider.penjuals.any((p) => p['id'] == result);
                                  if (isNew) {
                                    await provider.fetchFormData();
                                  }
                                  _onPenjualChanged(result, provider);
                                }
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: IgnorePointer(
                                child: TextFormField(
                                  readOnly: true,
                                  key: ValueKey('penjual_$_selectedPenjualId'),
                                  initialValue: _selectedPenjualId != null
                                      ? provider.penjuals
                                            .firstWhere(
                                              (p) =>
                                                  p['id'].toString() == _selectedPenjualId.toString(),
                                              orElse: () => {'nama': ''},
                                            )['nama']
                                            .toString()
                                            .toUpperCase()
                                      : null,
                                  decoration: _getInputDecoration(
                                    label: 'Nama Penjual',
                                    icon: Icons.person_rounded,
                                    hint: 'Pilih Penjual',
                                    suffixIcon: const Icon(
                                      Icons.search,
                                      size: 20,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  validator: (val) => _selectedPenjualId == null
                                      ? 'Pilih penjual'
                                      : null,
                                ),
                              ),
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
                                final newPenjual = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddPenjualScreen(),
                                  ),
                                );
                                if (mounted && newPenjual != null) {
                                  await provider.fetchFormData();
                                  final newId = newPenjual is Map ? newPenjual['id'] : newPenjual.id;
                                  _onPenjualChanged(newId, provider);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Penjual sebagai Supir Checkbox
                      InkWell(
                        onTap: () {
                          setState(() {
                            _penjualSebagaiSupir = !_penjualSebagaiSupir;
                            if (_penjualSebagaiSupir) {
                              _selectedSupirId = null;
                            }
                          });
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                height: 20,
                                width: 20,
                                child: Checkbox(
                                  value: _penjualSebagaiSupir,
                                  activeColor: const Color(0xFF01579B),
                                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  visualDensity: VisualDensity.compact,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  onChanged: (val) {
                                    setState(() {
                                      _penjualSebagaiSupir = val ?? false;
                                      if (_penjualSebagaiSupir) {
                                        _selectedSupirId = null;
                                      }
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Penjual sekaligus Supir?',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Supir Dropdown (Hidden if penjual_sebagai_supir)
                      if (!_penjualSebagaiSupir) ...[
                        // Nama Supir (Searchable)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final result =
                                      await SearchableSelectionModal.show(
                                        context: context,
                                        title: 'Pilih Supir',
                                        items: provider.supirs.where((p) => p['is_active'] == null || p['is_active'] == 1 || p['is_active'] == true || p['is_active'] == '1').toList(),
                                        selectedId: _selectedSupirId,
                                        labelKey: 'nama',
                                        subLabelKey: 'sisa_hutang',
                                        hint: 'Cari nama supir...',
                                        addNewScreenBuilder: (query) => AddSupirScreen(initialName: query),
                                        addNewLabel: 'TAMBAH SUPIR BARU',
                                      );
                                  if (result != null) {
                                    final isNew = !provider.supirs.any((s) => s['id'] == result);
                                    if (isNew) {
                                      await provider.fetchFormData();
                                    }
                                    setState(() {
                                      _selectedSupirId = result;
                                    });
                                    _onFieldChanged();
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: IgnorePointer(
                                  child: TextFormField(
                                    readOnly: true,
                                    key: ValueKey('supir_$_selectedSupirId'),
                                    initialValue: _selectedSupirId != null
                                        ? provider.supirs
                                              .firstWhere(
                                                (s) =>
                                                    s['id'].toString() == _selectedSupirId.toString(),
                                                orElse: () => {'nama': ''},
                                              )['nama']
                                              .toString()
                                              .toUpperCase()
                                        : null,
                                    decoration: _getInputDecoration(
                                      label: 'Nama Supir',
                                      icon: Icons.local_shipping_outlined,
                                      hint: 'Pilih Supir',
                                      suffixIcon: const Icon(
                                        Icons.search,
                                        size: 20,
                                        color: Colors.grey,
                                      ),
                                    ),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                    validator: (val) => _selectedSupirId == null
                                        ? 'Pilih supir'
                                        : null,
                                  ),
                                ),
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
                                  final newSupir = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddSupirScreen(),
                                    ),
                                  );
                                  if (mounted && newSupir != null) {
                                    await provider.fetchFormData();
                                    final newId = newSupir is Map ? newSupir['id'] : newSupir.id;
                                    setState(() {
                                      _selectedSupirId = newId;
                                    });
                                    _onFieldChanged();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],



                      TextFormField(
                        controller: _hargaSatuanController,
                        focusNode: _hargaSatuanFocus,
                        decoration: _getInputDecoration(
                          label: 'Harga Satuan',
                          icon: Icons.payments_outlined,
                          hint: '0',
                        ).copyWith(prefixText: 'Rp '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _tonaseFocus.requestFocus(),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Isi harga' : null,
                        onChanged: (val) {
                          _onFieldChanged();
                        },
                      ),
                      const SizedBox(height: 10),

                      // Checkbox: Gunakan harga sama hari ini (Moved here)
                      if (_savedHargaHariIni != null && _savedHargaHariIni! > 0 && !_nomorDoController.text.endsWith('001') && (_gunakanHargaSama || _hargaSatuanController.text.isEmpty)) ...[  
                        InkWell(
                          onTap: () {
                            setState(() {
                              _gunakanHargaSama = !_gunakanHargaSama;
                              if (_gunakanHargaSama) {
                                final formatted = NumberFormat.currency(
                                  locale: 'id_ID',
                                  symbol: '',
                                  decimalDigits: 0,
                                ).format(_savedHargaHariIni).trim();
                                _hargaSatuanController.text = formatted;
                              } else {
                                _hargaSatuanController.clear();
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: _gunakanHargaSama
                                  ? const Color(0xFF01579B).withValues(alpha: 0.08)
                                  : Colors.blue[50],
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _gunakanHargaSama
                                    ? const Color(0xFF01579B).withValues(alpha: 0.4)
                                    : Colors.grey[300]!,
                              ),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: Checkbox(
                                    value: _gunakanHargaSama,
                                    activeColor: const Color(0xFF01579B),
                                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    visualDensity: VisualDensity.compact,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    onChanged: (val) {
                                      setState(() {
                                        _gunakanHargaSama = val ?? false;
                                        if (_gunakanHargaSama) {
                                          final formatted = NumberFormat.currency(
                                            locale: 'id_ID',
                                            symbol: '',
                                            decimalDigits: 0,
                                          ).format(_savedHargaHariIni).trim();
                                          _hargaSatuanController.text = formatted;
                                        } else {
                                          _hargaSatuanController.clear();
                                        }
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Gunakan harga satuan sama hari ini',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF37474F),
                                        ),
                                      ),
                                      Text(
                                        NumberFormat.currency(
                                          locale: 'id_ID',
                                          symbol: 'Rp ',
                                          decimalDigits: 0,
                                        ).format(_savedHargaHariIni),
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w800,
                                          color: Color(0xFF01579B),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 6),
                      TextFormField(
                        controller: _tonaseController,
                        focusNode: _tonaseFocus,
                        decoration: _getInputDecoration(
                          label: 'Tonase (Kg)',
                          icon: Icons.scale_rounded,
                          hint: '0',
                        ).copyWith(suffixText: ' Kg'),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        inputFormatters: [CurrencyInputFormatter()],
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _upahBongkarFocus.requestFocus(),
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Isi tonase' : null,
                      ),
                      const SizedBox(height: 16),

                      // Sub Total (Read Only)
                      TextFormField(
                        controller: _subTotalController,
                        readOnly: true,
                        decoration: _getInputDecoration(
                          label: 'Sub Total',
                          icon: Icons.calculate_rounded,
                          fillColor: const Color(
                            0xFFF1F8E9,
                          ), // Light green tint
                          prefixStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _upahBongkarController,
                        focusNode: _upahBongkarFocus,
                        decoration: _getInputDecoration(
                          label: 'Upah Bongkar',
                          icon: Icons.handyman_outlined,
                          hint: '0',
                        ).copyWith(prefixText: 'Rp '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) => _biayaLainFocus.requestFocus(),
                        inputFormatters: [CurrencyInputFormatter()],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _biayaLainController,
                        focusNode: _biayaLainFocus,
                        decoration: _getInputDecoration(
                          label: 'Biaya Lain/Pengambilan',
                          icon: Icons.more_horiz_rounded,
                          hint: '0',
                        ).copyWith(prefixText: 'Rp '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        onFieldSubmitted: (_) {
                          if (_currentSellerDebt > 0 || CurrencyInputFormatter.parse(_pembayaranHutangController.text) > 0) {
                            _potongHutangFocus.requestFocus();
                          } else {
                            _caraBayarFocus.requestFocus();
                          }
                        },
                        inputFormatters: [CurrencyInputFormatter()],
                      ),
                      const SizedBox(height: 16),

                      // Potong Hutang (di-disable di form DO sesuai permintaan, dialihkan ke Operasional)
                      if (_currentSellerDebt > 0) ...[
                        TextFormField(
                          controller: _pembayaranHutangController,
                          focusNode: _potongHutangFocus,
                          decoration: _getInputDecoration(
                            label: 'Potong Hutang',
                            icon: Icons.money_off_rounded,
                            hint: '0',
                            helperText: 'Sisa Hutang Penjual: ${CurrencyFormatter.formatRupiah(_currentSellerDebt)}',
                          ).copyWith(prefixText: 'Rp '),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _caraBayarFocus.requestFocus(),
                          inputFormatters: [CurrencyInputFormatter()],
                          validator: (val) {
                            if (val == null || val.isEmpty) return null;
                            final potong = CurrencyInputFormatter.parse(val);
                            if (potong > _currentSellerDebt) {
                              return 'Melebihi sisa hutang penjual';
                            }
                            final totalBiaya = CurrencyInputFormatter.parse(_upahBongkarController.text) + CurrencyInputFormatter.parse(_biayaLainController.text);
                            final sisaHasil = max(0.0, _subTotal - totalBiaya);
                            if (potong > sisaHasil) {
                              return 'Melebihi sisa hasil transaksi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _sisaBayarController,
                        readOnly: true,
                        decoration: _getInputDecoration(
                          label: 'Total Bayar ke Penjual',
                          icon: Icons.account_balance_wallet_rounded,
                          fillColor: const Color(0xFFE3F2FD),
                          prefixStyle: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w900,
                            fontSize: 24,
                          ),
                        ).copyWith(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Indikator Saldo Perusahaan (Match Filament Placeholder)
                      Builder(
                        builder: (context) {
                          final double currentSaldo = context
                              .select<DashboardProvider, double>(
                                (p) => p.summary?.saldo ?? 0,
                              );
                          final bool isLow = currentSaldo < 500000;
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: isLow
                                  ? Colors.red[100]
                                  : const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(10),
                              border: isLow
                                  ? Border.all(color: Colors.red[300]!)
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLow
                                      ? Icons.warning_amber_rounded
                                      : Icons.account_balance_rounded,
                                  size: 16,
                                  color: isLow
                                      ? Colors.red[700]
                                      : Colors.black87,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isLow
                                            ? 'Saldo Sangat Rendah!'
                                            : 'Kondisi Saldo Saat Ini',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: isLow
                                              ? Colors.red[900]
                                              : Colors.black87,
                                        ),
                                      ),
                                      Text(
                                        CurrencyFormatter.formatRupiah(
                                          currentSaldo,
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: isLow
                                              ? Colors.red[900]
                                              : Colors.black,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Cara Bayar (urutan sesuai Filament)
                      DropdownButtonFormField<String>(
                        focusNode: _caraBayarFocus,
                        initialValue:
                            _currentCaraBayarOptions.contains(
                              _selectedCaraBayar,
                            )
                            ? _selectedCaraBayar
                            : _currentCaraBayarOptions.first,
                        decoration: _getInputDecoration(
                          label: 'Cara Bayar',
                          icon: Icons.payments_rounded,
                        ),
                        items: _currentCaraBayarOptions.map((opt) {
                          return DropdownMenuItem(
                            value: opt,
                            child: Text(
                              opt.toUpperCase(),
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (val) =>
                            setState(() => _selectedCaraBayar = val!),
                      ),
                      const SizedBox(height: 16),

                      // Keterangan Pembayaran
                      if (_selectedCaraBayar == 'cair di luar' ||
                          _selectedCaraBayar == 'belum dibayar') ...[
                        TextFormField(
                          controller: _keteranganPembayaranController,
                          decoration: _getInputDecoration(
                            label:
                                'Keterangan ${_selectedCaraBayar.toUpperCase()}',
                            icon: Icons.info_outline_rounded,
                            hint: 'Tambahkan detail pembayaran...',
                          ),
                          maxLines: 2,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  void _submitForm() async {
    if (_formKey.currentState!.validate()) {
      // Validasi Saldo Perusahaan
      final double saldoPerusahaan =
          context.read<DashboardProvider>().summary?.saldo ?? 0;

      if (_selectedCaraBayar == 'tunai' && _sisaBayar > saldoPerusahaan) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Saldo tunai perusahaan tidak mencukupi (Saldo: ${CurrencyFormatter.formatRupiah(saldoPerusahaan)})',
            ),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }

      final provider = context.read<TransaksiDoProvider>();
      final penjualNama = provider.penjuals.firstWhere(
        (p) => p['id'].toString() == _selectedPenjualId.toString(),
        orElse: () => {'nama': ''},
      )['nama'];
      
      final supirNama = _penjualSebagaiSupir ? penjualNama : provider.supirs.firstWhere(
        (s) => s['id'].toString() == _selectedSupirId.toString(),
        orElse: () => {'nama': ''},
      )['nama'];

      final success = await provider
          .createTransaction(
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
            nomorDo: _nomorDoController.text,
            penjualId: _selectedPenjualId!,
            penjualNama: penjualNama,
            supirId: _penjualSebagaiSupir ? null : _selectedSupirId,
            supirNama: supirNama,
            noPolisi: _noPolisiController.text,
            tonase: CurrencyInputFormatter.parse(_tonaseController.text),
            hargaSatuan: CurrencyInputFormatter.parse(
              _hargaSatuanController.text,
            ),
            upahBongkar: CurrencyInputFormatter.parse(
              _upahBongkarController.text,
            ),
            biayaLain: CurrencyInputFormatter.parse(_biayaLainController.text),
            pembayaranHutang: CurrencyInputFormatter.parse(
              _pembayaranHutangController.text,
            ),
            keteranganBiayaLain: '',
            caraBayar: _selectedCaraBayar,
            buktiTransfer: null,
            keteranganPembayaran: _keteranganPembayaranController.text,
          );

      if (mounted) {
        if (success) {
          // Simpan harga satuan hari ini agar tidak perlu input ulang
          final tanggalStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
          final hargaSatuan = CurrencyInputFormatter.parse(_hargaSatuanController.text);
          if (hargaSatuan > 0) {
            context.read<TransaksiDoProvider>().saveLastHargaSatuan(tanggalStr, hargaSatuan);
          }

          final bool isOffline =
              context.read<TransaksiDoProvider>().errorMessage?.contains(
                'offline',
              ) ??
              false;
          
          context.read<TransaksiDoProvider>().clearErrorMessage();
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isOffline
                    ? 'Disimpan offline. Akan disinkronkan saat sinyal pulih.'
                    : 'DO ${_nomorDoController.text} berhasil disimpan.',
              ),
              backgroundColor: isOffline ? Colors.orange[800] : Colors.green[600],
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 2),
            ),
          );
          
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<TransaksiDoProvider>().errorMessage ??
                    'Gagal menyimpan transaksi',
              ),
            ),
          );
        }
      }
    } else {
      // Android-style modal for validation errors
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Data Belum Lengkap'),
          content: const Text(
            'Silakan lengkapi semua data yang wajib diisi sebelum menyimpan transaksi.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('PAHAM'),
            ),
          ],
        ),
      );
    }
  }
}
