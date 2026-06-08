import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../../core/services/notification_service.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'homework', 'leave', 'announcement', 'timetable'
  final DateTime timestamp;
  final RxBool isRead;
  final Map<String, dynamic>? data;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    required bool isRead,
    this.data,
  }) : isRead = isRead.obs;

  factory NotificationModel.fromJson(Map<String, dynamic> json, String defaultId) {
    final dataMap = json['data'] is Map ? Map<String, dynamic>.from(json['data'] as Map) : <String, dynamic>{};
    final type = dataMap['type'] ?? json['type'] ?? 'announcement';
    return NotificationModel(
      id: json['id']?.toString() ?? defaultId,
      title: json['title'] ?? 'No Title',
      body: json['body'] ?? 'No Body',
      type: type.toString().toLowerCase(),
      timestamp: DateTime.tryParse(json['received_at'] ?? '') ?? DateTime.now(),
      isRead: json['isRead'] ?? false,
      data: dataMap,
    );
  }
}

class NotificationsController extends GetxController {
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final NotificationService _service = NotificationService.instance;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();

    // Listen to real-time incoming foreground notifications
    _service.newNotificationStream.listen((n) {
      final newModel = NotificationModel.fromJson(n, DateTime.now().millisecondsSinceEpoch.toString());
      notifications.insert(0, newModel);
    });
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      final saved = await _service.getSavedNotifications();
      notifications.value = saved.asMap().entries.map((entry) {
        return NotificationModel.fromJson(entry.value, entry.key.toString());
      }).toList();
    } catch (_) {
      notifications.value = [];
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> markAsRead(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !notifications[index].isRead.value) {
      await _service.markNotificationAsRead(index);
      notifications[index].isRead.value = true;
      notifications.refresh();
    }
  }

  Future<void> markAllAsRead() async {
    await _service.markAllNotificationsAsRead();
    for (var n in notifications) {
      n.isRead.value = true;
    }
    notifications.refresh();
  }

  Future<void> deleteNotification(String id) async {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      await _service.deleteNotification(index);
      notifications.removeAt(index);
      notifications.refresh();
    }
  }

  Future<void> clearAll() async {
    await _service.clearNotifications();
    notifications.clear();
  }
}

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  IconData _getIcon(String type) {
    switch (type) {
      case 'homework':
        return Icons.assignment_rounded;
      case 'leave':
        return Icons.event_busy_rounded;
      case 'announcement':
        return Icons.campaign_rounded;
      case 'timetable':
        return Icons.schedule_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _getColor(String type) {
    switch (type) {
      case 'homework':
        return AppColors.warning;
      case 'leave':
        return AppColors.danger;
      case 'announcement':
        return AppColors.info;
      case 'timetable':
        return AppColors.primary;
      default:
        return AppColors.textSecondary;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${diff.inDays}d ago';
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NotificationsController());

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: AppColors.gradientPrimary,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: const Text(
          'Notifications',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          Obx(() {
            if (ctrl.notifications.isEmpty) return const SizedBox.shrink();
            return Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
                  tooltip: 'Clear all',
                  onPressed: () {
                    Get.dialog(
                      AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Clear All Notifications'),
                        content: const Text('Are you sure you want to delete all notifications? This cannot be undone.'),
                        actions: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () {
                              ctrl.clearAll();
                              Get.back();
                            },
                            child: const Text('Clear', style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.done_all_rounded, color: Colors.white),
                  tooltip: 'Mark all as read',
                  onPressed: () {
                    ctrl.markAllAsRead();
                    Get.snackbar(
                      'Success',
                      'All notifications marked as read',
                      backgroundColor: AppColors.primary,
                      colorText: Colors.white,
                      snackPosition: SnackPosition.TOP,
                      margin: const EdgeInsets.all(16),
                      borderRadius: 12,
                    );
                  },
                ),
              ],
            );
          }),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          );
        }

        if (ctrl.notifications.isEmpty) {
          return const EmptyState(
            icon: Icons.notifications_none_rounded,
            title: 'No Notifications',
            subtitle: 'You are all caught up! No new notifications.',
          );
        }

        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: ctrl.loadNotifications,
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.notifications.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (ctx, i) {
              final item = ctrl.notifications[i];
              final iconColor = _getColor(item.type);

              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) {
                  ctrl.deleteNotification(item.id);
                },
                child: GestureDetector(
                  onTap: () {
                    ctrl.markAsRead(item.id);
                    if (item.type == 'homework') {
                      Get.toNamed(AppRoutes.homework);
                    } else if (item.type == 'leave') {
                      Get.toNamed(AppRoutes.leaves);
                    } else if (item.type == 'timetable') {
                      Get.toNamed(AppRoutes.timetable);
                    } else {
                      Get.dialog(
                        AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                          title: Row(
                            children: [
                              Icon(Icons.campaign_rounded, color: iconColor),
                              const SizedBox(width: 10),
                              const Text('Announcement'),
                            ],
                          ),
                          content: Text(item.body),
                          actions: [
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('Close'),
                            ),
                          ],
                        ),
                      );
                    }
                  },
                  child: Obx(() => Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: item.isRead.value ? Colors.white : const Color(0xFFFAF5FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: item.isRead.value
                            ? const Color(0xFFF1F5F9)
                            : AppColors.primary.withOpacity(0.15),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: iconColor.withOpacity(0.1),
                          ),
                          child: Center(
                            child: Icon(
                              _getIcon(item.type),
                              color: iconColor,
                              size: 22,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      item.title,
                                      style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 14,
                                        fontWeight: item.isRead.value
                                            ? FontWeight.w600
                                            : FontWeight.w800,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    _timeAgo(item.timestamp),
                                    style: const TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 11,
                                      color: AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.body,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!item.isRead.value) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.secondary,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                  )),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
