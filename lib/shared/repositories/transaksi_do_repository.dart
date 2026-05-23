import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
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
          // ✅ Tambahkan per_page: 9999 di sini
          .get(
            ApiConstants.penjual,
            queryParameters: {'all': true, 'per_page': 9999},
          )
          .timeout(const Duration(seconds: 5));
      return _extractListData(response.data);
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
          // ✅ Tambahkan per_page: 9999 di sini
          .get(
            ApiConstants.supir,
            queryParameters: {'all': true, 'per_page': 9999},
          )
          .timeout(const Duration(seconds: 5));
      return _extractListData(response.data);
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
          // ✅ Tambahkan per_page: 9999 di sini
          .get(
            ApiConstants.kendaraan,
            queryParameters: {'all': true, 'per_page': 9999},
          )
          .timeout(const Duration(seconds: 5));
      return _extractListData(response.data);
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

  Future<dynamic> getTransaksiDo({
    String? tanggal,
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final queryParams = <String, dynamic>{'page': page, 'per_page': perPage};
      if (tanggal != null) queryParams['tanggal'] = tanggal;

      final response = await _apiClient.dio
          .get(ApiConstants.transaksiDo, queryParameters: queryParams)
          .timeout(const Duration(seconds: 15));

      final data = _extractListData(response.data);
      if (page == 1) {
        await _syncService.cacheData('transaksi_do', data);
        final pendingData = await _syncService.getMergedOfflineData('transaksi_do', ApiConstants.transaksiDo);
        
        final filteredPending = pendingData.where((item) {
          if (tanggal != null && item['tanggal'] != tanggal) return false;
          return true;
        }).toList();
        
        if (response.data is Map) {
          response.data['data'] = filteredPending;
        }
      }

      return response.data;
    } catch (e) {
      try {
        final pendingData = await _syncService.getMergedOfflineData(
          'transaksi_do',
          ApiConstants.transaksiDo,
        );

        final filteredPending = pendingData.where((item) {
          if (tanggal != null && item['tanggal'] != tanggal) return false;
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
      );

      return response.data['data'] ?? 'OTOMATIS (SISTEM)';
    } catch (e) {
      final dateStr = tanggal != null
          ? tanggal.replaceAll('-', '')
          : DateFormat('yyyyMMdd').format(DateTime.now());

      try {
        final pendingData = await _syncService.getMergedOfflineData(
          'transaksi_do',
          ApiConstants.transaksiDo,
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
        await _syncService.addToQueue('${ApiConstants.transaksiDo}/$id', 'PUT', data);
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
        final response = await _apiClient.dio.post(
          '${ApiConstants.transaksiDo}/$id',
          data: formData,
        ).timeout(const Duration(seconds: 15));
        return response.data;
      } else {
        final response = await _apiClient.dio.put(
          '${ApiConstants.transaksiDo}/$id',
          data: data,
        ).timeout(const Duration(seconds: 15));
        return response.data;
      }
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode != null) {
        if (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          rethrow;
        }
      }
      await _syncService.addToQueue('${ApiConstants.transaksiDo}/$id', 'PUT', data);
      return {'offline': true, 'id': id};
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        await _syncService.addToQueue('${ApiConstants.transaksiDo}/$id', 'PUT', data);
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
        await _syncService.addToQueue('${ApiConstants.transaksiDo}/$id', 'DELETE', {});
        return;
      }

      await _apiClient.dio.delete('${ApiConstants.transaksiDo}/$id');
    } on DioException catch (e) {
      if (e.response != null && e.response!.statusCode != null) {
        if (e.response!.statusCode! >= 400 && e.response!.statusCode! < 500) {
          rethrow;
        }
      }
      await _syncService.addToQueue('${ApiConstants.transaksiDo}/$id', 'DELETE', {});
    }
  }
}
