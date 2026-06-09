import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/routes/app_pages.dart';
import 'core/routes/app_routes.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'core/bindings/app_binding.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase Initialization with Options
  try {
    if (kIsWeb) {
      await Firebase.initializeApp();
    } else {
      if (GetPlatform.isAndroid) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyCmL0xq-K7Ax-NrO9VEHGDg8evkeyJlQZ8',
            appId: '1:30883525731:android:75cc0c37aa56038f887456',
            messagingSenderId: '30883525731',
            projectId: 'school-management-19ee2',
            storageBucket: 'school-management-19ee2.firebasestorage.app',
          ),
        );
      } else if (GetPlatform.isIOS) {
        await Firebase.initializeApp(
          options: const FirebaseOptions(
            apiKey: 'AIzaSyCmL0xq-K7Ax-NrO9VEHGDg8evkeyJlQZ8',
            appId: '1:30883525731:ios:75cc0c37aa56038f887456',
            messagingSenderId: '30883525731',
            projectId: 'school-management-19ee2',
            storageBucket: 'school-management-19ee2.firebasestorage.app',
            iosBundleId: 'com.school.teacher_app',
          ),
        );
      } else {
        await Firebase.initializeApp();
      }
    }

    debugPrint('Firebase initialized successfully');

    // Background Notifications Handler
    if (!kIsWeb) {
      FirebaseMessaging.onBackgroundMessage(
        firebaseMessagingBackgroundHandler,
      );

      // Local Notification Service
      await NotificationService.instance.init();
      NotificationService.instance.listenToTokenRefresh();

      try {
        final token = await FirebaseMessaging.instance.getToken();
        debugPrint('📱 FCM Token: $token');
      } catch (e) {
        debugPrint('Failed to get FCM token: $e');
      }
    }
  } catch (e) {
    debugPrint('Failed to initialize Firebase or Notifications: $e');
  }

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));

  runApp(const SchoolTeacherApp());
}

class SchoolTeacherApp extends StatelessWidget {
  const SchoolTeacherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'School Teacher',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.light,
      initialRoute: AppRoutes.splash,
      initialBinding: AppBinding(),
      getPages: AppPages.pages,
      defaultTransition: Transition.cupertino,
    );
  }
}
