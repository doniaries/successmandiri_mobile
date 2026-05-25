import 'package:sawitappmobile/shared/models/mutasi_hutang_model.dart';

class Pekerja {
  final int id;
  final String nama;
  final String? telepon;
  final String? alamat;
  final String posisi;
  final double hutang;
  final double sisaHutang;
  final int perusahaanId;
  final bool isActive;
  final List<MutasiHutang>? mutasiHutang;
  final DateTime? createdAt;

  Pekerja({
    required this.id,
    required this.nama,
    this.telepon,
    this.alamat,
    required this.posisi,
    required this.hutang,
    required this.sisaHutang,
    required this.perusahaanId,
    required this.isActive,
    this.mutasiHutang,
    this.createdAt,
  });

  factory Pekerja.fromJson(Map<String, dynamic> json) {
    DateTime? parsedDate;
    try {
      if (json['created_at'] != null && json['created_at'].toString().isNotEmpty) {
        parsedDate = DateTime.parse(json['created_at']).toLocal();
      }
    } catch (_) {}

    // Parse is_active with better null handling
    final isActiveParsed = json['is_active'];
    final isActive = isActiveParsed == true ||
                    isActiveParsed == 1 ||
                    isActiveParsed == '1' ||
                    isActiveParsed == 'true';

    return Pekerja(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nama: json['nama'],
      telepon: json['telepon'],
      alamat: json['alamat'],
      posisi: json['posisi'] ?? 'Staff',
      hutang: double.tryParse(json['hutang']?.toString() ?? '0') ?? 0,
      sisaHutang: double.tryParse(json['sisa_hutang']?.toString() ?? '0') ?? 0,
      perusahaanId: (json['perusahaan_id'] is int) ? json['perusahaan_id'] : int.tryParse(json['perusahaan_id']?.toString() ?? '0') ?? 0,
      isActive: isActive,
      mutasiHutang: json['mutasi_hutang'] != null
          ? (json['mutasi_hutang'] as List)
              .map((i) => MutasiHutang.fromJson(i))
              .toList()
          : null,
      createdAt: parsedDate,
    );
  }
}

