import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Top-level background handler ─────
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  if (kDebugMode) {
    print('═══════════════════════════════════════════════');
    print('📱 [FCM BACKGROUND] Notification Received');
    print('═══════════════════════════════════════════════');
    print('📌 Title: ${message.notification?.title}');
    print('📌 Body: ${message.notification?.body}');
    print('📌 Data: ${message.data}');
  }

  await NotificationService.instance.saveNotification(message);
}

class NotificationService {
  static final NotificationService instance = NotificationService._();
  NotificationService._();

  FirebaseMessaging get _firebaseMessaging => FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotificationsPlugin = FlutterLocalNotificationsPlugin();

  static const String _notificationsKey = 'saved_notifications';

  // Real-time stream for unread count
  final _unreadCountController = StreamController<int>.broadcast();
  Stream<int> get unreadCountStream => _unreadCountController.stream;

  // Real-time stream for new notifications
  final _newNotificationController = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get newNotificationStream => _newNotificationController.stream;

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'high_importance_channel',
    'High Importance Notifications',
    description: 'This channel is used for important notifications.',
    importance: Importance.high,
    playSound: true,
  );

  Future<void> init() async {
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (kDebugMode) {
      print('🔔 [FCM] Permission status: ${settings.authorizationStatus}');
    }

    // Initialize Local Notifications
    const AndroidInitializationSettings androidInitSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings iosInitSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidInitSettings,
      iOS: iosInitSettings,
    );

    await _localNotificationsPlugin.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        if (kDebugMode) {
          print('🔔 [FCM] Notification tapped, payload: ${response.payload}');
        }
      },
    );

    await _localNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(_channel);

    await _firebaseMessaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Handle Foreground Messages
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      if (kDebugMode) {
        print('📨 [FCM Foreground] Title: ${message.notification?.title}');
        print('📨 [FCM Foreground] Body: ${message.notification?.body}');
      }

      await saveNotification(message);
      _showLocalNotification(message);

      // Emit new notification to stream
      _newNotificationController.add({
        'title': message.notification?.title ?? 'No Title',
        'body': message.notification?.body ?? 'No Body',
        'received_at': DateTime.now().toIso8601String(),
        'data': message.data,
      });
    });

    // Handle background message open
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (kDebugMode) {
        print('📬 [FCM Opened] Message opened from background: ${message.data}');
      }
    });

    // Check initial message
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      if (kDebugMode) {
        print('📬 [FCM Initial] App opened from terminated state: ${initialMessage.data}');
      }
    }

    // Initial unread count broadcast
    final initialCount = await getUnreadCount();
    _unreadCountController.add(initialCount);

    if (kDebugMode) {
      final token = await getFCMToken();
      print('🔑 [FCM Token on init]: $token');
    }
  }

  Future<String?> getFCMToken() async {
    try {
      final token = await _firebaseMessaging.getToken();
      return token;
    } catch (e) {
      if (kDebugMode) {
        print('❌ [FCM] Error getting token: $e');
      }
      return null;
    }
  }

  void listenToTokenRefresh() {
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      if (kDebugMode) {
        print('🔄 [FCM Token Refreshed]: $newToken');
      }
    });
  }

  void _showLocalNotification(RemoteMessage message) {
    final notification = message.notification;
    if (notification != null) {
      _localNotificationsPlugin.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            icon: '@mipmap/ic_launcher',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: jsonEncode(message.data),
      );
    }
  }

  Future<void> saveNotification(RemoteMessage message) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

    final Map<String, dynamic> notificationData = {
      'title': message.notification?.title ?? 'No Title',
      'body': message.notification?.body ?? 'No Body',
      'data': message.data,
      'received_at': DateTime.now().toIso8601String(),
      'isRead': false, // Mark as unread by default
    };

    notifications.insert(0, jsonEncode(notificationData));
    await prefs.setStringList(_notificationsKey, notifications);

    // Update unread count
    final newCount = await getUnreadCount();
    _unreadCountController.add(newCount);

    if (kDebugMode) {
      print('💾 [Notification Saved] Total: ${notifications.length}, Unread: $newCount');
    }
  }

  Future<List<Map<String, dynamic>>> getSavedNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];
    return notifications.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
  }

  Future<int> getUnreadCount() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

    return notifications.where((n) {
      final data = jsonDecode(n);
      return data['isRead'] == false || data['isRead'] == null;
    }).length;
  }

  Future<void> markNotificationAsRead(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

    if (index < notifications.length) {
      final notification = jsonDecode(notifications[index]);
      notification['isRead'] = true;
      notifications[index] = jsonEncode(notification);
      await prefs.setStringList(_notificationsKey, notifications);

      // Update unread count
      final newCount = await getUnreadCount();
      _unreadCountController.add(newCount);
    }
  }

  Future<void> markAllNotificationsAsRead() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

    bool changed = false;
    for (int i = 0; i < notifications.length; i++) {
      final notification = jsonDecode(notifications[i]);
      if (notification['isRead'] == false || notification['isRead'] == null) {
        notification['isRead'] = true;
        notifications[i] = jsonEncode(notification);
        changed = true;
      }
    }

    if (changed) {
      await prefs.setStringList(_notificationsKey, notifications);
      // Update unread count
      final newCount = await getUnreadCount();
      _unreadCountController.add(newCount);
    }
  }

  Future<void> deleteNotification(int index) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> notifications = prefs.getStringList(_notificationsKey) ?? [];

    if (index < notifications.length) {
      notifications.removeAt(index);
      await prefs.setStringList(_notificationsKey, notifications);

      // Update unread count
      final newCount = await getUnreadCount();
      _unreadCountController.add(newCount);
    }
  }

  Future<void> clearNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_notificationsKey);
    _unreadCountController.add(0);
    if (kDebugMode) {
      print('🗑️ [Notifications Cleared] All notifications have been removed');
    }
  }

  void dispose() {
    _unreadCountController.close();
    _newNotificationController.close();
  }
}
