import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/services/sync_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handler notifikasi saat app di background/terminated (top-level function wajib)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  // Catatan: Jangan panggil _showLocalNotification di background handler jika payload FCM memiliki objek 'notification'.
  // Firebase SDK secara otomatis menampilkan notifikasi sistem ketika aplikasi berada di background/terminated.
  // Memanggil _showLocalNotification di sini akan menyebabkan notifikasi ganda (duplicate).
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'transaksi_channel_v4';
  static const String _channelName = 'Notifikasi Transaksi';
  static const String _channelDesc =
      'Notifikasi transaksi DO, saldo, dan operasional';

  static Future<void> initialize() async {
    try {
      debugPrint('FCM DEBUG: Memulai inisialisasi PushNotificationService...');
      await _initLocalNotifications();
      await _initFCM();
      debugPrint('FCM DEBUG: Inisialisasi selesai dengan sukses.');
    } catch (e) {
      debugPrint('FCM DEBUG ERROR: Gagal inisialisasi total: $e');
    }
  }

  static Future<void> _initLocalNotifications() async {
    try {
      const AndroidInitializationSettings androidSettings =
          AndroidInitializationSettings('@mipmap/ic_launcher');

      const InitializationSettings initSettings = InitializationSettings(
        android: androidSettings,
      );

      debugPrint('FCM DEBUG: Menginisialisasi flutter_local_notifications...');
      final initResult = await _localNotifications.initialize(
        settings: initSettings,
        onDidReceiveNotificationResponse: _onNotificationTap,
      );
      debugPrint('FCM DEBUG: flutter_local_notifications diinisialisasi. Status: $initResult');

      // Pola getar kuat: Jeda 0ms, Getar 1 detik, Jeda 0.5 detik, Getar 1 detik, Jeda 0.5 detik, Getar 1.5 detik
      final Int64List vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1500]);

      // Buat notification channel dengan suara default dan kepentingan maksimal
      final AndroidNotificationChannel channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
      );

      final androidPlugin = _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(channel);
        debugPrint('FCM DEBUG: Berhasil membuat AndroidNotificationChannel: $_channelId');
      } else {
        debugPrint('FCM DEBUG WARNING: AndroidFlutterLocalNotificationsPlugin NULL, tidak dapat membuat saluran!');
      }
    } catch (e) {
      debugPrint('FCM DEBUG ERROR: Gagal inisialisasi notifikasi lokal: $e');
    }
  }

  static Future<void> _initFCM() async {
    try {
      final messaging = FirebaseMessaging.instance;

      debugPrint('FCM DEBUG: Meminta izin notifikasi...');
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      debugPrint('FCM DEBUG: Status Izin Notifikasi: ${settings.authorizationStatus}');

      if (settings.authorizationStatus == AuthorizationStatus.authorized) {
        debugPrint('FCM DEBUG: Izin notifikasi resmi diberikan oleh user.');
      } else {
        debugPrint('FCM DEBUG WARNING: Izin notifikasi DITOLAK atau belum disetujui!');
      }

      // Handler saat app di foreground — tampilkan notifikasi lokal
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('FCM DEBUG foreground: Pesan masuk! Judul: "${message.notification?.title}", Isi: "${message.notification?.body}"');
        _showLocalNotification(message);
        
        // Sinkronisasi data di background agar UI (seperti bell count) langsung update
        SyncService().syncNow();
      });

      // Handler saat user tap notifikasi dari background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        debugPrint('FCM DEBUG onMessageOpenedApp: User mengetuk notifikasi! Data: ${message.data}');
        SyncService().syncNow();
      });

      // Handler background (top-level function)
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

      // Cek apakah app dibuka dari terminated state
      final initialMessage = await messaging.getInitialMessage();
      if (initialMessage != null) {
        debugPrint('FCM DEBUG initial message: Aplikasi dibuka dari posisi mati melalui notifikasi! Data: ${initialMessage.data}');
      }
    } catch (e) {
      debugPrint('FCM DEBUG ERROR: Gagal setup FCM: $e');
    }
  }

  /// Tampilkan notifikasi lokal dengan suara (untuk pesan foreground)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    try {
      final notification = message.notification;
      if (notification == null) {
        debugPrint('FCM DEBUG: RemoteMessage tidak memiliki payload notification, lewati.');
        return;
      }

      debugPrint('FCM DEBUG: Mempersiapkan untuk menampilkan local notification...');
      final Int64List vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1500]);

      final AndroidNotificationDetails androidDetails =
          AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.max,
        priority: Priority.high,
        playSound: true,
        enableVibration: true,
        vibrationPattern: vibrationPattern,
        icon: '@mipmap/ic_launcher',
      );

      const NotificationDetails details = NotificationDetails(
        android: androidDetails,
      );

      await _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: details,
        payload: jsonEncode(message.data),
      );
      debugPrint('FCM DEBUG: Berhasil menampilkan local notification ke layar!');
    } catch (e) {
      debugPrint('FCM DEBUG ERROR: Gagal memanggil _localNotifications.show: $e');
    }
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint('FCM DEBUG: Notifikasi diketuk oleh pengguna. Type: ${data['type']}');
      } catch (e) {
        debugPrint('FCM DEBUG ERROR: Gagal parsing payload tap notifikasi: $e');
      }
    }
  }

  /// Register FCM token ke backend Laravel setelah login
  static Future<void> registerTokenToBackend(String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      if (!notificationsEnabled) {
        debugPrint('FCM: Notifikasi dinonaktifkan oleh user, skip register token');
        return;
      }

      debugPrint('FCM: Mengambil token...');
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint('FCM: Token null, skip register');
        return;
      }
      debugPrint('FCM TOKEN: $fcmToken');
      // Selalu daftarkan ke backend untuk memastikan token sinkron di database backend

      final deviceId = Platform.isAndroid
          ? 'android_${fcmToken.substring(0, 16)}'
          : 'ios_${fcmToken.substring(0, 16)}';

      final dio = Dio();
      final response = await dio.post(
        '${ApiConstants.baseUrl}/fcm/token',
        data: {
          'token': fcmToken,
          'device_id': deviceId,
          'platform': Platform.isAndroid ? 'android' : 'ios',
        },
        options: Options(headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        }),
      );

      if (response.statusCode == 200) {
        await prefs.setString('fcm_token', fcmToken);
        debugPrint('FCM: Token terdaftar ke backend');
      }
    } catch (e) {
      debugPrint('FCM registerToken error: $e');
    }
  }

  /// Hapus FCM token dari backend saat logout
  static Future<void> unregisterTokenFromBackend(String authToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final fcmToken = prefs.getString('fcm_token');
      if (fcmToken == null) return;

      final dio = Dio();
      await dio.delete(
        '${ApiConstants.baseUrl}/fcm/token',
        data: {'token': fcmToken},
        options: Options(headers: {
          'Authorization': 'Bearer $authToken',
          'Accept': 'application/json',
        }),
      );

      await prefs.remove('fcm_token');
      debugPrint('FCM: Token dihapus dari backend');
    } catch (e) {
      debugPrint('FCM unregisterToken error: $e');
    }
  }
}
