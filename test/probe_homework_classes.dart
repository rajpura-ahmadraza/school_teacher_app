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

  try {
    print('Logging in...');
    final loginResp = await dio.post('/auth/login', data: {
      'email': 'teacher1@school.com',
      'password': 'password',
    });
    final token = loginResp.data['access_token'];
    final userId = loginResp.data['user']['id'];
    dio.options.headers['Authorization'] = 'Bearer $token';

    final paramsToTest = [
      {'teacher_id': userId},
      {'assigned_by': userId},
      {'assigned_by_id': userId},
      {'created_by': userId},
      {'my_homework': '1'},
      {'scope': 'own'},
      {'own': '1'},
      {'type': 'assigned'},
    ];

    for (final params in paramsToTest) {
      final resp = await dio.get('/homework', queryParameters: params);
      final list = resp.data['data'] as List;
      print('Params: $params -> Count: ${list.length}');
      if (list.isNotEmpty) {
        for (final hw in list) {
          if (hw['id'] == 59 || hw['class_id'] == 44) {
            print('  -> FOUND TARGET HOMEWORK! ID: ${hw['id']}, Class ID: ${hw['class_id']}');
          }
        }
      }
    }
  } catch (e) {
    print('Error: $e');
  }
}
