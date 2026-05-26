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
  int _currentPage = 1;
  bool _hasMore = true;
  bool _isFetchingMore = false;
  bool _isSaving = false;
  bool _isRefreshing = false;

  int _unreadCount = 0;
  int _totalTransactions = 0;
  String? _lastFilterDate;

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
  int get totalTransactions => _totalTransactions;
  String? get lastFilterDate => _lastFilterDate;

  void clearData() {
    _transactions.clear();
    _penjuals.clear();
    _supirs.clear();
    _kendaraans.clear();
    _errorMessage = null;
    _hasNewData = false;
    _unreadCount = 0;
    _currentPage = 1;
    _hasMore = true;
    _lastFilterDate = null;
    notifyListeners();
  }

  Future<void> fetchTransactions({String? tanggal}) async {
    if (tanggal != null) {
      _lastFilterDate = tanggal;
    } else {
      tanggal = _lastFilterDate;
    }

    if (_isRefreshing || _isFetchingMore) return;
    _isRefreshing = true;
    if (_transactions.isEmpty) _isLoading = true;
    _errorMessage = null;
    _currentPage = 1;
    _hasMore = true;
    notifyListeners();

    try {
      final dynamic response = await _repository.getTransaksiDo(
        tanggal: tanggal,
        page: _currentPage,
      );

      List<dynamic> rawData = [];
      if (response is Map) {
        rawData = response['data'] ?? [];
        _hasMore = response['next_page_url'] != null;
        _totalTransactions =
            _parseTotalFromResponse(response) ?? rawData.length;
      } else if (response is List) {
        rawData = response;
        _hasMore = false;
        _totalTransactions = rawData.length;
      }

      _transactions = rawData
          .map((json) => TransaksiDo.fromJson(json))
          .toList();
      _isLoading = false;

      if (_transactions.isNotEmpty) {
        final prefs = await SharedPreferences.getInstance();
        final lastSeenId =
            int.tryParse(prefs.getString('seen_state_transaksi_do') ?? '0') ??
            0;
        _unreadCount = _transactions.where((t) => t.id > lastSeenId).length;
        _hasNewData = _unreadCount > 0;
      } else {
        _unreadCount = 0;
        _hasNewData = false;
      }

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      if (e is DioException &&
          (e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.connectionTimeout)) {
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

  int? _parseTotalFromResponse(Map<dynamic, dynamic> response) {
    final candidates = <dynamic>[
      response['total'],
      response['meta'] is Map ? response['meta']['total'] : null,
      response['pagination'] is Map ? response['pagination']['total'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate == null) continue;
      final parsed = int.tryParse(candidate.toString());
      if (parsed != null && parsed >= 0) return parsed;
    }
    return null;
  }

  Future<void> fetchMoreTransactions({String? tanggal}) async {
    if (tanggal != null) {
      _lastFilterDate = tanggal;
    } else {
      tanggal = _lastFilterDate;
    }

    if (_isFetchingMore || _isRefreshing || !_hasMore) return;

    _isFetchingMore = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _currentPage++;
      final dynamic response = await _repository.getTransaksiDo(
        tanggal: tanggal,
        page: _currentPage,
      );

      List<dynamic> rawData = [];
      if (response is Map) {
        rawData = response['data'] ?? [];
        _hasMore = response['next_page_url'] != null;
        final pageTotal = _parseTotalFromResponse(response);
        if (pageTotal != null) {
          _totalTransactions = pageTotal;
        }
      } else if (response is List) {
        rawData = response;
        _hasMore = false;
      }

      final newItems = rawData
          .map((json) => TransaksiDo.fromJson(json))
          .toList();

      for (var item in newItems) {
        if (!_transactions.any((e) => e.id == item.id)) {
          _transactions.add(item);
        }
      }

      // Re-evaluate unreadCount after fetching more items
      final prefs = await SharedPreferences.getInstance();
      final lastSeenId =
          int.tryParse(prefs.getString('seen_state_transaksi_do') ?? '0') ?? 0;
      _unreadCount = _transactions.where((t) => t.id > lastSeenId).length;
      _hasNewData = _unreadCount > 0;

      _isFetchingMore = false;
      notifyListeners();
    } catch (e) {
      _isFetchingMore = false;
      _currentPage--; // Rollback page on error
      notifyListeners();
    }
  }

  Future<void> markAsSeen() async {
    if (_transactions.isNotEmpty) {
      final maxId = _transactions
          .map((t) => t.id)
          .reduce((curr, next) => curr > next ? curr : next);
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
      _penjuals = results[0];
      _supirs = results[1];
      _kendaraans = results[2];
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
        _errorMessage =
            'Koneksi bermasalah. Transaksi disimpan di antrean offline.';
        // Tetap return true karena dianggap "berhasil disimpan" di lokal
      } else {
        await fetchTransactions(); // Refresh list hanya jika online berhasil
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
        _errorMessage =
            'Koneksi bermasalah. Transaksi disimpan di antrean offline.';
      } else {
        await fetchTransactions();
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
