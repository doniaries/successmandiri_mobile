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
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      perusahaanId: int.tryParse(json['perusahaan_id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      tanggal: DateTime.parse(json['tanggal']).toLocal(),
      nominal: double.tryParse(json['nominal']?.toString() ?? '0') ?? 0.0,
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
