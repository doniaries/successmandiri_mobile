import 'package:flutter/foundation.dart';

class ApiConstants {
  static const bool useLocalInDebug = false; // true = IP lokal, false = produksi


  static String get baseUrl {
    if (kDebugMode && useLocalInDebug) {
      if (kIsWeb) return 'http://127.0.0.1:8000/api';
      return 'http://192.168.1.46:8000/api'; // IP Lokal Wi-Fi Laptop/PC
    }
    // Selalu gunakan Produksi (Online) agar data sinkron dengan sawit.successmandiri.com
    return 'https://sawit.successmandiri.com/api';
  }

  static String get storageUrl {
    return baseUrl.replaceFirst('/api', '/storage');
  }

  static String? normalizeUrl(String? url) {
    if (url == null || url.isEmpty) return null;

    if (!url.startsWith('http')) {
      final base = baseUrl.replaceAll('/api', '');
      return '$base/storage/$url';
    }

    try {
      final uri = Uri.parse(url);
      final apiUri = Uri.parse(baseUrl);

      final newUri = uri.replace(
        scheme: apiUri.scheme,
        host: apiUri.host,
        port: apiUri.port,
      );
      return newUri.toString();
    } catch (e) {
      return url;
    }
  }

  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';
  static const String transaksiDo = '/transaksi-do';
  static const String generateDoNumber = '/transaksi-do/generate-number';
  static const String tambahSaldo = '/tambah-saldo';
  static const String penjual = '/penjual';
  static const String supir = '/supir';
  static const String pekerja = '/pekerja';
  static const String kendaraan = '/kendaraan';
  static const String operasional = '/operasional';
  static const String jurnalKeuangan = '/jurnal-keuangan';
  static const String perusahaan = '/perusahaans';
  static const String switchPerusahaan = '/switch-perusahaan';
  static const String updateCompanyLogo = '/perusahaan/logo';
  static const String dashboardSummary = '/dashboard/summary';
  static const String appSettings = '/app-settings';
}
