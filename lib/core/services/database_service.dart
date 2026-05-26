import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  static Database? _database;

  factory DatabaseService() => _instance;

  DatabaseService._internal();

  Future<Database?> get database async {
    if (kIsWeb) return null;
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'successmandiri.db');
    return await openDatabase(
      path, 
      version: 3, 
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      try { await db.execute('ALTER TABLE penjual ADD COLUMN is_active INTEGER DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE supir ADD COLUMN is_active INTEGER DEFAULT 1'); } catch (_) {}
      try { await db.execute('ALTER TABLE pekerja ADD COLUMN is_active INTEGER DEFAULT 1'); } catch (_) {}
    }
    if (oldVersion < 3) {
      final oldTables = [
        'penjual', 'supir', 'pekerja', 'kendaraan', 'users', 'perusahaans', 'transaksi_do'
      ];
      for (var table in oldTables) {
        await db.execute('DROP TABLE IF EXISTS $table');
        await db.execute('CREATE TABLE $table (id INTEGER PRIMARY KEY, data TEXT)');
      }
      final newTables = ['operasional', 'jurnal_keuangan', 'tambah_saldo', 'pengajuan_dana'];
      for (var table in newTables) {
        await db.execute('CREATE TABLE IF NOT EXISTS $table (id INTEGER PRIMARY KEY, data TEXT)');
      }
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE offline_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        endpoint TEXT,
        method TEXT,
        data TEXT,
        timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    ''');
    
    final tables = [
      'penjual', 'supir', 'pekerja', 'kendaraan', 'users', 'perusahaans', 'transaksi_do',
      'operasional', 'jurnal_keuangan', 'tambah_saldo', 'pengajuan_dana'
    ];
    for (var table in tables) {
      await db.execute('CREATE TABLE $table (id INTEGER PRIMARY KEY, data TEXT)');
    }
  }

  Future<int> insert(String table, Map<String, dynamic> data) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db!.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> query(String table) async {
    if (kIsWeb) return [];
    final db = await database;
    return await db!.query(table);
  }

  Future<int> deleteQueue(int id) async {
    if (kIsWeb) return 0;
    final db = await database;
    return await db!.delete('offline_queue', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearTable(String table) async {
    if (kIsWeb) return;
    final db = await database;
    await db!.delete(table);
  }

  Future<void> clearAllTables() async {
    if (kIsWeb) return;
    final db = await database;
    final tables = [
      'penjual', 'supir', 'pekerja', 'kendaraan', 'users', 'perusahaans', 'transaksi_do',
      'operasional', 'jurnal_keuangan', 'tambah_saldo', 'pengajuan_dana'
    ];
    for (var table in tables) {
      await db!.delete(table);
    }
    // We intentionally keep offline_queue
  }

  Future<void> batchInsert(String table, List<Map<String, dynamic>> list) async {
    if (kIsWeb) return;
    final db = await database;
    
    // Chunking: proses data secara bertahap (misal 500 per chunk)
    // agar Thread UI tidak hang saat memproses puluhan ribu baris.
    const int chunkSize = 500;
    for (var i = 0; i < list.length; i += chunkSize) {
      final batch = db!.batch();
      final int end = (i + chunkSize < list.length) ? i + chunkSize : list.length;
      final chunk = list.sublist(i, end);
      
      for (var data in chunk) {
        batch.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
      
      // Beri jeda sangat singkat agar UI (Main Thread) bisa bernapas dan me-render frame.
      await Future.delayed(const Duration(milliseconds: 15));
    }
  }
}
