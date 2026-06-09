import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
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

  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
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
    // JANGAN set _isLoading=true di sini agar form langsung tampil
    // Data lokal di-load diam-diam, lalu UI di-refresh setelah server merespons
    
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

    // 1. Tampilkan data dari SQLite (Local) terlebih dahulu agar cepat (Offline-first)
    try {
      final localResults = await Future.wait([
        _repository.getLocalPenjuals(),
        _repository.getLocalSupirs(),
        _repository.getLocalKendaraans(),
      ]);

      if (localResults[0].isNotEmpty || localResults[1].isNotEmpty || localResults[2].isNotEmpty) {
        _penjuals = List.from(localResults[0]);
        sortData(_penjuals);
        
        _supirs = List.from(localResults[1]);
        sortData(_supirs);
        
        _kendaraans = List.from(localResults[2]);
        sortData(_kendaraans);
        
        notifyListeners();
      }
    } catch (_) {}

    // 2. Fetch data terbaru dari server di background (diam-diam)
    try {
      final results = await Future.wait([
        _repository.getPenjuals(),
        _repository.getSupirs(),
        _repository.getKendaraans(),
      ]);
      
      _penjuals = List.from(results[0]);
      sortData(_penjuals);
      
      _supirs = List.from(results[1]);
      sortData(_supirs);
      
      _kendaraans = List.from(results[2]);
      sortData(_kendaraans);
    } catch (e) {
      _errorMessage = 'Gagal memuat data form terbaru';
    } finally {
      notifyListeners();
    }
  }

  /// Refresh transaksi di background tanpa memblokir UI (tidak set _isLoading)
  void _refreshInBackground() {
    Future.microtask(() async {
      try {
        // Local first
        final localData = await _repository.getLocalTransaksiDo(tanggal: _currentTanggal);
        _transactions = localData.map((json) => TransaksiDo.fromJson(json)).toList();
        notifyListeners();

        // Lalu sync dari server diam-diam
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
          allTransactions.addAll(rawData.map((json) => TransaksiDo.fromJson(json)));
          if (!hasMoreData) break;
          page++;
        }
        _transactions = allTransactions;
        notifyListeners();
      } catch (_) {}
    });
  }

  /// Simpan harga satuan terakhir berdasarkan tanggal
  Future<void> saveLastHargaSatuan(String tanggal, double harga) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('last_harga_satuan_value', harga);
    await prefs.setString('last_harga_satuan_tanggal', tanggal);
  }

  /// Ambil harga satuan terakhir:
  /// 1. Cek dari transaksi yang sudah ada di memori (paling akurat)
  /// 2. Fallback ke SharedPreferences jika memori kosong
  Future<double?> getLastHargaSatuan(String tanggal) async {
    // Prioritas 1: ambil dari transaksi yang sudah ada di memori untuk tanggal ini
    if (_transactions.isNotEmpty) {
      final txHariIni = _transactions.where((t) {
        final tgl = DateFormat('yyyy-MM-dd').format(t.tanggal.toLocal());
        return tgl == tanggal;
      }).toList();
      if (txHariIni.isNotEmpty) {
        // Ambil harga dari transaksi paling baru
        return txHariIni.first.hargaSatuan;
      }
    }

    // Prioritas 2: fallback ke SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final savedTanggal = prefs.getString('last_harga_satuan_tanggal');
    if (savedTanggal == tanggal) {
      return prefs.getDouble('last_harga_satuan_value');
    }
    return null;
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
        _refreshInBackground();
        // Tetap return true karena dianggap "berhasil disimpan" di lokal
      } else {
        if (result is Map && result['data'] != null) {
          try {
            final newDo = TransaksiDo.fromJson(result['data']);
            _transactions.insert(0, newDo);
          } catch (e) {
            // Parsing gagal — refresh di background tanpa set _isLoading
            _refreshInBackground();
          }
        } else {
          // Refresh di background tanpa set _isLoading
          _refreshInBackground();
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
        _refreshInBackground();
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
    _errorMessage = null;
    
    // Simpan data lama & hapus secara sinkron untuk mencegah error Dismissible Flutter
    final index = _transactions.indexWhere((element) => element.id == id);
    TransaksiDo? backupTx;
    if (index != -1) {
      backupTx = _transactions[index];
      _transactions.removeAt(index);
      notifyListeners();
    }

    try {
      await _repository.deleteTransaksiDo(id);
      return true;
    } catch (e) {
      // Kembalikan data jika gagal
      if (index != -1 && backupTx != null) {
        _transactions.insert(index, backupTx);
      }
      
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

  Future<String?> getPrintUrl(int id) async {
    _isLoading = true;
    notifyListeners();
    
    final url = await _repository.getPrintUrl(id);
    
    _isLoading = false;
    notifyListeners();
    
    return url;
  }
}

