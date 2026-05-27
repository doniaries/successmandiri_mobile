import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

class BackupService {
  static const String _dbName = 'successmandiri.db';

  Future<File?> getDatabaseFile() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = join(dbPath, _dbName);
      final file = File(path);
      if (await file.exists()) {
        return file;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting database file: $e');
      return null;
    }
  }

  Future<bool> backupAndShare(BuildContext context) async {
    try {
      final dbFile = await getDatabaseFile();
      if (dbFile == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('File database tidak ditemukan')),
          );
        }
        return false;
      }

      // Create a copy in temporary directory with timestamp
      final tempDir = await getTemporaryDirectory();
      final dateStr = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final backupFileName = 'successmandiri_backup_$dateStr.db';
      final backupPath = join(tempDir.path, backupFileName);
      
      final backupFile = await dbFile.copy(backupPath);
      
      if (context.mounted) {
        // ignore: deprecated_member_use
        final result = await Share.shareXFiles(
          [XFile(backupFile.path)],
          text: 'Backup Database Success Mandiri $dateStr',
        );
        
        if (result.status == ShareResultStatus.success) {
          return true;
        }
      }
      return true;
    } catch (e) {
      debugPrint('Error backing up database: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal backup database: $e')),
        );
      }
      return false;
    }
  }

  Future<void> automaticSilentBackup() async {
    try {
      final dbFile = await getDatabaseFile();
      if (dbFile == null) return;

      final docsDir = await getApplicationDocumentsDirectory();
      
      // Simpan backup dengan format per hari saja agar tidak menumpuk terlalu banyak
      final dateStr = DateFormat('yyyyMMdd').format(DateTime.now());
      final backupFileName = 'autobackup_$dateStr.db';
      final backupPath = join(docsDir.path, backupFileName);
      
      final backupFile = File(backupPath);
      if (!(await backupFile.exists())) {
        await dbFile.copy(backupPath);
        debugPrint('Auto backup successful: $backupPath');
        
        // Hapus backup lama (lebih dari 7 hari)
        final files = docsDir.listSync();
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        
        for (var file in files) {
          if (file is File && file.path.contains('autobackup_')) {
            final stat = await file.stat();
            if (stat.modified.isBefore(sevenDaysAgo)) {
              await file.delete();
              debugPrint('Deleted old backup: ${file.path}');
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error automatic silent backup: $e');
    }
  }
}
