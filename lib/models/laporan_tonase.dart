class LaporanTonase {
  final String tanggal;
  final double tonase;
  final double harga;
  final String keterangan;
  final bool isHoliday;

  LaporanTonase({
    required this.tanggal,
    required this.tonase,
    required this.harga,
    required this.keterangan,
    required this.isHoliday,
  });

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    if (value is double) return value.toInt();
    return 0;
  }

  factory LaporanTonase.fromJson(Map<String, dynamic> json) {
    return LaporanTonase(
      tanggal: json['tanggal'] ?? '',
      tonase: _parseDouble(json['tonase']),
      harga: _parseDouble(json['harga']),
      keterangan: json['keterangan'] ?? '',
      isHoliday: json['is_holiday'] ?? false,
    );
  }
}

class LaporanTonaseResponse {
  final List<LaporanTonase> report;
  final double totalTonase;
  final int month;
  final int year;
  final String? perusahaanName;
  final String? perusahaanPabrik;

  LaporanTonaseResponse({
    required this.report,
    required this.totalTonase,
    required this.month,
    required this.year,
    this.perusahaanName,
    this.perusahaanPabrik,
  });

  factory LaporanTonaseResponse.fromJson(Map<String, dynamic> json) {
    return LaporanTonaseResponse(
      report: (json['report'] as List?)
              ?.map((e) => LaporanTonase.fromJson(e))
              .toList() ??
          [],
      totalTonase: LaporanTonase._parseDouble(json['total_tonase']),
      month: LaporanTonase._parseInt(json['month']),
      year: LaporanTonase._parseInt(json['year']),
      perusahaanName: json['perusahaan_name']?.toString(),
      perusahaanPabrik: json['perusahaan_pabrik']?.toString(),
    );
  }
}
