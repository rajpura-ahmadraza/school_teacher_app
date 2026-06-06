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

  // Let's test different methods and structures on:
  // 1. /students/attendance
  // 2. /students/{id}/attendance
  // 3. /students/attendance/{id}
  
  final targets = [
    // Endpoint, Method, UseBody, QueryParams
    {
      'url': '/students/attendance',
      'method': 'GET',
      'body': null,
      'params': {'class_id': '47', 'date': '2026-06-06'}
    },
    {
      'url': '/students/attendance',
      'method': 'PUT',
      'body': {
        'class_id': 47,
        'date': '2026-06-06',
        'records': [
          {'student_id': 39, 'status': 'A'},
          {'student_id': 50, 'status': 'P'},
        ]
      },
      'params': null
    },
    {
      'url': '/students/attendance',
      'method': 'PATCH',
      'body': {
        'class_id': 47,
        'date': '2026-06-06',
        'records': [
          {'student_id': 39, 'status': 'A'},
          {'student_id': 50, 'status': 'P'},
        ]
      },
      'params': null
    },
    // Let's try individual student attendance
    {
      'url': '/students/39/attendance',
      'method': 'GET',
      'body': null,
      'params': null
    },
    {
      'url': '/students/39/attendance',
      'method': 'POST',
      'body': {'status': 'present', 'date': '2026-06-06'},
      'params': null
    },
    {
      'url': '/students/39/attendance',
      'method': 'PUT',
      'body': {'status': 'present', 'date': '2026-06-06'},
      'params': null
    },
    {
      'url': '/students/39/attendance',
      'method': 'PATCH',
      'body': {'status': 'present', 'date': '2026-06-06'},
      'params': null
    },
    // Let's try /students/attendance/39
    {
      'url': '/students/attendance/39',
      'method': 'GET',
      'body': null,
      'params': null
    },
    {
      'url': '/students/attendance/39',
      'method': 'POST',
      'body': {'status': 'present', 'date': '2026-06-06'},
      'params': null
    },
    {
      'url': '/students/attendance/39',
      'method': 'PUT',
      'body': {'status': 'present', 'date': '2026-06-06'},
      'params': null
    },
    {
      'url': '/students/attendance/39',
      'method': 'PATCH',
      'body': {'status': 'present', 'date': '2026-06-06'},
      'params': null
    },
    // What if they expect class-level updates?
    {
      'url': '/classes/47/attendance',
      'method': 'PUT',
      'body': {
        'date': '2026-06-06',
        'records': [
          {'student_id': 39, 'status': 'A'},
          {'student_id': 50, 'status': 'P'}
        ]
      },
      'params': null
    },
    // Let's try other possible patterns
    {
      'url': '/attendance',
      'method': 'POST',
      'body': {
        'class_id': 47,
        'date': '2026-06-06',
        'records': [
          {'student_id': 39, 'status': 'A'},
          {'student_id': 50, 'status': 'P'}
        ]
      },
      'params': null
    }
  ];

  for (final t in targets) {
    final url = t['url'] as String;
    final method = t['method'] as String;
    final body = t['body'];
    final params = t['params'] as Map<String, dynamic>?;

    try {
      final Response resp = await dio.request(
        url,
        data: body,
        queryParameters: params,
        options: Options(method: method),
      );
      print('SUCCESS: $method $url -> Status: ${resp.statusCode}, Data: ${resp.data}');
    } on DioException catch (e) {
      print('FAILED: $method $url -> Status: ${e.response?.statusCode}, Body: ${e.response?.data}');
    } catch (e) {
      print('ERROR: $method $url -> $e');
    }
  }
}
