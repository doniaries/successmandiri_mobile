import 'dart:convert';
import 'lib/features/auth/models/user_model.dart';

void main() {
  final jsonString = '''
{
  "token": "150|UHQGbOOTIRZBXw9p0JqTLo7FASMBpndUiM4H3zSX972e53f3",
  "user": {
    "id": 3,
    "name": "Taufik",
    "email": "taufik@gmail.com",
    "perusahaan_id": 3,
    "perusahaan_name": "Koperasi Sijunjung Success Mandiri",
    "perusahaan_pabrik": "PT. SMP",
    "is_active": true,
    "photo": null,
    "photo_url": null,
    "perusahaan_logo_url": "https://sawit.successmandiri.com/storage/1000733990.jpg",
    "perusahaan_kasir": "Taufik",
    "roles": [],
    "permissions": [],
    "perusahaans": [
      {
        "id": 3,
        "name": "Koperasi Sijunjung Success Mandiri",
        "nama_kasir": "Taufik"
      }
    ]
  }
}
  ''';

  final responseData = jsonDecode(jsonString);

  final dynamic rawUserData = responseData['user'] ?? responseData['data'];
  print('rawUserData is Map? \${rawUserData is Map}');
  print('contains data? \${rawUserData is Map && rawUserData.containsKey('data')}');

  Map<String, dynamic> userData;
  if (rawUserData is Map) {
    if (rawUserData.containsKey('data') && rawUserData['data'] != null) {
      userData = Map<String, dynamic>.from(rawUserData['data']);
    } else {
      userData = Map<String, dynamic>.from(rawUserData);
    }
  } else {
    throw Exception('error');
  }

  print('userData: \$userData');

  final user = User.fromJson(userData);
  print('user.name: \${user.name}');
  print('user.perusahaanName: \${user.perusahaanName}');
}
