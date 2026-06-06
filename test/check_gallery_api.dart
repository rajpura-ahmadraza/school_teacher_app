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

  try {
    final resp = await dio.get('/gallery');
    print('\nSUCCESS: GET /gallery');
    print('albums type: ${resp.data['albums']?.runtimeType}');
    print('albums value: ${resp.data['albums']}');
  } on DioException catch (e) {
    print('FAILED: GET /gallery -> Status: ${e.response?.statusCode}, Message: ${e.response?.data}');
  }
}
