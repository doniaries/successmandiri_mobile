import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/core/navigation/navigation_service.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/services/database_service.dart';
import 'package:sawitappmobile/core/services/notification_service.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';

class SyncService {
  static final SyncService _instance = SyncService._internal();
  final DatabaseService _db = DatabaseService();
  final ApiClient _apiClient = ApiClient();
  final NotificationService _notificationService = NotificationService();
  bool _isSyncing = false;
  
  final ValueNotifier<int> pendingSyncCount = ValueNotifier(0);

  factory SyncService() => _instance;

  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  SyncService._internal() {
    updatePendingCount();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      final wasOffline = _isOffline;
      _isOffline = results.any((r) => r == ConnectivityResult.none);
      _connectivityController.add(!_isOffline);

      if (!_isOffline) {
        // Koneksi kembali → sync data yang tertunda
        syncNow();
      } else if (!wasOffline && _isOffline) {
        // Baru saja offline → cek apakah ada data pending
        _notifyOfflineIfHasPending();
      }
    });

    // Initial check
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.any((r) => r == ConnectivityResult.none);
      _connectivityController.add(!_isOffline);
      // Jika langsung offline saat app dibuka dan ada pending, beri tahu user
      if (_isOffline) {
        _notifyOfflineIfHasPending();
      }
    });
  }

  /// Tampilkan notifikasi lokal jika ada data pending saat offline
  Future<void> _notifyOfflineIfHasPending() async {
    try {
      final queue = await _db.query('offline_queue');
      if (queue.isEmpty) return;

      final endpoints = queue
          .map((item) => _getProcessName(item['endpoint'] as String))
          .toSet()
          .toList();
      final processNames = endpoints.join(', ');

      await _notificationService.showOfflineNotification(
        pendingCount: queue.length,
        processNames: processNames,
      );
    } catch (e) {
      debugPrint('Error notifying offline pending: \$e');
    }
  }

  Future<void> updatePendingCount() async {
    try {
      final queue = await _db.query('offline_queue');
      pendingSyncCount.value = queue.length;
    } catch (e) {
      debugPrint('Error updating pending count: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOfflineQueueForEndpoint(String endpointMatch) async {
    try {
      final queue = await _db.query('offline_queue');
      List<Map<String, dynamic>> results = [];
      for (var item in queue) {
        final endpoint = item['endpoint'] as String;
        if (endpoint.contains(endpointMatch)) {
          final data = jsonDecode(item['data'] as String);
          results.add({
            'id': -1 * (item['id'] as int),
            'data': data,
          });
        }
      }
      return results;
    } catch (e) {
      debugPrint('Error getting offline queue: $e');
      return [];
    }
  }

  /// Menggabungkan data dari tabel lokal dengan data yang masih ada di antrean offline (offline_queue).
  /// Ini memastikan item yang baru ditambahkan secara offline langsung muncul di daftar saat offline.
  Future<List<Map<String, dynamic>>> getMergedOfflineData(String table, String endpoint) async {
    try {
      List<Map<String, dynamic>> list = [];
      try {
        final localData = await _db.query(table);
        list = List<Map<String, dynamic>>.from(localData.map((e) => Map<String, dynamic>.from(e)));
      } catch (e) {
        // Table doesn't exist (e.g. operasional, transaksi_do), it's fine, we just want the offline queue
      }

      final queue = await _db.query('offline_queue');
      for (var item in queue) {
        final qEndpoint = item['endpoint'].toString();
        final method = item['method'].toString();
        final qId = item['id'] as int;

        if (qEndpoint == endpoint && method == 'POST') {
          try {
            final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;
            data['id'] = -1 * qId; // ID negatif sementara untuk offline
            list.add(data);
          } catch (_) {}
        } else if (qEndpoint.startsWith('$endpoint/') && method == 'PUT') {
          try {
            final data = jsonDecode(item['data'] as String) as Map<String, dynamic>;
            final idStr = qEndpoint.split('/').last;
            final id = int.tryParse(idStr);
            if (id != null) {
              final index = list.indexWhere((p) => p['id'] == id);
              if (index != -1) {
                list[index].addAll(data);
              }
            }
          } catch (_) {}
        }
      }
      return list;
    } catch (e) {
      debugPrint('Error merging offline data for $table: $e');
      return [];
    }
  }

  Future<void> deleteFromQueue(int id) async {
    try {
      await _db.deleteQueue(id);
      await updatePendingCount();
    } catch (e) {
      debugPrint('Error deleting from queue: $e');
    }
  }

  Future<void> updateQueueData(int id, Map<String, dynamic> newData) async {
    try {
      final queue = await _db.query('offline_queue');
      final item = queue.firstWhere((q) => q['id'] == id, orElse: () => {});
      if (item.isNotEmpty) {
        final existingData = jsonDecode(item['data'] as String) as Map<String, dynamic>;
        existingData.addAll(newData);
        
        final db = await DatabaseService().database;
        if (db != null) {
          await db.update(
            'offline_queue',
            {'data': jsonEncode(existingData)},
            where: 'id = ?',
            whereArgs: [id],
          );
        }
      }
    } catch (e) {
      debugPrint('Error updating queue: $e');
    }
  }

  Future<void> addToQueue(String endpoint, String method, Map<String, dynamic> data) async {
    await _db.insert('offline_queue', {
      'endpoint': endpoint,
      'method': method,
      'data': jsonEncode(data),
    });
    await updatePendingCount();
    syncNow();
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;
    
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final queue = await _db.query('offline_queue');
    if (queue.isEmpty) return;

    _isSyncing = true;
    int successCount = 0;
    // Kumpulkan endpoints yang BENAR-BENAR berhasil (fix bug take(successCount))
    final List<String> syncedEndpoints = [];

    try {
      final syncTasks = queue.map((item) async {
        final id = item['id'] as int;
        final endpoint = item['endpoint'] as String;
        final method = item['method'] as String;
        final data = jsonDecode(item['data'] as String);

        try {
          if (method == 'POST') {
            await _apiClient.dio.post(endpoint, data: data);
          } else if (method == 'PUT') {
            await _apiClient.dio.put(endpoint, data: data);
          } else if (method == 'DELETE') {
            await _apiClient.dio.delete(endpoint);
          }
          await _db.deleteQueue(id);
          return _getProcessName(endpoint); // sukses
        } catch (e) {
          dev.log('Sync failed for item $id: $e');
          return null; // gagal
        }
      });

      final results = await Future.wait(syncTasks);
      
      for (var res in results) {
        if (res != null) {
          successCount++;
          syncedEndpoints.add(res);
        }
      }

      if (successCount > 0) {
        final uniqueEndpoints = syncedEndpoints.toSet().toList();
        final processNames = uniqueEndpoints.join(', ');
        final title = uniqueEndpoints.length == 1
            ? '✅ ${uniqueEndpoints.first} Berhasil'
            : '✅ Sinkronisasi Berhasil';
        final body = uniqueEndpoints.length == 1
            ? '$successCount data $processNames telah dikirim ke server.'
            : '$successCount data ($processNames) berhasil disinkronkan.';

        await _notificationService.showNotification(
          id: 999,
          title: title,
          body: body,
        );

        // Auto-refresh UI jika aplikasi sedang terbuka
        try {
          final context = NavigationService.navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final rp = Provider.of<ResourceProvider>(context, listen: false);
            final dp = Provider.of<DashboardProvider>(context, listen: false);
            rp.fetchAllResources();
            dp.fetchSummary();
          }
        } catch (_) {}
      }
    } finally {
      _isSyncing = false;
      updatePendingCount();
    }
  }

  /// Konversi endpoint API ke nama proses yang mudah dibaca
  String _getProcessName(String endpoint) {
    if (endpoint.contains('tambah-saldo')) return 'Tambah Saldo';
    if (endpoint.contains('transaksi-do')) return 'Transaksi DO';
    if (endpoint.contains('operasional')) return 'Operasional';
    if (endpoint.contains('penjual')) return 'Data Penjual';
    if (endpoint.contains('supir')) return 'Data Supir';
    if (endpoint.contains('pekerja')) return 'Data Pekerja';
    if (endpoint.contains('kendaraan')) return 'Data Kendaraan';
    if (endpoint.contains('pembayaran-hutang')) return 'Bayar Hutang';
    if (endpoint.contains('lansir')) return 'Lansir';
    return 'Data';
  }


  Future<void> cacheData(String table, List<dynamic> list) async {
    List<Map<String, dynamic>> mappedList = [];
    
    for (var item in list) {
      if (item is Map) {
        try {
          Map<String, dynamic> mappedData = {};
          
          if (table == 'penjual') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'alamat': item['alamat'],
              'sisa_hutang': double.tryParse(item['sisa_hutang']?.toString() ?? '0'),
              'is_active': (item['is_active'] == true || item['is_active'] == 1 || item['is_active'] == '1') ? 1 : 0,
            };
          } else if (table == 'supir') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'sim': item['sim'],
              'sisa_hutang': double.tryParse(item['sisa_hutang']?.toString() ?? '0'),
              'is_active': (item['is_active'] == true || item['is_active'] == 1 || item['is_active'] == '1') ? 1 : 0,
            };
          } else if (table == 'pekerja') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'sisa_hutang': double.tryParse(item['sisa_hutang']?.toString() ?? '0'),
              'perusahaan_id': item['perusahaan_id'],
              'is_active': (item['is_active'] == true || item['is_active'] == 1 || item['is_active'] == '1') ? 1 : 0,
            };
          } else if (table == 'kendaraan') {
            mappedData = {
              'id': item['id'],
              'no_polisi': item['no_polisi'],
              'merk': item['merk'],
              'tipe': item['tipe'],
            };
          } else if (table == 'users') {
            mappedData = {
              'id': item['id'],
              'name': item['name'],
              'email': item['email'],
              'role': item['role'],
            };
          } else if (table == 'perusahaans') {
            mappedData = {
              'id': item['id'],
              'name': item['name'],
              'logo_url': item['logo_url'],
            };
          } else if (table == 'transaksi_do') {
            mappedData = {
              'id': item['id'],
              'nomor': item['nomor'],
              'tanggal': item['tanggal'],
              'penjual_nama': item['penjual_nama'] ?? item['penjual']?['nama'],
              'supir_nama': item['supir_nama'] ?? item['supir']?['nama'],
              'sub_total': double.tryParse(item['sub_total']?.toString() ?? '0'),
              'sisa_bayar': double.tryParse(item['sisa_bayar']?.toString() ?? '0'),
            };
          }

          if (mappedData.isNotEmpty) {
            mappedList.add(mappedData);
          }
        } catch (e) {
          debugPrint('Error mapping data for $table: $e');
        }
      }
    }

    await _db.clearTable(table);
    if (mappedList.isNotEmpty) {
      await _db.batchInsert(table, mappedList);
    }
  }

  // Method to sync all master data from web to local DB
  Future<void> performFullSync(dynamic repository) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      // Sesuai permintaan: Hanya sinkronkan data yang dibutuhkan di awal (Dashboard, DO, Laporan)
      // Master data (Supir, Penjual, Pekerja, Kendaraan) akan dimuat per halaman saat dibutuhkan.
      
      // Sync Users (Karyawan) - Biasanya datanya kecil dan sering dibutuhkan

      try {
        final response = await _apiClient.dio.get('/users');
        if (response.data != null) {
          final List<dynamic> userData = response.data is List ? response.data : (response.data['data'] ?? []);
          await cacheData('users', userData);
        }
      } catch (e) {
        debugPrint('Error syncing users: $e');
      }

      // Sync Perusahaans (Unit Bisnis)
      try {
        final response = await _apiClient.dio.get('/perusahaans');
        if (response.data != null) {
          final List<dynamic> compData = response.data is List ? response.data : (response.data['data'] ?? []);
          await cacheData('perusahaans', compData);
        }
      } catch (e) {
        debugPrint('Error syncing companies: $e');
      }

      debugPrint('Full sync completed successfully');
    } catch (e) {
      debugPrint('Full sync failed: $e');
    }
  }
}

