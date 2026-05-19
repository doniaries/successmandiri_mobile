import 'package:sawitappmobile/shared/models/mutasi_hutang_model.dart';

class Penjual {
  final int id;
  final String nama;
  final String? alamat;
  final String? telepon;
  final double? hutang;
  final double? sisaHutang;
  final bool isActive;
  final List<dynamic>? transaksiDo;
  final List<MutasiHutang>? mutasiHutang;
  final DateTime? createdAt;

  Penjual({
    required this.id,
    required this.nama,
    this.alamat,
    this.telepon,
    this.hutang,
    this.sisaHutang,
    required this.isActive,
    this.transaksiDo,
    this.mutasiHutang,
    this.createdAt,
  });

  factory Penjual.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
        parsedDate = DateTime.parse(json['created_at']).toLocal();
      }
    } catch (_) {}

    return Penjual(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama'],
      alamat: json['alamat'],
      telepon: json['telepon'],
      hutang: _parseDouble(json['hutang']),
      sisaHutang: _parseDouble(json['sisa_hutang']),
      isActive: json['is_active'] == true || json['is_active'] == 1 || json['is_active'] == '1',
      transaksiDo: json['transaksi_do'],
      mutasiHutang: (json['mutasi_hutang'] as List?)
          ?.map((m) => MutasiHutang.fromJson(m))
          .toList(),
      createdAt: parsedDate,
    );
  }
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString());
  }
}

