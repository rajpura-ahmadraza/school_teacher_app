import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
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
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final isTablet = width >= 600;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _showExitConfirm(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: Obx(() {
          final user = auth.user.value;
          final name = user?['name'] as String? ?? 'Teacher';
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
                  expandedHeight: isTablet ? 176.0 : 136.0,
                  toolbarHeight: isTablet ? 76.0 : 70.0,
                  pinned: true,
                  stretch: true,
                  elevation: 0.0,
                  backgroundColor: const Color(0xFFF7F8FC),
                  automaticallyImplyLeading: false,
                  flexibleSpace: LayoutBuilder(builder:
                      (BuildContext context, BoxConstraints constraints) {
                    final double top = constraints.biggest.height;
                    final double statusBarHeight =
                        MediaQuery.of(context).padding.top;
                    final double collapsedHeight = isTablet ? 76.0 : 70.0;
                    final double minHeight = statusBarHeight + collapsedHeight;
                    final double maxHeight =
                        (isTablet ? 176.0 : 136.0) + statusBarHeight;

                    final double delta = maxHeight - minHeight;
                    final double collapsePercent =
                        ((maxHeight - top) / delta).clamp(0.0, 1.0);

                    final double expandedOpacity =
                        (1.0 - (collapsePercent / 0.5)).clamp(0.0, 1.0);
                    final double collapsedOpacity =
                        ((collapsePercent - 0.5) / 0.5).clamp(0.0, 1.0);

                    return Padding(
                      padding: EdgeInsets.only(bottom: isTablet ? 8.0 : 6.0),
                      child: Stack(
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
                              width: isTablet ? 260.0 : 170.0,
                              height: isTablet ? 260.0 : 170.0,
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
                              width: isTablet ? 200.0 : 127.0,
                              height: isTablet ? 200.0 : 127.0,
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
                            child: IgnorePointer(
                              ignoring: collapsePercent > 0.5,
                              child: Opacity(
                                opacity: expandedOpacity,
                                child: Padding(
                                  padding: EdgeInsets.fromLTRB(
                                    isTablet ? 32.0 : 20.0,
                                    0,
                                    isTablet ? 32.0 : 20.0,
                                    isTablet ? 24.0 : 16.0,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    mainAxisSize: MainAxisSize.min,
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
                                                      fontSize: isTablet
                                                          ? 16.0
                                                          : 12.0,
                                                      fontWeight:
                                                          FontWeight.w400,
                                                    )),
                                                SizedBox(
                                                    height:
                                                        isTablet ? 8.0 : 4.0),
                                                Text(name,
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontFamily: 'Inter',
                                                      fontSize: isTablet
                                                          ? 18.0
                                                          : 14.0,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    )),
                                              ],
                                            ),
                                          ),
                                          GestureDetector(
                                            onTap: () => Get.toNamed(
                                                AppRoutes.notifications),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(10.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: const Icon(
                                                  Icons.notifications_rounded,
                                                  color: Colors.white,
                                                  size: 22.0),
                                            ),
                                          ),
                                          const SizedBox(width: 8.0),
                                          GestureDetector(
                                            onTap: () => _showLogoutConfirm(
                                                context, auth),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.all(10.0),
                                              decoration: BoxDecoration(
                                                color: Colors.white
                                                    .withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(12.0),
                                              ),
                                              child: const Icon(
                                                Icons.logout_rounded,
                                                color: Colors.white,
                                                size: 22.0,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(
                                        height: isTablet ? 16.0 : 12.0,
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: isTablet ? 14.0 : 10.0,
                                            vertical: isTablet ? 8.0 : 6.0),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.15),
                                          borderRadius: BorderRadius.circular(
                                              isTablet ? 24.0 : 16.0),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              width: isTablet ? 10.0 : 8.0,
                                              height: isTablet ? 10.0 : 8.0,
                                              decoration: const BoxDecoration(
                                                color: Color(0xFF4ADE80),
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                            SizedBox(
                                                width: isTablet ? 10.0 : 6.0),
                                            Text(
                                              user?['employee_id'] != null
                                                  ? 'ID: ${user!['employee_id']}'
                                                  : user?['email'] as String? ??
                                                      'Teacher',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                                fontSize:
                                                    isTablet ? 14.0 : 12.0,
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
                            height: isTablet ? 68.0 : 64.0,
                            child: IgnorePointer(
                              ignoring: collapsePercent <= 0.5,
                              child: Opacity(
                                opacity: collapsedOpacity,
                                child: Padding(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: isTablet ? 32.0 : 20.0),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              '${_greeting()}, 👋',
                                              style: TextStyle(
                                                color: Colors.white
                                                    .withOpacity(0.85),
                                                fontFamily: 'Inter',
                                                fontSize:
                                                    isTablet ? 14.0 : 12.0,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                            const SizedBox(height: 2.0),
                                            Text(
                                              name,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                                fontSize:
                                                    isTablet ? 15.0 : 12.0,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ],
                                        ),
                                      ),
                                      GestureDetector(
                                        onTap: () => Get.toNamed(
                                            AppRoutes.notifications),
                                        child: Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                          ),
                                          child: const Icon(
                                              Icons.notifications_rounded,
                                              color: Colors.white,
                                              size: 22.0),
                                        ),
                                      ),
                                      const SizedBox(
                                        width: 8.0,
                                      ),
                                      GestureDetector(
                                        onTap: () =>
                                            _showLogoutConfirm(context, auth),
                                        child: Container(
                                          padding: const EdgeInsets.all(10.0),
                                          decoration: BoxDecoration(
                                            color:
                                                Colors.white.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(12.0),
                                          ),
                                          child: const Icon(
                                              Icons.logout_rounded,
                                              color: Colors.white,
                                              size: 22.0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),

                // ── Content ──────────────────────────────────────
                if (ctrl.isLoading.value) ...[
                  // Shimmer Stats grid
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isTablet ? 32.0 : 16.0,
                        isTablet ? 32.0 : 20.0, isTablet ? 32.0 : 16.0, 0),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: isTablet ? 24.0 : 12.0,
                      mainAxisSpacing: isTablet ? 24.0 : 12.0,
                      childAspectRatio: isTablet ? 2.5 : 1.1,
                      children: [
                        ShimmerCard(radius: isTablet ? 20.0 : 16.0),
                        ShimmerCard(radius: isTablet ? 20.0 : 16.0),
                      ],
                    ),
                  ),

                  // Shimmer Quick Actions Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, isTablet ? 40.0 : 24.0, 0, isTablet ? 20.0 : 12.0),
                      child: const SectionHeader(
                        title: 'Quick Actions',
                      ),
                    ),
                  ),

                  // Shimmer Quick Actions Grid
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32.0 : 16.0,
                    ),
                    sliver: SliverGrid.count(
                      crossAxisCount: isTablet ? 5 : 3,
                      crossAxisSpacing: isTablet ? 18.0 : 12.0,
                      mainAxisSpacing: isTablet ? 18.0 : 12.0,
                      childAspectRatio: isTablet ? 0.85 : 0.9,
                      children: List.generate(
                        7,
                        (index) => ShimmerCard(radius: isTablet ? 16.0 : 12.0),
                      ),
                    ),
                  ),

                  // Shimmer Recent Homework Header
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, isTablet ? 40.0 : 24.0, 0, isTablet ? 24.0 : 16.0),
                      child: const SectionHeader(
                        title: 'Recent Homework',
                      ),
                    ),
                  ),

                  // Shimmer Recent Homework List
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      isTablet ? 32.0 : 16.0,
                      0,
                      isTablet ? 32.0 : 16.0,
                      isTablet ? 24.0 : 16.0,
                    ),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) {
                          return Padding(
                            padding:
                                EdgeInsets.only(bottom: isTablet ? 16.0 : 10.0),
                            child: ShimmerCard(
                                height: isTablet ? 90.0 : 70.0,
                                radius: isTablet ? 16.0 : 12.0),
                          );
                        },
                        childCount: 3,
                      ),
                    ),
                  ),
                ] else ...[
                  // Stats grid
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(isTablet ? 32.0 : 16.0,
                        isTablet ? 32.0 : 20.0, isTablet ? 32.0 : 16.0, 0),
                    sliver: SliverGrid.count(
                      crossAxisCount: 2,
                      crossAxisSpacing: isTablet ? 24.0 : 12.0,
                      mainAxisSpacing: isTablet ? 24.0 : 12.0,
                      childAspectRatio: isTablet ? 2.5 : 1.1,
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
                      ],
                    ),
                  ),

                  // Quick Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                          0, isTablet ? 40.0 : 24.0, 0, isTablet ? 20.0 : 12.0),
                      child: const SectionHeader(
                        title: 'Quick Actions',
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 32.0 : 16.0,
                    ),
                    sliver: SliverGrid.count(
                      crossAxisCount: isTablet ? 5 : 3,
                      crossAxisSpacing: isTablet ? 18.0 : 12.0,
                      mainAxisSpacing: isTablet ? 18.0 : 12.0,
                      childAspectRatio: isTablet ? 0.85 : 0.9,
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
                          label: 'Leave Requests',
                          color: AppColors.danger,
                          onTap: () => Get.toNamed(AppRoutes.leaves),
                        ),
                        _QuickAction(
                          icon: Icons.photo_library_rounded,
                          label: 'Gallery',
                          color: AppColors.purple,
                          onTap: () => Get.toNamed(AppRoutes.gallery),
                        ),
                        _QuickAction(
                          icon: Icons.lock_reset_rounded,
                          label: 'Change Password',
                          color: AppColors.primary,
                          onTap: () => Get.toNamed(AppRoutes.changePassword),
                        ),
                      ],
                    ),
                  ),

                  // Recent Homework
                  if (ctrl.recentHomework.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(0, isTablet ? 40.0 : 24.0,
                            0, isTablet ? 24.0 : 16.0),
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
                        isTablet ? 32.0 : 16.0,
                        0,
                        isTablet ? 32.0 : 16.0,
                        isTablet ? 24.0 : 16.0,
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
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            color: const Color(0xFFF7F8FC),
            padding: EdgeInsets.symmetric(vertical: isTablet ? 20.0 : 12.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Powered by',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isTablet ? 14.0 : 12.0,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary,
                  ),
                ),
                SizedBox(
                  width: isTablet ? 8.0 : 4.0,
                ),
                GestureDetector(
                  onTap: () async {
                    final Uri url =
                        Uri.parse('https://www.emaadinfotech.com/get-in-touch');
                    await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: Text(
                    'Emaad Infotech®',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 14.0 : 12.0,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExitConfirm(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            isTablet ? 24.0 : 16.0,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(
            isTablet ? 32.0 : 20.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(
              isTablet ? 24.0 : 16.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Beautiful Double-Ring Gradient Glow Icon Header
              Container(
                width: isTablet ? 90.0 : 70.0,
                height: isTablet ? 90.0 : 70.0,
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
                    width: isTablet ? 64.0 : 48.0,
                    height: isTablet ? 64.0 : 48.0,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white,
                    ),
                    child: Center(
                      child: Icon(
                        Icons.power_settings_new_rounded,
                        color: AppColors.primary,
                        size: isTablet ? 36.0 : 28.0,
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: isTablet ? 24.0 : 16.0,
              ),
              // Title
              Text(
                'Exit App?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 22.0 : 18.0,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isTablet ? 12.0 : 8.0),
              // Description
              Text(
                'Are you sure you want to close the app?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 15.0 : 13.0,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(height: isTablet ? 32.0 : 24.0),
              // Premium buttons side by side
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16.0 : 12.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 14.0 : 12.0,
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
                          fontSize: isTablet ? 15.0 : 13.0,
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
                        padding: EdgeInsets.symmetric(
                            vertical: isTablet ? 16.0 : 12.0),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(isTablet ? 14.0 : 12.0),
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
                          fontSize: isTablet ? 15.0 : 13.0,
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
    final isTablet = MediaQuery.of(context).size.width >= 600;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            isTablet ? 24.0 : 16.0,
          ),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: EdgeInsets.all(
            isTablet ? 32.0 : 20.0,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(
              isTablet ? 24.0 : 16.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 16.0,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with custom circular gradient background
              Container(
                width: isTablet ? 80.0 : 60.0,
                height: isTablet ? 80.0 : 60.0,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withOpacity(0.1),
                ),
                child: Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: isTablet ? 36.0 : 28.0,
                  ),
                ),
              ),
              SizedBox(
                height: isTablet ? 24.0 : 16.0,
              ),
              // Title
              Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 22.0 : 18.0,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(
                height: isTablet ? 12.0 : 8.0,
              ),
              // Subtitle/Content
              Text(
                'Are you sure you want to sign out?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 15.0 : 13.0,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              SizedBox(
                height: isTablet ? 32.0 : 24.0,
              ),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16.0 : 12.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 14.0 : 12.0,
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
                          fontSize: isTablet ? 15.0 : 13.0,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: isTablet ? 16.0 : 12.0,
                  ),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(
                          vertical: isTablet ? 16.0 : 12.0,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isTablet ? 14.0 : 12.0,
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
                          fontSize: isTablet ? 15.0 : 13.0,
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
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 12.0 : 6.0, vertical: isTablet ? 16.0 : 8.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            isTablet ? 20.0 : 16.0,
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
              width: isTablet ? 60.0 : 44.0,
              height: isTablet ? 60.0 : 44.0,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isTablet ? 16.0 : 12.0),
                border: Border.all(color: color.withOpacity(0.2)),
              ),
              child: Icon(
                icon,
                color: color,
                size: isTablet ? 28.0 : 22.0,
              ),
            ),
            SizedBox(
              height: isTablet ? 12.0 : 8.0,
            ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: isTablet ? 13.0 : 11.0,
                fontWeight: FontWeight.w500,
                color: AppColors.textPrimary,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeworkTile extends StatefulWidget {
  final Map<String, dynamic> hw;
  const _HomeworkTile({required this.hw});

  @override
  State<_HomeworkTile> createState() => _HomeworkTileState();
}

class _HomeworkTileState extends State<_HomeworkTile> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return GestureDetector(
      onTap: _isLoading
          ? null
          : () async {
              setState(() => _isLoading = true);
              await Get.toNamed(AppRoutes.homeworkDetail, arguments: widget.hw);
              if (mounted) setState(() => _isLoading = false);
            },
      child: Stack(
        children: [
          Container(
            margin: EdgeInsets.only(bottom: isTablet ? 16.0 : 10.0),
            padding: EdgeInsets.all(isTablet ? 20.0 : 14.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                isTablet ? 18.0 : 12.0,
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
                  width: isTablet ? 54.0 : 42.0,
                  height: isTablet ? 54.0 : 42.0,
                  decoration: BoxDecoration(
                    gradient: AppColors.gradientOrange,
                    borderRadius: BorderRadius.circular(
                      isTablet ? 14.0 : 10.0,
                    ),
                  ),
                  child: Icon(
                    Icons.assignment_rounded,
                    color: Colors.white,
                    size: isTablet ? 28.0 : 22.0,
                  ),
                ),
                SizedBox(
                  width: isTablet ? 18.0 : 12.0,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.hw['title'] as String? ?? 'Homework',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: isTablet ? 18.0 : 14.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          )),
                      SizedBox(height: isTablet ? 6.0 : 2.0),
                      Text(
                        (widget.hw['class'] as Map?)?['name'] as String? ??
                            widget.hw['class_name'] as String? ??
                            '',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Inter',
                          fontSize: isTablet ? 14.0 : 12.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_isLoading)
                  SizedBox(
                    width: isTablet ? 32.0 : 22.0,
                    height: isTablet ? 32.0 : 22.0,
                    child: const CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.primary),
                  )
                else
                  Icon(Icons.chevron_right_rounded,
                      color: AppColors.textTertiary,
                      size: isTablet ? 30.0 : 24.0),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
