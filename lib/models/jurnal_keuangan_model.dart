class JurnalKeuangan {
  final int id;
  final DateTime tanggal;
  final String jenisTransaksi;
  final String kategori;
  final String subKategori;
  final double nominal;
  final String sumberTransaksi;
  final String? nomorReferensi;
  final String? pihakTerkait;
  final String? keterangan;
  final String caraPembayaran;

  JurnalKeuangan({
    required this.id,
    required this.tanggal,
    required this.jenisTransaksi,
    required this.kategori,
    required this.subKategori,
    required this.nominal,
    required this.sumberTransaksi,
    required this.caraPembayaran,
    this.nomorReferensi,
    this.pihakTerkait,
    this.keterangan,
  });

  factory JurnalKeuangan.fromJson(Map<String, dynamic> json) {
    return JurnalKeuangan(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      tanggal: DateTime.parse(json['tanggal']),
      jenisTransaksi: json['jenis_transaksi'],
      kategori: json['kategori'],
      subKategori: json['sub_kategori'] ?? '-',
      nominal: double.tryParse(json['nominal']?.toString() ?? '0') ?? 0,
      sumberTransaksi: json['sumber_transaksi'],
      nomorReferensi: json['nomor_referensi'],
      pihakTerkait: json['pihak_terkait'],
      keterangan: json['keterangan'],
      caraPembayaran: json['cara_pembayaran'] ?? 'tunai',
    );
  }
}

