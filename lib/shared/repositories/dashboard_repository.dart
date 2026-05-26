import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import package:sawitappmobile/core/utils/app_time.dart;

class DashboardRepository {
  final ApiClient _apiClient = ApiClient();

  Future<DashboardSummary> getSummary({String? date}) async {
    final prefs = await SharedPreferences.getInstance();
    final cacheKey = 'cached_dashboard_summary${date != null ? "_$date" : ""}';

    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.dashboardSummary,
            queryParameters: date != null ? {'date': date} : null,
          )
          .timeout(const Duration(seconds: 15));
      debugPrint(
        'DashboardRepository.getSummary: fetched from API for date=$date, response_keys=${response.data is Map ? (response.data as Map).keys.toList() : 'list'}',
      );

      // Simpan ke cache jika sukses
      await prefs.setString(cacheKey, jsonEncode(response.data));

      return DashboardSummary.fromJson(response.data);
    } catch (e) {
      // Jika gagal (misal offline), coba ambil dari cache
      final cachedDataStr = prefs.getString(cacheKey);
      DashboardSummary summary;

      if (cachedDataStr != null) {
        debugPrint('DashboardRepository.getSummary: using cache key=$cacheKey');
        try {
          summary = DashboardSummary.fromJson(jsonDecode(cachedDataStr));
        } catch (_) {
          summary = _createEmptySummary();
        }
      } else {
        summary = _createEmptySummary();
      }

      try {
        final syncService = SyncService();

        final connectivity = await Connectivity().checkConnectivity();
        final isTrulyOffline = connectivity.contains(ConnectivityResult.none);

        if (!isTrulyOffline) {
          // Jika ada koneksi tapi gagal API (timeout), return cached data saja
          return summary;
        }

        double totalOfflinePengeluaran = 0;
        int countOfflinePengeluaran = 0;
        double totalOfflinePemasukan = 0;
        int countOfflinePemasukan = 0;

        // 1. Pending Operasional
        final pendingOperasional = await syncService.getMergedOfflineData(
          'operasional',
          ApiConstants.operasional,
        );
        final offlineOps = pendingOperasional.where((e) {
          final id = e['id'] as int?;
          return id != null &&
              id < 0; // Hanya ID negatif = truly offline/pending
        }).toList();

        if (offlineOps.isNotEmpty) {
          final ops = offlineOps.map((e) => Operasional.fromJson(e)).toList();

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
        final pendingDo = await syncService.getMergedOfflineData(
          'transaksi_do',
          ApiConstants.transaksiDo,
        );
        final offlineDo = pendingDo.where((e) {
          final id = e['id'] as int?;
          return id != null && id < 0;
        }).toList();

        if (offlineDo.isNotEmpty) {
          final dos = offlineDo.map((e) => TransaksiDo.fromJson(e)).toList();

          for (var d in dos) {
            if (d.caraBayar == 'tunai') {
              totalOfflinePengeluaran += d.sisaBayar;
              countOfflinePengeluaran++;
            }
          }

          final mergedDos = [...dos, ...summary.transactions];
          if (mergedDos.length > 10) mergedDos.length = 10;

          summary = summary.copyWith(transactions: mergedDos);
        }

        // 3. Pending Jurnal Keuangan (Pemasukan / Pengeluaran / Tambah Saldo)
        final pendingJurnal = await syncService.getMergedOfflineData(
          'jurnal_keuangan',
          ApiConstants.jurnalKeuangan,
        );
        final offlineJurnal = pendingJurnal.where((e) {
          final id = e['id'] as int?;
          return id != null && id < 0;
        }).toList();

        if (offlineJurnal.isNotEmpty) {
          for (var j in offlineJurnal) {
            final double nominal =
                double.tryParse(j['nominal']?.toString() ?? '0') ?? 0;
            if (j['jenis_transaksi'] == 'Pemasukan') {
              totalOfflinePemasukan += nominal;
              countOfflinePemasukan++;
            } else if (j['jenis_transaksi'] == 'Pengeluaran') {
              totalOfflinePengeluaran += nominal;
              countOfflinePengeluaran++;
            }
          }
        }

        // 4. Pending Tambah Saldo
        final pendingTambahSaldo = await syncService.getMergedOfflineData(
          'tambah_saldo',
          ApiConstants.tambahSaldo,
        );
        final offlineTambahSaldo = pendingTambahSaldo.where((e) {
          final id = e['id'] as int?;
          return id != null && id < 0;
        }).toList();

        if (offlineTambahSaldo.isNotEmpty) {
          for (var ts in offlineTambahSaldo) {
            final double nominal =
                double.tryParse(ts['nominal']?.toString() ?? '0') ?? 0;
            totalOfflinePemasukan += nominal;
            countOfflinePemasukan++;
          }
        }

        final tsQueue = await syncService.getOfflineQueueForEndpoint(
          ApiConstants.tambahSaldo,
        );
        final pendingTsDeletes = tsQueue
            .where((q) => q['method'] == 'DELETE')
            .length;

        // Update saldo dan stats HANYA jika ada offline data
        if (countOfflinePemasukan > 0 ||
            countOfflinePengeluaran > 0 ||
            offlineTambahSaldo.isNotEmpty ||
            pendingTsDeletes > 0) {
          double newSaldo =
              summary.saldo + totalOfflinePemasukan - totalOfflinePengeluaran;
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
                total:
                    oldStats.pengeluaran.today.total + totalOfflinePengeluaran,
                count:
                    oldStats.pengeluaran.today.count + countOfflinePengeluaran,
              ),
              month: StatDetail(
                total:
                    oldStats.pengeluaran.month.total + totalOfflinePengeluaran,
                count:
                    oldStats.pengeluaran.month.count + countOfflinePengeluaran,
              ),
            ),
            transaksi: oldStats.transaksi, // retain other stats
          );

          summary = summary.copyWith(
            saldo: newSaldo,
            totalJurnalKeuangan:
                summary.totalJurnalKeuangan + offlineJurnal.length,
            tambahSaldoTodayCount:
                (summary.tambahSaldoTodayCount +
                        offlineTambahSaldo.length -
                        pendingTsDeletes)
                    .clamp(0, 999999),
            stats: newStats,
          );
        }

        // 5. Pending Penjual
        final pendingPenjual = await syncService.getMergedOfflineData(
          'penjual',
          ApiConstants.penjual,
        );
        final offlinePenjualCount = pendingPenjual.where((e) {
          final id = e['id'] as int?;
          return id != null && id < 0;
        }).length;

        // 6. Pending Supir
        final pendingSupir = await syncService.getMergedOfflineData(
          'supir',
          ApiConstants.supir,
        );
        final offlineSupirCount = pendingSupir.where((e) {
          final id = e['id'] as int?;
          return id != null && id < 0;
        }).length;

        // 7. Pending Pekerja
        final pendingPekerja = await syncService.getMergedOfflineData(
          'pekerja',
          ApiConstants.pekerja,
        );
        final offlinePekerjaCount = pendingPekerja.where((e) {
          final id = e['id'] as int?;
          return id != null && id < 0;
        }).length;

        if (offlinePenjualCount > 0 ||
            offlineSupirCount > 0 ||
            offlinePekerjaCount > 0) {
          summary = summary.copyWith(
            totalPenjual: summary.totalPenjual + offlinePenjualCount,
            totalSupir: summary.totalSupir + offlineSupirCount,
            totalPekerja: summary.totalPekerja + offlinePekerjaCount,
          );
        }

        return summary;
      } catch (_) {}

      return summary;
    }
  }

  DashboardSummary _createEmptySummary() {
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
      operasionalTodayCount: 0,
      jurnalTodayCount: 0,
      perusahaanName: '-',
      namaKasir: '-',
      systemActiveDate: AppTime.now().toIso8601String().split('T')[0],
      transactions: [],
      latestOperasional: [],
      stats: DashboardStats.fromJson({}),
    );
  }
}
