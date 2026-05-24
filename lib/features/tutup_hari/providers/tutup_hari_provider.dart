import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/features/tutup_hari/models/tutup_hari_model.dart';

class TutupHariProvider with ChangeNotifier {
  final ApiClient _apiClient = ApiClient();
  
  bool _isLoading = false;
  String _errorMessage = '';
  TutupHariModel? _closingData;
  bool _isClosed = false;

  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  TutupHariModel? get closingData => _closingData;
  bool get isClosed => _isClosed;

  Future<int?> _getPerusahaanId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('selected_perusahaan_id');
  }

  Future<void> checkStatus(String tanggal) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final perusahaanId = await _getPerusahaanId();
      if (perusahaanId == null) throw Exception("Perusahaan belum dipilih.");

      final response = await _apiClient.dio.get(
        '/tutup-hari/status',
        queryParameters: {'tanggal': tanggal},
        options: Options(headers: {'X-Perusahaan-ID': perusahaanId}),
      );

      if (response.data['success']) {
        _isClosed = response.data['data']['is_closed'];
      } else {
        _errorMessage = response.data['message'] ?? 'Gagal cek status tutup hari.';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan.';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<bool> performClosing({
    required String tanggal,
    required double saldoAkhirFisik,
    String? catatan,
  }) async {
    _isLoading = true;
    _errorMessage = '';
    notifyListeners();

    try {
      final perusahaanId = await _getPerusahaanId();
      if (perusahaanId == null) throw Exception("Perusahaan belum dipilih.");

      final response = await _apiClient.dio.post(
        '/tutup-hari',
        data: {
          'tanggal': tanggal,
          'saldo_akhir_fisik': saldoAkhirFisik,
          'catatan': catatan,
        },
        options: Options(headers: {'X-Perusahaan-ID': perusahaanId}),
      );

      if (response.data['success']) {
        _closingData = TutupHariModel.fromJson(response.data['data']);
        _isClosed = true;
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _errorMessage = response.data['message'] ?? 'Gagal melakukan tutup hari.';
      }
    } on DioException catch (e) {
      _errorMessage = e.response?.data['message'] ?? 'Terjadi kesalahan jaringan.';
    } catch (e) {
      _errorMessage = e.toString();
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }
}
