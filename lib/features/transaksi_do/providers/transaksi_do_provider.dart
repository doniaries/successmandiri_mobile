import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:sawitappmobile/features/transaksi_do/models/transaksi_do_model.dart';
import 'package:sawitappmobile/shared/repositories/transaksi_do_repository.dart';
import 'package:sawitappmobile/core/services/seen_state_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TransaksiDoProvider with ChangeNotifier {
  final TransaksiDoRepository _repository;
  List<TransaksiDo> _transactions = [];
  List<dynamic> _penjuals = [];
  List<dynamic> _supirs = [];
  List<dynamic> _kendaraans = [];
  bool _isLoading = false;
  String? _errorMessage;
  bool _hasNewData = false;
  bool _hasMore = true;
  final bool _isFetchingMore = false;
  bool _isSaving = false;
  bool _isRefreshing = false;
  String? _currentTanggal;

  int _unreadCount = 0;

  TransaksiDoProvider(this._repository);

  List<TransaksiDo> get transactions => _transactions;
  List<dynamic> get penjuals => _penjuals;
  List<dynamic> get supirs => _supirs;
  List<dynamic> get kendaraans => _kendaraans;
  bool get isLoading => _isLoading;
  bool get isFetchingMore => _isFetchingMore;
  bool get isRefreshing => _isRefreshing;
  bool get isSaving => _isSaving;
  bool get hasMore => _hasMore;
  String? get errorMessage => _errorMessage;
  bool get hasNewData => _hasNewData;
  int get unreadCount => _unreadCount;
  int get totalTransactions => _transactions.length;

  String? get currentTanggal => _currentTanggal;

  void clearData() {
    _transactions.clear();
    _penjuals.clear();
    _supirs.clear();
    _kendaraans.clear();
    _errorMessage = null;
    _hasNewData = false;
    _unreadCount = 0;
    _hasMore = true;
    notifyListeners();
  }

  Future<void> fetchTransactions({String? tanggal}) async {
    if (_isRefreshing) return;
    
    // Update active date if provided
    if (tanggal != null) {
      _currentTanggal = tanggal;
    }
    
    _isRefreshing = true;
    if (_transactions.isEmpty) _isLoading = true;
    _errorMessage = null;
    _hasMore = false; // Disable pagination for DO transactions
    notifyListeners();

    // 1. Tampilkan data dari SQLite (Local) terlebih dahulu agar cepat (Offline-first)
    try {
      final localDataRaw = await _repository.getLocalTransaksiDo(tanggal: _currentTanggal);
      _transactions = localDataRaw.map((json) => TransaksiDo.fromJson(json)).toList();
      _isLoading = false;
      notifyListeners();
    } catch (_) {}

    try {
      // 2. Fetch data terbaru dari server di background
      List<TransaksiDo> allTransactions = [];
      int page = 1;
      bool hasMoreData = true;

      while (hasMoreData) {
        final dynamic response = await _repository.getTransaksiDo(
          tanggal: _currentTanggal,
          page: page,
        );

        List<dynamic> rawData = [];
        if (response is Map) {
          rawData = response['data'] ?? [];
          hasMoreData = response['next_page_url'] != null;
        } else if (response is List) {
          rawData = response;
          hasMoreData = false;
        }

        final pageTransactions = rawData.map((json) => TransaksiDo.fromJson(json)).toList();
        allTransactions.addAll(pageTransactions);

        if (!hasMoreData) break;
        page++;
      }

      _transactions = allTransactions;
      _isLoading = false;

      if (_transactions.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final lastSeenId = int.tryParse(prefs.getString('seen_state_transaksi_do') ?? '0') ?? 0;
        _unreadCount = _transactions.where((t) => t.id > lastSeenId).length;
        _hasNewData = _unreadCount > 0;
      } else {
        _unreadCount = 0;
        _hasNewData = false;
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) {
        // Suppress offline error, just show whatever data we have
      } else {
        _errorMessage = 'Gagal memuat data transaksi: $e';
      }
      notifyListeners();
    } finally {
      _isRefreshing = false;
      notifyListeners();
    }
  }

  Future<void> fetchMoreTransactions({String? tanggal}) async {
    // Pagination disabled for DO transactions - fetch all for the selected date
    return;
  }

  Future<void> markAsSeen() async {
    if (_transactions.isNotEmpty) {
      final maxId = _transactions.map((t) => t.id).reduce((curr, next) => curr > next ? curr : next);
      await SeenStateService.markAsSeen('transaksi_do', maxId.toString());
      _unreadCount = 0;
      _hasNewData = false;
      notifyListeners();
    }
  }

  Future<String> getNextDoNumber({String? tanggal}) async {
    return await _repository.getNextDoNumber(tanggal: tanggal);
  }

  Future<void> fetchFormData() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _repository.getPenjuals(),
        _repository.getSupirs(),
        _repository.getKendaraans(),
      ]);
      
      void sortData(List<dynamic> list) {
        list.sort((a, b) {
          int idA = a['id'] ?? 0;
          int idB = b['id'] ?? 0;
          if (idA < 0 && idB >= 0) return -1;
          if (idB < 0 && idA >= 0) return 1;
          if (idA < 0 && idB < 0) return idA.compareTo(idB);
          return idB.compareTo(idA);
        });
      }

      _penjuals = List.from(results[0]);
      sortData(_penjuals);
      
      _supirs = List.from(results[1]);
      sortData(_supirs);
      
      _kendaraans = List.from(results[2]);
      sortData(_kendaraans);
      
      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal memuat data formulir.';
      notifyListeners();
    }
  }

  Future<bool> createTransaction({
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
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();
 
    try {
      final result = await _repository.createTransaksiDo(
        tanggal: tanggal,
        penjualId: penjualId,
        penjualNama: penjualNama,
        supirId: supirId,
        supirNama: supirNama,
        noPolisi: noPolisi,
        tonase: tonase,
        hargaSatuan: hargaSatuan,
        upahBongkar: upahBongkar,
        biayaLain: biayaLain,
        pembayaranHutang: pembayaranHutang,
        keteranganBiayaLain: keteranganBiayaLain,
        caraBayar: caraBayar,
        buktiTransfer: buktiTransfer,
        keteranganPembayaran: keteranganPembayaran,
        nomorDo: nomorDo,
      );

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'Koneksi bermasalah. Transaksi disimpan di antrean offline.';
        // Tetap return true karena dianggap "berhasil disimpan" di lokal
      } else {
        if (result is Map && result['data'] != null) {
          try {
            final newDo = TransaksiDo.fromJson(result['data']);
            _transactions.insert(0, newDo);
          } catch (e) {
            await fetchTransactions();
          }
        } else {
          await fetchTransactions();
        }
      }

      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      if (e is DioException) {
        final serverMessage = e.response?.data['message'];
        _errorMessage = serverMessage ?? 'Gagal menghubungi server.';
      } else {
        _errorMessage = 'Gagal menyimpan transaksi: $e';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateTransaction(
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
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _repository.updateTransaksiDo(
        id,
        tanggal: tanggal,
        penjualId: penjualId,
        supirId: supirId,
        noPolisi: noPolisi,
        tonase: tonase,
        hargaSatuan: hargaSatuan,
        upahBongkar: upahBongkar,
        biayaLain: biayaLain,
        pembayaranHutang: pembayaranHutang,
        keteranganBiayaLain: keteranganBiayaLain,
        caraBayar: caraBayar,
        buktiTransfer: buktiTransfer,
        keteranganPembayaran: keteranganPembayaran,
      );

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'Koneksi bermasalah. Perubahan disimpan di antrean offline.';
      } else {
        if (result is Map && result['data'] != null) {
          try {
            final updatedDo = TransaksiDo.fromJson(result['data']);
            final index = _transactions.indexWhere((t) => t.id == id);
            if (index != -1) {
              _transactions[index] = updatedDo;
            }
          } catch (e) {
            await fetchTransactions();
          }
        } else {
          await fetchTransactions();
        }
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isSaving = false;
      if (e is DioException) {
        final serverMessage = e.response?.data['message'];
        _errorMessage = serverMessage ?? 'Gagal menghubungi server.';
      } else {
        _errorMessage = 'Gagal memperbarui transaksi: $e';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTransaction(int id) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _repository.deleteTransaksiDo(id);
      _transactions.removeWhere((element) => element.id == id);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      if (e is DioException) {
        final serverMessage = e.response?.data['message'];
        _errorMessage = serverMessage ?? 'Gagal menghubungi server.';
      } else {
        _errorMessage = 'Gagal menghapus transaksi: $e';
      }
      notifyListeners();
      return false;
    }
  }
}

