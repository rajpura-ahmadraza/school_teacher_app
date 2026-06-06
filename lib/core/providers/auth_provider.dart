import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_client.dart';

class AuthState {
  final String? token;
  final Map<String, dynamic>? user;
  final bool isLoading;
  final bool isInitializing;
  final String? error;

  const AuthState({
    this.token,
    this.user,
    this.isLoading = false,
    this.isInitializing = true,
    this.error,
  });

  bool get isAuthenticated => token != null && token!.isNotEmpty;

  AuthState copyWith({
    String? token,
    Map<String, dynamic>? user,
    bool? isLoading,
    bool? isInitializing,
    String? error,
    bool clearError = false,
    bool clearAuth = false,
  }) =>
      AuthState(
        token: clearAuth ? null : (token ?? this.token),
        user: clearAuth ? null : (user ?? this.user),
        isLoading: isLoading ?? this.isLoading,
        isInitializing: isInitializing ?? this.isInitializing,
        error: clearError ? null : (error ?? this.error),
      );
}

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._api) : super(const AuthState()) {
    _init();
  }

  final ApiClient _api;

  Future<void> _init() async {
    state = state.copyWith(isInitializing: true);
    try {
      final token = await _api.getToken();
      if (token != null && token.isNotEmpty) {
        await _api.setToken(token);
        final resp = await _api.get('/auth/me');
        final raw = resp.data;
        final user = Map<String, dynamic>.from(
          raw['user'] as Map? ?? raw as Map? ?? {},
        );
        if (user['role'] == 'teacher') {
          state = AuthState(token: token, user: user, isInitializing: false);
          return;
        }
      }
    } catch (_) {}
    await _api.clearToken();
    state = const AuthState(isInitializing: false);
  }

  Future<String?> login(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final resp = await _api.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      final user = Map<String, dynamic>.from(resp.data['user'] as Map);
      if (user['role'] != 'teacher') {
        state = state.copyWith(
            isLoading: false,
            error: 'Access denied. Teacher account required.');
        return 'Access denied. Teacher account required.';
      }
      final token = resp.data['access_token'] as String;
      await _api.setToken(token);
      state = AuthState(token: token, user: user, isInitializing: false);
      return null;
    } on ApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.displayMessage);
      return e.displayMessage;
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Something went wrong');
      return 'Something went wrong';
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _api.clearToken();
    state = const AuthState(isInitializing: false);
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>(
  (ref) => AuthNotifier(ref.read(apiClientProvider)),
);
