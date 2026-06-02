import 'package:dio/dio.dart';

void main() async {
  try {
    final dio = Dio();
    final response = await dio.post(
      'https://sawit.successmandiri.com/api/login',
      data: {'email': 'taufik@gmail.com', 'password': 'taufik2026', 'device_name': 'emulator'},
    );
    print('Status: ${response.statusCode}');
    print('Data: ${response.data}');
  } catch(e) {
    print('Error: $e');
    if (e is DioException) {
      print('Response: ${e.response?.data}');
    }
  }
}
