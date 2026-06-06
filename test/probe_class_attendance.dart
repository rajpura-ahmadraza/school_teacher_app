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

  final endpoints = [
    '/students/attendance/47',
    '/students/attendance/class/47',
  ];

  final methods = ['POST', 'PUT', 'PATCH', 'GET'];

  final payload = {
    'date': '2026-06-06',
    'records': [
      {'student_id': 39, 'status': 'A'},
      {'student_id': 50, 'status': 'P'},
      {'student_id': 40, 'status': 'A'},
      {'student_id': 52, 'status': 'P'},
      {'student_id': 41, 'status': 'A'}
    ]
  };

  print('\nProbing class attendance endpoints...');

  for (final endpoint in endpoints) {
    for (final method in methods) {
      dynamic requestData = (method == 'GET') ? null : payload;
      Map<String, dynamic>? queryParams = (method == 'GET') ? {'date': '2026-06-06'} : null;

      try {
        final Response resp = await dio.request(
          endpoint,
          data: requestData,
          queryParameters: queryParams,
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
