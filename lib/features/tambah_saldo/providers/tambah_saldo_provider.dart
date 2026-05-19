import 'package:flutter/material.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/shared/repositories/tambah_saldo_repository.dart';
import 'package:sawitappmobile/core/services/seen_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TambahSaldoProvider with ChangeNotifier {
  final TambahSaldoRepository _repository;
  List<TambahSaldoModel> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasNewData = false;
  int _unreadCount = 0;

  TambahSaldoProvider(this._repository);

  List<TambahSaldoModel> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasNewData => _hasNewData;
  int get unreadCount => _unreadCount;
  int get totalCount => _requests.length;

  void clearData() {
    _requests.clear();
    _errorMessage = null;
    _hasNewData = false;
    _unreadCount = 0;
    notifyListeners();
  }

  Future<void> fetchRequests() async {
    if (_requests.isEmpty) _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _requests = await _repository.getTambahSaldo().timeout(const Duration(seconds: 15));
      _isLoading = false;
      
      if (_requests.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final lastSeenId = int.tryParse(prefs.getString('seen_state_tambah_saldo') ?? '0') ?? 0;
        _unreadCount = _requests.where((r) => r.id > lastSeenId).length;
        _hasNewData = _unreadCount > 0;
      } else {
        _unreadCount = 0;
        _hasNewData = false;
      }
      
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data tambah saldo: $e';
      notifyListeners();
    }
  }

  Future<void> markAsSeen() async {
    if (_requests.isNotEmpty) {
      await SeenStateService.markAsSeen('tambah_saldo', _requests.first.id.toString());
      _unreadCount = 0;
      _hasNewData = false;
      notifyListeners();
    }
  }

  Future<bool> createRequest({
    required double nominal,
    required String tanggal,
    String? keterangan,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.createTambahSaldo(
        nominal: nominal,
        tanggal: tanggal,
        keterangan: keterangan,
      );

      if (result is Map && result['offline'] == true) {
        // Benar-benar offline → tandai dengan pesan offline
        _errorMessage = 'offline';
      } else {
        _errorMessage = null;
      }
      await fetchRequests();

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      // Error dari server — tampilkan pesan error nyata, bukan offline
      final msg = e.toString().replaceAll('Exception: ', '');
      _errorMessage = msg.contains('DioException')
          ? 'Gagal terhubung ke server. Periksa koneksi Anda.'
          : msg;
      notifyListeners();
      return false;
    }
  }


  Future<bool> updateRequest(int id, {
    required double nominal,
    required String tanggal,
    required String keterangan,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.updateTambahSaldo(
        id,
        nominal: nominal,
        tanggal: tanggal,
        keterangan: keterangan,
      );
      await fetchRequests();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memperbarui saldo: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteRequest(int id) async {
    // Optimistic UI: remove item locally first
    final index = _requests.indexWhere((r) => r.id == id);
    TambahSaldoModel? backupRequest;
    if (index != -1) {
      backupRequest = _requests[index];
      _requests.removeAt(index);
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners(); // Rebuild UI instantly without the deleted item

    try {
      await _repository.deleteTambahSaldo(id);
      await fetchRequests();
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      // Revert if request failed
      if (index != -1 && backupRequest != null) {
        _requests.insert(index, backupRequest);
      }
      _isLoading = false;
      _errorMessage = 'Gagal menghapus saldo: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
