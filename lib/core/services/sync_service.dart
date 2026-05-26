import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sawitappmobile/core/navigation/navigation_service.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/services/database_service.dart';
import 'package:sawitappmobile/core/services/notification_service.dart';
import 'package:sawitappmobile/shared/providers/resource_provider.dart';
import 'package:sawitappmobile/features/dashboard/providers/dashboard_provider.dart';
import 'package:sawitappmobile/features/tambah_saldo/providers/tambah_saldo_provider.dart';
import 'package:sawitappmobile/features/transaksi_do/providers/transaksi_do_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';

List<Map<String, dynamic>> _mapDataForDb(List<dynamic> list) {
  List<Map<String, dynamic>> mappedList = [];
  for (var item in list) {
    if (item is Map) {
      try {
        if (item['id'] != null) {
          final mappedItem = {
            'id': item['id'],
            'data': jsonEncode(item),
          };
          if (item.containsKey('tanggal') && item['tanggal'] != null) {
            final t = item['tanggal'].toString();
            if (t.length >= 10) {
              mappedItem['tanggal'] = t.substring(0, 10);
            } else {
              mappedItem['tanggal'] = t;
            }
          }
          mappedList.add(mappedItem);
        }
      } catch (_) {}
    }
  }
  return mappedList;
}

class SyncService {
  static final SyncService _instance = SyncService._internal();
  final DatabaseService _db = DatabaseService();
  final ApiClient _apiClient = ApiClient();
  final NotificationService _notificationService = NotificationService();
  bool _isSyncing = false;
  bool _cancelRequested = false;
  CancelToken? _cancelToken;

  final ValueNotifier<int> pendingSyncCount = ValueNotifier(0);

  factory SyncService() => _instance;

  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();
  Stream<bool> get connectivityStream => _connectivityController.stream;
  bool _isOffline = false;
  bool get isOffline => _isOffline;

  SyncService._internal() {
    updatePendingCount();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((
      List<ConnectivityResult> results,
    ) {
      _isOffline = results.any((r) => r == ConnectivityResult.none);
      _connectivityController.add(!_isOffline);

      if (!_isOffline) {
        // Koneksi kembali → sync data yang tertunda
        syncNow();
      }
    });

    // Initial check
    Connectivity().checkConnectivity().then((results) {
      _isOffline = results.any((r) => r == ConnectivityResult.none);
      _connectivityController.add(!_isOffline);
    });
  }

  Future<void> updatePendingCount() async {
    try {
      final db = await DatabaseService().database;
      if (db != null) {
        // Hanya menarik 1 angka murni dari SQLite, jauh lebih cepat!
        int? count = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM offline_queue')
        );
        pendingSyncCount.value = count ?? 0;
      }
    } catch (e) {
      debugPrint('Error updating pending count: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getOfflineQueueForEndpoint(
    String endpointMatch,
  ) async {
    try {
      final queue = await _db.query('offline_queue');
      List<Map<String, dynamic>> results = [];
      for (var item in queue) {
        final endpoint = item['endpoint'] as String;
        if (endpoint.contains(endpointMatch)) {
          final data = jsonDecode(item['data'] as String);
          results.add({'id': -1 * (item['id'] as int), 'data': data});
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
  Future<List<Map<String, dynamic>>> getMergedOfflineData(
    String table,
    String endpoint, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
  }) async {
    try {
      final queue = await _db.query('offline_queue');
      final deletedIds = <int>{};
      for (var item in queue) {
        final qEndpoint = item['endpoint'].toString();
        final method = item['method'].toString();
        if (method == 'DELETE' && qEndpoint.startsWith('$endpoint/')) {
          final idStr = qEndpoint.split('/').last;
          final id = int.tryParse(idStr);
          if (id != null) {
            deletedIds.add(id);
          }
        }
      }

      final List<Map<String, dynamic>> list = [];

      try {
        final localData = await _db.query(table, where: where, whereArgs: whereArgs, orderBy: orderBy);
        for (var e in localData) {
          final id = e['id'];
          if (id != null && id is int && id <= 0) {
            continue; // Filter out id <= 0
          }
          if (id != null && id is int && deletedIds.contains(id)) {
            continue; // Filter out deleted items
          }
          if (e['data'] != null) {
            try {
              final parsed =
                  jsonDecode(e['data'] as String) as Map<String, dynamic>;
              list.add(parsed);
            } catch (_) {}
          }
        }
      } catch (e) {
        // Table doesn't exist (e.g. operasional, transaksi_do), it's fine, we just want the offline queue
      }

      for (var item in queue) {
        final qEndpoint = item['endpoint'].toString();
        final method = item['method'].toString();
        final qId = item['id'] as int;

        if (qEndpoint == endpoint && method == 'POST') {
          try {
            final data =
                jsonDecode(item['data'] as String) as Map<String, dynamic>;
            final offlineId = -1 * qId; // ID negatif sementara untuk offline
            if (deletedIds.contains(offlineId)) {
              continue;
            }
            data['id'] = offlineId;

            // --- 1. BERIKAN NILAI DEFAULT ---
            // Mencegah model .fromJson() error karena field backend tidak ada di form POST
            data['sisa_hutang'] ??= 0;
            data['is_active'] ??= 1;
            if (endpoint.contains('supir')) data['status_supir'] ??= 'Tersedia';
            if (endpoint.contains('operasional')) data['status'] ??= 'pending';

            // --- 2. UBAH .add MENJADI .insert ---
            // Agar data offline baru selalu muncul di urutan PALING ATAS list
            list.insert(0, data);
          } catch (e) {
            debugPrint('Error parsing offline queue item: $e');
          }
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
        final existingData =
            jsonDecode(item['data'] as String) as Map<String, dynamic>;
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

  Future<int> addToQueue(
    String endpoint,
    String method,
    Map<String, dynamic> data,
  ) async {
    final id = await _db.insert('offline_queue', {
      'endpoint': endpoint,
      'method': method,
      'data': jsonEncode(data),
    });
    await updatePendingCount();
    if (!_isOffline) {
      syncNow();
    }
    return id;
  }

  Future<void> syncNow() async {
    if (_isSyncing) return;

    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    final queue = await _db.query('offline_queue');
    if (queue.isEmpty) return;

    _isSyncing = true;
    _cancelRequested = false;
    _cancelToken = CancelToken();
    int successCount = 0;
    // Kumpulkan endpoints yang BENAR-BENAR berhasil (fix bug take(successCount))
    final List<String> syncedEndpoints = [];

    try {
      debugPrint(
        'SyncService.syncNow: starting sync. queue size=${queue.length}',
      );
      // Sequential sync instead of parallel
      for (var item in queue) {
        if (_cancelRequested) {
          dev.log('SyncService.syncNow: cancel requested, breaking loop');
          break;
        }

        final id = item['id'] as int;
        final endpoint = item['endpoint'] as String;
        final method = item['method'] as String;
        final data = jsonDecode(item['data'] as String);

        try {
          if (method == 'POST') {
            await _apiClient.dio.post(endpoint, data: data, cancelToken: _cancelToken);
          } else if (method == 'PUT') {
            await _apiClient.dio.put(endpoint, data: data, cancelToken: _cancelToken);
          } else if (method == 'DELETE') {
            await _apiClient.dio.delete(endpoint, cancelToken: _cancelToken);
          }
          await _db.deleteQueue(id);
          successCount++;
          syncedEndpoints.add(_getProcessName(endpoint));
          await updatePendingCount(); // Update UI immediately so counter goes down
          debugPrint(
            'SyncService.syncNow: item synced id=$id endpoint=$endpoint method=$method',
          );
        } catch (e) {
          dev.log('Sync failed for item $id: $e');
          if (e is DioException && e.response?.statusCode == 422) {
            dev.log('Item $id returned 422 Validation Error (possibly duplicate). Removing from queue.');
            await _db.deleteQueue(id);
            // Optionally, we could increment successCount, but it's technically a skip
            successCount++;
            syncedEndpoints.add(_getProcessName(endpoint));
            await updatePendingCount(); // Update UI immediately for skipped item
          }
        }
      }

      // Update UI immediately before heavy provider refresh
      await updatePendingCount();

      if (successCount > 0) {
        debugPrint(
          'SyncService.syncNow: successCount=$successCount, refreshing providers',
        );
        // Clear cached dashboard summary agar refresh dari server tanpa offline data
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('cached_dashboard_summary');
        } catch (_) {}

        // Auto-refresh UI jika aplikasi sedang terbuka, tunggu sampai selesai sebelum update notifikasi & UI state
        try {
          final context = NavigationService.navigatorKey.currentContext;
          if (context != null && context.mounted) {
            final rp = Provider.of<ResourceProvider>(context, listen: false);
            final dp = Provider.of<DashboardProvider>(context, listen: false);
            final tp = Provider.of<TambahSaldoProvider>(context, listen: false);
            final doProv = Provider.of<TransaksiDoProvider>(
              context,
              listen: false,
            );

            // Prefer sequential refresh to reduce race conditions
            debugPrint(
              'SyncService.syncNow: calling ResourceProvider.fetchAllResources',
            );
            await rp.fetchAllResources();
            // Ensure jurnal_keuangan is refreshed for ALL users (not only leaders)
            try {
              debugPrint(
                'SyncService.syncNow: forcing jurnal_keuangan refresh',
              );
              await rp.fetchResources('jurnal_keuangan', refresh: true);
              debugPrint(
                'SyncService.syncNow: jurnal_keuangan refresh completed',
              );
            } catch (e) {
              debugPrint(
                'SyncService.syncNow: jurnal_keuangan refresh failed: $e',
              );
            }
            debugPrint(
              'SyncService.syncNow: calling DashboardProvider.fetchSummary',
            );
            await dp.fetchSummary();
            debugPrint(
              'SyncService.syncNow: calling TambahSaldoProvider.fetchRequests',
            );
            await tp.fetchRequests();
            debugPrint(
              'SyncService.syncNow: calling TransaksiDoProvider.fetchTransactions',
            );
            await doProv.fetchTransactions();
          }
        } catch (_) {}

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

        // Also show an in-app SnackBar if app is foreground
        try {
          final ctx = NavigationService.navigatorKey.currentContext;
          if (ctx != null && ctx.mounted) {
            final scaffoldMessenger = ScaffoldMessenger.of(ctx);
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('$title\n$body'),
                duration: const Duration(seconds: 4),
                backgroundColor: Colors.green[700],
              ),
            );
          }
        } catch (_) {}
      }
    } finally {
      _isSyncing = false;
      _cancelRequested = false;
      _cancelToken = null;
      updatePendingCount();
    }
  }

  /// Request cancellation of a running sync. If a sync is in progress,
  /// this will cancel ongoing HTTP requests and stop processing further items.
  void cancelSync() {
    if (!_isSyncing) return;
    _cancelRequested = true;
    try {
      _cancelToken?.cancel('Cancelled by user');
    } catch (_) {}
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

  Future<void> cacheData(
    String table,
    List<dynamic> list, {
    bool clear = true,
  }) async {
    if (list.isEmpty) {
      if (clear) await _db.clearTable(table);
      return;
    }

    // Pindahkan komputasi berat (jsonEncode looping) ke Background Isolate
    // menggunakan fungsi compute bawaan Flutter agar Main Thread (UI) tidak freeze
    final mappedList = await compute(_mapDataForDb, list);

    if (clear) {
      await _db.clearTable(table);
    }
    
    // Beri jeda sangat singkat agar UI sempat bernapas (render frame) sebelum akses database
    await Future.delayed(const Duration(milliseconds: 10));

    if (mappedList.isNotEmpty) {
      await _db.batchInsert(table, mappedList);
    }
  }

  // Method to sync all master data from web to local DB
  Future<void> performFullSync(dynamic repository) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      // Sinkronisasi Master Data (Penjual, Supir, Pekerja, Kendaraan) agar tersedia offline seluruhnya
      try {
        await repository.getPenjuals();
        await repository.getSupirs();
        await repository.getPekerjas();
        await repository.getKendaraans();
      } catch (e) {
        debugPrint('Error syncing master data: $e');
      }

      // Sync Users (Karyawan) - Biasanya datanya kecil dan sering dibutuhkan

      try {
        final response = await _apiClient.dio.get('/users');
        if (response.data != null) {
          final List<dynamic> userData = response.data is List
              ? response.data
              : (response.data['data'] ?? []);
          await cacheData('users', userData);
        }
      } catch (e) {
        debugPrint('Error syncing users: $e');
      }

      // Sync Perusahaans (Unit Bisnis)
      try {
        final response = await _apiClient.dio.get('/perusahaans');
        if (response.data != null) {
          final List<dynamic> compData = response.data is List
              ? response.data
              : (response.data['data'] ?? []);
          await cacheData('perusahaans', compData);
        }
      } catch (e) {
        debugPrint('Error syncing companies: $e');
      }

      // Beri waktu Main Thread untuk bernapas kembali setelah sinkronisasi panjang
      await Future.delayed(const Duration(milliseconds: 50));

      debugPrint('Full sync completed successfully');
    } catch (e) {
      debugPrint('Full sync failed: $e');
    }
  }
}
