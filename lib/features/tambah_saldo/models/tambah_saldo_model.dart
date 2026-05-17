class TambahSaldoModel {
  final int id;
  final int perusahaanId;
  final int userId;
  final DateTime tanggal;
  final double nominal;
  final String keterangan;
  final String? buktiTransfer;
  final String? userName;

  final String status;

  TambahSaldoModel({
    required this.id,
    required this.perusahaanId,
    required this.userId,
    required this.tanggal,
    required this.nominal,
    required this.keterangan,
    required this.status,
    this.buktiTransfer,
    this.userName,
  });

  factory TambahSaldoModel.fromJson(Map<String, dynamic> json) {
    return TambahSaldoModel(
      id: json['id'],
      perusahaanId: json['perusahaan_id'],
      userId: json['user_id'],
      tanggal: DateTime.parse(json['tanggal']).toLocal(),
      nominal: double.parse(json['nominal'].toString()),
      keterangan: json['keterangan'] ?? '',
      status: json['status'] ?? 'pending',
      buktiTransfer: json['bukti_transfer'],
      userName: json['user'] != null ? json['user']['name'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'perusahaan_id': perusahaanId,
      'user_id': userId,
      'tanggal': tanggal.toIso8601String(),
      'nominal': nominal,
      'keterangan': keterangan,
      'status': status,
      'bukti_transfer': buktiTransfer,
    };
  }
}
