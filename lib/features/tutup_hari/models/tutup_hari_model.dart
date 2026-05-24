class TutupHariModel {
  final int id;
  final int perusahaanId;
  final int userId;
  final DateTime tanggal;
  final double totalDoTonase;
  final double totalDoRupiah;
  final double totalPemasukan;
  final double totalPengeluaran;
  final double saldoAkhirSistem;
  final double saldoAkhirFisik;
  final double selisih;
  final String? catatan;
  final String status;
  final String? userName;

  TutupHariModel({
    required this.id,
    required this.perusahaanId,
    required this.userId,
    required this.tanggal,
    required this.totalDoTonase,
    required this.totalDoRupiah,
    required this.totalPemasukan,
    required this.totalPengeluaran,
    required this.saldoAkhirSistem,
    required this.saldoAkhirFisik,
    required this.selisih,
    this.catatan,
    required this.status,
    this.userName,
  });

  factory TutupHariModel.fromJson(Map<String, dynamic> json) {
    return TutupHariModel(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      perusahaanId: int.tryParse(json['perusahaan_id']?.toString() ?? '') ?? 0,
      userId: int.tryParse(json['user_id']?.toString() ?? '') ?? 0,
      tanggal: DateTime.parse(json['tanggal']).toLocal(),
      totalDoTonase: double.tryParse(json['total_do_tonase']?.toString() ?? '0') ?? 0.0,
      totalDoRupiah: double.tryParse(json['total_do_rupiah']?.toString() ?? '0') ?? 0.0,
      totalPemasukan: double.tryParse(json['total_pemasukan']?.toString() ?? '0') ?? 0.0,
      totalPengeluaran: double.tryParse(json['total_pengeluaran']?.toString() ?? '0') ?? 0.0,
      saldoAkhirSistem: double.tryParse(json['saldo_akhir_sistem']?.toString() ?? '0') ?? 0.0,
      saldoAkhirFisik: double.tryParse(json['saldo_akhir_fisik']?.toString() ?? '0') ?? 0.0,
      selisih: double.tryParse(json['selisih']?.toString() ?? '0') ?? 0.0,
      catatan: json['catatan'],
      status: json['status'] ?? 'closed',
      userName: json['user'] != null ? json['user']['name'] : null,
    );
  }
}
