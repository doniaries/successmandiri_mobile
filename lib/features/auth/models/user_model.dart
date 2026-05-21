import 'package:sawitappmobile/core/constants/api_constants.dart';

class User {
  final int id;
  final String name;
  final String email;
  final int? perusahaanId;
  final String? perusahaanName;
  final String? perusahaanKasir;
  final bool? isActive;

  final String? photo;
  final String? photoUrl;
  final String? perusahaanLogoUrl;
  final List<String> roles;
  final List<String> permissions;
  final List<UserCompany> perusahaans;

  User({
    required this.id,
    required this.name,
    required this.email,
    this.perusahaanId,
    this.perusahaanName,
    this.perusahaanKasir,
    this.isActive,
    this.photo,
    this.photoUrl,
    this.perusahaanLogoUrl,
    this.roles = const [],
    this.permissions = const [],
    this.perusahaans = const [],
  });

  String? get role => roles.isNotEmpty ? roles.first : null;

  bool can(String permissionName) => permissions.contains(permissionName);

  bool get isSuperAdmin => roles.any((r) {
    final lower = r.toLowerCase();
    return lower == 'super_admin' || lower == 'superadmin';
  });

  bool get isAdmin => roles.any((r) {
    final lower = r.toLowerCase();
    return lower == 'admin' || isSuperAdmin;
  });

  String? get fullPhotoUrl {
    if (photoUrl == null || photoUrl!.isEmpty) return null;
    if (photoUrl!.startsWith('http')) return photoUrl;
    
    // Fallback to storage URL (standard Laravel link)
    // baseUrl usually ends with /api, we need to go up one level
    final base = ApiConstants.baseUrl.replaceAll('/api', '');
    return '$base/storage/$photoUrl';
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] is int) ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      perusahaanId: (json['perusahaan_id'] is int) ? json['perusahaan_id'] : int.tryParse(json['perusahaan_id']?.toString() ?? ''),
      perusahaanName: json['perusahaan_name'],
      perusahaanKasir: json['perusahaan_kasir'] ?? json['nama_kasir'],
      isActive: (json['is_active'] is bool) ? json['is_active'] : (json['is_active']?.toString() == '1' || json['is_active']?.toString() == 'true'),
      photo: json['photo'] ?? json['avatar'],
      photoUrl: _parsePhotoUrl(json),
      perusahaanLogoUrl: ApiConstants.normalizeUrl(json['perusahaan_logo_url']),
      roles: _parseRoles(json),
      permissions: _parsePermissions(json),
      perusahaans: (json['perusahaans'] is List)
          ? (json['perusahaans'] as List)
              .map((p) => UserCompany.fromJson(p as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  static String? _parsePhotoUrl(Map<String, dynamic> json) {
    return json['photo_url'] ?? 
           json['avatar_url'] ?? 
           json['profile_photo_url'] ?? 
           json['photo'] ?? 
           json['avatar'];
  }

  static List<String> _parsePermissions(Map<String, dynamic> json) {
    final data = json['permissions'];
    if (data == null) return [];
    if (data is List) {
      return data.map((p) => p.toString()).toList();
    }
    return [];
  }

  static List<String> _parseRoles(Map<String, dynamic> json) {
    // 1. Check common role fields
    final roleKeys = ['roles', 'roles_list', 'user_roles', 'role', 'peran', 'role_name'];
    
    for (var key in roleKeys) {
      var data = json[key];
      if (data == null) continue;
      
      if (data is List) {
        return data.map((r) {
          if (r is Map && r.containsKey('name')) return r['name'].toString();
          return r.toString();
        }).toList();
      }
      
      if (data is String) return [data];
      
      if (data is Map) {
        if (data.containsKey('name')) return [data['name'].toString()];
        if (data.containsKey('role')) return [data['role'].toString()];
      }
    }
    
    // 3. Last resort: check if name contains 'Admin' (only as hint, maybe not safe)
    // But let's stick to explicit roles for now.
    
    return [];
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'perusahaan_id': perusahaanId,
      'perusahaan_name': perusahaanName,
      'perusahaan_kasir': perusahaanKasir,
      'is_active': isActive,
      'photo': photo,
      'photo_url': photoUrl,
      'perusahaan_logo_url': perusahaanLogoUrl,
      'roles': roles,
      'permissions': permissions,
      'perusahaans': perusahaans.map((p) => p.toJson()).toList(),
    };
  }
}

class UserCompany {
  final int id;
  final String name;
  final String? logoUrl;
  final String? namaKasir;

  UserCompany({required this.id, required this.name, this.logoUrl, this.namaKasir});

  factory UserCompany.fromJson(Map<String, dynamic> json) {
    return UserCompany(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      name: json['name'] ?? '',
      logoUrl: ApiConstants.normalizeUrl(json['logo_url'] ?? json['logo_path']),
      namaKasir: json['nama_kasir'] ?? json['kasir_name'],
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'logo_url': logoUrl,
    'nama_kasir': namaKasir,
  };
}

