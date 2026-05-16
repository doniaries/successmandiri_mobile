import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:uuid/uuid.dart';
import 'dart:developer' as dev;

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
    String? nomorDo,
  }) async {
    final String clientUuid = const Uuid().v4();
    final Map<String, dynamic> data = {
      'tanggal': tanggal,
      'nomor_do': nomorDo,
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
        final response = await _apiClient.dio.post(
          ApiConstants.transaksiDo,
          data: formData,
        );
        return response.data;
      } else {
        // Jika tidak ada file, kirim sebagai JSON biasa (Map)
        // Ini lebih stabil di Web dan konsisten dengan ResourceRepository
        final response = await _apiClient.dio.post(
          ApiConstants.transaksiDo,
          data: postData,
        );
        return response.data;
      }
    } on DioException catch (e) {
      dev.log('DioError creating TransaksiDo: ${e.response?.statusCode} - ${e.message}');
      
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
      return 'OTOMATIS (SISTEM)';
    }
  }
}

