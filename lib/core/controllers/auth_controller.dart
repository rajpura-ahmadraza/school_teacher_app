import 'package:get/get.dart';
import '../api/api_client.dart';
import '../routes/app_routes.dart';

class AuthController extends GetxController {
  final _api = ApiClient.instance;

  final Rx<Map<String, dynamic>?> user = Rx(null);
  final RxString token = ''.obs;
  final RxBool isLoading = false.obs;
  final RxBool isInitializing = true.obs;
  final RxString error = ''.obs;

  bool get isAuthenticated => token.value.isNotEmpty;

  @override
  void onInit() {
    super.onInit();
    _init();
  }

  Future<void> _init() async {
    isInitializing.value = true;
    try {
      final savedToken = await _api.getToken();
      if (savedToken != null && savedToken.isNotEmpty) {
        await _api.setToken(savedToken);
        final resp = await _api.get('/auth/me');
        final raw = resp.data;
        final u = Map<String, dynamic>.from(
          raw['user'] as Map? ?? raw as Map? ?? {},
        );
        if (u['role'] == 'teacher') {
          token.value = savedToken;
          user.value = u;
          isInitializing.value = false;
          Get.offAllNamed(AppRoutes.dashboard);
          return;
        }
      }
    } catch (_) {}
    await _api.clearToken();
    token.value = '';
    user.value = null;
    isInitializing.value = false;
    Get.offAllNamed(AppRoutes.login);
  }

  Future<String?> login(String email, String password) async {
    isLoading.value = true;
    error.value = '';
    try {
      final resp = await _api.post('/auth/login', {
        'email': email.trim(),
        'password': password,
      });
      final u = Map<String, dynamic>.from(resp.data['user'] as Map);
      if (u['role'] != 'teacher') {
        isLoading.value = false;
        error.value = 'Access denied. Teacher account required.';
        return error.value;
      }
      final t = resp.data['access_token'] as String;
      await _api.setToken(t);
      token.value = t;
      user.value = u;
      isLoading.value = false;
      Get.offAllNamed(AppRoutes.dashboard);
      return null;
    } on ApiException catch (e) {
      isLoading.value = false;
      error.value = e.displayMessage;
      return e.displayMessage;
    } catch (_) {
      isLoading.value = false;
      error.value = 'Something went wrong';
      return 'Something went wrong';
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } catch (_) {}
    await _api.clearToken();
    token.value = '';
    user.value = null;
    Get.offAllNamed(AppRoutes.login);
  }
}
