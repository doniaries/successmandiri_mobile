import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';

class DashboardRepository {
  final ApiClient _apiClient = ApiClient();

  Future<DashboardSummary> getSummary({String? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_dashboard_summary${date != null ? "_$date" : ""}';

    try {
      final response = await _apiClient.dio.get(
        ApiConstants.dashboardSummary,
        queryParameters: date != null ? {'date': date} : null,
      ).timeout(const Duration(seconds: 15));
      
      // Simpan ke cache jika sukses
      await prefs.setString(cacheKey, jsonEncode(response.data));
      
      return DashboardSummary.fromJson(response.data);
    } catch (e) {
      // Jika gagal (misal offline), coba ambil dari cache
      final cachedDataStr = prefs.getString(cacheKey);
      if (cachedDataStr != null) {
        try {
          var summary = DashboardSummary.fromJson(jsonDecode(cachedDataStr));
          final syncService = SyncService();

          double totalOfflinePengeluaran = 0;
          int countOfflinePengeluaran = 0;
          double totalOfflinePemasukan = 0;
          int countOfflinePemasukan = 0;

          // 1. Pending Operasional
          final pendingOperasional = await syncService.getMergedOfflineData('operasional', ApiConstants.operasional);
          if (pendingOperasional.isNotEmpty) {
             final ops = pendingOperasional.map((e) => Operasional.fromJson(e)).toList();
             
             double totalOps = 0;
             for (var op in ops) {
                totalOps += op.nominal.toDouble();
             }
             totalOfflinePengeluaran += totalOps;
             countOfflinePengeluaran += ops.length;
             
             final mergedOps = [...ops, ...summary.latestOperasional];
             if (mergedOps.length > 5) mergedOps.length = 5;
             
             summary = summary.copyWith(
                totalOperasional: summary.totalOperasional + ops.length,
                latestOperasional: mergedOps,
             );
          }

          // 2. Pending Transaksi DO
          final pendingDo = await syncService.getMergedOfflineData('transaksi_do', ApiConstants.transaksiDo);
          if (pendingDo.isNotEmpty) {
             final dos = pendingDo.map((e) => TransaksiDo.fromJson(e)).toList();
             
             for (var d in dos) {
               if (d.caraBayar == 'tunai') {
                 totalOfflinePengeluaran += d.sisaBayar ?? 0;
                 countOfflinePengeluaran++;
               }
             }

             final mergedDos = [...dos, ...summary.transactions];
             if (mergedDos.length > 10) mergedDos.length = 10;
             
             summary = summary.copyWith(
                transactions: mergedDos,
             );
          }
          
          // 3. Pending Jurnal Keuangan (Pemasukan / Pengeluaran / Tambah Saldo)
          final pendingJurnal = await syncService.getMergedOfflineData('jurnal_keuangan', ApiConstants.jurnalKeuangan);
          if (pendingJurnal.isNotEmpty) {
             for (var j in pendingJurnal) {
               final double nominal = double.tryParse(j['nominal']?.toString() ?? '0') ?? 0;
               if (j['jenis_transaksi'] == 'Pemasukan') {
                 totalOfflinePemasukan += nominal;
                 countOfflinePemasukan++;
               } else if (j['jenis_transaksi'] == 'Pengeluaran') {
                 totalOfflinePengeluaran += nominal;
                 countOfflinePengeluaran++;
               }
             }
          }

          // Update saldo dan stats
          double newSaldo = summary.saldo + totalOfflinePemasukan - totalOfflinePengeluaran;
          final oldStats = summary.stats;
          final newStats = DashboardStats(
            pemasukan: PemasukanStats(
              today: StatDetail(
                total: oldStats.pemasukan.today.total + totalOfflinePemasukan,
                count: oldStats.pemasukan.today.count + countOfflinePemasukan,
              ),
              month: StatDetail(
                total: oldStats.pemasukan.month.total + totalOfflinePemasukan,
                count: oldStats.pemasukan.month.count + countOfflinePemasukan,
              ),
            ),
            pengeluaran: PengeluaranStats(
              today: StatDetail(
                total: oldStats.pengeluaran.today.total + totalOfflinePengeluaran,
                count: oldStats.pengeluaran.today.count + countOfflinePengeluaran,
              ),
              month: StatDetail(
                total: oldStats.pengeluaran.month.total + totalOfflinePengeluaran,
                count: oldStats.pengeluaran.month.count + countOfflinePengeluaran,
              ),
            ),
            transaksi: oldStats.transaksi, // retain other stats
          );
          
          summary = summary.copyWith(
            saldo: newSaldo,
            totalJurnalKeuangan: summary.totalJurnalKeuangan + pendingJurnal.length,
            stats: newStats,
          );
          
          return summary;
        } catch (_) {}
      }
      
      // Jika tidak ada di cache, buat data kosong agar tidak error jika offline pertama kali
      if (cachedDataStr == null) {
         return DashboardSummary(
           saldo: 0,
           totalPenjual: 0,
           totalSupir: 0,
           totalPekerja: 0,
           totalKendaraan: 0,
           totalJurnalKeuangan: 0,
           totalOperasional: 0,
           totalUser: 0,
           totalPengajuanDana: 0,
           totalPengajuanCount: 0,
           tambahSaldoTodayCount: 0,
           perusahaanName: '-',
           namaKasir: '-',
           systemActiveDate: DateTime.now().toIso8601String().split('T')[0],
           transactions: [],
           latestOperasional: [],
           stats: DashboardStats.fromJson({}),
         );
      }
      rethrow;
    }
  }
}
