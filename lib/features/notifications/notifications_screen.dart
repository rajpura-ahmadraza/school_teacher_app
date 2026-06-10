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

  factory NotificationModel.fromJson(
      Map<String, dynamic> json, String defaultId) {
    final dataMap = json['data'] is Map
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};
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
  final RxList<NotificationModel> allNotifications = <NotificationModel>[].obs;
  final RxList<NotificationModel> notifications = <NotificationModel>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  int _page = 1;
  final NotificationService _service = NotificationService.instance;

  @override
  void onInit() {
    super.onInit();
    loadNotifications();

    // Listen to real-time incoming foreground notifications
    _service.newNotificationStream.listen((n) {
      final newModel = NotificationModel.fromJson(
          n, DateTime.now().millisecondsSinceEpoch.toString());
      allNotifications.insert(0, newModel);
      notifications.insert(0, newModel);
    });
  }

  Future<void> loadNotifications() async {
    isLoading.value = true;
    try {
      final saved = await _service.getSavedNotifications();
      allNotifications.value = saved.asMap().entries.map((entry) {
        return NotificationModel.fromJson(entry.value, entry.key.toString());
      }).toList();
      _page = 1;
      notifications.value = allNotifications.take(15).toList();
      hasMore.value = notifications.length < allNotifications.length;
    } catch (_) {
      allNotifications.value = [];
      _page = 1;
      notifications.value = [];
      hasMore.value = false;
    } finally {
      isLoading.value = false;
    }
  }

  void loadMore() {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    final start = _page * 15;
    final nextItems = allNotifications.skip(start).take(15).toList();
    if (nextItems.isNotEmpty) {
      notifications.addAll(nextItems);
      _page++;
    }
    hasMore.value = notifications.length < allNotifications.length;
    isLoadingMore.value = false;
  }

  Future<void> markAsRead(String id) async {
    final allIdx = allNotifications.indexWhere((n) => n.id == id);
    if (allIdx != -1 && !allNotifications[allIdx].isRead.value) {
      await _service.markNotificationAsRead(allIdx);
      allNotifications[allIdx].isRead.value = true;
      final dispIdx = notifications.indexWhere((n) => n.id == id);
      if (dispIdx != -1) {
        notifications[dispIdx].isRead.value = true;
      }
      notifications.refresh();
    }
  }

  Future<void> markAllAsRead() async {
    await _service.markAllNotificationsAsRead();
    for (var n in allNotifications) {
      n.isRead.value = true;
    }
    for (var n in notifications) {
      n.isRead.value = true;
    }
    notifications.refresh();
  }

  Future<void> deleteNotification(String id) async {
    final allIdx = allNotifications.indexWhere((n) => n.id == id);
    if (allIdx != -1) {
      await _service.deleteNotification(allIdx);
      allNotifications.removeAt(allIdx);
      final dispIdx = notifications.indexWhere((n) => n.id == id);
      if (dispIdx != -1) {
        notifications.removeAt(dispIdx);
      }
      notifications.refresh();
    }
  }

  Future<void> clearAll() async {
    await _service.clearNotifications();
    allNotifications.clear();
    notifications.clear();
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationsController ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(NotificationsController());
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!ctrl.isLoading.value &&
          !ctrl.isLoadingMore.value &&
          ctrl.hasMore.value) {
        ctrl.loadMore();
      }
    }
  }

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
                  icon: const Icon(Icons.delete_sweep_rounded,
                      color: Colors.white),
                  tooltip: 'Clear all',
                  onPressed: () {
                    Get.dialog(
                      AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(Get.height / 37.8),
                        ),
                        title: const Text('Clear All Notifications'),
                        content: const Text(
                            'Are you sure you want to delete all notifications? This cannot be undone.'),
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
                            child: const Text('Clear',
                                style: TextStyle(color: AppColors.danger)),
                          ),
                        ],
                      ),
                      barrierDismissible: false,
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
                      margin: EdgeInsets.all(Get.height / 47.25),
                      borderRadius: Get.height / 63,
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
            controller: _scrollCtrl,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.all(Get.height / 47.25),
            itemCount: ctrl.notifications.length + (ctrl.hasMore.value ? 1 : 0),
            separatorBuilder: (_, __) => SizedBox(height: Get.height / 75.6),
            itemBuilder: (ctx, i) {
              if (i == ctrl.notifications.length) {
                return Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: Get.height / 63),
                    child: const CircularProgressIndicator(
                        color: AppColors.primary),
                  ),
                );
              }
              final item = ctrl.notifications[i];
              final iconColor = _getColor(item.type);

              return Dismissible(
                key: Key(item.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  padding: EdgeInsets.symmetric(horizontal: Get.height / 37.8),
                  decoration: BoxDecoration(
                    color: AppColors.danger,
                    borderRadius: BorderRadius.circular(Get.height / 47.25),
                  ),
                  alignment: Alignment.centerRight,
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Colors.white),
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
                            borderRadius:
                                BorderRadius.circular(Get.height / 37.8),
                          ),
                          title: Row(
                            children: [
                              Icon(Icons.campaign_rounded, color: iconColor),
                              SizedBox(width: Get.height / 37.8),
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
                        barrierDismissible: false,
                      );
                    }
                  },
                  child: Obx(() => Container(
                        padding: EdgeInsets.all(Get.height / 47.25),
                        decoration: BoxDecoration(
                          color: item.isRead.value
                              ? Colors.white
                              : const Color(0xFFFAF5FF),
                          borderRadius:
                              BorderRadius.circular(Get.height / 47.25),
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
                              width: Get.height / 17.18,
                              height: Get.height / 17.18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: iconColor.withOpacity(0.1),
                              ),
                              child: Center(
                                child: Icon(
                                  _getIcon(item.type),
                                  color: iconColor,
                                  size: Get.height / 34.36,
                                ),
                              ),
                            ),
                            SizedBox(width: Get.height / 54),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          item.title,
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontSize: Get.height / 54,
                                            fontWeight: item.isRead.value
                                                ? FontWeight.w600
                                                : FontWeight.w800,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      Text(
                                        _timeAgo(item.timestamp),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: Get.height / 68.72,
                                          color: AppColors.textTertiary,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: Get.height / 126),
                                  Text(
                                    item.body,
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: Get.height / 58.15,
                                      color: AppColors.textSecondary,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!item.isRead.value) ...[
                              SizedBox(width: Get.height / 94.5),
                              Container(
                                width: Get.height / 94.5,
                                height: Get.height / 94.5,
                                margin: EdgeInsets.only(top: Get.height / 126),
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
