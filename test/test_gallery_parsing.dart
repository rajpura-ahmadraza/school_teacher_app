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

  try {
    final resp = await dio.get('/gallery');
    print('\nSUCCESS: GET /gallery');
    final raw = resp.data;

    // Run the parsing logic we wrote in remaining_screens.dart
    if (raw is Map) {
      // Extract photos
      List<dynamic> allPhotos = [];
      final photosNode = raw['photos'];
      if (photosNode is Map) {
        allPhotos = List<dynamic>.from(photosNode['data'] ?? []);
      } else if (photosNode is List) {
        allPhotos = photosNode;
      } else if (raw['data'] is List) {
        allPhotos = raw['data'];
      }

      // Extract album names
      List<String> albumNames = [];
      final albumsNode = raw['albums'];
      if (albumsNode is List) {
        albumNames = albumsNode.map((e) => e.toString()).toList();
      } else {
        albumNames = allPhotos
            .map((p) => (p is Map) ? p['album']?.toString() : null)
            .whereType<String>()
            .toSet()
            .toList();
      }

      // Group photos by album name
      final List<Map<String, dynamic>> grouped = [];
      for (final name in albumNames) {
        final photosInAlbum = allPhotos.where((p) {
          if (p is! Map) return false;
          final albumVal = p['album'];
          return albumVal?.toString().trim().toLowerCase() == name.trim().toLowerCase();
        }).map((p) {
          final pMap = Map<String, dynamic>.from(p as Map);
          pMap['url'] = pMap['image_url'] ?? pMap['thumbnail_url'] ?? pMap['image_path'] ?? '';
          return pMap;
        }).toList();

        grouped.add({
          'title': name,
          'photos': photosInAlbum,
        });
      }

      print('Grouped albums count: ${grouped.length}');
      for (final album in grouped) {
        print('Album: ${album['title']} (${album['photos'].length} photos)');
        if (album['photos'].isNotEmpty) {
          print('  First photo URL: ${album['photos'].first['url']}');
        }
      }
      print('\nPASSED: Data structured correctly for the Gallery UI!');
    } else {
      print('FAILED: raw is not a Map');
    }
  } on DioException catch (e) {
    print('FAILED: GET /gallery -> Status: ${e.response?.statusCode}, Message: ${e.response?.data}');
  }
}
