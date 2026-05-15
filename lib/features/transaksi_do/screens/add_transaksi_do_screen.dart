import 'package:flutter/material.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/shared/widgets/success_dialog.dart';
import 'package:sawitappmobile/core/utils/currency_formatter.dart';
import 'package:sawitappmobile/shared/widgets/app_loading_indicator.dart';
import '../penjual/add_penjual_screen.dart';
import '../supir/add_supir_screen.dart';
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
  final _keteranganBiayaLainController = TextEditingController();
  final _keteranganPembayaranController = TextEditingController();
  final _nominalTunaiController = TextEditingController();
  final _nominalTransferController = TextEditingController();

  bool _isMismatch = false;
  XFile? _buktiRekap;
  XFile? _buktiTransfer;
  DateTime _selectedDate = DateTime.now();
  int? _selectedPenjualId;
  int? _selectedSupirId;
  String _selectedCaraBayar = 'tunai';
  double _currentSellerDebt = 0;

  // Controller tambahan untuk field read-only
  final _subTotalController = TextEditingController();
  final _sisaHutangController = TextEditingController();
  final _sisaBayarController = TextEditingController();

  List<String> get _currentCaraBayarOptions {
    final double saldoPerusahaan = context.read<DashboardProvider>().summary?.saldo ?? 0;
    if (_sisaBayar > saldoPerusahaan) {
      return ['cair di luar', 'belum dibayar'];
    }
    return ['tunai', 'transfer', 'tunai & transfer', 'cair di luar', 'belum dibayar'];
  }

  @override
  void initState() {
    super.initState();
    _tonaseController.addListener(_onFieldChanged);
    _hargaSatuanController.addListener(_onFieldChanged);
    _upahBongkarController.addListener(_onFieldChanged);
    _biayaLainController.addListener(_onFieldChanged);
    _pembayaranHutangController.addListener(_onFieldChanged);
    _nominalTunaiController.addListener(_onFieldChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<TransaksiDoProvider>().fetchFormData();
    });
  }

  void _onFieldChanged() {
    final subTotal = _subTotal;
    final totalDeductions = CurrencyInputFormatter.parse(_upahBongkarController.text) +
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

    if (_selectedCaraBayar == 'tunai & transfer') {
      final nominalTunai = CurrencyInputFormatter.parse(_nominalTunaiController.text);
      final nominalTransfer = max(0.0, sisaBayar - nominalTunai);
      _nominalTransferController.text = currencyFormat.format(nominalTransfer).trim();
    }

    // Validasi saldo otomatis
    final options = _currentCaraBayarOptions;
    if (!options.contains(_selectedCaraBayar)) {
      _selectedCaraBayar = 'cair di luar';
      
      // Tampilkan modal jika baru saja menjadi tidak cukup
      final double saldoPerusahaan = context.read<DashboardProvider>().summary?.saldo ?? 0;
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

    setState(() {});
  }

  @override
  void dispose() {
    _noPolisiController.dispose();
    _tonaseController.dispose();
    _hargaSatuanController.dispose();
    _upahBongkarController.dispose();
    _biayaLainController.dispose();
    _pembayaranHutangController.dispose();
    _keteranganBiayaLainController.dispose();
    _keteranganPembayaranController.dispose();
    _nominalTunaiController.dispose();
    _nominalTransferController.dispose();
    _subTotalController.dispose();
    _sisaHutangController.dispose();
    _sisaBayarController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(bool isTransfer) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isTransfer) {
          _buktiTransfer = image;
        } else {
          _buktiRekap = image;
        }
      });
    }
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

  InputDecoration _getInputDecoration({
    required String label,
    String? hint,
    IconData? icon,
    Widget? suffixIcon,
    Color? fillColor,
    String? helperText,
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
      prefixStyle: const TextStyle(
        color: Color(0xFF01579B),
        fontWeight: FontWeight.bold,
      ),
      errorStyle: const TextStyle(color: Colors.orangeAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TransaksiDoProvider>(context);
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    return AppLoadingOverlay(
      isLoading: provider.isSaving,
      message: 'Menyimpan transaksi...',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tambah Transaksi DO'),
          backgroundColor: const Color(0xFF01579B),
          foregroundColor: Colors.white,
        ),
        body: provider.isLoading && provider.penjuals.isEmpty
            ? const Center(child: AppLoadingIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Nomor DO (Read Only - Match Filament)
                      TextFormField(
                        initialValue: 'OTOMATIS (SISTEM)',
                        readOnly: true,
                        decoration: _getInputDecoration(
                          label: 'Nomor DO',
                          icon: Icons.tag_rounded,
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
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

                      // Penjual Dropdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedPenjualId,
                              isExpanded: true,
                              decoration: _getInputDecoration(
                                label: 'Penjual',
                                icon: Icons.person_outline_rounded,
                                helperText: _selectedPenjualId != null
                                    ? 'Hutang: ${currencyFormat.format(_currentSellerDebt)}'
                                    : null,
                              ),
                              items: provider.penjuals.map<DropdownMenuItem<int>>((
                                p,
                              ) {
                                final double hutang =
                                    double.tryParse(
                                      p['sisa_hutang']?.toString() ?? '0',
                                    ) ??
                                    0;
                                return DropdownMenuItem<int>(
                                  value: p['id'],
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        p['nama'].toString().toUpperCase(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (hutang > 0)
                                        Text(
                                          'Hutang: ${currencyFormat.format(hutang)}',
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
                                return provider.penjuals.map<Widget>((p) {
                                  return Text(
                                    p['nama'].toString().toUpperCase(),
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
                                  _selectedPenjualId = val;
                                  final penjual = provider.penjuals.firstWhere(
                                    (p) => p['id'] == val,
                                  );
                                  _currentSellerDebt =
                                      double.tryParse(
                                        penjual['sisa_hutang']?.toString() ??
                                            '0',
                                      ) ??
                                      0;
                                });
                                _onFieldChanged();
                              },
                              validator: (val) =>
                                  val == null ? 'Pilih penjual' : null,
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
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddPenjualScreen(),
                                  ),
                                );
                                if (mounted) provider.fetchFormData();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Supir Dropdown
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<int>(
                              initialValue: _selectedSupirId,
                              isExpanded: true,
                              decoration: _getInputDecoration(
                                label: 'Supir',
                                icon: Icons.local_shipping_outlined,
                              ),
                              items: provider.supirs.map<DropdownMenuItem<int>>((
                                s,
                              ) {
                                final double hutang =
                                    double.tryParse(
                                      s['sisa_hutang']?.toString() ?? '0',
                                    ) ??
                                    0;
                                return DropdownMenuItem<int>(
                                  value: s['id'],
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        s['nama'].toString().toUpperCase(),
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      if (hutang > 0)
                                        Text(
                                          'Hutang: ${currencyFormat.format(hutang)}',
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
                                return provider.supirs.map<Widget>((s) {
                                  return Text(
                                    s['nama'].toString().toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                }).toList();
                              },
                              onChanged: (val) =>
                                  setState(() => _selectedSupirId = val),
                              validator: (val) =>
                                  val == null ? 'Pilih supir' : null,
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
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const AddSupirScreen(),
                                  ),
                                );
                                if (mounted) provider.fetchFormData();
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Kendaraan Dropdown (No Polisi)
                      TextFormField(
                        controller: _noPolisiController,
                        decoration: _getInputDecoration(
                          label: 'No Kendaraan',
                          icon: Icons.numbers_rounded,
                          hint: 'Masukkan nomor polisi',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        textCapitalization: TextCapitalization.characters,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Isi no polisi' : null,
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _tonaseController,
                        decoration: _getInputDecoration(
                          label: 'Tonase (Kg)',
                          icon: Icons.scale_rounded,
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.number,
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Isi tonase' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _hargaSatuanController,
                        decoration: _getInputDecoration(
                          label: 'Harga Satuan',
                          icon: Icons.payments_outlined,
                        ).copyWith(prefixText: 'Rp '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.text,
                        inputFormatters: [CurrencyInputFormatter()],
                        validator: (val) =>
                            val == null || val.isEmpty ? 'Isi harga' : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _upahBongkarController,
                        decoration: _getInputDecoration(
                          label: 'Upah Bongkar',
                          icon: Icons.handyman_outlined,
                        ).copyWith(prefixText: 'Rp '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.text,
                        inputFormatters: [CurrencyInputFormatter()],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _biayaLainController,
                        decoration: _getInputDecoration(
                          label: 'Biaya Lain',
                          icon: Icons.more_horiz_rounded,
                        ).copyWith(prefixText: 'Rp '),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                        keyboardType: TextInputType.text,
                        inputFormatters: [CurrencyInputFormatter()],
                      ),
                      const SizedBox(height: 16),

                      // Sub Total (Read Only)
                      TextFormField(
                        controller: _subTotalController,
                        readOnly: true,
                        decoration: _getInputDecoration(
                          label: 'Sub Total (Tonase x Harga)',
                          icon: Icons.calculate_rounded,
                          fillColor: const Color(
                            0xFFF1F8E9,
                          ), // Light green tint
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2E7D32),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Section Pembayaran Hutang
                      if (_currentSellerDebt > 0) ...[
                        TextFormField(
                          controller: _pembayaranHutangController,
                          decoration: _getInputDecoration(
                            label: 'Potongan Hutang',
                            hint:
                                'Maks: ${currencyFormat.format(_currentSellerDebt)}',
                            icon: Icons.history_rounded,
                            suffixIcon: IconButton(
                              icon: const Icon(
                                Icons.account_balance_wallet,
                                color: Color(0xFF01579B),
                              ),
                              onPressed: () {
                                if (_currentSellerDebt > 0) {
                                  final amount = _currentSellerDebt < _subTotal
                                      ? _currentSellerDebt
                                      : _subTotal;
                                  _pembayaranHutangController.text =
                                      NumberFormat.decimalPattern(
                                        'id_ID',
                                      ).format(amount);
                                  _onFieldChanged();
                                }
                              },
                            ),
                          ).copyWith(prefixText: 'Rp '),
                          keyboardType: TextInputType.text,
                          inputFormatters: [CurrencyInputFormatter()],
                          validator: (val) {
                            if (val != null && val.isNotEmpty) {
                              final amount = CurrencyInputFormatter.parse(val);
                              if (amount > _currentSellerDebt) {
                                return 'Melebihi hutang';
                              }
                              // Match Filament: validatePotonganHutang
                              final otherDeductions = CurrencyInputFormatter.parse(_upahBongkarController.text) +
                                                     CurrencyInputFormatter.parse(_biayaLainController.text);
                              final maxBayarHutang = max(0.0, _subTotal - otherDeductions);
                              if (amount > maxBayarHutang) {
                                return 'Melebihi sisa hasil transaksi';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        TextFormField(
                          controller: _sisaHutangController,
                          readOnly: true,
                          decoration: _getInputDecoration(
                            label: 'Sisa Hutang Penjual',
                            icon: Icons.account_balance_outlined,
                          ),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 16),
                      ],

                      TextFormField(
                        controller: _sisaBayarController,
                        readOnly: true,
                        decoration: _getInputDecoration(
                          label: 'Sisa Yang Dibayar',
                          icon: Icons.account_balance_wallet_rounded,
                          fillColor: const Color(0xFFE3F2FD), // Light blue tint
                        ),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF01579B),
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),

                      TextFormField(
                        controller: _keteranganBiayaLainController,
                        decoration: _getInputDecoration(
                          label: 'Keterangan Biaya Lain',
                          icon: Icons.description_outlined,
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      const SizedBox(height: 16),

                      // Cara Bayar
                      DropdownButtonFormField<String>(
                        initialValue: _currentCaraBayarOptions.contains(_selectedCaraBayar)
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

                      // Field Tambahan untuk Tunai & Transfer
                      if (_selectedCaraBayar == 'tunai & transfer') ...[
                        TextFormField(
                          controller: _nominalTunaiController,
                          decoration: _getInputDecoration(
                            label: 'Nominal Tunai',
                            icon: Icons.money_rounded,
                            hint: 'Masukkan jumlah tunai',
                          ).copyWith(prefixText: 'Rp '),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          keyboardType: TextInputType.text,
                          inputFormatters: [CurrencyInputFormatter()],
                          validator: (val) {
                            if (val == null || val.isEmpty) return 'Isi nominal tunai';
                            final amount = CurrencyInputFormatter.parse(val);
                            if (amount > _sisaBayar) return 'Melebihi total bayar';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _nominalTransferController,
                          readOnly: true,
                          decoration: _getInputDecoration(
                            label: 'Nominal Transfer (Otomatis)',
                            icon: Icons.account_balance_rounded,
                            fillColor: Colors.blue[50],
                          ),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0D47A1),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      const SizedBox(height: 16),

                      // Bukti Transfer (Hanya jika Transfer atau Tunai & Transfer)
                      if (_selectedCaraBayar == 'transfer' || _selectedCaraBayar == 'tunai & transfer') ...[
                        InkWell(
                          onTap: () => _pickImage(true),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.cloud_upload_outlined,
                                  color: _buktiTransfer != null
                                      ? Colors.green
                                      : const Color(0xFF01579B),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    _buktiTransfer != null
                                        ? 'Bukti Terpilih: ${_buktiTransfer!.name}'
                                        : 'Upload Bukti Transfer (Screenshot)',
                                    style: TextStyle(
                                      color: _buktiTransfer != null
                                          ? Colors.green[700]
                                          : Colors.grey[700],
                                      fontWeight: _buktiTransfer != null
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                    ),
                                  ),
                                ),
                                if (_buktiTransfer != null)
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Keterangan Pembayaran (Untuk Selain Tunai/Transfer?)
                      // User minta: Cair di luar (tambah keterangan), belum dibayar (tambah keterangan)
                      if (_selectedCaraBayar == 'cair di luar' ||
                          _selectedCaraBayar == 'belum dibayar') ...[
                        TextFormField(
                          controller: _keteranganPembayaranController,
                          decoration: _getInputDecoration(
                            label: 'Keterangan ${_selectedCaraBayar.toUpperCase()}',
                            icon: Icons.info_outline_rounded,
                            hint: 'Tambahkan detail pembayaran...',
                          ),
                          maxLines: 2,
                          validator: (val) =>
                              val == null || val.isEmpty
                                  ? 'Keterangan wajib diisi'
                                  : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      const Divider(height: 32),
                      
                      // Section Validasi & Lampiran (Match Filament)
                      const Text(
                        'Validasi & Lampiran',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF01579B),
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // is_mismatch toggle
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: _isMismatch ? Colors.red[50] : Colors.grey[50],
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: _isMismatch ? Colors.red[200]! : Colors.grey[200]!,
                          ),
                        ),
                        child: SwitchListTile(
                          title: const Text(
                            'Hitungan Meragukan',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: const Text(
                            'Tandai jika data pembukuan tidak sesuai sistem',
                            style: TextStyle(fontSize: 12),
                          ),
                          value: _isMismatch,
                          onChanged: (val) => setState(() => _isMismatch = val),
                          activeThumbColor: Colors.red,
                          secondary: Icon(
                            _isMismatch 
                              ? Icons.report_problem_rounded 
                              : Icons.check_circle_outline_rounded,
                            color: _isMismatch ? Colors.red : Colors.green,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      
                      // bukti_rekap file upload
                      InkWell(
                        onTap: () => _pickImage(false),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.receipt_long_rounded,
                                color: _buktiRekap != null
                                    ? Colors.green
                                    : const Color(0xFF01579B),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _buktiRekap != null
                                      ? 'Bukti Rekap: ${_buktiRekap!.name}'
                                      : 'Unggah Bukti Pedoman Rekap Kasir',
                                  style: TextStyle(
                                    color: _buktiRekap != null
                                        ? Colors.green[700]
                                        : Colors.grey[700],
                                    fontWeight: _buktiRekap != null
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              if (_buktiRekap != null)
                                const Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),

                      const SizedBox(height: 24),

                      ElevatedButton(
                        onPressed: (provider.isLoading || provider.isSaving)
                            ? null
                            : _submitForm,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          backgroundColor: const Color(0xFF01579B),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 4,
                          shadowColor: const Color(0xFF01579B).withValues(alpha: 0.4),
                        ),
                        child: const Text(
                          'SIMPAN TRANSAKSI',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.5,
                          ),
                        ),
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
      
      double totalTunaiDibutuhkan = 0;
      if (_selectedCaraBayar == 'tunai') {
        totalTunaiDibutuhkan = _sisaBayar;
      } else if (_selectedCaraBayar == 'tunai & transfer') {
        totalTunaiDibutuhkan = CurrencyInputFormatter.parse(_nominalTunaiController.text);
      } else if (_selectedCaraBayar == 'transfer') {
        // Asumsi transfer tetap cek saldo jika ingin ketat, 
        // tapi di Laravel JurnalObserver: transfer tidak mempengaruhi_kas (false).
        // Maka kita biarkan 0 jika transfer murni agar sesuai logika Laravel terbaru.
        totalTunaiDibutuhkan = 0; 
      }

      if (totalTunaiDibutuhkan > saldoPerusahaan) {
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

      final success = await context
          .read<TransaksiDoProvider>()
          .createTransaction(
            tanggal: DateFormat('yyyy-MM-dd').format(_selectedDate),
            penjualId: _selectedPenjualId!,
            supirId: _selectedSupirId!,
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
            keteranganBiayaLain: _keteranganBiayaLainController.text,
            caraBayar: _selectedCaraBayar,
            buktiTransfer: _buktiTransfer,
            keteranganPembayaran: _keteranganPembayaranController.text,
            nominalTunai: _selectedCaraBayar == 'tunai & transfer' 
                ? CurrencyInputFormatter.parse(_nominalTunaiController.text) 
                : null,
            isMismatch: _isMismatch,
            buktiRekap: _buktiRekap,
          );

      if (mounted) {
        if (success) {
          SuccessDialog.show(
            context,
            title: 'Transaksi Berhasil!',
            message:
                'Data Transaksi DO dengan nomor ${_noPolisiController.text} berhasil disimpan.',
            onConfirm: () => Navigator.pop(context),
          );
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
    }
  }
}

