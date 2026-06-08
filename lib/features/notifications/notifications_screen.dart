import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final String type; // 'homework', 'leave', 'announcement', 'timetable'
  final DateTime timestamp;
  bool isRead;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });
}

class NotificationsController extends GetxController {
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      // Simulate API load and populate with premium mock data
      await Future.delayed(const Duration(milliseconds: 600));
      _loadMockNotifications();
    } catch (_) {
      _loadMockNotifications();
    } finally {
      isLoading.value = false;
    }
  }

  void _loadMockNotifications() {
    notifications.value = [
      NotificationModel(
        id: '1',
        title: 'New Homework Assigned',
        body: 'Mathematics homework assigned to Grade 4-A. Due: Jun 12, 2026.',
        type: 'homework',
        timestamp: DateTime.now().subtract(const Duration(minutes: 10)),
        isRead: false,
      ),
      NotificationModel(
        id: '2',
        title: 'Leave Request Received',
        body: 'Aarav Sharma has requested sick leave for Jun 10, 2026.',
        type: 'leave',
        timestamp: DateTime.now().subtract(const Duration(hours: 2)),
        isRead: false,
      ),
      NotificationModel(
        id: '3',
        title: 'Staff Meeting Announcement',
        body:
            'All staff members are requested to join the main hall at 3:00 PM for a briefing.',
        type: 'announcement',
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
        isRead: true,
      ),
      NotificationModel(
        id: '4',
        title: 'Timetable Updated',
        body:
            'Your timetable for Thursday has been adjusted. Please review the updated schedule.',
        type: 'timetable',
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
        isRead: true,
      ),
    ];
  }

  void markAsRead(String id) {
    final index = notifications.indexWhere((n) => n.id == id);
    if (index != -1) {
      notifications[index].isRead = true;
      notifications.refresh();
    }
  }

  void markAllAsRead() {
    for (var n in notifications) {
      n.isRead = true;
    }
    notifications.refresh();
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
            return IconButton(
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

              return GestureDetector(
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
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: item.isRead ? Colors.white : const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: item.isRead
                          ? const Color(0xFFF1F5F9)
                          : AppColors.primary.withValues(alpha: 0.15),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
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
                          color: iconColor.withValues(alpha: 0.1),
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
                                      fontWeight: item.isRead
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
                      if (!item.isRead) ...[
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
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
