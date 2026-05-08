import 'mutasi_hutang_model.dart';

class Pekerja {
  final int id;
  final String nama;
  final String? telepon;
  final String? alamat;
  final String posisi;
  final double hutang;
  final double sisaHutang;
  final int perusahaanId;
  final List<MutasiHutang>? mutasiHutang;

  Pekerja({
    required this.id,
    required this.nama,
    this.telepon,
    this.alamat,
    required this.posisi,
    required this.hutang,
    required this.sisaHutang,
    required this.perusahaanId,
    this.mutasiHutang,
  });

  factory Pekerja.fromJson(Map<String, dynamic> json) {
    return Pekerja(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama'],
      telepon: json['telepon'],
      alamat: json['alamat'],
      posisi: json['posisi'] ?? 'Staff',
      hutang: double.tryParse(json['hutang']?.toString() ?? '0') ?? 0,
      sisaHutang: double.tryParse(json['sisa_hutang']?.toString() ?? '0') ?? 0,
      perusahaanId: (json['perusahaan_id'] is int) ? json['perusahaan_id'] : int.tryParse(json['perusahaan_id']?.toString() ?? '0') ?? 0,
      mutasiHutang: json['mutasi_hutang'] != null
          ? (json['mutasi_hutang'] as List)
              .map((i) => MutasiHutang.fromJson(i))
              .toList()
          : null,
    );
  }
}

