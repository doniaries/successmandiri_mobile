import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import '../core/network/api_client.dart';
import 'database_service.dart';
import 'notification_service.dart';

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
            };
          } else if (table == 'supir') {
            mappedData = {
              'id': item['id'],
              'nama': item['nama'],
              'telepon': item['telepon'],
              'sim': item['sim'],
            };
          } else if (table == 'kendaraan') {
            mappedData = {
              'id': item['id'],
              'no_polisi': item['no_polisi'],
              'merk': item['merk'],
              'tipe': item['tipe'],
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
            await _db.insert(table, mappedData);
          }
        } catch (e) {
          // ignore error to prevent blocking UI
        }
      }
    }
  }
}

