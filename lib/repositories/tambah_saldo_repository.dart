import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/tambah_saldo_model.dart';
import '../services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

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
        queryParameters: status != null ? {'status': status} : null,
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
    String? keperluan,
  }) async {
    final Map<String, dynamic> data = {
      'nominal': nominal,
      'tanggal_pengajuan': tanggal,
      'keperluan': keperluan,
    };

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        await _syncService.addToQueue(ApiConstants.tambahSaldo, 'POST', data);
        return {'offline': true};
      }

      final response = await _apiClient.dio.post(
        ApiConstants.tambahSaldo,
        data: data,
      );

      return TambahSaldoModel.fromJson(response.data);
    } catch (e) {
      await _syncService.addToQueue(ApiConstants.tambahSaldo, 'POST', data);
      return {'offline': true};
    }
  }

  Future<dynamic> approveTambahSaldo(int id, {XFile? buktiTransfer, String? catatan}) async {
    dynamic uploadData;
    
    if (buktiTransfer != null) {
      uploadData = FormData.fromMap({
        'bukti_transfer': await MultipartFile.fromFile(
          buktiTransfer.path,
          filename: buktiTransfer.name,
        ),
        'catatan_pimpinan': catatan,
      });
    } else {
      uploadData = {
        'catatan_pimpinan': catatan,
      };
    }

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id/approve', 'POST', {
          'catatan_pimpinan': catatan,
          'offline_file': buktiTransfer?.path,
        });
        return {'offline': true};
      }

      final response = await _apiClient.dio.post(
        '${ApiConstants.tambahSaldo}/$id/approve',
        data: uploadData,
      );

      return TambahSaldoModel.fromJson(response.data);
    } catch (e) {
      await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id/approve', 'POST', {
        'catatan_pimpinan': catatan,
      });
      return {'offline': true};
    }
  }

  Future<dynamic> rejectTambahSaldo(int id, {required String catatan}) async {
    final Map<String, dynamic> data = {
      'catatan_pimpinan': catatan,
    };

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id/reject', 'POST', data);
        return {'offline': true};
      }

      final response = await _apiClient.dio.post(
        '${ApiConstants.tambahSaldo}/$id/reject',
        data: data,
      );

      return TambahSaldoModel.fromJson(response.data);
    } catch (e) {
      await _syncService.addToQueue('${ApiConstants.tambahSaldo}/$id/reject', 'POST', data);
      return {'offline': true};
    }
  }
}

