import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

const String kBaseUrl =
    'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/';
const String _tokenKey = 'teacher_jwt_token';

class ApiClient {
  late final Dio _dio;
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  ApiClient() {
    _dio = Dio(BaseOptions(
      baseUrl: kBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    _dio.interceptors.add(_AuthInterceptor(_dio, _storage));
    _dio.interceptors.add(LogInterceptor(
      requestHeader: false,
      requestBody: true,
      responseHeader: false,
      responseBody: true,
      error: true,
    ));
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _handle(() => _dio.get(path, queryParameters: params));

  Future<Response> post(String path, [dynamic data]) =>
      _handle(() => _dio.post(path, data: data));

  Future<Response> put(String path, [dynamic data]) =>
      _handle(() => _dio.put(path, data: data));

  Future<Response> delete(String path) => _handle(() => _dio.delete(path));

  Future<Response> upload(String path, FormData formData) =>
      _handle(() => _dio.post(path,
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'})));

  Future<Response> _handle(Future<Response> Function() call) async {
    try {
      return await call();
    } on DioException catch (e) {
      throw ApiException(
        e.response?.data?['message'] as String? ?? e.message ?? 'Network error',
        e.response?.statusCode ?? 0,
        errors: e.response?.data?['errors'],
      );
    }
  }

  Future<void> setToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  Future<String?> getToken() => _storage.read(key: _tokenKey);

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
    _dio.options.headers.remove('Authorization');
  }

  // Singleton instance
  static final ApiClient instance = ApiClient();
}

class _AuthInterceptor extends Interceptor {
  final Dio _dio;
  final FlutterSecureStorage _storage;

  _AuthInterceptor(this._dio, this._storage);

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _storage.read(key: _tokenKey);
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final token = await _storage.read(key: _tokenKey);
        if (token != null) {
          final resp = await _dio.post('/auth/refresh',
              options: Options(headers: {'Authorization': 'Bearer $token'}));
          final newToken = resp.data['access_token'] as String;
          await _storage.write(key: _tokenKey, value: newToken);
          err.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          return handler.resolve(await _dio.fetch(err.requestOptions));
        }
      } catch (_) {
        await _storage.delete(key: _tokenKey);
      }
    }
    handler.next(err);
  }
}

class ApiException implements Exception {
  final String message;
  final int statusCode;
  final dynamic errors;
  const ApiException(this.message, this.statusCode, {this.errors});

  bool get isUnauthorized => statusCode == 401;
  bool get isValidation => statusCode == 422;
  bool get isServerError => statusCode >= 500;
  bool get isNetworkError => statusCode == 0;

  String get displayMessage {
    if (errors is Map) {
      final vals = (errors as Map).values;
      if (vals.isNotEmpty) {
        final first = vals.first;
        if (first is List && first.isNotEmpty) return first.first.toString();
      }
    }
    return message;
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient.instance);
