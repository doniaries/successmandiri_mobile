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

  factory LaporanTonase.fromJson(Map<String, dynamic> json) {
    return LaporanTonase(
      tanggal: json['tanggal'] ?? '',
      tonase: (json['tonase'] ?? 0).toDouble(),
      harga: (json['harga'] ?? 0).toDouble(),
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

  LaporanTonaseResponse({
    required this.report,
    required this.totalTonase,
    required this.month,
    required this.year,
  });

  factory LaporanTonaseResponse.fromJson(Map<String, dynamic> json) {
    return LaporanTonaseResponse(
      report: (json['report'] as List?)
              ?.map((e) => LaporanTonase.fromJson(e))
              .toList() ??
          [],
      totalTonase: (json['total_tonase'] ?? 0).toDouble(),
      month: json['month'] ?? 1,
      year: json['year'] ?? 2026,
    );
  }
}
