import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:sawitappmobile/core/services/database_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as dev;
import 'dart:convert';
import 'dart:math';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransaksiDoRepository {
  final ApiClient _apiClient;
  final SyncService _syncService = SyncService();

  TransaksiDoRepository(this._apiClient);

  List<dynamic> _extractListData(dynamic responseData) {
    if (responseData is Map) {
      return responseData['data'] ?? [];
    } else if (responseData is List) {
      return responseData;
    }
    return [];
  }

  Future<List<dynamic>> getPenjuals() async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.penjual,
            queryParameters: {'all': true, 'per_page': 9999},
          )
          .timeout(const Duration(seconds: 30));
          
      final serverData = _extractListData(response.data);
      final List<dynamic>? activeIds = response.data is Map ? response.data['active_ids'] : null;
      await _syncService.cacheDataIncremental('penjual', serverData, activeIds);
      
      final pendingQueue = await _syncService.getOfflineQueueForEndpoint(ApiConstants.penjual);
      final pendingItems = pendingQueue.map((item) {
        final data = Map<String, dynamic>.from(item['data'] as Map);
        data['id'] = item['id'];
        return data;
      }).toList();
      
      return [...pendingItems, ...serverData];
    } catch (e) {
      try {
        final mergedData = await _syncService.getMergedOfflineData(
          'penjual',
          ApiConstants.penjual,
        );
        return mergedData.isNotEmpty ? mergedData : [];
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<dynamic>> getSupirs() async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.supir,
            queryParameters: {'all': true, 'per_page': 9999},
          )
          .timeout(const Duration(seconds: 30));
          
      final serverData = _extractListData(response.data);
      final List<dynamic>? activeIds = response.data is Map ? response.data['active_ids'] : null;
      await _syncService.cacheDataIncremental('supir', serverData, activeIds);
      
      final pendingQueue = await _syncService.getOfflineQueueForEndpoint(ApiConstants.supir);
      final pendingItems = pendingQueue.map((item) {
        final data = Map<String, dynamic>.from(item['data'] as Map);
        data['id'] = item['id'];
        return data;
      }).toList();
      
      return [...pendingItems, ...serverData];
    } catch (e) {
      try {
        final mergedData = await _syncService.getMergedOfflineData(
          'supir',
          ApiConstants.supir,
        );
        return mergedData.isNotEmpty ? mergedData : [];
      } catch (_) {}
      rethrow;
    }
  }

  Future<List<dynamic>> getKendaraans() async {
    try {
      final response = await _apiClient.dio
          .get(
            ApiConstants.kendaraan,
            queryParameters: {'all': true, 'per_page': 9999},
          )
          .timeout(const Duration(seconds: 30));
          
      final serverData = _extractListData(response.data);
      final List<dynamic>? activeIds = response.data is Map ? response.data['active_ids'] : null;
      await _syncService.cacheDataIncremental('kendaraan', serverData, activeIds);
      
      final pendingQueue = await _syncService.getOfflineQueueForEndpoint(ApiConstants.kendaraan);
      final pendingItems = pendingQueue.map((item) {
        final data = Map<String, dynamic>.from(item['data'] as Map);
        data['id'] = item['id'];
        return data;
      }).toList();
      
      return [...pendingItems, ...serverData];
    } catch (e) {
      try {
        final mergedData = await _syncService.getMergedOfflineData(
          'kendaraan',
          ApiConstants.kendaraan,
        );
        return mergedData.isNotEmpty ? mergedData : [];
      } catch (_) {}
      rethrow;
    }
  }
  Future<List<dynamic>> getLocalPenjuals() async {
    try {
      final mergedData = await _syncService.getMergedOfflineData('penjual', ApiConstants.penjual);
      return mergedData.isNotEmpty ? mergedData : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getLocalSupirs() async {
    try {
      final mergedData = await _syncService.getMergedOfflineData('supir', ApiConstants.supir);
      return mergedData.isNotEmpty ? mergedData : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getLocalKendaraans() async {
    try {
      final mergedData = await _syncService.getMergedOfflineData('kendaraan', ApiConstants.kendaraan);
      return mergedData.isNotEmpty ? mergedData : [];
    } catch (_) {
      return [];
    }
  }

  Future<List<dynamic>> getLocalTransaksiDo({String? tanggal}) async {
    try {
      String? whereClause;
      List<dynamic>? whereArgs;
      if (tanggal != null) {
        whereClause = 'tanggal LIKE ?';
        whereArgs = ['$tanggal%'];
      }

      final pendingData = await _syncService.getMergedOfflineData(
        'transaksi_do',
        ApiConstants.transaksiDo,
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

      return filteredPending;
    } catch (e) {
      return [];
    }
  }

  Future<dynamic> getTransaksiDo({
    String? tanggal,
    int page = 1,
    int perPage = 9999,
    bool forceOfflineFallback = false,
  }) async {
    try {
      if (forceOfflineFallback) throw Exception('Force Offline Fallback');
      final queryParams = <String, dynamic>{'page': page, 'per_page': perPage, 'all': true};
      if (tanggal != null) queryParams['tanggal'] = tanggal;

      final response = await _apiClient.dio
          .get(ApiConstants.transaksiDo, queryParameters: queryParams)
          .timeout(const Duration(seconds: 15));

      final data = _extractListData(response.data);
      
      // Cache data for all pages, but only clear table on page 1 without date filter
      await _syncService.cacheData('transaksi_do', data, clear: (page == 1 && tanggal == null));

      if (page == 1) {
        // Ambil data offline MURNI (yang belum di-sync / belum ada ID server positif)
        final offlineQueue = await _syncService.getOfflineQueueForEndpoint(
          ApiConstants.transaksiDo,
        );

        // Filter offline queue berdasarkan tanggal yang dipilih
        final filteredOffline = offlineQueue
            .where((item) {
              final itemData = item['data'] as Map<String, dynamic>;
              if (tanggal != null) {
                final itemTanggal = itemData['tanggal']?.toString() ?? '';
                if (!itemTanggal.startsWith(tanggal)) return false;
              }
              return true;
            })
            .map((item) {
              final mapped = Map<String, dynamic>.from(item['data']);
              mapped['id'] = item['id']; // pakai id negatif
              return mapped;
            })
            .toList();

        if (response.data is Map) {
          // Gabungkan data offline (di atas) dengan data online dari server
          final original = response.data as Map<String, dynamic>;
          final online = data;
          final merged = [...filteredOffline, ...online];
          original['data'] = merged;

          // Perbaiki metadata total jika perlu (tambahkan jumlah item offline)
          try {
            final rawTotal = original['total'];
            int serverTotal = rawTotal is int
                ? rawTotal
                : int.tryParse(rawTotal?.toString() ?? '') ?? online.length;
            original['total'] = serverTotal + filteredOffline.length;
          } catch (_) {
            original['total'] = merged.length;
          }

          // Update from/to/last_page jika ada informasi per_page
          try {
            final perPageVal = original['per_page'] is int
                ? original['per_page'] as int
                : int.tryParse(original['per_page']?.toString() ?? '') ??
                      perPage;
            original['from'] = 1;
            original['to'] = merged.length < perPageVal
                ? merged.length
                : perPageVal;
            final totalVal =
                int.tryParse(original['total']?.toString() ?? '') ??
                merged.length;
            original['last_page'] = (totalVal / perPageVal).ceil();
          } catch (_) {}
        } else if (response.data is List) {
          response.data = [...filteredOffline, ...data];
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

        final pendingData = await _syncService.getMergedOfflineData(
          'transaksi_do',
          ApiConstants.transaksiDo,
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
          'total': filteredPending.length,
        };
      } catch (_) {}
      rethrow;
    }
  }

  Future<TransaksiDo> getTransaksiDoDetail(int id) async {
    try {
      final response = await _apiClient.dio.get(
        '${ApiConstants.transaksiDo}/$id',
      );
      return TransaksiDo.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createTransaksiDo({
    required String tanggal,
    required int penjualId,
    String? penjualNama,
    int? supirId,
    String? supirNama,
    String? noPolisi,
    required double tonase,
    required double hargaSatuan,
    double? upahBongkar,
    double? biayaLain,
    double? pembayaranHutang,
    String? keteranganBiayaLain,
    required String caraBayar,
    XFile? buktiTransfer,
    String? keteranganPembayaran,
    String? nomorDo,
  }) async {
    final String clientUuid = const Uuid().v4();
    final Map<String, dynamic> data = {
      'tanggal': tanggal,
      'nomor_do': nomorDo,
      'penjual_id': penjualId,
      'penjual_nama': penjualNama,
      'supir_id': supirId,
      'supir_nama': supirNama,
      'no_polisi': noPolisi,
      'tonase': tonase,
      'harga_satuan': hargaSatuan,
      'upah_bongkar': upahBongkar,
      'biaya_lain': biayaLain,
      'pembayaran_hutang': pembayaranHutang,
      'keterangan_biaya_lain': keteranganBiayaLain,
      'cara_bayar': caraBayar,
      'keterangan_pembayaran': keteranganPembayaran,
      'client_uuid': clientUuid,
    };

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        dev.log('Offline: Adding TransaksiDo to queue...');
        final clientUuid = const Uuid().v4();
        data['client_uuid'] = clientUuid;
        await _syncService.addToQueue(ApiConstants.transaksiDo, 'POST', data);
        return {'offline': true, 'client_uuid': clientUuid};
      }

      final Map<String, dynamic> postData = Map.from(data);
      if (buktiTransfer != null) {
        if (kIsWeb) {
          postData['bukti_transfer'] = MultipartFile.fromBytes(
            await buktiTransfer.readAsBytes(),
            filename: buktiTransfer.name,
          );
        } else {
          postData['bukti_transfer'] = await MultipartFile.fromFile(
            buktiTransfer.path,
            filename: buktiTransfer.name,
          );
        }

        final formData = FormData.fromMap(postData);
        final response = await _apiClient.dio
            .post(ApiConstants.transaksiDo, data: formData)
            .timeout(const Duration(seconds: 15));
        return response.data;
      } else {
        // Jika tidak ada file, kirim sebagai JSON biasa (Map)
        // Ini lebih stabil di Web dan konsisten dengan ResourceRepository
        final response = await _apiClient.dio
            .post(ApiConstants.transaksiDo, data: postData)
            .timeout(const Duration(seconds: 15));
        return response.data;
      }
    } on DioException catch (e) {
      dev.log(
        'DioError creating TransaksiDo: ${e.response?.statusCode} - ${e.message}',
      );

      // Jika error validasi (422) atau error client (400-499), JANGAN diantrekan.
      // Lempar kembali agar UI bisa menampilkan pesan error yang jelas.
      if (e.response != null && e.response!.statusCode != null) {
        if (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          rethrow;
        }
      }

      // Jika error koneksi atau server error (500+), baru diantrekan ke offline queue.
      await _syncService.addToQueue(ApiConstants.transaksiDo, 'POST', data);
      return {'offline': true, 'client_uuid': clientUuid};
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        dev.log('Timeout creating TransaksiDo, queueing offline...');
        await _syncService.addToQueue(ApiConstants.transaksiDo, 'POST', data);
        return {'offline': true, 'client_uuid': clientUuid};
      }
      dev.log('Unexpected Error creating TransaksiDo: $e');
      rethrow;
    }
  }

  Future<String> getNextDoNumber({String? tanggal}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (tanggal != null) queryParams['tanggal'] = tanggal;

      final response = await _apiClient.dio.get(
        ApiConstants.generateDoNumber,
        queryParameters: queryParams,
      ).timeout(const Duration(seconds: 3));

      return response.data['data'] ?? 'OTOMATIS (SISTEM)';
    } catch (e) {
      final dateStr = tanggal != null
          ? tanggal.replaceAll('-', '')
          : DateFormat('yyyyMMdd').format(DateTime.now());

      try {
        final queryTanggal = tanggal ?? DateFormat('yyyy-MM-dd').format(DateTime.now());
        
        final pendingData = await _syncService.getMergedOfflineData(
          'transaksi_do',
          ApiConstants.transaksiDo,
          where: 'tanggal LIKE ?',
          whereArgs: ['$queryTanggal%'],
        );

        int maxSeq = 0;
        for (var item in pendingData) {
          String? noDo = item['nomor'] ?? item['nomor_do'];
          if (noDo != null && noDo.contains(dateStr)) {
            final regex = RegExp(r'DO-(?:P\d+-)?' + dateStr + r'-(\d+)');
            final match = regex.firstMatch(noDo);
            if (match != null) {
              final seq = int.parse(match.group(1)!);
              if (seq > maxSeq) {
                maxSeq = seq;
              }
            }
          }
        }

        final prefs = await SharedPreferences.getInstance();
        final userStr = prefs.getString('cached_user');
        String companyPrefix = '';
        if (userStr != null) {
          try {
            final userData = jsonDecode(userStr);
            if (userData['perusahaan_id'] != null) {
              companyPrefix = 'P${userData['perusahaan_id']}-';
            }
          } catch (_) {}
        }

        int nextSeq = maxSeq + 1;
        final seqStr = nextSeq.toString().padLeft(4, '0');

        return 'DO-$companyPrefix$dateStr-$seqStr';
      } catch (_) {
        final randomStr = (1000 + Random().nextInt(9000)).toString();
        return 'DO-PENDING-$dateStr-$randomStr';
      }
    }
  }

  Future<dynamic> updateTransaksiDo(
    int id, {
    required String tanggal,
    required int penjualId,
    int? supirId,
    String? noPolisi,
    required double tonase,
    required double hargaSatuan,
    double? upahBongkar,
    double? biayaLain,
    double? pembayaranHutang,
    String? keteranganBiayaLain,
    required String caraBayar,
    dynamic buktiTransfer,
    String? keteranganPembayaran,
  }) async {
    final Map<String, dynamic> data = {
      'tanggal': tanggal,
      'penjual_id': penjualId,
      'supir_id': supirId,
      'no_polisi': noPolisi,
      'tonase': tonase,
      'harga_satuan': hargaSatuan,
      'upah_bongkar': upahBongkar,
      'biaya_lain': biayaLain,
      'pembayaran_hutang': pembayaranHutang,
      'keterangan_biaya_lain': keteranganBiayaLain,
      'cara_bayar': caraBayar,
      'keterangan_pembayaran': keteranganPembayaran,
    };

    if (buktiTransfer is String) {
      data['bukti_transfer'] = buktiTransfer;
    } else if (buktiTransfer == null) {
      data['bukti_transfer'] = '';
    }

    if (id < 0) {
      await _syncService.updateQueueData(id.abs(), data);
      return {'offline': true, 'id': id};
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        await _syncService.addToQueue(
          '${ApiConstants.transaksiDo}/$id',
          'PUT',
          data,
        );
        return {'offline': true, 'id': id};
      }

      if (buktiTransfer is XFile) {
        final Map<String, dynamic> postData = Map.from(data);
        if (kIsWeb) {
          postData['bukti_transfer'] = MultipartFile.fromBytes(
            await buktiTransfer.readAsBytes(),
            filename: buktiTransfer.name,
          );
        } else {
          postData['bukti_transfer'] = await MultipartFile.fromFile(
            buktiTransfer.path,
            filename: buktiTransfer.name,
          );
        }

        postData['_method'] = 'PUT';
        final formData = FormData.fromMap(postData);
        final response = await _apiClient.dio
            .post('${ApiConstants.transaksiDo}/$id', data: formData)
            .timeout(const Duration(seconds: 15));
        return response.data;
      } else {
        final response = await _apiClient.dio
            .put('${ApiConstants.transaksiDo}/$id', data: data)
            .timeout(const Duration(seconds: 15));
        return response.data;
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode != null) {
        if (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          rethrow;
        }
      }
      await _syncService.addToQueue(
        '${ApiConstants.transaksiDo}/$id',
        'PUT',
        data,
      );
      return {'offline': true, 'id': id};
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        await _syncService.addToQueue(
          '${ApiConstants.transaksiDo}/$id',
          'PUT',
          data,
        );
        return {'offline': true, 'id': id};
      }
      rethrow;
    }
  }

  Future<void> deleteTransaksiDo(int id) async {
    try {
      if (id < 0) {
        await _syncService.deleteFromQueue(id.abs());
        return;
      }

      final connectivity = await Connectivity().checkConnectivity();
      final isOffline = connectivity.every((r) => r == ConnectivityResult.none);

      if (isOffline) {
        await _syncService.addToQueue(
          '${ApiConstants.transaksiDo}/$id',
          'DELETE',
          {},
        );
        try { await DatabaseService().delete('transaksi_do', where: 'id = ?', whereArgs: [id]); } catch (_) {}
        return;
      }

      await _apiClient.dio.delete('${ApiConstants.transaksiDo}/$id');
      try { await DatabaseService().delete('transaksi_do', where: 'id = ?', whereArgs: [id]); } catch (_) {}
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode != null) {
        if (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          rethrow;
        }
      }
      await _syncService.addToQueue(
        '${ApiConstants.transaksiDo}/$id',
        'DELETE',
        {},
      );
    }
  }

  Future<String?> getPrintUrl(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.transaksiDo}/$id/print-url');
      if (response.data['success'] == true) {
        return response.data['data']['url'];
      }
      return null;
    } catch (e) {
      dev.log('Error getting print URL: $e');
      return null;
    }
  }
}
