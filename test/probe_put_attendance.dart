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

  final payloads = [
    // 1. Single student payload (standard keys)
    {
      'name': 'Single Student Standard Keys',
      'data': {
        'student_id': 39,
        'status': 'P',
        'date': '2026-06-06',
      }
    },
    // 2. Single student with full status name
    {
      'name': 'Single Student Full Status Name',
      'data': {
        'student_id': 39,
        'status': 'present',
        'date': '2026-06-06',
      }
    },
    // 3. Class-wide records list (top-level records)
    {
      'name': 'Records List Top-Level',
      'data': {
        'records': [
          {'student_id': 39, 'status': 'P'},
          {'student_id': 50, 'status': 'P'}
        ],
        'date': '2026-06-06',
      }
    },
    // 4. Class-wide with class_id
    {
      'name': 'Records List with class_id',
      'data': {
        'class_id': 47,
        'records': [
          {'student_id': 39, 'status': 'P'},
          {'student_id': 50, 'status': 'P'}
        ],
        'date': '2026-06-06',
      }
    },
    // 5. Array of records directly
    {
      'name': 'Direct Array of Records',
      'data': [
        {'student_id': 39, 'status': 'P', 'date': '2026-06-06'},
        {'student_id': 50, 'status': 'P', 'date': '2026-06-06'}
      ]
    },
    // 6. Plural students key
    {
      'name': 'Plural students key',
      'data': {
        'class_id': 47,
        'date': '2026-06-06',
        'students': [
          {'id': 39, 'status': 'P'},
          {'id': 50, 'status': 'P'}
        ]
      }
    }
  ];

  print('\nProbing payloads on PUT /students/attendance (clean messages)...');

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
