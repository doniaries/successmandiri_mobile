import 'dart:async';
import 'dart:convert';
import 'dart:developer' as dev;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/services/database_service.dart';
import 'package:sawitappmobile/core/services/notification_service.dart';

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
      _isOffline = results.any((r) => r == ConnectivityResult.none);
      _connectivityController.add(!_isOffline);
      
      if (!_isOffline) {
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
      final queue = await _db.query('offline_queue');
      pendingSyncCount.value = queue.length;
    } catch (e) {
      debugPrint('Error updating pending count: $e');
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
    
    try {
      for (var item in queue) {
        final id = item['id'] as int;
        final endpoint = item['endpoint'] as String;
        final method = item['method'] as String;
        final data = jsonDecode(item['data'] as String);

        try {
          if (method == 'POST') {
            await _apiClient.dio.post(endpoint, data: data);
          } else if (method == 'PUT') {
            await _apiClient.dio.put(endpoint, data: data);
          }
          await _db.deleteQueue(id);
          successCount++;
        } catch (e) {
          dev.log('Sync failed for item ${item['id']}: $e');
          continue;
        }
      }

      if (successCount > 0) {
        // Buat pesan notifikasi berdasarkan endpoint yang berhasil disinkronkan
        final syncedEndpoints = queue
            .take(successCount)
            .map((item) => _getProcessName(item['endpoint'] as String))
            .toSet()
            .toList();

        final processNames = syncedEndpoints.join(', ');
        final title = syncedEndpoints.length == 1
            ? '✅ ${syncedEndpoints.first} Berhasil'
            : '✅ Sinkronisasi Berhasil';
        final body = syncedEndpoints.length == 1
            ? '$successCount data $processNames telah dikirim ke server.'
            : '$successCount data ($processNames) berhasil disinkronkan.';

        await _notificationService.showNotification(
          id: 999,
          title: title,
          body: body,
        );
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
      if (item is Map<String, dynamic>) {
        try {
          Map<String, dynamic> mappedData = {};
          
          if (table == 'penjual') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'alamat': item['alamat'],
              'sisa_hutang': double.tryParse(item['sisa_hutang']?.toString() ?? '0'),
            };
          } else if (table == 'supir') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'sim': item['sim'],
              'sisa_hutang': double.tryParse(item['sisa_hutang']?.toString() ?? '0'),
            };
          } else if (table == 'pekerja') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'sisa_hutang': double.tryParse(item['sisa_hutang']?.toString() ?? '0'),
              'perusahaan_id': item['perusahaan_id'],
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

    if (mappedList.isNotEmpty) {
      await _db.batchInsert(table, mappedList);
    }
  }

  // Method to sync all master data from web to local DB
  Future<void> performFullSync(dynamic repository) async {
    final connectivity = await Connectivity().checkConnectivity();
    if (connectivity.contains(ConnectivityResult.none)) return;

    try {
      // Sync Penjual
      await repository.getPenjuals();
      // getPenjuals already calls cacheData, but we can be explicit if needed
      
      // Sync Supir
      await repository.getSupirs();
      
      // Sync Pekerja
      await repository.getPekerjas();
      
      // Sync Kendaraan
      await repository.getKendaraans();

      // Sync Users (Karyawan)
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

