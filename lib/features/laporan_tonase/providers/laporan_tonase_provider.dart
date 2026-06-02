import 'package:flutter/foundation.dart';
import '../../../core/network/api_client.dart';
import '../../../models/laporan_tonase.dart';

class LaporanTonaseProvider with ChangeNotifier {
  final ApiClient _apiClient;

  LaporanTonaseProvider(this._apiClient);

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _error;
  String? get error => _error;

  LaporanTonaseResponse? _data;
  LaporanTonaseResponse? get data => _data;

  Future<void> fetchLaporan({int? month, int? year}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final m = month ?? DateTime.now().month;
      final y = year ?? DateTime.now().year;

      final response = await _apiClient.dio.get(
        '/laporan/tonase',
        queryParameters: {
          'month': m,
          'year': y,
        },
      );

      if (response.data['success'] == true) {
        _data = LaporanTonaseResponse.fromJson(response.data['data']);
      } else {
        _error = response.data['message'] ?? 'Failed to fetch laporan';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
