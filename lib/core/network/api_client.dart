import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/navigation/navigation_service.dart';
import 'package:sawitappmobile/features/auth/screens/login_screen.dart';

class ApiClient {
  late Dio _dio;
  static bool _isRedirecting = false;

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 60),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      },
    ));

    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
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
          final currentToken = prefs.getString('auth_token');
          
          if (currentToken != null && !_isRedirecting) {
            _isRedirecting = true;
            await prefs.remove('auth_token');
            await prefs.remove('cached_user');
            
            // Redirect ke Login jika tidak di halaman login
            NavigationService.navigatorKey.currentState?.pushAndRemoveUntil(
              MaterialPageRoute(builder: (context) => const LoginScreen()),
              (route) => false,
            ).then((_) {
              _isRedirecting = false;
            });
          }
        }
        return handler.next(e);
      },
    ));
  }

  Dio get dio => _dio;
}

