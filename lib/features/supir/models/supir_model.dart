import 'package:sawitappmobile/shared/models/mutasi_hutang_model.dart';

class Supir {
  final int id;
  final String nama;
  final String? telepon;
  final String? alamat;
  final String? status;
  final double? hutang;
  final double? sisaHutang;
  final bool isActive;
  final List<dynamic>? transaksiDo;
  final List<MutasiHutang>? mutasiHutang;
  final DateTime? createdAt;

  Supir({
    required this.id,
    required this.nama,
    this.telepon,
    this.alamat,
    this.status,
    this.hutang,
    this.sisaHutang,
    required this.isActive,
    this.transaksiDo,
    this.mutasiHutang,
    this.createdAt,
  });

  factory Supir.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
        parsedDate = DateTime.parse(json['created_at']).toLocal();
      }
    } catch (_) {}

    return Supir(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama'],
      telepon: json['telepon'],
      alamat: json['alamat'],
      status: json['status_supir'],
      hutang: double.tryParse(json['hutang']?.toString() ?? '0'),
      sisaHutang: double.tryParse(json['sisa_hutang']?.toString() ?? '0'),
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      transaksiDo: json['transaksi_do'],
      mutasiHutang: (json['mutasi_hutang'] as List?)
          ?.map((m) => MutasiHutang.fromJson(m))
          .toList(),
      createdAt: parsedDate,
    );
  }
}

