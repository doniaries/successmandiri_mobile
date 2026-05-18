import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Handler notifikasi saat app di background/terminated (top-level function wajib)
@pragma('vm:entry-point')
Future<void> firebaseBackgroundMessageHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  await PushNotificationService._showLocalNotification(message);
}

class PushNotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static const String _channelId = 'transaksi_channel';
  static const String _channelName = 'Notifikasi Transaksi';
  static const String _channelDesc =
      'Notifikasi transaksi DO, saldo, dan operasional';

  static Future<void> initialize() async {
    await _initLocalNotifications();
    await _initFCM();
  }

  static Future<void> _initLocalNotifications() async {
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    // Versi terbaru flutter_local_notifications menggunakan named parameter
    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Buat notification channel dengan suara default
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  static Future<void> _initFCM() async {
    final messaging = FirebaseMessaging.instance;

    // Minta izin notifikasi Android
    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('FCM: Izin notifikasi diberikan');
    }

    // Handler saat app di foreground — tampilkan notifikasi lokal
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM foreground: ${message.notification?.title}');
      _showLocalNotification(message);
    });

    // Handler saat user tap notifikasi dari background
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint('FCM onMessageOpenedApp: ${message.data}');
    });

    // Handler background (top-level function)
    FirebaseMessaging.onBackgroundMessage(firebaseBackgroundMessageHandler);

    // Cek apakah app dibuka dari terminated state
    final initialMessage = await messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('FCM initial message: ${initialMessage.data}');
    }
  }

  /// Tampilkan notifikasi lokal dengan suara (untuk pesan foreground)
  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDesc,
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    // Versi terbaru flutter_local_notifications pakai named parameters
    await _localNotifications.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: details,
      payload: jsonEncode(message.data),
    );
  }

  static void _onNotificationTap(NotificationResponse response) {
    if (response.payload != null) {
      try {
        final data = jsonDecode(response.payload!) as Map<String, dynamic>;
        debugPrint('Notification tapped, type: ${data['type']}');
      } catch (_) {}
    }
  }

  /// Register FCM token ke backend Laravel setelah login
  static Future<void> registerTokenToBackend(String authToken) async {
    try {
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        debugPrint('FCM: Token null, skip register');
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      final savedToken = prefs.getString('fcm_token');

      // Hanya daftarkan ulang jika token berubah
      if (savedToken == fcmToken) {
        debugPrint('FCM: Token tidak berubah, skip');
        return;
      }

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
