import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/user_model.dart';

class AuthRepository {
  final ApiClient _apiClient;
  List<dynamic>? _cachedPerusahaans;
  
  AuthRepository(this._apiClient);

  Future<Map<String, dynamic>> login(String email, String password, String deviceName) async {
    try {
      final response = await _apiClient.dio.post(
        ApiConstants.login,
        data: {
          'email': email,
          'password': password,
          'device_name': deviceName,
        },
      );

      if (response.statusCode == 200) {
        final token = response.data['token'];
        final dynamic rawUserData = response.data['user'];
        final Map<String, dynamic> userData = (rawUserData is Map && rawUserData.containsKey('data'))
            ? Map<String, dynamic>.from(rawUserData['data'])
            : Map<String, dynamic>.from(rawUserData);
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        return {
          'user': User.fromJson(userData),
          'token': token,
        };
      }
      throw Exception('Gagal login');
    } on DioException catch (e) {
      if (e.response != null) {
        final dynamic responseData = e.response?.data;
        if (responseData is Map && responseData.containsKey('message')) {
          String msg = responseData['message'].toString();
          if (msg.toLowerCase().contains('kredensial') || msg.toLowerCase().contains('credentials')) {
            throw Exception('Email atau password salah');
          }
          throw Exception(msg);
        }
        throw Exception('Email atau password salah');
      }
      throw Exception('Tidak dapat terhubung ke server. Periksa koneksi internet Anda.');
    } catch (e) {
      throw Exception('Terjadi kesalahan: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      await _apiClient.dio.post(ApiConstants.logout);
    } catch (e) {
      // Abaikan error saat logout (misal 401) agar tetap bisa membersihkan data lokal
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('auth_token');
      await prefs.remove('cached_user');
      _cachedPerusahaans = null;
    }
  }
  Future<User?> getCurrentUser() async {
    try {
      final response = await _apiClient.dio.get(ApiConstants.user);
      if (response.statusCode == 200) {
        // Laravel UserResource wraps in 'data' key by default
        final dynamic baseData = response.data;
        final Map<String, dynamic> data = (baseData is Map && baseData.containsKey('data')) 
          ? Map<String, dynamic>.from(baseData['data']) 
          : Map<String, dynamic>.from(baseData);
        return User.fromJson(data);
      }
      return null;
    } catch (e) {
      return null;
    }
  }


  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> saveRememberMe(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('remember_email', email);
    await prefs.setString('remember_password', password);
    await prefs.setString('is_remember_me', 'true');
  }

  Future<Map<String, String?>> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString('remember_email');
    final password = prefs.getString('remember_password');
    final isRememberMe = prefs.getString('is_remember_me');
    return {
      'email': email,
      'password': password,
      'isRememberMe': isRememberMe,
    };
  }

  Future<void> clearRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('remember_email');
    await prefs.remove('remember_password');
    await prefs.remove('is_remember_me');
  }

  Future<void> saveLastEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_email', email);
    
    // Simpan ke daftar riwayat email
    final existingStr = prefs.getString('saved_emails');
    List<String> emails = [];
    if (existingStr != null) {
      try {
        emails = List<String>.from(jsonDecode(existingStr));
      } catch (e) {
        // Abaikan jika json rusak
      }
    }
    
    if (!emails.contains(email)) {
      emails.insert(0, email); // Masukkan ke paling atas
      if (emails.length > 5) emails = emails.sublist(0, 5); // Batasi 5 riwayat
      await prefs.setString('saved_emails', jsonEncode(emails));
    }
  }

  Future<String?> getLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('last_email');
  }

  Future<void> saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cached_user', jsonEncode(user.toJson()));
  }

  Future<User?> getCachedUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userStr = prefs.getString('cached_user');
    if (userStr != null) {
      try {
        return User.fromJson(jsonDecode(userStr));
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Future<List<String>> getSavedEmails() async {
    final prefs = await SharedPreferences.getInstance();
    final existingStr = prefs.getString('saved_emails');
    if (existingStr != null) {
      try {
        return List<String>.from(jsonDecode(existingStr));
      } catch (e) {
        return [];
      }
    }
    return [];
  }

  Future<List<dynamic>> getPerusahaans() async {
    if (_cachedPerusahaans != null) return _cachedPerusahaans!;
    
    try {
      final response = await _apiClient.dio.get(ApiConstants.perusahaan);
      _cachedPerusahaans = response.data;
      return _cachedPerusahaans!;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> switchPerusahaan(int perusahaanId) async {
    try {
      await _apiClient.dio.post(
        ApiConstants.switchPerusahaan,
        data: {'perusahaan_id': perusahaanId},
      );
      _cachedPerusahaans = null; // Invalidate cache after switch
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateProfilePhoto(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'photo': await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      final response = await _apiClient.dio.post(
        '/user/photo',
        data: formData,
      );

      if (response.statusCode == 200) {
        final dynamic rawUserData = response.data['user'];
        final Map<String, dynamic> userData = (rawUserData is Map && rawUserData.containsKey('data'))
            ? Map<String, dynamic>.from(rawUserData['data'])
            : (rawUserData is Map 
                ? Map<String, dynamic>.from(rawUserData) 
                : Map<String, dynamic>.from(response.data));
                
        return User.fromJson(userData);
      }
      throw Exception('Gagal memperbarui foto profil');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateCompanyLogo(File imageFile) async {
    try {
      String fileName = imageFile.path.split('/').last;
      FormData formData = FormData.fromMap({
        'logo': await MultipartFile.fromFile(imageFile.path, filename: fileName),
      });

      final response = await _apiClient.dio.post(
        ApiConstants.updateCompanyLogo,
        data: formData,
      );

      if (response.statusCode == 200) {
        _cachedPerusahaans = null; // Invalidate cache after logo update
        final dynamic rawUserData = response.data['user'];
        final Map<String, dynamic> userData = (rawUserData is Map && rawUserData.containsKey('data'))
            ? Map<String, dynamic>.from(rawUserData['data'])
            : Map<String, dynamic>.from(rawUserData);
                
        return User.fromJson(userData);
      }
      throw Exception('Gagal memperbarui logo unit bisnis');
    } catch (e) {
      rethrow;
    }
  }
}

