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
  String token;
  try {
    final loginResp = await dio.post('/auth/login', data: {
      'email': 'teacher1@school.com',
      'password': 'password',
    });
    token = loginResp.data['access_token'];
    dio.options.headers['Authorization'] = 'Bearer $token';
    print('Login successful.');
  } catch (e) {
    print('Login failed: $e');
    return;
  }

  final paramsToTest = [
    {'scope': 'all'},
    {'all': '1'},
    {'type': 'all'},
    {'view': 'all'},
    {'class_id': '44', 'scope': 'all'},
    {'class_id': '44', 'all': '1'},
    {'class_id': '44', 'subject_id': '25'},
  ];

  for (final params in paramsToTest) {
    try {
      final resp = await dio.get('/homework', queryParameters: params);
      final raw = resp.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(raw['data'] ?? raw['homeworks'] ?? raw['homework'] ?? []);
      }
      print('Params: $params -> Count: ${list.length}');
      if (list.isNotEmpty) {
        for (final hw in list.take(1)) {
          print('  -> Sample HW ID: ${hw['id']}, Class ID: ${hw['class_id']}, Title: ${hw['title']}');
        }
      }
    } catch (e) {
      print('Params: $params -> Error: $e');
    }
  }
}
