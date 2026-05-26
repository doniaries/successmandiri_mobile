import 'package:dio/dio.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/features/penjual/models/penjual_model.dart';
import 'package:sawitappmobile/features/supir/models/supir_model.dart';
import 'package:sawitappmobile/features/pekerja/models/pekerja_model.dart';
import 'package:sawitappmobile/features/kendaraan/models/kendaraan_model.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ResourceRepository {
  final ApiClient _apiClient;
  final SyncService syncService = SyncService();

  ResourceRepository(this._apiClient);

  List<dynamic> _extractListData(dynamic responseData) {
    if (responseData is Map) {
      return responseData['data'] ?? [];
    } else if (responseData is List) {
      return responseData;
    }
    return [];
  }

  Future<dynamic> getPenjualPaginated({int page = 1}) async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.penjual,
            queryParameters: {'page': page, 'per_page': 10},
          )
          .timeout(const Duration(seconds: 15));

      if (page == 1) {
        // Hapus kode SharedPreferences, ganti dengan SQLite Cache
        final List<dynamic> listData = _extractListData(response.data);
        await syncService.cacheData('penjual', listData, clear: false);
        final pendingData = await syncService.getMergedOfflineData('penjual', ApiConstants.penjual);
        if (response.data is Map) {
          response.data['data'] = pendingData;
        }
      }

      return response.data;
    } catch (e) {
      try {
        final pendingData = await syncService.getMergedOfflineData(
          'penjual',
          ApiConstants.penjual,
        );
        return {
          'data': pendingData,
          'current_page': 1,
          'last_page': 1,
        };
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Penjual>> getPenjuals() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final mergedData = await syncService.getMergedOfflineData(
          'penjual',
          ApiConstants.penjual,
        );
        return mergedData.map((e) => Penjual.fromJson(e)).toList();
      }

      final response = await _apiClient.dio
          .get(ApiConstants.penjual, queryParameters: {'all': true})
          .timeout(const Duration(seconds: 5));
      final List<dynamic> data = _extractListData(response.data);

      await syncService.cacheData('penjual', data);
      final mergedData = await syncService.getMergedOfflineData('penjual', ApiConstants.penjual);
      return mergedData.map((e) => Penjual.fromJson(e)).toList();
    } catch (e) {
      final mergedData = await syncService.getMergedOfflineData(
        'penjual',
        ApiConstants.penjual,
      );
      return mergedData.map((e) => Penjual.fromJson(e)).toList();
    }
  }

  Future<dynamic> storePenjual(Map<String, dynamic> data) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      final qId = await syncService.addToQueue(
        ApiConstants.penjual,
        'POST',
        data,
      );
      data['id'] = -1 * qId;
      return data;
    }
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.penjual,
        data: data,
      );
      return Penjual.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow; // Validation/client error — jangan queue
      }
      final qId = await syncService.addToQueue(
        ApiConstants.penjual,
        'POST',
        data,
      );
      data['id'] = -1 * qId;
      return data;
    }
  }

  Future<void> updatePenjual(int id, Map<String, dynamic> data) async {
    final url = '${ApiConstants.penjual}/$id';
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      await syncService.addToQueue(url, 'PUT', data);
      return;
    }
    try {
      await _apiClient.dio.put(url, data: data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(url, 'PUT', data);
    }
  }

  Future<void> deletePenjual(int id) async {
    final url = '${ApiConstants.penjual}/$id';
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      await syncService.addToQueue(url, 'DELETE', {});
      return;
    }
    try {
      await _apiClient.dio.delete(url);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(url, 'DELETE', {});
    }
  }

  Future<dynamic> getSupirPaginated({int page = 1}) async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.supir,
            queryParameters: {'page': page, 'per_page': 10},
          )
          .timeout(const Duration(seconds: 15));

      if (page == 1) {
        final List<dynamic> listData = _extractListData(response.data);
        await syncService.cacheData('supir', listData, clear: false);
        final pendingData = await syncService.getMergedOfflineData('supir', ApiConstants.supir);
        if (response.data is Map) {
          response.data['data'] = pendingData;
        }
      }

      return response.data;
    } catch (e) {
      try {
        final pendingData = await syncService.getMergedOfflineData(
          'supir', // <-- UBAH DARI 'penjual'
          ApiConstants.supir, // <-- UBAH DARI ApiConstants.penjual
        );
        return {
          'data': pendingData,
          'current_page': 1,
          'last_page': 1,
        };
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Supir>> getSupirs() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final mergedData = await syncService.getMergedOfflineData(
          'supir',
          ApiConstants.supir,
        );
        return mergedData.map((e) => Supir.fromJson(e)).toList();
      }

      final response = await _apiClient.dio
          .get(ApiConstants.supir, queryParameters: {'all': true})
          .timeout(const Duration(seconds: 5));
      final List<dynamic> data = _extractListData(response.data);

      await syncService.cacheData('supir', data);
      final mergedData = await syncService.getMergedOfflineData('supir', ApiConstants.supir);
      return mergedData.map((e) => Supir.fromJson(e)).toList();
    } catch (e) {
      final mergedData = await syncService.getMergedOfflineData(
        'supir',
        ApiConstants.supir,
      );
      return mergedData.map((e) => Supir.fromJson(e)).toList();
    }
  }

  Future<dynamic> storeSupir(Map<String, dynamic> data) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      await syncService.addToQueue(ApiConstants.supir, 'POST', data);
      return {'offline': true};
    }
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.supir,
        data: data,
      );
      return Supir.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(ApiConstants.supir, 'POST', data);
      return {'offline': true};
    }
  }

  Future<void> updateSupir(int id, Map<String, dynamic> data) async {
    final url = '${ApiConstants.supir}/$id';
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      await syncService.addToQueue(url, 'PUT', data);
      return;
    }
    try {
      await _apiClient.dio.put(url, data: data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(url, 'PUT', data);
    }
  }

  Future<void> deleteSupir(int id) async {
    final url = '${ApiConstants.supir}/$id';
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      await syncService.addToQueue(url, 'DELETE', {});
      return;
    }
    try {
      await _apiClient.dio.delete(url);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(url, 'DELETE', {});
    }
  }

  Future<dynamic> getPekerjaPaginated({int page = 1}) async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.pekerja,
            queryParameters: {'page': page, 'per_page': 10},
          )
          .timeout(const Duration(seconds: 15));
      if (page == 1) {
        final List<dynamic> listData = _extractListData(response.data);
        await syncService.cacheData('pekerja', listData, clear: false);
        final pendingData = await syncService.getMergedOfflineData('pekerja', ApiConstants.pekerja);
        if (response.data is Map) {
          response.data['data'] = pendingData;
        }
      }

      return response.data;
    } catch (e) {
      try {
        final pendingData = await syncService.getMergedOfflineData(
          'pekerja',
          ApiConstants.pekerja,
        );
        return {
          'data': pendingData,
          'current_page': 1,
          'last_page': 1,
        };
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Pekerja>> getPekerjas() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final mergedData = await syncService.getMergedOfflineData(
          'pekerja',
          ApiConstants.pekerja,
        );
        return mergedData.map((e) => Pekerja.fromJson(e)).toList();
      }

      final response = await _apiClient.dio
          .get(ApiConstants.pekerja, queryParameters: {'all': true})
          .timeout(const Duration(seconds: 5));
      final List<dynamic> data = _extractListData(response.data);

      await syncService.cacheData('pekerja', data);
      final mergedData = await syncService.getMergedOfflineData('pekerja', ApiConstants.pekerja);
      return mergedData.map((e) => Pekerja.fromJson(e)).toList();
    } catch (e) {
      final mergedData = await syncService.getMergedOfflineData(
        'pekerja',
        ApiConstants.pekerja,
      );
      return mergedData.map((e) => Pekerja.fromJson(e)).toList();
    }
  }

  Future<dynamic> storePekerja(Map<String, dynamic> data) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      await syncService.addToQueue(ApiConstants.pekerja, 'POST', data);
      return {'offline': true};
    }
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.pekerja,
        data: data,
      );
      return Pekerja.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(ApiConstants.pekerja, 'POST', data);
      return {'offline': true};
    }
  }

  Future<void> updatePekerja(int id, Map<String, dynamic> data) async {
    final url = '${ApiConstants.pekerja}/$id';
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      await syncService.addToQueue(url, 'PUT', data);
      return;
    }
    try {
      await _apiClient.dio.put(url, data: data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(url, 'PUT', data);
    }
  }

  Future<void> deletePekerja(int id) async {
    final url = '${ApiConstants.pekerja}/$id';
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.every((r) => r == ConnectivityResult.none)) {
      await syncService.addToQueue(url, 'DELETE', {});
      return;
    }
    try {
      await _apiClient.dio.delete(url);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(url, 'DELETE', {});
    }
  }

  Future<dynamic> getKendaraanPaginated({int page = 1}) async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.kendaraan,
            queryParameters: {'page': page, 'per_page': 10},
          )
          .timeout(const Duration(seconds: 15));

      if (page == 1) {
        final List<dynamic> listData = _extractListData(response.data);
        await syncService.cacheData('kendaraan', listData, clear: false);
        final pendingData = await syncService.getMergedOfflineData('kendaraan', ApiConstants.kendaraan);
        if (response.data is Map) {
          response.data['data'] = pendingData;
        }
      }

      return response.data;
    } catch (e) {
      try {
        final pendingData = await syncService.getMergedOfflineData(
          'kendaraan',
          ApiConstants.kendaraan,
        );
        return {
          'data': pendingData,
          'current_page': 1,
          'last_page': 1,
        };
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Kendaraan>> getKendaraans() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final mergedData = await syncService.getMergedOfflineData(
          'kendaraan',
          ApiConstants.kendaraan,
        );
        return mergedData.map((e) => Kendaraan.fromJson(e)).toList();
      }

      final response = await _apiClient.dio
          .get(ApiConstants.kendaraan, queryParameters: {'all': true})
          .timeout(const Duration(seconds: 5));
      final List<dynamic> data = _extractListData(response.data);

      await syncService.cacheData('kendaraan', data);
      final mergedData = await syncService.getMergedOfflineData('kendaraan', ApiConstants.kendaraan);
      return mergedData.map((e) => Kendaraan.fromJson(e)).toList();
    } catch (e) {
      final mergedData = await syncService.getMergedOfflineData(
        'kendaraan',
        ApiConstants.kendaraan,
      );
      return mergedData.map((e) => Kendaraan.fromJson(e)).toList();
    }
  }

  Future<dynamic> storeKendaraan(Map<String, dynamic> data) async {
    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      await syncService.addToQueue(ApiConstants.kendaraan, 'POST', data);
      return {'offline': true};
    }
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.kendaraan,
        data: data,
      );
      return Kendaraan.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(ApiConstants.kendaraan, 'POST', data);
      return {'offline': true};
    }
  }

  Future<dynamic> getOperasionalPaginated({int page = 1, String? tanggal}) async {
    try {
      final Map<String, dynamic> params = {'page': page, 'per_page': 10};
      if (tanggal != null) params['tanggal'] = tanggal;

      final response = await _apiClient.dio
          .get(
            ApiConstants.operasional,
            queryParameters: params,
          )
          .timeout(const Duration(seconds: 15));

      if (page == 1) {
        final List<dynamic> listData = _extractListData(response.data);
        
        await syncService.cacheData('operasional', listData, clear: (tanggal == null));
        
        String? whereClause;
        List<dynamic>? whereArgs;
        if (tanggal != null) {
          whereClause = 'tanggal LIKE ?';
          whereArgs = ['$tanggal%'];
        }
        
        final pendingData = await syncService.getMergedOfflineData(
          'operasional', 
          ApiConstants.operasional,
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'id DESC',
        );
        
        final filteredPending = pendingData.where((item) {
          if (tanggal != null) {
            final itemTanggal = item['tanggal']?.toString() ?? '';
            if (!itemTanggal.startsWith(tanggal)) return false;
          }
          return true;
        }).toList();

        if (response.data is Map) {
          response.data['data'] = filteredPending;
        }
      }

      return response.data;
    } catch (e) {
      try {
        String? whereClause;
        List<dynamic>? whereArgs;
        if (tanggal != null) {
          whereClause = 'tanggal LIKE ?';
          whereArgs = ['$tanggal%'];
        }
        final pendingData = await syncService.getMergedOfflineData(
          'operasional',
          ApiConstants.operasional,
          where: whereClause,
          whereArgs: whereArgs,
          orderBy: 'id DESC',
        );
        
        final filteredPending = pendingData.where((item) {
          if (tanggal != null) {
            final itemTanggal = item['tanggal']?.toString() ?? '';
            if (!itemTanggal.startsWith(tanggal)) return false;
          }
          return true;
        }).toList();

        return {
          'data': filteredPending,
          'current_page': 1,
          'last_page': 1,
        };
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<Operasional>> getOperasionals() async {
    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        final mergedData = await syncService.getMergedOfflineData('operasional', ApiConstants.operasional);
        return mergedData.map((e) => Operasional.fromJson(e)).toList();
      }
      
      final response = await _apiClient.dio.get(ApiConstants.operasional);
      final List<dynamic> data = _extractListData(response.data);
      await syncService.cacheData('operasional', data);
      final mergedData = await syncService.getMergedOfflineData('operasional', ApiConstants.operasional);
      return mergedData.map((e) => Operasional.fromJson(e)).toList();
    } catch (e) {
      final mergedData = await syncService.getMergedOfflineData('operasional', ApiConstants.operasional);
      return mergedData.map((e) => Operasional.fromJson(e)).toList();
    }
  }

  Future<Operasional> getOperasionalDetail(int id) async {
    final response = await _apiClient.dio.get(
      '${ApiConstants.operasional}/$id',
    );
    return Operasional.fromJson(response.data);
  }

  Future<dynamic> getUsersPaginated({int page = 1}) async {
    final response = await _apiClient.dio.get(
      '/users',
      queryParameters: {'page': page, 'per_page': 10},
    );
    return response.data;
  }

  Future<dynamic> getJurnalPaginated({
    int page = 1,
    String? startDate,
    String? endDate,
    String? jenisTransaksi,
  }) async {
    try {
      final Map<String, dynamic> params = {'page': page, 'per_page': 10};
      if (startDate != null) params['start_date'] = startDate;
      if (endDate != null) params['end_date'] = endDate;
      if (jenisTransaksi != null) params['jenis_transaksi'] = jenisTransaksi;

      final response = await _apiClient.dio
          .get(ApiConstants.jurnalKeuangan, queryParameters: params)
          .timeout(const Duration(seconds: 15));

      if (page == 1) {
        final cacheKey =
            'cache_jurnal_list_${startDate ?? ''}_${endDate ?? ''}_${jenisTransaksi ?? ''}';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(cacheKey, jsonEncode(response.data));
      }
      return response.data;
    } catch (e) {
      try {
        final cacheKey =
            'cache_jurnal_list_${startDate ?? ''}_${endDate ?? ''}_${jenisTransaksi ?? ''}';
        final prefs = await SharedPreferences.getInstance();
        final cachedStr = prefs.getString(cacheKey);

        final pendingData = await syncService.getMergedOfflineData(
          'jurnal_keuangan',
          ApiConstants.jurnalKeuangan,
        );
        // Filter pendingData based on type
        final filteredPending = pendingData.where((item) {
          if (jenisTransaksi != null &&
              item['jenis_transaksi'] != jenisTransaksi) {
            return false;
          }
          // Note: offline data dates might not match strictly without complex parsing, but usually it's fine for today
          return true;
        }).toList();

        if (cachedStr != null) {
          final cachedData = jsonDecode(cachedStr);
          if (filteredPending.isNotEmpty) {
            final List existingList = _extractListData(cachedData);
            final combinedList = [...filteredPending, ...existingList];
            if (cachedData is Map) {
              cachedData['data'] = combinedList;
            } else {
              return combinedList;
            }
          }
          return cachedData;
        } else if (filteredPending.isNotEmpty) {
          return {
            'data': filteredPending,
            'current_page': 1,
            'last_page': 1,
            'total': filteredPending.length,
          };
        }
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<JurnalKeuangan>> getJurnalKeuangan({
    String? startDate,
    String? endDate,
  }) async {
    final Map<String, dynamic> params = {};
    if (startDate != null) params['start_date'] = startDate;
    if (endDate != null) params['end_date'] = endDate;

    final response = await _apiClient.dio.get(
      ApiConstants.jurnalKeuangan,
      queryParameters: params,
    );
    final List<dynamic> data = _extractListData(response.data);
    return data.map((e) => JurnalKeuangan.fromJson(e)).toList();
  }

  Future<Penjual> getPenjualDetail(int id) async {
    final response = await _apiClient.dio.get('${ApiConstants.penjual}/$id');
    return Penjual.fromJson(response.data);
  }

  Future<Supir> getSupirDetail(int id) async {
    final response = await _apiClient.dio.get('${ApiConstants.supir}/$id');
    return Supir.fromJson(response.data);
  }

  Future<Pekerja> getPekerjaDetail(int id) async {
    final response = await _apiClient.dio.get('${ApiConstants.pekerja}/$id');
    return Pekerja.fromJson(response.data);
  }

  Future<dynamic> storeOperasional(Map<String, dynamic> data) async {
    if (data['client_uuid'] == null) {
      data['client_uuid'] = const Uuid().v4();
    }
    if (data['client_created_at'] == null) {
      data['client_created_at'] = DateTime.now().toUtc().toIso8601String();
    }

    final connectivity = await Connectivity().checkConnectivity();
    final isOffline = connectivity.every((r) => r == ConnectivityResult.none);
    if (isOffline) {
      await syncService.addToQueue(ApiConstants.operasional, 'POST', data);
      return {'offline': true};
    }
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.operasional,
        data: data,
      );
      return Operasional.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response != null &&
          (e.response!.statusCode ?? 0) >= 400 &&
          (e.response!.statusCode ?? 0) < 500) {
        rethrow;
      }
      await syncService.addToQueue(ApiConstants.operasional, 'POST', data);
      return {'offline': true};
    }
  }

  Future<Operasional> updateOperasional(
    int id,
    Map<String, dynamic> data,
  ) async {
    try {
      final response = await _apiClient.dio.put(
        '${ApiConstants.operasional}/$id',
        data: data,
      );
      return Operasional.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> deleteOperasional(int id) async {
    try {
      if (id < 0) {
        await syncService.deleteFromQueue(id.abs());
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        await syncService.addToQueue('${ApiConstants.operasional}/$id', 'DELETE', {});
        return;
      }

      await _apiClient.dio.delete('${ApiConstants.operasional}/$id');
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode != null) {
        if (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          rethrow;
        }
      }
      await syncService.addToQueue('${ApiConstants.operasional}/$id', 'DELETE', {});
    }
  }

  Future<Map<String, dynamic>> getAppSettings() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.appSettings);
      return response.data['data'] as Map<String, dynamic>;
    } catch (e) {
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateAppSettings(
    Map<String, dynamic> data,
  ) async {
    final response = await _apiClient.dio.post(
      ApiConstants.appSettings,
      data: data,
    );
    return response.data['data'] as Map<String, dynamic>;
  }

  Future<void> changePassword(
    String currentPassword,
    String newPassword,
    String confirmPassword,
  ) async {
    await _apiClient.dio.post(
      '/user/change-password',
      data: {
        'current_password': currentPassword,
        'password': newPassword,
        'password_confirmation': confirmPassword,
      },
    );
  }

  Future<void> resetUserPassword(
    int userId,
    String newPassword,
    String confirmPassword,
  ) async {
    await _apiClient.dio.post(
      '/user/$userId/reset-password',
      data: {'password': newPassword, 'password_confirmation': confirmPassword},
    );
  }
}
