import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class TambahSaldoRepository {
  final ApiClient _apiClient;
  final SyncService _syncService = SyncService();

  TambahSaldoRepository(this._apiClient);

  List<dynamic> _extractListData(dynamic responseData) {
    if (responseData is Map) {
      return responseData['data'] ?? [];
    } else if (responseData is List) {
      return responseData;
    }
    return [];
  }

  Future<List<TambahSaldoModel>> getTambahSaldo({String? status}) async {
    try {
      final response = await _apiClient.dio.get(
        ApiConstants.tambahSaldo,
      );

      final List<dynamic> data = _extractListData(response.data);
      return data.map((json) => TambahSaldoModel.fromJson(json)).toList();
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createTambahSaldo({
    required double nominal,
    required String tanggal,
    String? keterangan,
  }) async {
    final Map<String, dynamic> data = {
      'nominal': nominal,
      'tanggal': tanggal,
      'keterangan': keterangan,
    };

    // Cek koneksi terlebih dahulu
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);

    if (isOffline) {
      // Benar-benar offline → simpan ke queue
      await _syncService.addToQueue(ApiConstants.tambahSaldo, 'POST', data);
      return {'offline': true};
    }

    // Ada koneksi → coba kirim ke server
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.tambahSaldo,
        data: data,
      );
      return TambahSaldoModel.fromJson(response.data['data'] ?? response.data);
    } on Exception catch (_) {
      // Cek ulang koneksi saat terjadi error
      final connectivityAfter = await Connectivity().checkConnectivity();
      final isReallyOffline = connectivityAfter.every((r) => r == ConnectivityResult.none);

      if (isReallyOffline) {
        // Koneksi putus saat request → simpan ke queue
        await _syncService.addToQueue(ApiConstants.tambahSaldo, 'POST', data);
        return {'offline': true};
      }

      // Error dari server (bukan masalah koneksi) → lempar error agar ditampilkan
      rethrow;
    }
  }


  Future<TambahSaldoModel> updateTambahSaldo(int id, {
    required double nominal,
    required String tanggal,
    required String keterangan,
  }) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.tambahSaldo}/$id',
        data: {
          'nominal': nominal,
          'tanggal': tanggal,
          'keterangan': keterangan,
        },
      );
      return TambahSaldoModel.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteTambahSaldo(int id) async {
    try {
      await _apiClient.dio.delete(
        '${ApiConstants.tambahSaldo}/$id',
      );
    } catch (e) {
      rethrow;
    }
  }
}
