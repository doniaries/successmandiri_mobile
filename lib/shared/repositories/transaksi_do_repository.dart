import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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
      final response = await _apiClient.dio.get(ApiConstants.penjual);
      return _extractListData(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getSupirs() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.supir);
      return _extractListData(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<List<dynamic>> getKendaraans() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.kendaraan);
      return _extractListData(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> getTransaksiDo({String? tanggal, int page = 1, int perPage = 20}) async {
    try {
      final queryParams = <String, dynamic>{
        'page': page,
        'per_page': perPage,
      };
      if (tanggal != null) queryParams['tanggal'] = tanggal;

      final response = await _apiClient.dio.get(
        ApiConstants.transaksiDo,
        queryParameters: queryParams,
      );

      return response.data;
    } catch (e) {
      rethrow;
    }
  }

  Future<TransaksiDo> getTransaksiDoDetail(int id) async {
    try {
      final response = await _apiClient.dio.get('${ApiConstants.transaksiDo}/$id');
      return TransaksiDo.fromJson(response.data);
    } catch (e) {
      rethrow;
    }
  }

  Future<dynamic> createTransaksiDo({
    required String tanggal,
    required int penjualId,
    required int supirId,
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
    double? nominalTunai,
    bool isMismatch = false,
    XFile? buktiRekap,
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
      'nominal_tunai': nominalTunai,
      'is_mismatch': isMismatch ? 1 : 0,
    };

    try {
      final connectivity = await Connectivity().checkConnectivity();
      if (connectivity.contains(ConnectivityResult.none)) {
        await _syncService.addToQueue(ApiConstants.transaksiDo, 'POST', data);
        return {'offline': true};
      }

      if (buktiTransfer != null) {
        data['bukti_transfer'] = await MultipartFile.fromFile(
          buktiTransfer.path,
          filename: buktiTransfer.name,
        );
      }

      if (buktiRekap != null) {
        data['bukti_rekap'] = await MultipartFile.fromFile(
          buktiRekap.path,
          filename: buktiRekap.name,
        );
      }

      final formData = FormData.fromMap(data);

      final response = await _apiClient.dio.post(
        ApiConstants.transaksiDo,
        data: formData,
      );

      return TransaksiDo.fromJson(response.data);
    } catch (e) {
      // Offline queue doesn't easily support files, fallback to normal data for queue
      await _syncService.addToQueue(ApiConstants.transaksiDo, 'POST', data);
      return {'offline': true};
    }
  }
}

