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

  // Student 45 has an existing attendance record for 2026-06-06 (ID 78)
  final payloads = [
    {
      'name': 'Update Existing Student Attendance (records list)',
      'data': {
        'class_id': 47,
        'date': '2026-06-06',
        'records': [
          {'student_id': 45, 'status': 'absent'}
        ]
      }
    },
    {
      'name': 'Update Existing Student Attendance (single keys)',
      'data': {
        'student_id': 45,
        'status': 'absent',
        'date': '2026-06-06'
      }
    }
  ];

  print('\nProbing existing student updates on PUT/PATCH /students/attendance...');

  for (final p in payloads) {
    print('Testing: ${p['name']}');
    for (final method in ['PUT', 'PATCH']) {
      try {
        final Response resp = await dio.request(
          '/students/attendance',
          data: p['data'],
          options: Options(method: method),
        );
        print('  --> SUCCESS: $method -> Status: ${resp.statusCode}, Data: ${resp.data}');
      } on DioException catch (e) {
        final status = e.response?.statusCode;
        final dynamic body = e.response?.data;
        final message = (body is Map) ? body['message'] : body.toString();
        print('  --> FAILED: $method -> Status: $status, Message: $message');
      } catch (e) {
        print('  --> ERROR: $method -> $e');
      }
    }
  }
}
