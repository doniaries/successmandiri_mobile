import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sawitappmobile/core/constants/api_constants.dart';
import 'package:sawitappmobile/core/network/api_client.dart';
import 'package:sawitappmobile/core/services/push_notification_service.dart';
import 'package:sawitappmobile/features/auth/models/user_model.dart';
import 'package:sawitappmobile/core/services/database_service.dart';

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
        if (response.data is! Map) {
          throw Exception('Format respon tidak valid dari server.');
        }
        
        final token = response.data['token'];
        final dynamic rawUserData = response.data['user'] ?? response.data['data'];
        
        if (rawUserData == null) {
          throw Exception('Data user tidak ditemukan dalam respon server.');
        }

        Map<String, dynamic> userData;
        if (rawUserData is Map) {
          if (rawUserData.containsKey('data') && rawUserData['data'] != null) {
            userData = Map<String, dynamic>.from(rawUserData['data']);
          } else {
            userData = Map<String, dynamic>.from(rawUserData);
          }
        } else {
          throw Exception('Format data user tidak sesuai.');
        }

        final parsedUser = User.fromJson(userData);
        if (parsedUser.name.trim().isEmpty) {
           throw Exception('Data user tidak lengkap (nama kosong).');
        }
        
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', token);
        
        // Simpan backup untuk login offline jika tidak ada sinyal
        await prefs.setString('offline_backup_token', token);
        await prefs.setString('offline_backup_user', jsonEncode(userData));

        // Daftarkan FCM token ke backend setelah login berhasil
        PushNotificationService.registerTokenToBackend(token)
            .catchError((e) => null); // Non-blocking

        return {
          'user': parsedUser,
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
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString('auth_token');
      
      // Jalankan penghapusan FCM token dan pencabutan token di backend secara asynchronous (background)
      // agar proses logout di sisi user langsung instan tanpa menunggu jaringan
      if (authToken != null) {
        PushNotificationService.unregisterTokenFromBackend(authToken).then((_) {
          _apiClient.dio.post(ApiConstants.logout).catchError((e) => Response(requestOptions: RequestOptions()));
        }).catchError((e) => null);
      }
    } catch (_) {
      // Abaikan jika terjadi error inisialisasi awal
    } finally {
      // Bersihkan penyimpanan lokal secara instan
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
        if (response.data is! Map) return null;
        
        // Laravel UserResource wraps in 'data' key by default
        final dynamic baseData = response.data;
        if (baseData == null) return null;

        Map<String, dynamic> data;
        if (baseData is Map) {
          if (baseData.containsKey('data') && baseData['data'] != null) {
            data = Map<String, dynamic>.from(baseData['data']);
          } else {
            data = Map<String, dynamic>.from(baseData);
          }
        } else {
          return null;
        }

        final user = User.fromJson(data);
        if (user.name.trim().isEmpty) {
          return null;
        }
        return user;
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
      try {
        final db = DatabaseService();
        final localData = await db.query('perusahaans');
        if (localData.isNotEmpty) {
          _cachedPerusahaans = localData;
          return _cachedPerusahaans!;
        }
      } catch (_) {}
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
        if (response.data is! Map) {
          throw Exception('Format respon tidak valid.');
        }

        final dynamic rawUserData = response.data['user'] ?? response.data['data'];
        if (rawUserData == null) {
          throw Exception('Data user tidak ditemukan dari server.');
        }

        Map<String, dynamic> userData;
        if (rawUserData is Map) {
          if (rawUserData.containsKey('data') && rawUserData['data'] != null) {
            userData = Map<String, dynamic>.from(rawUserData['data']);
          } else {
            userData = Map<String, dynamic>.from(rawUserData);
          }
        } else {
          throw Exception('Format data user tidak sesuai.');
        }
                
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
        if (response.data is! Map) {
          throw Exception('Format respon tidak valid.');
        }

        final dynamic rawUserData = response.data['user'] ?? response.data['data'];
        if (rawUserData == null) {
          throw Exception('Data user tidak ditemukan dari server.');
        }

        Map<String, dynamic> userData;
        if (rawUserData is Map) {
          if (rawUserData.containsKey('data') && rawUserData['data'] != null) {
            userData = Map<String, dynamic>.from(rawUserData['data']);
          } else {
            userData = Map<String, dynamic>.from(rawUserData);
          }
        } else {
          throw Exception('Format data user tidak sesuai.');
        }
                
        return User.fromJson(userData);
      }
      throw Exception('Gagal memperbarui logo unit bisnis');
    } catch (e) {
      rethrow;
    }
  }

  Future<User> updateCompanyDetails(String? name, String? alamat, int? kasirId) async {
    try {
      final response = await _apiClient.dio.post(
        '/perusahaan/update',
        data: {
          'name': name,
          'alamat': alamat,
          'kasir_id': kasirId,
        },
      );

      if (response.statusCode == 200) {
        _cachedPerusahaans = null;
        final dynamic rawUserData = response.data['user'];
        final Map<String, dynamic> userData = (rawUserData is Map && rawUserData.containsKey('data'))
            ? Map<String, dynamic>.from(rawUserData['data'])
            : Map<String, dynamic>.from(rawUserData);
                
        return User.fromJson(userData);
      }
      throw Exception('Gagal memperbarui pengaturan perusahaan');
    } catch (e) {
      if (e is DioException && e.response?.data != null) {
         throw Exception(e.response?.data['message'] ?? 'Gagal memperbarui perusahaan');
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getUsers() async {
    try {
      final response = await _apiClient.dio.get('/users?per_page=100');
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('data')) {
           return response.data['data'];
        }
        return response.data;
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }
}

