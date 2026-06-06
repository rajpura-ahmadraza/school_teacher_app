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
    '/attendance/create',
    '/attendance/bulk',
    '/attendance/bulk-store',
    '/attendance/bulk-save',
    '/attendance/records',
    '/attendance/record',
    '/attendance-save',
    '/attendance-store',
    '/attendance-mark',
    '/save-attendance',
    '/store-attendance',
    '/mark-attendance',
    '/submit-attendance',
    '/student-attendance',
    '/class-attendance',
    '/classes/attendance',
    '/class/attendance',
    '/teachers/attendance',
    '/teacher/attendance',
    '/attendance/teacher',
    '/attendance/teachers',
    '/attendance/class',
    '/attendance/classes',
    '/attendance/students',
    '/attendance/student',
  ];

  final methods = ['POST', 'PUT', 'PATCH', 'GET'];

  final payload = {
    'class_id': 47,
    'date': '2026-06-06',
    'records': [
      {'student_id': 39, 'status': 'A'},
      {'student_id': 50, 'status': 'P'},
    ]
  };

  print('\nProbing wider list of endpoints...');

  for (final endpoint in endpoints) {
    for (final method in methods) {
      dynamic requestData = (method == 'GET') ? null : payload;
      Map<String, dynamic>? queryParams = (method == 'GET') ? {'class_id': '47', 'date': '2026-06-06'} : null;

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
        if (status != 404 && status != 405) {
          print('INTERESTING: $method $endpoint -> Status: $status, Body: $body');
        }
      } catch (e) {
        // other error
      }
    }
  }
  print('Done probing.');
}
