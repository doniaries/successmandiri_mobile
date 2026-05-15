import 'dart:async';
import 'dart:convert';
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

  SyncService._internal() {
    updatePendingCount();
    // Listen for connectivity changes
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (results.any((r) => r != ConnectivityResult.none)) {
        syncNow();
      }
    });
  }

  Future<void> updatePendingCount() async {
    final queue = await _db.query('offline_queue');
    pendingSyncCount.value = queue.length;
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
          continue;
        }
      }

      if (successCount > 0) {
        await _notificationService.showNotification(
          id: 999,
          title: 'Sinkronisasi Berhasil',
          body: '$successCount data telah berhasil disinkronkan ke server.',
        );
      }
    } finally {
      _isSyncing = false;
      updatePendingCount();
    }
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

