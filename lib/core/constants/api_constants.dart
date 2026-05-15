class ApiConstants {
  static String get baseUrl {
    // 1. IP Lokal (Gunakan port 8000 untuk Laravel Serve)
    return 'http://192.168.100.246:8000/api';

    // 2. Produksi (Hapus komentar rute di bawah jika sudah online)
    // return 'https://sawitapp.com/api';
  }

  static String get storageUrl {
    return baseUrl.replaceFirst('/api', '/storage');
  }

  static const String login = '/login';
  static const String logout = '/logout';
  static const String user = '/user';
  static const String transaksiDo = '/transaksi-do';
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
