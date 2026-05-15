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
    return await openDatabase(path, version: 1, onCreate: _onCreate);
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
    await db.execute('''
      CREATE TABLE penjual (id INTEGER PRIMARY KEY, nama TEXT, telepon TEXT, alamat TEXT, sisa_hutang REAL DEFAULT 0)
    ''');
    await db.execute('''
      CREATE TABLE supir (id INTEGER PRIMARY KEY, nama TEXT, telepon TEXT, sim TEXT, sisa_hutang REAL DEFAULT 0)
    ''');
    await db.execute('''
      CREATE TABLE pekerja (id INTEGER PRIMARY KEY, nama TEXT, telepon TEXT, sisa_hutang REAL DEFAULT 0, perusahaan_id INTEGER)
    ''');
    await db.execute('''
      CREATE TABLE kendaraan (id INTEGER PRIMARY KEY, no_polisi TEXT, merk TEXT, tipe TEXT)
    ''');
    await db.execute('''
      CREATE TABLE users (id INTEGER PRIMARY KEY, name TEXT, email TEXT, role TEXT)
    ''');
    await db.execute('''
      CREATE TABLE perusahaans (id INTEGER PRIMARY KEY, name TEXT, logo_url TEXT)
    ''');
    await db.execute('''
      CREATE TABLE transaksi_do (
        id INTEGER PRIMARY KEY, nomor TEXT, tanggal TEXT,
        penjual_nama TEXT, supir_nama TEXT, sub_total REAL, sisa_bayar REAL
      )
    ''');
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

  Future<void> batchInsert(String table, List<Map<String, dynamic>> list) async {
    if (kIsWeb) return;
    final db = await database;
    final batch = db!.batch();
    for (var data in list) {
      batch.insert(table, data, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }
}
