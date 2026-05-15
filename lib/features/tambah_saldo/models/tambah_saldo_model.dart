class TambahSaldoModel {
  final int id;
  final int perusahaanId;
  final int userId;
  final DateTime tanggal;
  final double nominal;
  final String keperluan;
  String status;
  DateTime? tanggalProses;
  final int? prosesBy;
  final String? catatanPimpinan;
  final String? buktiTransfer;
  final String? userName;

  TambahSaldoModel({
    required this.id,
    required this.perusahaanId,
    required this.userId,
    required this.tanggal,
    required this.nominal,
    required this.keperluan,
    required this.status,
    this.tanggalProses,
    this.prosesBy,
    this.catatanPimpinan,
    this.buktiTransfer,
    this.userName,
  });

  factory TambahSaldoModel.fromJson(Map<String, dynamic> json) {
    return TambahSaldoModel(
      id: json['id'],
      perusahaanId: json['perusahaan_id'],
      userId: json['user_id'],
      tanggal: DateTime.parse(json['tanggal_pengajuan']),
      nominal: double.parse(json['nominal'].toString()),
      keperluan: json['keperluan'],
      status: json['status'],
      tanggalProses: json['tanggal_proses'] != null 
          ? DateTime.parse(json['tanggal_proses']) 
          : null,
      prosesBy: json['proses_by'],
      catatanPimpinan: json['catatan_pimpinan'],
      buktiTransfer: json['bukti_transfer'],
      userName: json['user'] != null ? json['user']['name'] : null,
    );
  }
}

