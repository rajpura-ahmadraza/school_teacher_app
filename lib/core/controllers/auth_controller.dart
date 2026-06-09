import 'package:get/get.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
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

  Future<Map<String, dynamic>> _getDeviceInfo() async {
    final Map<String, dynamic> deviceData = {
      'device_model': 'Unknown',
      'device_type': 'Unknown',
      'device_platform': 'Unknown',
      'device_uuid': 'Unknown',
      'device_version': 'Unknown',
      'device_manufacturer': 'Unknown',
      'device_IsVirtual': 'false',
    };
    try {
      if (GetPlatform.isWeb) {
        deviceData['device_model'] = 'Web Browser';
        deviceData['device_type'] = 'Web';
        deviceData['device_platform'] = 'Web';
        deviceData['device_uuid'] = 'Web';
        deviceData['device_version'] = '1.0';
        deviceData['device_manufacturer'] = 'Web';
        deviceData['device_IsVirtual'] = 'false';
      } else {
        final deviceInfo = DeviceInfoPlugin();
        if (GetPlatform.isAndroid) {
          final androidInfo = await deviceInfo.androidInfo;
          deviceData['device_model'] = androidInfo.model;
          deviceData['device_type'] = 'Android';
          deviceData['device_platform'] =
              'Android ${androidInfo.version.release}';
          deviceData['device_uuid'] = androidInfo.id;
          deviceData['device_version'] = androidInfo.version.sdkInt.toString();
          deviceData['device_manufacturer'] = androidInfo.manufacturer;
          deviceData['device_IsVirtual'] =
              (!androidInfo.isPhysicalDevice).toString();
        } else if (GetPlatform.isIOS) {
          final iosInfo = await deviceInfo.iosInfo;
          deviceData['device_model'] = iosInfo.model;
          deviceData['device_type'] = 'iOS';
          deviceData['device_platform'] = iosInfo.systemName;
          deviceData['device_uuid'] = iosInfo.identifierForVendor ?? 'Unknown';
          deviceData['device_version'] = iosInfo.systemVersion;
          deviceData['device_manufacturer'] = 'Apple';
          deviceData['device_IsVirtual'] = (!iosInfo.isPhysicalDevice).toString();
        }
      }
    } catch (_) {}
    return deviceData;
  }

  Future<String?> _getFcmToken() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
      return await FirebaseMessaging.instance.getToken();
    } catch (_) {
      return null;
    }
  }

  Future<String?> login(String email, String password) async {
    isLoading.value = true;
    error.value = '';
    try {
      final deviceInfo = await _getDeviceInfo();
      final userFcm = await _getFcmToken();

      final params = {
        'email': email.trim(),
        'password': password,
        'device_id': userFcm?.toString() ?? ' ',
        'fcm_token': userFcm?.toString() ?? ' ',
        'device_info': deviceInfo['device_model']?.toString() ?? 'Unknown',
        'device_type': deviceInfo['device_type']?.toString() ?? 'Unknown',
        'device_model': deviceInfo['device_model']?.toString() ?? 'Unknown',
        'device_platform':
            deviceInfo['device_platform']?.toString() ?? 'Unknown',
        'device_uuid': deviceInfo['device_uuid']?.toString() ?? 'Unknown',
        'device_version': deviceInfo['device_version']?.toString() ?? 'Unknown',
        'device_manufacturer':
            deviceInfo['device_manufacturer']?.toString() ?? 'Unknown',
        'device_IsVirtual':
            deviceInfo['device_IsVirtual']?.toString() ?? 'false',
        'app_version_code': GetPlatform.isAndroid ? '1' : '1',
      };

      print(params);

      final resp = await _api.post('/auth/login', params);
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
