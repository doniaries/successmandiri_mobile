import 'package:flutter/material.dart';
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

  // Pagination state for each resource
  final Map<String, int> _currentPage = {};
  final Map<String, bool> _hasMore = {};
  final Map<String, bool> _isFetchingMore = {};

  bool isFetchingMoreFor(String type) => _isFetchingMore[type] ?? false;
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

  bool hasNewDataFor(String type) => _hasNewData[type] ?? false;

  Future<void> fetchAppSettings() async {
    try {
      final settings = await _repository.getAppSettings().timeout(
        const Duration(seconds: 15),
      );
      _appVersion = settings['app_version'] ?? '1.0.0';
      _appCreator = settings['app_creator'] ?? 'Don Borland';
      _appLogoUrl = ApiConstants.normalizeUrl(settings['app_logo_url']);
    } catch (e) {
      // Ignore if fetch fails
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
      if (_isFetchingMore[type] == true || _hasMore[type] == false) return;
      _isFetchingMore[type] = true;
      notifyListeners();
    }

    try {
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
        }
      } else if (response is List) {
        rawData = response;
        hasMore = false;
      }

      switch (type) {
        case 'penjual':
          final items = rawData.map((e) => Penjual.fromJson(e)).toList();
          if (page == 1) _penjuals.clear();
          _penjuals.addAll(items);
          break;
        case 'supir':
          final items = rawData.map((e) => Supir.fromJson(e)).toList();
          if (page == 1) _supirs.clear();
          _supirs.addAll(items);
          break;
        case 'pekerja':
          final items = rawData.map((e) => Pekerja.fromJson(e)).toList();
          if (page == 1) _pekerjas.clear();
          _pekerjas.addAll(items);
          break;
        case 'kendaraan':
          final items = rawData.map((e) => Kendaraan.fromJson(e)).toList();
          if (page == 1) _kendaraans.clear();
          _kendaraans.addAll(items);
          break;
        case 'operasional':
          final items = rawData.map((e) => Operasional.fromJson(e)).toList();
          if (page == 1) _operasionals.clear();
          _operasionals.addAll(items);
          break;
        case 'jurnal_keuangan':
          final items = rawData.map((e) => JurnalKeuangan.fromJson(e)).toList();
          if (page == 1) _jurnalKeuangans.clear();
          _jurnalKeuangans.addAll(items);
          break;
        case 'user':
          final items = rawData.map((e) => User.fromJson(e)).toList();
          if (page == 1) _users.clear();
          _users.addAll(items);
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
      notifyListeners();
    }
  }

  Future<void> _checkNewDataFor(String type) async {
    String latestId = "";
    switch (type) {
      case 'penjual':
        latestId = _penjuals.isNotEmpty ? _penjuals.first.id.toString() : "";
        break;
      case 'supir':
        latestId = _supirs.isNotEmpty ? _supirs.first.id.toString() : "";
        break;
      case 'pekerja':
        latestId = _pekerjas.isNotEmpty ? _pekerjas.first.id.toString() : "";
        break;
      case 'kendaraan':
        latestId = _kendaraans.isNotEmpty
            ? _kendaraans.first.id.toString()
            : "";
        break;
      case 'operasional':
        latestId = _operasionals.isNotEmpty
            ? _operasionals.first.id.toString()
            : "";
        break;
      case 'jurnal_keuangan':
        latestId = _jurnalKeuangans.isNotEmpty
            ? _jurnalKeuangans.first.id.toString()
            : "";
        break;
      case 'user':
        latestId = _users.isNotEmpty ? _users.first.id.toString() : "";
        break;
    }
    if (latestId.isNotEmpty) {
      _hasNewData[type] = !await SeenStateService.isSeen(type, latestId);
    }
  }

  Future<void> fetchAllResources() async {
    // Sequential fetching to prevent local dev server request queuing timeout
    syncMasterData();
    await fetchResources('penjual', refresh: true);
    await fetchResources('supir', refresh: true);
    await fetchResources('pekerja', refresh: true);
    await fetchResources('kendaraan', refresh: true);
    await fetchResources('operasional', refresh: true);
    await fetchResources('jurnal_keuangan', refresh: true);
  }

  Future<void> markAsSeen(String type) async {
    String latestId = "";
    switch (type) {
      case 'penjual':
        latestId = _penjuals.isNotEmpty ? _penjuals.first.id.toString() : "";
        break;
      case 'supir':
        latestId = _supirs.isNotEmpty ? _supirs.first.id.toString() : "";
        break;
      case 'pekerja':
        latestId = _pekerjas.isNotEmpty ? _pekerjas.first.id.toString() : "";
        break;
      case 'kendaraan':
        latestId = _kendaraans.isNotEmpty
            ? _kendaraans.first.id.toString()
            : "";
        break;
      case 'operasional':
        latestId = _operasionals.isNotEmpty
            ? _operasionals.first.id.toString()
            : "";
        break;
      case 'jurnal_keuangan':
        latestId = _jurnalKeuangans.isNotEmpty
            ? _jurnalKeuangans.first.id.toString()
            : "";
        break;
      case 'user':
        latestId = _users.isNotEmpty ? _users.first.id.toString() : "";
        break;
    }

    if (latestId.isNotEmpty) {
      await SeenStateService.markAsSeen(type, latestId);
      _hasNewData[type] = false;
      notifyListeners();
    }
  }

  Future<void> markAllAsSeen() async {
    for (var type in _hasNewData.keys) {
      String latestId = "";
      switch (type) {
        case 'penjual':
          latestId = _penjuals.isNotEmpty ? _penjuals.first.id.toString() : "";
          break;
        case 'supir':
          latestId = _supirs.isNotEmpty ? _supirs.first.id.toString() : "";
          break;
        case 'pekerja':
          latestId = _pekerjas.isNotEmpty ? _pekerjas.first.id.toString() : "";
          break;
        case 'kendaraan':
          latestId = _kendaraans.isNotEmpty
              ? _kendaraans.first.id.toString()
              : "";
          break;
        case 'operasional':
          latestId = _operasionals.isNotEmpty
              ? _operasionals.first.id.toString()
              : "";
          break;
        case 'jurnal_keuangan':
          latestId = _jurnalKeuangans.isNotEmpty
              ? _jurnalKeuangans.first.id.toString()
              : "";
          break;
        case 'user':
          latestId = _users.isNotEmpty ? _users.first.id.toString() : "";
          break;
      }
      if (latestId.isNotEmpty) {
        await SeenStateService.markAsSeen(type, latestId);
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
    notifyListeners();
  }

  Future<dynamic> addPenjual(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      final result = await _repository.storePenjual(data);
      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      } else {
        await fetchResources('penjual', refresh: true);
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
      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      } else {
        await fetchResources('supir', refresh: true);
      }
      return result;
    } catch (e) {
      debugPrint('Error adding supir: $e');
      _errorMessage = e.toString();
      return null;
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
      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      } else {
        await fetchResources('pekerja', refresh: true);
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
      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      } else {
        await fetchAllResources();
      }
      return result;
    } catch (e) {
      debugPrint('Error adding kendaraan: $e');
      _errorMessage = e.toString();
      return null;
    }
  }

  Future<dynamic> addOperasional(Map<String, dynamic> data) async {
    _errorMessage = null;
    try {
      final result = await _repository.storeOperasional(data);
      if (result is Map && result['offline'] == true) {
        _errorMessage = 'offline';
      } else {
        await fetchAllResources();
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

  Future<bool> updateAppSettings(String version, String creator) async {
    _isLoading = true;
    notifyListeners();
    try {
      final data = {'app_version': version, 'app_creator': creator};
      final settings = await _repository.updateAppSettings(data);
      _appVersion = settings['app_version'] ?? version;
      _appCreator = settings['app_creator'] ?? creator;
      _appLogoUrl = ApiConstants.normalizeUrl(settings['app_logo_url']);
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
      return true;
    } catch (e) {
      debugPrint('Error deleting $type: $e');
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
}
