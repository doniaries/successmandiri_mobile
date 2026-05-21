import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';
import 'package:sawitappmobile/shared/repositories/auth_repository.dart';
import 'package:sawitappmobile/core/services/push_notification_service.dart';

import 'package:sawitappmobile/core/services/database_service.dart';
class AuthProvider with ChangeNotifier {
  final AuthRepository _authRepository;
  User? _user;
  bool _isLoading = false;
  bool _isSwitchingCompany = false;
  String? _errorMessage;

  AuthProvider(this._authRepository);

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isSwitchingCompany => _isSwitchingCompany;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _user != null;

  Future<bool> login(String email, String password, {bool isRememberMe = false}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authRepository.login(email, password, 'Mobile App').timeout(
        const Duration(seconds: 30),
        onTimeout: () => throw Exception('Koneksi timeout (Ditunggu 30 detik tidak merespons)'),
      );
      _user = result['user'];
      
      // Simpan user ke cache
      if (_user != null) {
        await _authRepository.saveUser(_user!);
        
        // Daftarkan FCM token ke backend segera setelah login berhasil
        final token = await _authRepository.getToken();
        if (token != null) {
          PushNotificationService.registerTokenToBackend(token).catchError((e) => null);
        }
      }

      if (isRememberMe) {
        await _authRepository.saveRememberMe(email, password);
      } else {
        await _authRepository.clearRememberMe();
      }
      
      await _authRepository.saveLastEmail(email);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<Map<String, String?>> getRememberedCredentials() async {
    return await _authRepository.getRememberMe();
  }

  Future<String?> getAuthToken() async {
    return await _authRepository.getToken();
  }

  Future<String?> getLastEmail() async {
    return await _authRepository.getLastEmail();
  }

  Future<List<String>> getSavedEmails() async {
    return await _authRepository.getSavedEmails();
  }

  Future<void> logout() async {
    try {
      final token = await _authRepository.getToken();
      if (token != null) {
        await PushNotificationService.unregisterTokenFromBackend(token);
      }
    } catch (e) {
      debugPrint('Error unregistering FCM token on logout: $e');
    }

    await _authRepository.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cached_user');
    _user = null;
    
    // Clear local data to prevent leak between accounts/companies
    await DatabaseService().clearAllTables();
    
    // SessionService().stop(); // REMOVED: Session restriction
    notifyListeners();
  }

  Future<void> checkAuthStatus() async {
    _isLoading = true;
    notifyListeners();

    try {
      final token = await _authRepository.getToken();
      if (token != null) {
        // Coba ambil dari cache dulu agar cepat
        _user = await _authRepository.getCachedUser();
        notifyListeners();

        // Daftarkan FCM token ke backend agar selalu sinkron jika database dibersihkan
        PushNotificationService.registerTokenToBackend(token).catchError((e) => null);

        // Refresh data dari server di background (opsional, tapi bagus untuk update info terbaru)
        try {
          final freshUser = await _authRepository.getCurrentUser().timeout(
            const Duration(seconds: 15),
          );
          if (freshUser != null) {
            _user = freshUser;
            await _authRepository.saveUser(freshUser);
            // SessionService().start(onTimeout: handleAutoLogout); // REMOVED: Session restriction
          }
        } catch (e) {
          debugPrint('Silent refresh failed: $e. Using cached user.');
        }
      }
    } catch (e) {
      debugPrint('CheckAuthStatus Error: $e');
      // Jika token ada tapi error (misal expired), logout akan ditangani di interceptor atau UI
    }

    _isLoading = false;
    notifyListeners();
  }
  Future<List<dynamic>> getAvailableCompanies() async {
    return await _authRepository.getPerusahaans();
  }

  Future<bool> switchCompany(int perusahaanId, {bool showLoading = true}) async {
    if (showLoading) {
      _isLoading = true;
    }
    _isSwitchingCompany = true;
    notifyListeners();

    try {
      await _authRepository.switchPerusahaan(perusahaanId);
      
      // Update local user model immediately if possible to show name change
      // or at least get the new user data from server
      final freshUser = await _authRepository.getCurrentUser();
      if (freshUser != null) {
        _user = freshUser;
        await _authRepository.saveUser(freshUser);
      }
      
      // Clear local data to ensure next sync pulls the new company's data
      await DatabaseService().clearAllTables();
      
      _isLoading = false;
      _isSwitchingCompany = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _isSwitchingCompany = false;
      if (e is DioException && (e.type == DioExceptionType.connectionError || e.type == DioExceptionType.connectionTimeout)) {
        _errorMessage = 'Pergantian perusahaan tidak bisa dilakukan saat offline.';
      } else {
        _errorMessage = 'Gagal ganti perusahaan: $e';
      }
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateProfilePhoto(File imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authRepository.updateProfilePhoto(imageFile);
      _user = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal upload foto: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCompanyLogo(File imageFile) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authRepository.updateCompanyLogo(imageFile);
      _user = updatedUser;
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Gagal upload logo unit bisnis: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> updateCompanyDetails(String? name, String? alamat, int? kasirId) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final updatedUser = await _authRepository.updateCompanyDetails(name, alamat, kasirId);
      _user = updatedUser;
      await _authRepository.saveUser(updatedUser);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<List<dynamic>> getUsers() async {
    return await _authRepository.getUsers();
  }

  // handleAutoLogout REMOVED: Session restriction
}

