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

  final records = [
    {'student_id': 39, 'status': 'P'},
    {'student_id': 50, 'status': 'P'},
  ];

  print('\nTesting PUT /students/attendance?class_id=47&date=2026-06-06...');
  try {
    final resp = await dio.put(
      '/students/attendance',
      data: {'records': records},
      queryParameters: {'class_id': '47', 'date': '2026-06-06'},
    );
    print('SUCCESS: Status: ${resp.statusCode}, Data: ${resp.data}');
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final message = (body is Map) ? body['message'] : body.toString();
    print('FAILED: Status: $status, Message: $message');
  }
}
