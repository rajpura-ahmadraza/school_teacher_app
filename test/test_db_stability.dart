import 'package:dio/dio.dart';

void main() async {
  final dio = Dio(BaseOptions(
    baseUrl: 'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 30),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
  ));

  print('Logging in...');
  try {
    final loginResp = await dio.post('/auth/login', data: {
      'email': 'teacher1@school.com',
      'password': 'password',
    });
    final token = loginResp.data['access_token'];
    dio.options.headers['Authorization'] = 'Bearer $token';
    print('Login successful.');
  } catch (e) {
    print('Login failed: $e');
    return;
  }

  print('\nTesting GET /attendance 10 times...');
  for (int i = 1; i <= 10; i++) {
    try {
      final resp = await dio.get('/attendance');
      print('  [$i] SUCCESS -> Status: ${resp.statusCode}');
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data;
      final message = (body is Map) ? body['message'] : body.toString();
      print('  [$i] FAILED -> Status: $status, Message: $message');
    }
    await Future.delayed(const Duration(milliseconds: 500));
  }
}
