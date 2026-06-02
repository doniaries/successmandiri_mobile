import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/widgets/app_primary_button.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import 'package:sawitappmobile/shared/widgets/searchable_selection_modal.dart';
import 'package:sawitappmobile/features/penjual/screens/add_penjual_screen.dart';
import 'package:sawitappmobile/features/supir/screens/add_supir_screen.dart';
import 'package:sawitappmobile/shared/widgets/balance_validation_modal.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';

class EditTransaksiDoScreen extends StatefulWidget {
  final TransaksiDo transaction;
  final bool popParent;

  const EditTransaksiDoScreen({
    super.key,
    required this.transaction,
    this.popParent = true,
  });

  @override
  State<EditTransaksiDoScreen> createState() => _EditTransaksiDoScreenState();
}

class _EditTransaksiDoScreenState extends State<EditTransaksiDoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _noPolisiController = TextEditingController();
  final _tonaseController = TextEditingController();
  final _hargaSatuanController = TextEditingController();
  final _upahBongkarController = TextEditingController();
  final _biayaLainController = TextEditingController();
  final _pembayaranHutangController = TextEditingController();
  final _keteranganPembayaranController = TextEditingController();
  final _nomorDoController = TextEditingController();

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

  XFile? _selectedBuktiTransferFile;
  String? _existingBuktiTransferUrl;
  final ImagePicker _picker = ImagePicker();

  // Controller tambahan untuk field read-only
  final _subTotalController = TextEditingController();
  final _sisaHutangController = TextEditingController();
  final _sisaBayarController = TextEditingController();

  List<String> get _currentCaraBayarOptions {
    final double saldoPerusahaan =
        context.read<DashboardProvider>().summary?.saldo ?? 0;

    // Untuk transaksi yang diedit, jika cara bayarnya sudah bernilai tertentu,
    // kita harus tetap menyertakan cara bayar aslinya agar valid.
    final List<String> options = [];
    if (_sisaBayar <= saldoPerusahaan ||
        widget.transaction.caraBayar == 'tunai') {
      options.add('tunai');
    }
    options.addAll(['transfer', 'cair di luar', 'belum dibayar']);
    return options.toSet().toList(); // pastikan unik
  }

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;

    _nomorDoController.text = t.nomor;
    _noPolisiController.text = t.noPolisi ?? '';
    _selectedDate = t.tanggal;
    _selectedPenjualId = t.penjualId;
    _selectedSupirId = t.supirId;
    _penjualSebagaiSupir = t.supirId == null;
    _selectedCaraBayar = t.caraBayar ?? 'tunai';
    _existingBuktiTransferUrl = t.buktiTransfer;

    final currencyFormat = NumberFormat.decimalPattern('id_ID');
    _tonaseController.text = currencyFormat.format(t.tonase);
    _hargaSatuanController.text = currencyFormat.format(t.hargaSatuan);
    _upahBongkarController.text = currencyFormat.format(t.upahBongkar);
    _biayaLainController.text = currencyFormat.format(t.biayaLain);
    _pembayaranHutangController.text = currencyFormat.format(
      t.pembayaranHutang,
    );
    _keteranganPembayaranController.text = t.keteranganPembayaran ?? '';

    // Nilai awal hutang penjual (menggunakan hutang_awal transaksi yang merekam hutang sebelum transaksi ini terjadi)
    _currentSellerDebt = t.hutangAwal;

    _tonaseController.addListener(_onFieldChanged);
    _hargaSatuanController.addListener(_onFieldChanged);
    _upahBongkarController.addListener(_onFieldChanged);
    _biayaLainController.addListener(_onFieldChanged);
    _pembayaranHutangController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final provider = context.read<TransaksiDoProvider>();
      await provider.fetchFormData();
      
      if (!mounted) return;

      // Hitung hutang aktual penjual jika data master penjual telah termuat
      if (_selectedPenjualId != null && provider.penjuals.isNotEmpty) {
        final found = provider.penjuals.firstWhere(
          (p) => p['id'].toString() == _selectedPenjualId.toString(),
          orElse: () => {},
        );
        if (found.isNotEmpty) {
          final double sisaHutangDb =
              double.tryParse(found['sisa_hutang']?.toString() ?? '0') ?? 0;
          setState(() {
            // Karena transaksi ini sudah tersimpan, database sisa_hutang sudah terpotong oleh t.pembayaranHutang.
            // Saat proses edit, kita kembalikan saldo potongan tersebut ke hutang penjual agar bisa diredistribusikan secara dinamis.
            _currentSellerDebt =
                sisaHutangDb + widget.transaction.pembayaranHutang;
          });
        }
      }
      _onFieldChanged();
    });
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

  void _onFieldChanged() {
    final subTotal = _subTotal;
    final totalDeductions = _totalPotongan;
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
        final double sisaHutangDb =
            double.tryParse(penjual['sisa_hutang']?.toString() ?? '0') ?? 0;

        // Jika penjual yang dipilih sama dengan penjual asli transaksi ini,
        // kembalikan nilai pembayaran_hutang asli untuk akurasi perhitungan.
        if (val == widget.transaction.penjualId) {
          _currentSellerDebt =
              sisaHutangDb + widget.transaction.pembayaranHutang;
        } else {
          _currentSellerDebt = sisaHutangDb;
        }
      } else {
        _currentSellerDebt = 0;
      }
    });
    _onFieldChanged();
  }

  Future<void> _pickBuktiTransfer() async {
    final XFile? image = await showModalBottomSheet<XFile?>(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeri'),
              onTap: () async {
                final file = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 70,
                );
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Kamera'),
              onTap: () async {
                final file = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 70,
                );
                if (context.mounted) Navigator.pop(context, file);
              },
            ),
            if (_selectedBuktiTransferFile != null ||
                (_existingBuktiTransferUrl != null &&
                    _existingBuktiTransferUrl!.isNotEmpty))
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text(
                  'Hapus Bukti Transfer',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  if (context.mounted) Navigator.pop(context, XFile('remove'));
                },
              ),
          ],
        ),
      ),
    );

    if (image != null) {
      setState(() {
        if (image.path == 'remove') {
          _selectedBuktiTransferFile = null;
          _existingBuktiTransferUrl = null;
        } else {
          _selectedBuktiTransferFile = image;
        }
      });
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
      fillColor: fillColor ?? Colors.grey[50],
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
        borderSide: const BorderSide(color: Colors.orangeAccent, width: 1),
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
      errorStyle: const TextStyle(color: Colors.orangeAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransaksiDoProvider>(context);

    return AppLoadingOverlay(
      isLoading: provider.isSaving,
      message: 'Menyimpan perubahan...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Ubah Transaksi DO',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          backgroundColor: const Color(0xFF01579B),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nomor DO (Read Only)
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
                                  _onPenjualChanged(newPenjual['id'], provider);
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

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
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 8,
                          ),
                          child: Row(
                            children: [
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: Checkbox(
                                  value: _penjualSebagaiSupir,
                                  activeColor: const Color(0xFF01579B),
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
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Penjual sekaligus Supir?',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF455A64),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Centang ini jika penjual yang membawa sendiri kendaraannya. Sistem akan menyembunyikan pilihan Nama Supir.',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

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
                                        items: provider.supirs.where((s) => s['is_active'] == null || s['is_active'] == 1 || s['is_active'] == true || s['is_active'] == '1').toList(),
                                        selectedId: _selectedSupirId,
                                        labelKey: 'nama',
                                        subLabelKey: 'sisa_hutang',
                                        hint: 'Cari nama supir...',
                                        addNewScreenBuilder: (query) => AddSupirScreen(initialName: query),
                                        addNewLabel: 'TAMBAH SUPIR BARU',
                                      );
                                  if (result != null) {
                                    await provider.fetchFormData();
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
                                  await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AddSupirScreen(),
                                    ),
                                  );
                                  if (mounted) {
                                    provider.fetchFormData();
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
                      ),
                      const SizedBox(height: 16),
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
                      if (_currentSellerDebt > 0 || CurrencyInputFormatter.parse(_pembayaranHutangController.text) > 0) ...[
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
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Total Bayar ke Penjual (selalu tampil, sesuai Filament)
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
                              horizontal: 16,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: isLow
                                  ? Colors.red[100]
                                  : const Color(0xFFFFD54F),
                              borderRadius: BorderRadius.circular(12),
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
                                  size: 18,
                                  color: isLow
                                      ? Colors.red[700]
                                      : Colors.black87,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        isLow
                                            ? 'Saldo Sangat Rendah!'
                                            : 'Kondisi Saldo Saat Ini',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w800,
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
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: isLow
                                              ? Colors.red[900]
                                              : Colors.black,
                                          letterSpacing: -0.5,
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

                      // Bukti Transfer (Khusus Transfer)
                      if (_selectedCaraBayar == 'transfer') ...[
                        InkWell(
                          onTap: _pickBuktiTransfer,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              children: [
                                if (_selectedBuktiTransferFile != null) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.file(
                                      File(_selectedBuktiTransferFile!.path),
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Ketuk untuk mengubah foto bukti transfer',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF01579B),
                                    ),
                                  ),
                                ] else if (_existingBuktiTransferUrl != null &&
                                    _existingBuktiTransferUrl!.isNotEmpty) ...[
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: Image.network(
                                      '${ApiConstants.storageUrl}/$_existingBuktiTransferUrl',
                                      height: 200,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              Container(
                                                height: 200,
                                                color: Colors.grey[200],
                                                child: const Center(
                                                  child: Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Ketuk untuk mengubah foto bukti transfer',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF01579B),
                                    ),
                                  ),
                                ] else ...[
                                  const Icon(
                                    Icons.cloud_upload_outlined,
                                    size: 48,
                                    color: Color(0xFF01579B),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    'Unggah Bukti Transfer',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Format JPG, PNG (Maksimal 2MB)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      const SizedBox(height: 24),

                      AppPrimaryButton(
                        text: 'SIMPAN PERUBAHAN',
                        onPressed: _submitForm,
                        isLoading: provider.isLoading || provider.isSaving,
                      ),
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

      // Jika cara bayar diubah menjadi tunai, dan saldo tidak mencukupi
      if (_selectedCaraBayar == 'tunai' && _sisaBayar > saldoPerusahaan) {
        // Namun, jika cara bayar asli memang tunai, maka kita kurangi sisaBayar dengan sisaBayar transaksi aslinya terlebih dahulu
        final double sisaBayarLama = widget.transaction.caraBayar == 'tunai'
            ? widget.transaction.sisaBayar
            : 0;
        final double selisihSaldo = _sisaBayar - sisaBayarLama;
        if (selisihSaldo > saldoPerusahaan) {
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
      }

      final success = await context
          .read<TransaksiDoProvider>()
          .updateTransaction(
            widget.transaction.id,
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
            penjualId: _selectedPenjualId!,
            supirId: _penjualSebagaiSupir ? null : _selectedSupirId,
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
            buktiTransfer: _selectedBuktiTransferFile,
            keteranganPembayaran: _keteranganPembayaranController.text,
          );

      if (mounted) {
        if (success) {
          SuccessDialog.show(
            context,
            title: 'Berhasil Diubah!',
            message:
                'Data Transaksi DO dengan nomor ${_nomorDoController.text} berhasil diperbarui.',
            onConfirm: () {
              // Pop edit screen
              Navigator.of(context).pop();
              // Pop detail screen jika popParent bernilai true
              if (widget.popParent) {
                Navigator.of(context).pop();
              }
            },
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.read<TransaksiDoProvider>().errorMessage ??
                    'Gagal memperbarui transaksi',
              ),
            ),
          );
        }
      }
    } else {
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
