import 'package:flutter/material.dart';
import '../models/tambah_saldo_model.dart';
import '../repositories/tambah_saldo_repository.dart';
import '../services/seen_state_service.dart';
import 'package:image_picker/image_picker.dart';

class TambahSaldoProvider with ChangeNotifier {
  final TambahSaldoRepository _repository;
  List<TambahSaldoModel> _requests = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasNewData = false;

  TambahSaldoProvider(this._repository);

  List<TambahSaldoModel> get requests => _requests;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get hasNewData => _hasNewData;
  int get totalCount => _requests.length;
  int get pendingCount => _requests.where((r) => r.status.toLowerCase() == 'pending').length;

  void clearData() {
    _requests.clear();
    _errorMessage = null;
    _hasNewData = false;
    notifyListeners();
  }

  Future<void> fetchRequests({String? status}) async {
    if (_requests.isEmpty) _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _requests = await _repository.getTambahSaldo(status: status).timeout(const Duration(seconds: 15));
      _isLoading = false;
      
      // Check for new pending data for admins/pimpinan
      final pendingRequests = _requests.where((r) => r.status.toLowerCase() == 'pending').toList();
      if (pendingRequests.isNotEmpty) {
        _hasNewData = !await SeenStateService.isSeen('tambah_saldo', pendingRequests.first.id.toString());
      } else {
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
    final pendingRequests = _requests.where((r) => r.status.toLowerCase() == 'pending').toList();
    if (pendingRequests.isNotEmpty) {
      await SeenStateService.markAsSeen('tambah_saldo', pendingRequests.first.id.toString());
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
    notifyListeners();

    try {
      await _repository.createTambahSaldo(
        nominal: nominal,
        tanggal: tanggal,
        keperluan: keterangan,
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

  Future<bool> approveRequest(int id, {XFile? buktiTransfer, String? catatan}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.approveTambahSaldo(id, buktiTransfer: buktiTransfer, catatan: catatan);
      await fetchRequests();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menyetujui: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }

  Future<bool> rejectRequest(int id, {required String catatan}) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.rejectTambahSaldo(id, catatan: catatan);
      await fetchRequests();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal menolak: ${e.toString()}';
      notifyListeners();
      return false;
    }
  }
}

