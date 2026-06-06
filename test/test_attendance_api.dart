import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl:
        'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  print('1. Logging in...');
  try {
    final loginResp = await dio.post('/auth/login', data: {
      'email': 'teacher1@school.com',
      'password': 'password',
    });
    final token = loginResp.data['access_token'];
    dio.options.headers['Authorization'] = 'Bearer $token';
    print('Login successful.');

    print('\n2. Trying POST /students/39/attendance ...');
    try {
      final payload = {
        'status': 'present',
        'date': '2026-06-06',
      };
      final resp = await dio.post('/students/39/attendance', data: payload);
      print('  --> POST Success! Code: ${resp.statusCode}, Data: ${resp.data}');
    } on DioException catch (e) {
      print(
          '  --> POST Failed! Status: ${e.response?.statusCode}, Body: ${e.response?.data}');
    }
  } catch (e) {
    print('General error: $e');
  }
}
