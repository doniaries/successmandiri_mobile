import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/navigation/navigation_service.dart';
import 'package:sawitappmobile/features/auth/screens/login_screen.dart';
import 'package:dio_smart_retry/dio_smart_retry.dart';

// Top-level functions untuk mencegah ANR saat jsonDecode string yang sangat besar
dynamic _parseAndDecode(String response) {
  return jsonDecode(response);
}

Future<dynamic> _parseJson(String text) {
  return compute(_parseAndDecode, text);
}

class ApiClient {
  late Dio _dio;
  static bool _isRedirecting = false;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 5),  // Fast connection timeout for offline fallback
      receiveTimeout: const Duration(seconds: 15), // Cukup untuk response besar
      sendTimeout: const Duration(seconds: 5),     // Fast send timeout for mutations
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    // Menggunakan Isolate (compute) untuk memproses respon JSON di background
    _dio.transformer = SyncTransformer()..jsonDecodeCallback = _parseJson;

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Tidak perlu prefs.reload() setiap request — token hanya berubah saat login/logout
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
      onResponse: (response, handler) {
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.reload(); // Pastikan kita mendapat data terbaru dari memory/disk di semua isolate
          final currentToken = prefs.getString('auth_token');
          
          // Token yang digunakan di request ini
          final requestToken = e.requestOptions.headers['Authorization']?.toString().replaceAll('Bearer ', '');
          
          // Hanya hapus token dan redirect JIKA token yang ditolak ADALAH token yang saat ini aktif
          // Jika tidak sama, berarti ini adalah request kadaluarsa (misal dari isolate background)
          if (currentToken != null && requestToken == currentToken && !_isRedirecting) {
            _isRedirecting = true;
            await prefs.remove('auth_token');
            await prefs.remove('cached_user');
            
            // Redirect ke Login jika navigator tersedia (berarti kita di UI isolate)
            if (NavigationService.navigatorKey.currentState != null) {
              NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
                MaterialPageRoute(builder: (context) => const LoginScreen()),
                (route) => false,
              ).then((_) {
                _isRedirecting = false;
              });
            } else {
              _isRedirecting = false;
            }
          }
        }
        return handler.next(e);
      },
    ));

    // RetryInterceptor: delay lebih singkat agar recovery lebih cepat
    _dio.interceptors.add(
      RetryInterceptor(
        dio: _dio,
        logPrint: debugPrint,
        retries: 2, // 2 retry sudah cukup untuk network transient error
        retryDelays: const [
          Duration(milliseconds: 500), // Retry cepat pertama
          Duration(seconds: 1),        // Retry kedua dengan jeda 1 detik
        ],
      ),
    );
  }

  Dio get dio => _dio;
}

