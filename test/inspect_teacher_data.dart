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

  print('Logging in as teacher3...');
  try {
    final loginResp = await dio.post('/auth/login', data: {
      'email': 'teacher3@school.com',
      'password': 'password',
    });
    final token = loginResp.data['access_token'];
    dio.options.headers['Authorization'] = 'Bearer $token';
    print('Login successful.');
  } catch (e) {
    print('Login failed: $e');
    return;
  }

  // Get user details
  final meResp = await dio.get('/auth/me');
  final teacherId = meResp.data['user']['id'];
  print('Teacher ID: $teacherId');

  // Get classes
  final classesResp = await dio.get('/classes');
  final classesList = classesResp.data as List;
  print('Classes: ${classesList.map((c) => 'ID=${c['id']} Name=${c['name']} Sec=${c['section']} Teacher=${c['teacher_id']}')}');

  // Fetch all homework from the API
  print('\n--- ALL Homeworks from API ---');
  final hwResp = await dio.get('/homework', queryParameters: {'per_page': 1000});
  final data = hwResp.data['data'] as List;
  print('Total homework count: ${data.length}');
  
  for (var i = 0; i < data.length; i++) {
    final hw = data[i];
    final hwClass = hw['class'] as Map?;
    final hwSubject = hw['subject'] as Map?;
    print('HW $i: ID=${hw['id']} Title="${hw['title']}" ClassID=${hw['class_id']} SubjectID=${hw['subject_id']}');
    print('FULL HW JSON: $hw');
    print('  Class Teacher ID: ${hwClass?['teacher_id']}');
    print('  Subject Teacher ID: ${hwSubject?['teacher_id']}');
  }
}
