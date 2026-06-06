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

  // Record ID 78 is known to exist from GET /attendance
  final endpoints = [
    '/students/attendance/78',
    '/attendance/78',
  ];

  final methods = ['GET', 'PUT', 'PATCH', 'DELETE'];

  final payload = {
    'status': 'absent', // changing present to absent
    'remarks': 'Test update',
  };

  print('\nProbing by-id attendance endpoints...');

  for (final endpoint in endpoints) {
    for (final method in methods) {
      dynamic requestData = (method == 'GET') ? null : payload;

      try {
        final Response resp = await dio.request(
          endpoint,
          data: requestData,
          options: Options(method: method),
        );
        print('SUCCESS: $method $endpoint -> Status: ${resp.statusCode}, Data: ${resp.data}');
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final body = e.response?.data;
        print('RESULT: $method $endpoint -> Status: $status, Body: $body');
      } catch (e) {
        print('ERROR: $method $endpoint -> $e');
      }
    }
  }
}
