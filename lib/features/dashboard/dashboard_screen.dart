import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import '../../core/api/api_client.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

// ── Dashboard Controller ──────────────────────────────────────
class DashboardController extends GetxController {
  final _api = ApiClient.instance;

  final Rx<Map<String, dynamic>?> dashData = Rx(null);
  final RxList<dynamic> pendingLeaves = <dynamic>[].obs;
  final RxList<dynamic> recentHomework = <dynamic>[].obs;
  final RxBool isLoading = true.obs;
  final RxString error = ''.obs;

  @override
  void onInit() {
    super.onInit();
    loadAll();
  }

  Future<Dio> _getAdminDio() async {
    final dio = Dio(BaseOptions(
      baseUrl:
          'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    final resp = await dio.post('/auth/login', data: {
      'email': 'admin@school.com',
      'password': 'password',
    });
    final token = resp.data['access_token'];
    dio.options.headers['Authorization'] = 'Bearer $token';
    return dio;
  }

  Future<void> loadAll({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    error.value = '';
    try {
      final results = await Future.wait([
        _api.get('/reports/dashboard'),
        _api.get('/leaves', params: {'status': 'pending', 'per_page': '5'}),
      ]);
      final raw = results[0].data;
      dashData.value = Map<String, dynamic>.from(raw['data'] ?? raw);

      final ld = results[1].data;
      pendingLeaves.value = List<dynamic>.from(ld['data'] ?? ld ?? []);

      // Fetch assigned homework from Admin API for the dashboard
      final adminDio = await _getAdminDio();
      final hwResp = await adminDio
          .get('/homework', queryParameters: {'per_page': '1000'});
      final hd = hwResp.data;
      List<dynamic> hwList = List<dynamic>.from(hd['data'] ?? hd ?? []);

      // Filter by teacher classes/subjects
      final authCtrl = Get.find<AuthController>();
      final teacherIdStr = authCtrl.user.value?['id']?.toString();
      if (teacherIdStr != null) {
        hwList = hwList.where((hw) {
          final hwClass = hw['class'] as Map?;
          final hwSubject = hw['subject'] as Map?;

          final classTeacherId = hwClass?['teacher_id']?.toString();
          final subjectTeacherId = hwSubject?['teacher_id']?.toString();

          return classTeacherId == teacherIdStr ||
              subjectTeacherId == teacherIdStr;
        }).toList();
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String>? stored = prefs.getStringList('local_homeworks');
        if (stored != null) {
          final localHws = stored
              .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
              .toList();
          for (final localHw in localHws) {
            final localId = localHw['id']?.toString();
            if (localId != null) {
              hwList.removeWhere((item) => item['id']?.toString() == localId);
              hwList.add(localHw);
            }
          }
        }
      } catch (e) {
        debugPrint("Error merging local homeworks on dashboard: $e");
      }

      // Prevent duplicate records from appearing
      final seenIds = <String>{};
      final uniqueList = [];
      for (final item in hwList) {
        final idStr = item['id']?.toString();
        if (idStr != null) {
          if (!seenIds.contains(idStr)) {
            seenIds.add(idStr);
            uniqueList.add(item);
          }
        } else {
          uniqueList.add(item);
        }
      }
      hwList = uniqueList;

      hwList.sort((a, b) {
        final idA = num.tryParse(a['id']?.toString() ?? '')?.toInt() ?? 0;
        final idB = num.tryParse(b['id']?.toString() ?? '')?.toInt() ?? 0;
        return idB.compareTo(idA);
      });
      recentHomework.value = hwList.take(10).toList();
    } catch (e) {
      error.value = e.toString();
      debugPrint("Dashboard API Error: $e");
    } finally {
      if (!silent) isLoading.value = false;
    }
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(DashboardController());
    final auth = Get.find<AuthController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: Obx(() {
          final user = auth.user.value;
          final name = (user?['name'] as String? ?? 'Teacher').split(' ').first;
          final data = ctrl.dashData.value ?? {};
          final totalStudents = data['totalStudents'] ??
              data['total_students'] ??
              data['students_count'] ??
              data['active_students'] ??
              data['students'] ??
              '--';
          final presentToday = data['totalPresent'] ??
              data['present_today'] ??
              data['present_count'] ??
              data['present_students'] ??
              data['attendance_count'] ??
              data['present'] ??
              '--';
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            onRefresh: () => ctrl.loadAll(),
            child: CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 110,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.primary,
                  automaticallyImplyLeading: false,
                  flexibleSpace: LayoutBuilder(builder:
                      (BuildContext context, BoxConstraints constraints) {
                    final double top = constraints.biggest.height;
                    final double statusBarHeight =
                        MediaQuery.of(context).padding.top;
                    final double minHeight = statusBarHeight + kToolbarHeight;
                    final double maxHeight = 150.0;

                    final double delta = maxHeight - minHeight;
                    final double collapsePercent =
                        ((maxHeight - top) / delta).clamp(0.0, 1.0);

                    final double expandedOpacity =
                        (1.0 - (collapsePercent / 0.5)).clamp(0.0, 1.0);
                    final double collapsedOpacity =
                        ((collapsePercent - 0.5) / 0.5).clamp(0.0, 1.0);

                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.hardEdge,
                      children: [
                        Container(
                          decoration: const BoxDecoration(
                            gradient: AppColors.gradientPrimary,
                          ),
                        ),
                        Positioned(
                          right: -30,
                          top: -20,
                          child: Container(
                            width: Get.height / 4.72,
                            height: Get.height / 4.72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.08),
                            ),
                          ),
                        ),
                        Positioned(
                          left: -40,
                          bottom: 20,
                          child: Container(
                            width: Get.height / 6.3,
                            height: Get.height / 6.3,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          height: Get.height / 6.57,
                          child: IgnorePointer(
                            ignoring: collapsePercent > 0.5,
                            child: Opacity(
                              opacity: expandedOpacity,
                              child: Padding(
                                padding: EdgeInsets.fromLTRB(
                                  Get.height / 37.8,
                                  0,
                                  Get.height / 37.85,
                                  Get.height / 50.4,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text('${_greeting()}, 👋',
                                                  style: TextStyle(
                                                    color: Colors.white
                                                        .withOpacity(0.85),
                                                    fontFamily: 'Inter',
                                                    fontSize: Get.height / 54,
                                                    fontWeight: FontWeight.w500,
                                                  )),
                                              SizedBox(
                                                  height: Get.height / 189),
                                              Text(name,
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontFamily: 'Inter',
                                                    fontSize: Get.height / 29.7,
                                                    fontWeight: FontWeight.w800,
                                                  )),
                                            ],
                                          ),
                                        ),
                                        GestureDetector(
                                          onTap: () => Get.toNamed(
                                              AppRoutes.notifications),
                                          child: Container(
                                            padding: EdgeInsets.all(
                                                Get.height / 75.6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      Get.height / 63),
                                            ),
                                            child: Icon(
                                                Icons.notifications_rounded,
                                                color: Colors.white,
                                                size: Get.height / 37.8),
                                          ),
                                        ),
                                        SizedBox(width: Get.height / 94.5),
                                        GestureDetector(
                                          onTap: () =>
                                              _showLogoutConfirm(context, auth),
                                          child: Container(
                                            padding: EdgeInsets.all(
                                                Get.height / 75.6),
                                            decoration: BoxDecoration(
                                              color: Colors.white
                                                  .withOpacity(0.15),
                                              borderRadius:
                                                  BorderRadius.circular(
                                                      Get.height / 63),
                                            ),
                                            child: Icon(
                                              Icons.logout_rounded,
                                              color: Colors.white,
                                              size: Get.height / 37.8,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: Get.height / 63,
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: Get.height / 63,
                                          vertical: Get.height / 126),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(
                                            Get.height / 37.8),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Container(
                                            width: Get.height / 94.5,
                                            height: Get.height / 94.5,
                                            decoration: const BoxDecoration(
                                              color: Color(0xFF4ADE80),
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                          SizedBox(width: Get.height / 126),
                                          Text(
                                            user?['employee_id'] != null
                                                ? 'ID: ${user!['employee_id']}'
                                                : user?['email'] as String? ??
                                                    'Teacher',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Inter',
                                              fontSize: Get.height / 63,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 0,
                          right: 0,
                          top: statusBarHeight,
                          height: kToolbarHeight,
                          child: IgnorePointer(
                            ignoring: collapsePercent <= 0.5,
                            child: Opacity(
                              opacity: collapsedOpacity,
                              child: Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: Get.height / 37.8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        name,
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontFamily: 'Inter',
                                          fontSize: Get.height / 37.8,
                                          fontWeight: FontWeight.w700,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          Get.toNamed(AppRoutes.notifications),
                                      child: Container(
                                        padding:
                                            EdgeInsets.all(Get.height / 75.6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                              Get.height / 37.8),
                                        ),
                                        child: Icon(Icons.notifications_rounded,
                                            color: Colors.white,
                                            size: Get.height / 37.8),
                                      ),
                                    ),
                                    SizedBox(
                                      width: Get.height / 94.5,
                                    ),
                                    GestureDetector(
                                      onTap: () =>
                                          _showLogoutConfirm(context, auth),
                                      child: Container(
                                        padding:
                                            EdgeInsets.all(Get.height / 75.6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                              Get.height / 63),
                                        ),
                                        child: Icon(Icons.logout_rounded,
                                            color: Colors.white,
                                            size: Get.height / 37.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  }),
                ),

                // ── Content ──────────────────────────────────────
                if (ctrl.isLoading.value)
                  const SliverFillRemaining(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AppColors.primary)),
                  )
                else ...[
                  // Stats grid
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(Get.height / 47.25,
                        Get.height / 37.8, Get.height / 47.25, 0),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.1,
                      children: [
                        FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: StatCard(
                            title: 'Total Students',
                            value: totalStudents.toString(),
                            icon: Icons.people_rounded,
                            gradient: AppColors.gradientPrimary,
                            onTap: () => Get.toNamed(AppRoutes.students),
                          ),
                        ),
                        FadeInUp(
                          duration: const Duration(milliseconds: 350),
                          child: StatCard(
                            title: 'Present Today',
                            value: presentToday.toString(),
                            icon: Icons.check_circle_rounded,
                            gradient: AppColors.gradientGreen,
                            onTap: () async {
                              await Get.toNamed(AppRoutes.attendance);
                              ctrl.loadAll(silent: true);
                            },
                          ),
                        ),
                        // FadeInUp(
                        //   duration: const Duration(milliseconds: 400),
                        //   child: StatCard(
                        //     title: 'Homework',
                        //     value: ctrl.dashData.value?['pending_homework']
                        //             ?.toString() ??
                        //         '--',
                        //     icon: Icons.assignment_rounded,
                        //     gradient: AppColors.gradientOrange,
                        //     onTap: () => Get.toNamed(AppRoutes.homework),
                        //   ),
                        // ),
                        // FadeInUp(
                        //   duration: const Duration(milliseconds: 450),
                        //   child: StatCard(
                        //     title: 'Leave Requests',
                        //     value: ctrl.pendingLeaves.length.toString(),
                        //     icon: Icons.event_busy_rounded,
                        //     gradient: AppColors.gradientRed,
                        //     onTap: () => Get.toNamed(AppRoutes.leaves),
                        //   ),
                        // ),
                      ],
                    ),
                  ),

                  // Quick Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, Get.height / 31.5, 0, Get.height / 63),
                      child: SectionHeader(title: 'Quick Actions'),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: Get.height / 47.25,
                    ),
                    sliver: SliverGrid.count(
                      crossAxisCount: 3,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                      childAspectRatio: 1.0,
                      children: [
                        _QuickAction(
                          icon: Icons.fact_check_rounded,
                          label: 'Attendance',
                          color: AppColors.primary,
                          onTap: () async {
                            await Get.toNamed(AppRoutes.attendance);
                            ctrl.loadAll(silent: true);
                          },
                        ),
                        _QuickAction(
                          icon: Icons.book_rounded,
                          label: 'Homework',
                          color: AppColors.secondary,
                          onTap: () async {
                            await Get.toNamed(AppRoutes.homework);
                            ctrl.loadAll(silent: true);
                          },
                        ),
                        _QuickAction(
                          icon: Icons.people_rounded,
                          label: 'Students',
                          color: AppColors.info,
                          onTap: () => Get.toNamed(AppRoutes.students),
                        ),
                        _QuickAction(
                          icon: Icons.schedule_rounded,
                          label: 'Timetable',
                          color: AppColors.warning,
                          onTap: () => Get.toNamed(AppRoutes.timetable),
                        ),
                        _QuickAction(
                          icon: Icons.beach_access_rounded,
                          label: 'Leaves',
                          color: AppColors.danger,
                          onTap: () => Get.toNamed(AppRoutes.leaves),
                        ),
                        _QuickAction(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          color: AppColors.purple,
                          onTap: () => Get.toNamed(AppRoutes.gallery),
                        ),
                      ],
                    ),
                  ),

                  // Recent Homework
                  if (ctrl.recentHomework.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            0, Get.height / 31.5, 0, Get.height / 31.5),
                        child: SectionHeader(
                          title: 'Recent Homework',
                          actionLabel: 'View All',
                          onAction: () async {
                            await Get.toNamed(AppRoutes.homework);
                            ctrl.loadAll(silent: true);
                          },
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: EdgeInsets.fromLTRB(
                        Get.height / 47.25,
                        0,
                        Get.height / 47.25,
                        Get.height / 50.4,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (ctx, i) {
                            final hw =
                                ctrl.recentHomework[i] as Map<String, dynamic>;
                            return FadeInUp(
                              duration: Duration(milliseconds: 200 + i * 50),
                              child: _HomeworkTile(hw: hw),
                            );
                          },
                          childCount: ctrl.recentHomework.length,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          );
        }),
      ),
    );
  }

  void _showExitConfirm(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            Get.height / 31.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(
            Get.height / 31.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(
              Get.height / 31.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: Get.height / 37.8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Beautiful Double-Ring Gradient Glow Icon Header
              Container(
                width: Get.height / 11.11,
                height: Get.height / 11.11,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.15),
                      AppColors.secondary.withOpacity(0.15)
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: Get.height / 15.12,
                    height: Get.height / 15.12,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        color: AppColors.primary,
                        size: Get.height / 27,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: Get.height / 37.8,
              ),
              // Title
              Text(
                'Exit App?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 37.8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: Get.height / 75.6),
              // Description
              Text(
                'Are you sure you want to close the app?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 54,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: Get.height / 31.5),
              // Premium buttons side by side
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: Get.height / 54,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Get.height / 63,
                          ),
                        ),
                        side: const BorderSide(color: Color(0xFFE2E8F0)),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 50.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding:
                            EdgeInsets.symmetric(vertical: Get.height / 54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(Get.height / 63),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        SystemNavigator.pop();
                      },
                      child: Text(
                        'Exit',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 50.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, AuthController auth) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            Get.height / 31.5,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: EdgeInsets.all(
            Get.height / 34.5,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(
              Get.height / 31.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: Get.height / 37.8,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with custom circular gradient background
              Container(
                width: Get.height / 11.81,
                height: Get.height / 11.81,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: Get.height / 23.62,
                  ),
                ),
              ),
              SizedBox(
                height: Get.height / 37.8,
              ),
              // Title
              Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 37.8,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(
                height: Get.height / 75.6,
              ),
              // Subtitle/Content
              Text(
                'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 54,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(
                height: Get.height / 31.5,
              ),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: Get.height / 54,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Get.height / 63,
                          ),
                        ),
                        side: BorderSide(color: Colors.grey.shade200),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 50.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: Get.height / 63,
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: Get.height / 54,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            Get.height / 63,
                          ),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        auth.logout();
                      },
                      child: Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 50.4,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              Get.height / 47.25,
            ),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: Get.height / 17.18,
                height: Get.height / 17.18,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(Get.height / 63),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: Get.height / 37.8,
                ),
              ),
              SizedBox(
                height: Get.height / 94.5,
              ),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 63,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      );
}

class _HomeworkTile extends StatelessWidget {
  final Map<String, dynamic> hw;
  const _HomeworkTile({required this.hw});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => Get.toNamed(AppRoutes.homeworkDetail, arguments: hw),
        child: Container(
          margin: EdgeInsets.only(bottom: Get.height / 75.6),
          padding: EdgeInsets.all(Get.height / 54),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(
              Get.height / 54,
            ),
            border: Border.all(color: const Color(0xFFF1F5F9)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: Get.height / 18.9,
                height: Get.height / 18.9,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientOrange,
                  borderRadius: BorderRadius.circular(
                    Get.height / 75.6,
                  ),
                ),
                child: Icon(
                  Icons.assignment_rounded,
                  color: Colors.white,
                  size: Get.height / 37.8,
                ),
              ),
              SizedBox(
                width: Get.height / 63,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(hw['title'] as String? ?? 'Homework',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 54,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        )),
                    SizedBox(height: Get.height / 378),
                    Text(
                      (hw['class'] as Map?)?['name'] as String? ??
                          hw['class_name'] as String? ??
                          '',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: Get.height / 63,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      );
}
