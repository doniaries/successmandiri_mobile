class TransaksiDo {
  final int id;
  final String nomor;
  final DateTime tanggal;
  final int? penjualId;
  final int? supirId;
  final String? noPolisi;
  final double tonase;
  final double hargaSatuan;
  final double subTotal;
  final double upahBongkar;
  final double biayaLain;
  final String? keteranganBiayaLain;
  final double sisaBayar;
  final String? penjualNama;
  final String? supirNama;
  final String? caraBayar;
  final double hutangAwal;
  final double pembayaranHutang;
  final double sisaHutangPenjual;
  final String? buktiTransfer;
  final String? keteranganPembayaran;

  String get displaySupirNama => supirNama ?? penjualNama ?? 'Tanpa Supir';


  final bool isMismatch;
  final String? buktiRekap;

  TransaksiDo({
    required this.id,
    required this.nomor,
    required this.tanggal,
    this.penjualId,
    this.supirId,
    this.noPolisi,
    required this.tonase,
    required this.hargaSatuan,
    required this.subTotal,
    required this.upahBongkar,
    required this.biayaLain,
    this.keteranganBiayaLain,
    required this.sisaBayar,
    this.penjualNama,
    this.supirNama,
    this.caraBayar,
    required this.hutangAwal,
    required this.pembayaranHutang,
    required this.sisaHutangPenjual,
    this.buktiTransfer,
    this.keteranganPembayaran,

    this.isMismatch = false,
    this.buktiRekap,
  });

  factory TransaksiDo.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['tanggal'] != null && json['tanggal'].toString().isNotEmpty) {
        parsedDate = DateTime.parse(json['tanggal']).toLocal();
      }
    } catch (_) {}

    return TransaksiDo(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nomor: json['nomor'] ?? '',
      tanggal: parsedDate ?? DateTime.now(),
      penjualId: (json['penjual_id'] is int) ? json['penjual_id'] : int.tryParse(json['penjual_id']?.toString() ?? ''),
      supirId: (json['supir_id'] is int) ? json['supir_id'] : int.tryParse(json['supir_id']?.toString() ?? ''),
      noPolisi: json['no_polisi']?.toString(),
      tonase: double.tryParse(json['tonase']?.toString() ?? '0') ?? 0,
      hargaSatuan: double.tryParse(json['harga_satuan']?.toString() ?? '0') ?? 0,
      subTotal: double.tryParse(json['sub_total']?.toString() ?? '0') ?? 0,
      upahBongkar: double.tryParse(json['upah_bongkar']?.toString() ?? '0') ?? 0,
      biayaLain: double.tryParse(json['biaya_lain']?.toString() ?? '0') ?? 0,
      keteranganBiayaLain: json['keterangan_biaya_lain'],
      sisaBayar: double.tryParse(json['sisa_bayar']?.toString() ?? '0') ?? 0,
      penjualNama: (json['penjual'] is Map) ? json['penjual']['nama']?.toString() : json['penjual_nama']?.toString(),
      supirNama: (json['supir'] is Map) ? json['supir']['nama']?.toString() : json['supir_nama']?.toString(),
      caraBayar: json['cara_bayar'],
      hutangAwal: double.tryParse(json['hutang_awal']?.toString() ?? '0') ?? 0,
      pembayaranHutang: double.tryParse(json['pembayaran_hutang']?.toString() ?? '0') ?? 0,
      sisaHutangPenjual: double.tryParse(json['sisa_hutang_penjual']?.toString() ?? '0') ?? 0,
      buktiTransfer: json['bukti_transfer'],
      keteranganPembayaran: json['keterangan_pembayaran'],

      isMismatch: json['is_mismatch'] == 1 || json['is_mismatch'] == true,
      buktiRekap: json['bukti_rekap'],
    );
  }
}

