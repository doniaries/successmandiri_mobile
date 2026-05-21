import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/dashboard/models/dashboard_summary_model.dart';

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
          final decoded = jsonDecode(cachedDataStr);
          return DashboardSummary.fromJson(decoded);
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

