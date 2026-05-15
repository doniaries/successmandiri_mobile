class Operasional {
  final int id;
  final DateTime tanggal;
  final String operasional; // Pemasukan/Pengeluaran
  final String kategori;
  final String? kategoriLabel;
  final double nominal;
  final String? keterangan;
  final int? pihakId;
  final String? pihakType;
  final String? namaPihak;

  Operasional({
    required this.id,
    required this.tanggal,
    required this.operasional,
    required this.kategori,
    this.kategoriLabel,
    required this.nominal,
    this.keterangan,
    this.pihakId,
    this.pihakType,
    this.namaPihak,
  });

  factory Operasional.fromJson(Map<String, dynamic> json) {
    return Operasional(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      tanggal: DateTime.parse(json['tanggal']),
      operasional: json['operasional'] ?? '',
      kategori: json['kategori'] ?? '',
      kategoriLabel: json['kategori_label'],
      nominal: double.tryParse(json['nominal'].toString()) ?? 0.0,
      keterangan: json['keterangan'],
      pihakId: (json['pihak_id'] is int) ? json['pihak_id'] : int.tryParse(json['pihak_id']?.toString() ?? ''),
      pihakType: json['pihak_type'],
      namaPihak: json['nama'] ?? json['pihak_nama'], // Handle from accessor
    );
  }
}

