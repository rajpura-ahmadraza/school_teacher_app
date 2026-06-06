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

  // 1. Get recent homework
  int? homeworkId;
  try {
    final resp = await dio.get('/homework');
    final data = resp.data['data'] as List;
    if (data.isNotEmpty) {
      homeworkId = data.first['id'];
      print('Found homework ID: $homeworkId');
    } else {
      print('No homework found.');
    }
  } catch (e) {
    print('Failed to get homework: $e');
    return;
  }

  if (homeworkId == null) return;

  // 2. Try to update this homework using PUT /homework/{id}
  print('\nTrying PUT /homework/$homeworkId...');
  try {
    final resp = await dio.put('/homework/$homeworkId', data: {
      'title': 'Test Probing Title',
      'description': 'Updated description',
      'class_id': 47,
      'subject_id': 1,
      'due_date': '2026-06-10',
    });
    print('SUCCESS: PUT /homework/$homeworkId -> Status: ${resp.statusCode}');
  } on DioException catch (e) {
    final status = e.response?.statusCode;
    final body = e.response?.data;
    final message = (body is Map) ? body['message'] : body.toString();
    print('FAILED: PUT /homework/$homeworkId -> Status: $status, Message: $message');
  }
}
