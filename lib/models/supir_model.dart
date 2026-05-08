import 'mutasi_hutang_model.dart';

class Supir {
  final int id;
  final String nama;
  final String? telepon;
  final String? alamat;
  final String? status;
  final double? hutang;
  final double? sisaHutang;
  final List<dynamic>? transaksiDo;
  final List<MutasiHutang>? mutasiHutang;

  Supir({
    required this.id,
    required this.nama,
    this.telepon,
    this.alamat,
    this.status,
    this.hutang,
    this.sisaHutang,
    this.transaksiDo,
    this.mutasiHutang,
  });

  factory Supir.fromJson(Map<String, dynamic> json) {
    return Supir(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama'],
      telepon: json['telepon'],
      alamat: json['alamat'],
      status: json['status_supir'],
      hutang: double.tryParse(json['hutang']?.toString() ?? '0'),
      sisaHutang: double.tryParse(json['sisa_hutang']?.toString() ?? '0'),
      transaksiDo: json['transaksi_do'],
      mutasiHutang: (json['mutasi_hutang'] as List?)
          ?.map((m) => MutasiHutang.fromJson(m))
          .toList(),
    );
  }
}

