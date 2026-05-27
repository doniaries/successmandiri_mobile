import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:dio/dio.dart';

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
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((r) => r == ConnectivityResult.none)) {
        // Offline: baca dari SQLite cache + offline queue
        final mergedData = await _syncService.getMergedOfflineData(
          'tambah_saldo',
          ApiConstants.tambahSaldo,
        );
        return mergedData.map((e) => TambahSaldoModel.fromJson(e)).toList();
      }

      // Online: ambil langsung dari server
      final response = await _apiClient.dio.get(ApiConstants.tambahSaldo).timeout(const Duration(seconds: 15));
      final List<dynamic> serverData = _extractListData(response.data);

      // (Cache offline sekarang dikelola secara incremental oleh SyncService.performFullSync)

      // Ambil offline queue items (belum terkirim ke server)
      final pendingQueue = await _syncService.getOfflineQueueForEndpoint(ApiConstants.tambahSaldo);
      final pendingItems = pendingQueue.map((item) {
        final data = Map<String, dynamic>.from(item['data'] as Map);
        data['id'] = item['id']; // id negatif dari getOfflineQueueForEndpoint
        data['status'] ??= 'pending';
        return data;
      }).toList();

      // Gabungkan: offline items di depan + data server
      final combined = [...pendingItems, ...serverData];
      return combined.map((e) => TambahSaldoModel.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      // Fallback: baca dari SQLite cache + offline queue
      final mergedData = await _syncService.getMergedOfflineData(
        'tambah_saldo',
        ApiConstants.tambahSaldo,
      );
      return mergedData.map((e) => TambahSaldoModel.fromJson(e)).toList();
    }
  }

  Future<dynamic> createTambahSaldo({
    required double nominal,
    required String tanggal,
    String? keterangan,
  }) async {
    final Map<String, dynamic> data = {
      'client_uuid': const Uuid().v4(),
      'client_created_at': DateTime.now().toUtc().toIso8601String(),
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
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      
      // Jika terjadi timeout atau error koneksi (meskipun terhubung ke WiFi tanpa internet)
      await _syncService.addToQueue(ApiConstants.tambahSaldo, 'POST', data);
      return {'offline': true};
    }
  }


  Future<dynamic> updateTambahSaldo(int id, {
    required double nominal,
    required String tanggal,
    required String keterangan,
  }) async {
    final Map<String, dynamic> data = {
      'nominal': nominal,
      'tanggal': tanggal,
      'keterangan': keterangan,
    };

    if (id < 0) {
      await _syncService.updateQueueData(id.abs(), data);
      return TambahSaldoModel(
        id: id,
        perusahaanId: 0,
        userId: 0,
        tanggal: DateTime.parse(tanggal).toLocal(),
        nominal: nominal,
        keterangan: keterangan,
        status: 'pending',
        userName: 'Data Offline (Lokal)',
      );
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.every((r) => r == ConnectivityResult.none)) {
        await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id', 'PUT', data);
        return {'offline': true, 'id': id};
      }

      final response = await _apiClient.dio.put(
        '${ApiConstants.tambahSaldo}/$id',
        data: data,
      ).timeout(const Duration(seconds: 15));
      return TambahSaldoModel.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id', 'PUT', data);
      return {'offline': true, 'id': id};
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id', 'PUT', data);
        return {'offline': true, 'id': id};
      }
      rethrow;
    }
  }

  Future<void> deleteTambahSaldo(int id) async {
    try {
      if (id < 0) {
        await _syncService.deleteFromQueue(id.abs());
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id', 'DELETE', {});
        return;
      }

      await _apiClient.dio.delete(
        '${ApiConstants.tambahSaldo}/$id',
      );
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id', 'DELETE', {});
    }
  }
}
