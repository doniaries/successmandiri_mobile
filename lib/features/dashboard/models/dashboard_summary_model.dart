import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';

class DashboardSummary {
  final double saldo;
  final int totalPenjual;
  final int totalSupir;
  final int totalPekerja;
  final int totalKendaraan;
  final int totalJurnalKeuangan;
  final int totalOperasional;
  final int totalUser;
  final double totalPengajuanDana;
  final int totalPengajuanCount;
  final int tambahSaldoTodayCount;
  final String perusahaanName;
  final String namaKasir;
  final String systemActiveDate;
  final List<TransaksiDo> transactions;
  final List<Operasional> latestOperasional;
  final DashboardStats stats;

  DashboardSummary({
    required this.saldo,
    required this.totalPenjual,
    required this.totalSupir,
    required this.totalPekerja,
    required this.totalKendaraan,
    required this.totalJurnalKeuangan,
    required this.totalOperasional,
    required this.totalUser,
    required this.totalPengajuanDana,
    required this.totalPengajuanCount,
    required this.tambahSaldoTodayCount,
    required this.perusahaanName,
    required this.namaKasir,
    required this.systemActiveDate,
    required this.transactions,
    required this.latestOperasional,
    required this.stats,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    final statsJson = json['stats'];
    return DashboardSummary(
      saldo: double.tryParse(json['saldo']?.toString() ?? '0') ?? 0,
      totalPenjual: int.tryParse(json['total_penjual']?.toString() ?? '0') ?? 0,
      totalSupir: int.tryParse(json['total_supir']?.toString() ?? '0') ?? 0,
      totalPekerja: int.tryParse(json['total_pekerja']?.toString() ?? '0') ?? 0,
      totalKendaraan: int.tryParse(json['total_kendaraan']?.toString() ?? '0') ?? 0,
      totalJurnalKeuangan: int.tryParse(json['total_jurnal_keuangan']?.toString() ?? '0') ?? 0,
      totalOperasional: int.tryParse(json['total_operasional']?.toString() ?? '0') ?? 0,
      totalUser: int.tryParse(json['total_user']?.toString() ?? '0') ?? 0,
      totalPengajuanDana: double.tryParse(json['total_pengajuan_dana']?.toString() ?? '0') ?? 0,
      totalPengajuanCount: int.tryParse(json['total_pengajuan_count']?.toString() ?? '0') ?? 0,
      tambahSaldoTodayCount: int.tryParse(json['tambah_saldo_today_count']?.toString() ?? '0') ?? 0,
      perusahaanName: json['perusahaan_name']?.toString() ?? '-',
      namaKasir: json['nama_kasir']?.toString() ?? 'Kasir Utama',
      systemActiveDate: json['system_active_date']?.toString() ?? DateTime.now().toIso8601String().split('T')[0],
      transactions: (json['transactions'] as List?)
              ?.map((e) => TransaksiDo.fromJson(e))
              .toList() ??
          [],
      latestOperasional: (json['latest_operasional'] as List?)
              ?.map((e) => Operasional.fromJson(e))
              .toList() ??
          [],
      stats: DashboardStats.fromJson(statsJson is Map<String, dynamic> ? statsJson : {}),
    );
  }
}

class DashboardStats {
  final PemasukanStats pemasukan;
  final PengeluaranStats pengeluaran;
  final TransaksiStats transaksi;

  DashboardStats({
    required this.pemasukan,
    required this.pengeluaran,
    required this.transaksi,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    final pem = json['pemasukan'];
    final peng = json['pengeluaran'];
    final trx = json['transaksi'];
    
    return DashboardStats(
      pemasukan: PemasukanStats.fromJson(pem is Map<String, dynamic> ? pem : {}),
      pengeluaran: PengeluaranStats.fromJson(peng is Map<String, dynamic> ? peng : {}),
      transaksi: TransaksiStats.fromJson(trx is Map<String, dynamic> ? trx : {}),
    );
  }
}

class PemasukanStats {
  final StatDetail today;
  final StatDetail month;

  PemasukanStats({
    required this.today,
    required this.month,
  });

  factory PemasukanStats.fromJson(Map<String, dynamic> json) {
    return PemasukanStats(
      today: StatDetail.fromJson(json['today'] is Map<String, dynamic> ? json['today'] : {}),
      month: StatDetail.fromJson(json['month'] is Map<String, dynamic> ? json['month'] : {}),
    );
  }
}

class StatDetail {
  final double total;
  final int count;

  StatDetail({
    required this.total,
    required this.count,
  });

  factory StatDetail.fromJson(Map<String, dynamic> json) {
    return StatDetail(
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0,
      count: int.tryParse(json['count']?.toString() ?? '0') ?? 0,
    );
  }
}

class PengeluaranStats {
  final StatDetail today;
  final StatDetail month;

  PengeluaranStats({
    required this.today,
    required this.month,
  });

  factory PengeluaranStats.fromJson(Map<String, dynamic> json) {
    return PengeluaranStats(
      today: StatDetail.fromJson(json['today'] is Map<String, dynamic> ? json['today'] : {}),
      month: StatDetail.fromJson(json['month'] is Map<String, dynamic> ? json['month'] : {}),
    );
  }
}

class TransaksiStats {
  final StatDetail today;
  final StatDetail? yesterday;
  final StatDetail month;
  final String periodeAwal;
  final String periodeAkhir;

  TransaksiStats({
    required this.today,
    this.yesterday,
    required this.month,
    required this.periodeAwal,
    required this.periodeAkhir,
  });

  factory TransaksiStats.fromJson(Map<String, dynamic> json) {
    return TransaksiStats(
      today: StatDetail.fromJson(
        json['today'] is Map<String, dynamic> ? json['today'] : {},
      ),
      yesterday: json['yesterday'] != null
          ? StatDetail.fromJson(
              json['yesterday'] is Map<String, dynamic> ? json['yesterday'] : {},
            )
          : null,
      month: StatDetail.fromJson(
        json['month'] is Map<String, dynamic> ? json['month'] : {},
      ),
      periodeAwal: json['periode_awal']?.toString() ?? '',
      periodeAkhir: json['periode_akhir']?.toString() ?? '',
    );
  }
}

