import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:dio/dio.dart';
import 'package:sawitappmobile/features/penjual/models/penjual_model.dart';
import 'package:sawitappmobile/features/supir/models/supir_model.dart';
import 'package:sawitappmobile/features/pekerja/models/pekerja_model.dart';
import 'package:sawitappmobile/features/kendaraan/models/kendaraan_model.dart';
import 'package:sawitappmobile/features/operasional/models/operasional_model.dart';
import 'package:sawitappmobile/features/jurnal_keuangan/models/jurnal_keuangan_model.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';
import 'package:sawitappmobile/shared/repositories/resource_repository.dart';
import 'package:sawitappmobile/core/services/seen_state_service.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ResourceProvider with ChangeNotifier {
  final ResourceRepository _repository;

  bool _isLoading = false;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  final List<Penjual> _penjuals = [];
  final List<Supir> _supirs = [];
  final List<Pekerja> _pekerjas = [];
  final List<Kendaraan> _kendaraans = [];
  final List<Operasional> _operasionals = [];
  List<JurnalKeuangan> _jurnalKeuangans = [];
  final List<User> _users = [];

  String _appVersion = '1.0.0';
  String _appCreator = 'Don Borland';
  String? _appLogoUrl;
  String _changelog = 'Riwayat perubahan aplikasi.';

  // Track new data for each resource type
  final Map<String, bool> _hasNewData = {
    'penjual': false,
    'supir': false,
    'pekerja': false,
    'kendaraan': false,
    'operasional': false,
    'jurnal_keuangan': false,
    'user': false,
  };

  final Map<String, int> _unreadCounts = {
    'penjual': 0,
    'supir': 0,
    'pekerja': 0,
    'kendaraan': 0,
    'operasional': 0,
    'jurnal_keuangan': 0,
    'user': 0,
  };

  int get totalUnreadCount {
    int sum = 0;
    _unreadCounts.forEach((key, val) {
      sum += val;
    });
    return sum;
  }

  int getUnreadCountFor(String type) => _unreadCounts[type] ?? 0;

  // Pagination state for each resource
  final Map<String, int> _currentPage = {};
  final Map<String, bool> _hasMore = {};
  final Map<String, bool> _isFetchingMore = {};
  final Map<String, bool> _isRefreshing = {};

  bool isFetchingMoreFor(String type) => _isFetchingMore[type] ?? false;
  bool isRefreshingFor(String type) => _isRefreshing[type] ?? false;
  bool hasMoreFor(String type) => _hasMore[type] ?? true;

  // Total counts from summary (for list badges)
  int _totalPenjual = 0;
  int _totalSupir = 0;
  int _totalPekerja = 0;
  int _totalKendaraan = 0;
  int _totalOperasional = 0;
  int _totalJurnal = 0;
  int _totalUser = 0;

  // Real financial summary from server
  double _serverTotalPemasukan = 0;
  double _serverTotalPengeluaran = 0;

  double _totalHutangPenjual = 0.0;
  double _totalHutangSupir = 0.0;
  double _totalHutangPekerja = 0.0;

  double get totalHutangPenjual => _totalHutangPenjual;
  double get totalHutangSupir => _totalHutangSupir;
  double get totalHutangPekerja => _totalHutangPekerja;

  ResourceProvider(this._repository);

  bool get isLoading => _isLoading;
  bool hasMore(String type) => _hasMore[type] ?? false;
  bool isFetchingMore(String type) => _isFetchingMore[type] ?? false;
  List<Penjual> get penjuals => _penjuals;
  List<Supir> get supirs => _supirs;
  List<Pekerja> get pekerjas => _pekerjas;
  List<Kendaraan> get kendaraans => _kendaraans;
  List<Operasional> get operasionals => _operasionals;
  List<JurnalKeuangan> get jurnalKeuangans => _jurnalKeuangans;
  List<User> get users => _users;
  String get appVersion => _appVersion;
  String get appCreator => _appCreator;
  String? get appLogoUrl => _appLogoUrl;
  String get changelog => _changelog;

  bool hasNewDataFor(String type) => _hasNewData[type] ?? false;

  Future<void> fetchAppSettings() async {
    try {
      final settings = await _repository.getAppSettings().timeout(
        const Duration(seconds: 15),
      );
      _appVersion = settings['app_version'] ?? '1.0.0';
      _appCreator = settings['app_creator'] ?? 'Don Borland';
      _appLogoUrl = ApiConstants.normalizeUrl(settings['app_logo_url']);
      _changelog = settings['changelog'] ?? 'Riwayat perubahan aplikasi.';
    } catch (e) {
      debugPrint('ResourceProvider.fetchAppSettings error: $e');
      // Safely apply fallback values
      _appVersion = '1.0.0';
      _appCreator = 'Don Borland';
      _appLogoUrl = null;
      _changelog = 'Riwayat perubahan aplikasi.';
    } finally {
      notifyListeners();
    }
  }

  // Total counts for badges
  int get supirCount => _totalSupir;
  int get penjualCount => _totalPenjual;
  int get pekerjaCount => _totalPekerja;
  int get kendaraanCount => _totalKendaraan;
  int get operasionalCount => _totalOperasional;
  int get jurnalCount => _totalJurnal;
  int get userCount => _totalUser;

  void updateTotalCounts({
    int? penjual,
    int? supir,
    int? pekerja,
    int? kendaraan,
    int? operasional,
    int? jurnal,
    int? user,
  }) {
    if (penjual != null) _totalPenjual = penjual;
    if (supir != null) _totalSupir = supir;
    if (pekerja != null) _totalPekerja = pekerja;
    if (kendaraan != null) _totalKendaraan = kendaraan;
    if (operasional != null) _totalOperasional = operasional;
    if (jurnal != null) _totalJurnal = jurnal;
    if (user != null) _totalUser = user;
    notifyListeners();
  }

  Future<void> syncMasterData() async {
    await _repository.syncService.performFullSync(_repository);
    notifyListeners();
  }

  // Debtors (only those with sisa_hutang > 0)
  List<Supir> get supirDebtors =>
      _supirs.where((e) => (e.sisaHutang ?? 0) > 0).toList();
  List<Penjual> get penjualDebtors =>
      _penjuals.where((e) => (e.sisaHutang ?? 0) > 0).toList();
  List<Pekerja> get pekerjaDebtors =>
      _pekerjas.where((e) => e.sisaHutang > 0).toList();

  // Financial Summaries (Use server totals if available, otherwise fallback to local calculation)
  double get totalPemasukan {
    if (_serverTotalPemasukan > 0) return _serverTotalPemasukan;
    return _jurnalKeuangans
        .where((e) => e.jenisTransaksi == 'Pemasukan')
        .fold(0.0, (sum, item) => sum + item.nominal);
  }

  double get totalPengeluaran {
    if (_serverTotalPengeluaran > 0) return _serverTotalPengeluaran;
    return _jurnalKeuangans
        .where((e) => e.jenisTransaksi == 'Pengeluaran')
        .fold(0.0, (sum, item) => sum + item.nominal);
  }

  double get saldoKas => totalPemasukan - totalPengeluaran;

  Future<void> fetchJurnalByDateRange(String startDate, String endDate) async {
    if (_jurnalKeuangans.isEmpty) _isLoading = true;
    notifyListeners();
    try {
      _jurnalKeuangans = await _repository.getJurnalKeuangan(
        startDate: startDate,
        endDate: endDate,
      );
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchResources(
    String type, {
    bool refresh = false,
    Map<String, dynamic>? filters,
  }) async {
    if (refresh) {
      if (_isRefreshing[type] == true || _isFetchingMore[type] == true) return;
      _isRefreshing[type] = true;
      _currentPage[type] = 1;
      _hasMore[type] = true;
      _isFetchingMore[type] = false;

      // Only set isLoading if we don't have data yet to show skeletons
      // If we have data, we'll keep showing it while refreshing in background
      switch (type) {
        case 'penjual':
          if (_penjuals.isEmpty) _isLoading = true;
          break;
        case 'supir':
          if (_supirs.isEmpty) _isLoading = true;
          break;
        case 'pekerja':
          if (_pekerjas.isEmpty) _isLoading = true;
          break;
        case 'kendaraan':
          if (_kendaraans.isEmpty) _isLoading = true;
          break;
        case 'operasional':
          if (_operasionals.isEmpty) _isLoading = true;
          break;
        case 'jurnal_keuangan':
          if (_jurnalKeuangans.isEmpty) _isLoading = true;
          break;
        case 'user':
          if (_users.isEmpty) _isLoading = true;
          break;
      }
      notifyListeners();
    } else {
      if (_isFetchingMore[type] == true ||
          _isRefreshing[type] == true ||
          _hasMore[type] == false) {
        return;
      }
      _isFetchingMore[type] = true;
      notifyListeners();
    }

    try {
      debugPrint(
        'ResourceProvider.fetchResources: type=$type refresh=$refresh filters=${filters?.toString()} page=${_currentPage[type] ?? 1}',
      );
      int page = _currentPage[type] ?? 1;
      dynamic response;

      switch (type) {
        case 'penjual':
          response = await _repository.getPenjualPaginated(page: page);
          break;
        case 'supir':
          response = await _repository.getSupirPaginated(page: page);
          break;
        case 'pekerja':
          response = await _repository.getPekerjaPaginated(page: page);
          break;
        case 'kendaraan':
          response = await _repository.getKendaraanPaginated(page: page);
          break;
        case 'operasional':
          response = await _repository.getOperasionalPaginated(page: page);
          break;
        case 'jurnal_keuangan':
          response = await _repository.getJurnalPaginated(
            page: page,
            startDate: filters?['start_date'],
            endDate: filters?['end_date'],
            jenisTransaksi: filters?['jenis_transaksi'],
          );
          break;
        case 'user':
          response = await _repository.getUsersPaginated(page: page);
          break;
      }

      List<dynamic> rawData = [];
      bool hasMore = false;

      if (response is Map) {
        rawData = response['data'] ?? [];
        hasMore = response['next_page_url'] != null;

        // Capture summary if present
        if (response['summary'] != null) {
          _serverTotalPemasukan =
              double.tryParse(
                response['summary']['total_pemasukan']?.toString() ?? '0',
              ) ??
              0;
          _serverTotalPengeluaran =
              double.tryParse(
                response['summary']['total_pengeluaran']?.toString() ?? '0',
              ) ??
              0;

          double totalHutang =
              double.tryParse(
                response['summary']['total_hutang']?.toString() ?? '0.0',
              ) ??
              0.0;
          switch (type) {
            case 'penjual':
              _totalHutangPenjual = totalHutang;
              break;
            case 'supir':
              _totalHutangSupir = totalHutang;
              break;
            case 'pekerja':
              _totalHutangPekerja = totalHutang;
              break;
          }
        }
        // Debug logging for jurnal_keuangan responses
        try {
          if (type == 'jurnal_keuangan') {
            debugPrint(
              'ResourceProvider.fetchResources: jurnal_keuangan response total=${response['total']} summary=${response['summary']} data_len=${rawData.length}',
            );
          } else {
            debugPrint(
              'ResourceProvider.fetchResources: response keys=${response.keys.toList()} data_len=${rawData.length}',
            );
          }
        } catch (e) {
          debugPrint('ResourceProvider.fetchResources: logging failed: $e');
        }
      } else if (response is List) {
        rawData = response;
        hasMore = false;
      }

      switch (type) {
        case 'penjual':
          final items = rawData.map((e) => Penjual.fromJson(e)).toList();
          if (page == 1) _penjuals.clear();
          for (var item in items) {
            if (!_penjuals.any((e) => e.id == item.id)) {
              _penjuals.add(item);
            }
          }
          break;
        case 'supir':
          final items = rawData.map((e) => Supir.fromJson(e)).toList();
          if (page == 1) _supirs.clear();
          for (var item in items) {
            if (!_supirs.any((e) => e.id == item.id)) {
              _supirs.add(item);
            }
          }
          break;
        case 'pekerja':
          final items = rawData.map((e) => Pekerja.fromJson(e)).toList();
          if (page == 1) _pekerjas.clear();
          for (var item in items) {
            if (!_pekerjas.any((e) => e.id == item.id)) {
              _pekerjas.add(item);
            }
          }
          break;
        case 'kendaraan':
          final items = rawData.map((e) => Kendaraan.fromJson(e)).toList();
          if (page == 1) _kendaraans.clear();
          for (var item in items) {
            if (!_kendaraans.any((e) => e.id == item.id)) {
              _kendaraans.add(item);
            }
          }
          break;
        case 'operasional':
          final items = rawData.map((e) => Operasional.fromJson(e)).toList();
          if (page == 1) _operasionals.clear();
          for (var item in items) {
            if (!_operasionals.any((e) => e.id == item.id)) {
              _operasionals.add(item);
            }
          }
          break;
        case 'jurnal_keuangan':
          final items = rawData.map((e) => JurnalKeuangan.fromJson(e)).toList();
          if (page == 1) _jurnalKeuangans.clear();
          for (var item in items) {
            if (!_jurnalKeuangans.any((e) => e.id == item.id)) {
              _jurnalKeuangans.add(item);
            }
          }
          break;
        case 'user':
          final items = rawData.map((e) => User.fromJson(e)).toList();
          if (page == 1) _users.clear();
          for (var item in items) {
            if (!_users.any((e) => e.id == item.id)) {
              _users.add(item);
            }
          }
          break;
      }

      _currentPage[type] = page + 1;
      _hasMore[type] = hasMore;

      // Update counts based on total returned by API if available
      if (response is Map && response['total'] != null) {
        int total = int.tryParse(response['total'].toString()) ?? 0;
        switch (type) {
          case 'penjual':
            _totalPenjual = total;
            break;
          case 'supir':
            _totalSupir = total;
            break;
          case 'pekerja':
            _totalPekerja = total;
            break;
          case 'kendaraan':
            _totalKendaraan = total;
            break;
          case 'operasional':
            _totalOperasional = total;
            break;
          case 'jurnal_keuangan':
            _totalJurnal = total;
            break;
          case 'user':
            _totalUser = total;
            break;
        }
      }

      await _checkNewDataFor(type);
    } catch (e) {
      debugPrint('Error fetching $type: $e');
    } finally {
      _isLoading = false;
      _isFetchingMore[type] = false;
      _isRefreshing[type] = false;
      notifyListeners();
    }
  }

  Future<void> _checkNewDataFor(String type) async {
    final prefs = await SharedPreferences.getInstance();
    final lastSeenId =
        int.tryParse(prefs.getString('seen_state_$type') ?? '0') ?? 0;

    int count = 0;
    switch (type) {
      case 'penjual':
        count = _penjuals.where((item) => item.id > lastSeenId).length;
        break;
      case 'supir':
        count = _supirs.where((item) => item.id > lastSeenId).length;
        break;
      case 'pekerja':
        count = _pekerjas.where((item) => item.id > lastSeenId).length;
        break;
      case 'kendaraan':
        count = _kendaraans.where((item) => item.id > lastSeenId).length;
        break;
      case 'operasional':
        count = _operasionals.where((item) => item.id > lastSeenId).length;
        break;
      case 'jurnal_keuangan':
        count = _jurnalKeuangans.where((item) => item.id > lastSeenId).length;
        break;
      case 'user':
        count = _users.where((item) => item.id > lastSeenId).length;
        break;
    }

    _unreadCounts[type] = count;
    _hasNewData[type] = count > 0;
  }

  Future<bool> _isUserLeader() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('cached_user');
    if (userStr != null) {
      try {
        final decoded = jsonDecode(userStr);
        final user = User.fromJson(decoded);
        final role = user.role;
        return role == 'admin' || role == 'super_admin' || role == 'pimpinan';
      } catch (e) {
        debugPrint('Error parsing user in ResourceProvider: $e');
      }
    }
    return false;
  }

  Future<void> fetchAllResources() async {
    // Sequential fetching to prevent local dev server request queuing timeout
    syncMasterData();
    await fetchResources('penjual', refresh: true);
    await fetchResources('supir', refresh: true);
    await fetchResources('pekerja', refresh: true);
    await fetchResources('kendaraan', refresh: true);
    await fetchResources('operasional', refresh: true);

    final isLeader = await _isUserLeader();
    if (isLeader) {
      await fetchResources('jurnal_keuangan', refresh: true);
    }
  }

  Future<void> markAsSeen(String type) async {
    String latestId = "";
    switch (type) {
      case 'penjual':
        latestId = _penjuals.isNotEmpty
            ? _penjuals
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
      case 'supir':
        latestId = _supirs.isNotEmpty
            ? _supirs
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
      case 'pekerja':
        latestId = _pekerjas.isNotEmpty
            ? _pekerjas
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
      case 'kendaraan':
        latestId = _kendaraans.isNotEmpty
            ? _kendaraans
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
      case 'operasional':
        latestId = _operasionals.isNotEmpty
            ? _operasionals
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
      case 'jurnal_keuangan':
        latestId = _jurnalKeuangans.isNotEmpty
            ? _jurnalKeuangans
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
      case 'user':
        latestId = _users.isNotEmpty
            ? _users
                  .map((e) => e.id)
                  .reduce((curr, next) => curr > next ? curr : next)
                  .toString()
            : "";
        break;
    }

    if (latestId.isNotEmpty) {
      await SeenStateService.markAsSeen(type, latestId);
      _unreadCounts[type] = 0;
      _hasNewData[type] = false;
      notifyListeners();
    }
  }

  Future<void> markAllAsSeen() async {
    for (var type in _hasNewData.keys) {
      String latestId = "";
      switch (type) {
        case 'penjual':
          latestId = _penjuals.isNotEmpty
              ? _penjuals
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
        case 'supir':
          latestId = _supirs.isNotEmpty
              ? _supirs
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
        case 'pekerja':
          latestId = _pekerjas.isNotEmpty
              ? _pekerjas
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
        case 'kendaraan':
          latestId = _kendaraans.isNotEmpty
              ? _kendaraans
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
        case 'operasional':
          latestId = _operasionals.isNotEmpty
              ? _operasionals
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
        case 'jurnal_keuangan':
          latestId = _jurnalKeuangans.isNotEmpty
              ? _jurnalKeuangans
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
        case 'user':
          latestId = _users.isNotEmpty
              ? _users
                    .map((e) => e.id)
                    .reduce((curr, next) => curr > next ? curr : next)
                    .toString()
              : "";
          break;
      }
      if (latestId.isNotEmpty) {
        await SeenStateService.markAsSeen(type, latestId);
        _unreadCounts[type] = 0;
        _hasNewData[type] = false;
      }
    }
    notifyListeners();
  }

  void clearData() {
    _penjuals.clear();
    _supirs.clear();
    _pekerjas.clear();
    _kendaraans.clear();
    _operasionals.clear();
    _jurnalKeuangans.clear();
    _hasNewData.updateAll((key, value) => false);
    _unreadCounts.updateAll((key, value) => 0);
    notifyListeners();
  }

  Future<dynamic> addPenjual(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      final result = await _repository.storePenjual(data);

      // ✅ PANGGIL REFRESH DI SINI (DI LUAR ELSE)
      // Ini akan memicu pengambilan data (cache + queue offline terbaru)
      await fetchResources('penjual', refresh: true);

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      }
      return result;
    } catch (e) {
      debugPrint('Error adding penjual: $e');
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<dynamic> addSupir(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      final result = await _repository.storeSupir(data);

      // ✅ PANGGIL REFRESH DI SINI (DI LUAR ELSE)
      // Ini akan memicu pengambilan data (cache + queue offline terbaru)
      await fetchResources('supir', refresh: true);

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      }
      return result;
    } catch (e) {
      debugPrint('Error adding supir: $e');
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<bool> addDebtPenjual(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.addDebtPenjual(id, data);
      await fetchResources('penjual', refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error adding debt penjual: $e');
      if (e is DioException) {
        _errorMessage = e.response?.data?['message'] ?? e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDebtSupir(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.addDebtSupir(id, data);
      await fetchResources('supir', refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error adding debt supir: $e');
      if (e is DioException) {
        _errorMessage = e.response?.data?['message'] ?? e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> addDebtPekerja(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.addDebtPekerja(id, data);
      await fetchResources('pekerja', refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error adding debt pekerja: $e');
      if (e is DioException) {
        _errorMessage = e.response?.data?['message'] ?? e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updatePenjual(int id, Map<String, dynamic> data) async {
    try {
      await _repository.updatePenjual(id, data);
      await fetchResources('penjual', refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error updating penjual: $e');
      return false;
    }
  }

  Future<bool> updateSupir(int id, Map<String, dynamic> data) async {
    try {
      await _repository.updateSupir(id, data);
      await fetchResources('supir', refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error updating supir: $e');
      return false;
    }
  }

  Future<dynamic> addPekerja(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      final result = await _repository.storePekerja(data);

      // ✅ PANGGIL REFRESH DI SINI (DI LUAR ELSE)
      // Ini akan memicu pengambilan data (cache + queue offline terbaru)
      await fetchResources('pekerja', refresh: true);

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      }
      return result;
    } catch (e) {
      debugPrint('Error adding pekerja: $e');
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<bool> updatePekerja(int id, Map<String, dynamic> data) async {
    try {
      await _repository.updatePekerja(id, data);
      await fetchResources('pekerja', refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error updating pekerja: $e');
      return false;
    }
  }

  Future<dynamic> addKendaraan(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      final result = await _repository.storeKendaraan(data);

      // ✅ PANGGIL REFRESH DI SINI (DI LUAR ELSE)
      // Ini akan memicu pengambilan data (cache + queue offline terbaru)
      await fetchResources('kendaraan', refresh: true);

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      }
      return result;
    } catch (e) {
      debugPrint('Error adding kendaran: $e');
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<dynamic> addOperasional(Map<String, dynamic> data) async {
    _errorMessage = null;

    // OPTIMISTIC UPDATE UNTUK HUTANG PEKERJA/SUPIR/PENJUAL SAAT OFFLINE
    if (data['kategori'] == 'kasbon' || data['kategori'] == 'bayar_hutang') {
      double nominal = double.tryParse(data['nominal'].toString()) ?? 0.0;
      if (data['kategori'] == 'bayar_hutang') {
        nominal = -nominal; // kurangi hutang jika dibayar
      }

      int pihakId = data['pihak_id'] is int
          ? data['pihak_id']
          : int.tryParse(data['pihak_id']?.toString() ?? '') ?? 0;
      String type = data['pihak_type']?.toString() ?? '';

      if (type == 'App\\Models\\Penjual') {
        var idx = _penjuals.indexWhere((e) => e.id == pihakId);
        if (idx != -1) {
          final old = _penjuals[idx];
          _penjuals[idx] = Penjual(
            id: old.id,
            nama: old.nama,
            alamat: old.alamat,
            telepon: old.telepon,
            hutang: old.hutang,
            sisaHutang: (old.sisaHutang ?? 0) + nominal,
            isActive: old.isActive,
            transaksiDo: old.transaksiDo,
            mutasiHutang: old.mutasiHutang,
            createdAt: old.createdAt,
          );
        }
      } else if (type == 'App\\Models\\Supir') {
        var idx = _supirs.indexWhere((e) => e.id == pihakId);
        if (idx != -1) {
          final old = _supirs[idx];
          _supirs[idx] = Supir(
            id: old.id,
            nama: old.nama,
            telepon: old.telepon,
            alamat: old.alamat,
            status: old.status,
            hutang: old.hutang,
            sisaHutang: (old.sisaHutang ?? 0) + nominal,
            isActive: old.isActive,
            transaksiDo: old.transaksiDo,
            mutasiHutang: old.mutasiHutang,
            createdAt: old.createdAt,
          );
        }
      } else if (type == 'App\\Models\\Pekerja') {
        var idx = _pekerjas.indexWhere((e) => e.id == pihakId);
        if (idx != -1) {
          final old = _pekerjas[idx];
          _pekerjas[idx] = Pekerja(
            id: old.id,
            nama: old.nama,
            telepon: old.telepon,
            alamat: old.alamat,
            posisi: old.posisi,
            hutang: old.hutang,
            sisaHutang: old.sisaHutang + nominal,
            perusahaanId: old.perusahaanId,
            isActive: old.isActive,
            mutasiHutang: old.mutasiHutang,
            createdAt: old.createdAt,
          );
        }
      }
      notifyListeners();
    }

    try {
      final result = await _repository.storeOperasional(data);

      // ✅ SELALU refresh data agar data dari offline_queue langsung muncul
      await fetchResources('operasional', refresh: true);

      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      }
      return result;
    } catch (e) {
      debugPrint('Error adding operasional: $e');
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<bool> updateOperasional(int id, Map<String, dynamic> data) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      await _repository.updateOperasional(id, data);
      await fetchAllResources();
      return true;
    } catch (e) {
      debugPrint('Error updating operasional: $e');
      if (e is DioException) {
        _errorMessage = e.response?.data?['message'] ?? e.message;
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Operasional> getOperasionalDetail(int id) async {
    return await _repository.getOperasionalDetail(id);
  }

  Future<Penjual> getPenjualDetail(int id) async {
    return await _repository.getPenjualDetail(id);
  }

  Future<Supir> getSupirDetail(int id) async {
    return await _repository.getSupirDetail(id);
  }

  Future<Pekerja> getPekerjaDetail(int id) async {
    return await _repository.getPekerjaDetail(id);
  }

  Future<bool> updateAppSettings(
    String version,
    String creator, {
    String? changelog,
  }) async {
    _isLoading = true;
    notifyListeners();
    try {
      final Map<String, dynamic> data = {
        'app_version': version,
        'app_creator': creator,
        'changelog': changelog ?? '', // selalu kirim changelog meski kosong
      };
      final settings = await _repository.updateAppSettings(data);
      _appVersion = settings['app_version'] ?? version;
      _appCreator = settings['app_creator'] ?? creator;
      // Null-safe: logo bisa null jika belum diupload
      final logoUrl = settings['app_logo_url'];
      _appLogoUrl = logoUrl != null
          ? ApiConstants.normalizeUrl(logoUrl as String)
          : null;
      _changelog = settings['changelog'] ?? changelog ?? _changelog;
      return true;
    } catch (e) {
      debugPrint('Error updating app settings: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> changePassword(
    String current,
    String password,
    String confirm,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.changePassword(current, password, confirm);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> resetUserPassword(
    int userId,
    String password,
    String confirm,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _repository.resetUserPassword(userId, password, confirm);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> deleteResource(String type, int id) async {
    _isLoading = true;

    // OPTIMISTIC UPDATE: Langsung hapus dari state lokal agar UI langsung responsif
    switch (type) {
      case 'penjual':
        _penjuals.removeWhere((e) => e.id == id);
        break;
      case 'supir':
        _supirs.removeWhere((e) => e.id == id);
        break;
      case 'pekerja':
        _pekerjas.removeWhere((e) => e.id == id);
        break;
      case 'operasional':
        _operasionals.removeWhere((e) => e.id == id);
        break;
    }
    notifyListeners();

    try {
      switch (type) {
        case 'penjual':
          await _repository.deletePenjual(id);
          break;
        case 'supir':
          await _repository.deleteSupir(id);
          break;
        case 'pekerja':
          await _repository.deletePekerja(id);
          break;
        case 'operasional':
          await _repository.deleteOperasional(id);
          break;
        default:
          return false;
      }
      await fetchResources(type, refresh: true);
      if (type == 'operasional') {
        fetchResources('pekerja', refresh: true);
        fetchResources('supir', refresh: true);
        fetchResources('penjual', refresh: true);
      }
      return true;
    } catch (e) {
      debugPrint('Error deleting $type: $e');
      if (e is DioException) {
        // Jika item sudah tidak ada di server (404), anggap sukses
        if (e.response?.statusCode == 404 ||
            (e.response?.data?.toString().contains('No query results') ??
                false)) {
          await fetchResources(type, refresh: true);
          return true;
        }

        if (e.response?.data is Map && e.response?.data['errors'] != null) {
          final Map errors = e.response?.data['errors'];
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            _errorMessage = firstError.first.toString();
          } else {
            _errorMessage = firstError.toString();
          }
        } else {
          _errorMessage = e.response?.data?['message'] ?? e.message;
        }
      } else {
        _errorMessage = e.toString();
      }

      // Revert optimistic update by re-fetching data if deletion failed
      await fetchResources(type, refresh: true);
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> updateResourceStatus(String type, int id, bool isActive) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final Map<String, dynamic> data = {'is_active': isActive};

      switch (type) {
        case 'penjual':
          Penjual item;
          try {
            item = _penjuals.firstWhere((e) => e.id == id);
          } catch (_) {
            item = await _repository.getPenjualDetail(id);
          }
          data['nama'] = item.nama;
          data['alamat'] = item.alamat;
          data['telepon'] = item.telepon;
          await _repository.updatePenjual(id, data);
          break;
        case 'supir':
          Supir item;
          try {
            item = _supirs.firstWhere((e) => e.id == id);
          } catch (_) {
            item = await _repository.getSupirDetail(id);
          }
          data['nama'] = item.nama;
          data['alamat'] = item.alamat;
          data['telepon'] = item.telepon;
          data['status_supir'] = item.status;
          await _repository.updateSupir(id, data);
          break;
        case 'pekerja':
          Pekerja item;
          try {
            item = _pekerjas.firstWhere((e) => e.id == id);
          } catch (_) {
            item = await _repository.getPekerjaDetail(id);
          }
          data['nama'] = item.nama;
          data['alamat'] = item.alamat;
          data['telepon'] = item.telepon;
          await _repository.updatePekerja(id, data);
          break;
        default:
          throw Exception('Tipe resource tidak dikenal');
      }

      // Refresh list
      await fetchResources(type, refresh: true);
      return true;
    } catch (e) {
      debugPrint('Error updating $type status: $e');
      if (e is DioException) {
        if (e.response?.data is Map && e.response?.data['errors'] != null) {
          final Map errors = e.response?.data['errors'];
          final firstError = errors.values.first;
          if (firstError is List && firstError.isNotEmpty) {
            _errorMessage = firstError.first.toString();
          } else {
            _errorMessage = firstError.toString();
          }
        } else {
          _errorMessage = e.response?.data?['message'] ?? e.message;
        }
      } else {
        _errorMessage = e.toString();
      }
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    if (WidgetsBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        super.notifyListeners();
      });
    } else {
      super.notifyListeners();
    }
  }
}
