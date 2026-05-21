import 'package:flutter/foundation.dart';

class ApiConstants {
  // Set true untuk mengarahkan ke local server saat didebug, atau false untuk selalu ke produksi
  static const bool useLocalInDebug = false;

  static String get baseUrl {
    if (kDebugMode && useLocalInDebug) {
      // Pilihlah salah satu URL di bawah ini sesuai setup Anda:

      // Karena Anda menggunakan HP asli, kita akan gunakan IP Wi-Fi lokal komputer Anda.
      return 'http://192.168.1.8/successmandiri_laravel/public/api';
    }pada tab aktif dan aktif

    // Produksi (Online)
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
