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
      await _repository.createTambahSaldo(
        nominal: nominal,
        tanggal: tanggal,
        keterangan: keterangan,
      );
      await fetchRequests(); // Refresh list
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal membuat permintaan saldo: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}
