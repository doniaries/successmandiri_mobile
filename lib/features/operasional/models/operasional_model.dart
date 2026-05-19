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
  final String? userName;
  final String? perusahaanNama;

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
    this.userName,
    this.perusahaanNama,
  });

  factory Operasional.fromJson(Map<String, dynamic> json) {
    return Operasional(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      tanggal: DateTime.parse(json['tanggal']).toLocal(),
      operasional: json['operasional'] ?? '',
      kategori: json['kategori'] ?? '',
      kategoriLabel: json['kategori_label'],
      nominal: double.tryParse(json['nominal'].toString()) ?? 0.0,
      keterangan: json['keterangan'],
      pihakId: (json['pihak_id'] is int) ? json['pihak_id'] : int.tryParse(json['pihak_id']?.toString() ?? ''),
      pihakType: json['pihak_type'],
      namaPihak: json['nama'] ?? json['pihak_nama'], // Handle from accessor
      userName: json['user_name'] ?? json['user']?['name'], // Handle both accessor and direct eager relation
      perusahaanNama: json['perusahaan'] != null ? json['perusahaan']['name']?.toString() : json['perusahaan_nama']?.toString(),
    );
  }
}

