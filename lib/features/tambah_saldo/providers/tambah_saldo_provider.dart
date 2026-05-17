import 'package:flutter/material.dart';
import 'package:sawitappmobile/features/tambah_saldo/models/tambah_saldo_model.dart';
import 'package:sawitappmobile/shared/repositories/tambah_saldo_repository.dart';

class TambahSaldoProvider with ChangeNotifier {
  final TambahSaldoRepository _repository;
  List<TambahSaldoModel> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;

  TambahSaldoProvider(this._repository);

  List<TambahSaldoModel> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get totalCount => _requests.length;

  void clearData() {
    _requests.clear();
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> fetchRequests() async {
    if (_requests.isEmpty) _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _requests = await _repository.getTambahSaldo().timeout(const Duration(seconds: 15));
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data tambah saldo: $e';
      notifyListeners();
    }
  }

  Future<bool> createRequest({
    required double nominal,
    required String tanggal,
    String? keterangan,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final result = await _repository.createTambahSaldo(
        nominal: nominal,
        tanggal: tanggal,
        keterangan: keterangan,
      );
      
      if (result is Map && result['offline'] == true) {
        _errorMessage = 'Koneksi bermasalah. Permintaan saldo disimpan di antrean offline.';
      } else {
        await fetchRequests(); // Refresh list
      }
      
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal membuat permintaan saldo: ${e.toString()}';
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
