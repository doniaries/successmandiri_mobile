import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _notificationsPlugin = FlutterLocalNotificationsPlugin();

  factory NotificationService() => _instance;

  NotificationService._internal();

  Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    await _notificationsPlugin.initialize(settings: initializationSettings);
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'sync_channel',
      'Data Synchronization',
      channelDescription: 'Notifications for data background sync',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
    );

    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );

    await _notificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
    );
    // popToHome() dihapus — user tidak boleh dipaksa kembali ke home setiap sync
  }

  /// Notifikasi khusus saat offline dan ada data pending yang belum tersync
  Future<void> showOfflineNotification({
    required int pendingCount,
    required String processNames,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'offline_sync_channel',
      'Sinkronisasi Offline',
      channelDescription: 'Pemberitahuan data yang menunggu sinkronisasi saat online',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
      showWhen: true,
      ongoing: false,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notificationsPlugin.show(
      id: 998,
      title: '📶 Anda Sedang Offline',
      body: '$pendingCount data ($processNames) akan dikirim otomatis saat sinyal kembali.',
      notificationDetails: details,
    );
  }
}
