class MutasiHutang {
  final int id;
  final String tipe;
  final double nominal;
  final double saldoAkhir;
  final String? keterangan;
  final String createdAt;
  final String? referensiType;
  final int? referensiId;

  MutasiHutang({
    required this.id,
    required this.tipe,
    required this.nominal,
    required this.saldoAkhir,
    this.keterangan,
    required this.createdAt,
    this.referensiType,
    this.referensiId,
  });

  factory MutasiHutang.fromJson(Map<String, dynamic> json) {
    return MutasiHutang(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      tipe: json['tipe'],
      nominal: double.tryParse(json['nominal']?.toString() ?? '0') ?? 0.0,
      saldoAkhir: double.tryParse(json['saldo_akhir']?.toString() ?? '0') ?? 0.0,
      keterangan: json['keterangan'],
      createdAt: json['created_at'],
      referensiType: json['referensi_type'],
      referensiId: (json['referensi_id'] is int) ? json['referensi_id'] : int.tryParse(json['referensi_id']?.toString() ?? ''),
    );
  }

  bool get isMasuk => tipe == 'HUTANG_MASUK';
  bool get isKeluar => tipe == 'HUTANG_KELUAR';
}

