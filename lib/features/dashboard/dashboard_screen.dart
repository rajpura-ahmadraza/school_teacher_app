import 'dart:convert';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
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

  Future<void> loadAll({bool silent = false}) async {
    if (!silent) isLoading.value = true;
    error.value = '';
    try {
      final results = await Future.wait([
        _api.get('/reports/dashboard'),
        _api.get('/leaves', params: {'status': 'pending', 'per_page': '5'}),
        _api.get('/homework', params: {'per_page': '4'}),
      ]);
      final raw = results[0].data;
      dashData.value = Map<String, dynamic>.from(raw['data'] ?? raw);

      final ld = results[1].data;
      pendingLeaves.value = List<dynamic>.from(ld['data'] ?? ld ?? []);

      final hd = results[2].data;
      final List<dynamic> hwList = List<dynamic>.from(hd['data'] ?? hd ?? []);
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
      hwList.sort((a, b) {
        final idA = num.tryParse(a['id']?.toString() ?? '')?.toInt() ?? 0;
        final idB = num.tryParse(b['id']?.toString() ?? '')?.toInt() ?? 0;
        return idB.compareTo(idA);
      });
      recentHomework.value = hwList.take(4).toList();
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
                  expandedHeight: 140,
                  pinned: false,
                  stretch: true,
                  backgroundColor: Colors.transparent,
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    stretchModes: const [StretchMode.zoomBackground],
                    background: Stack(
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
                            width: 160,
                            height: 160,
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
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withOpacity(0.05),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
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
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                            )),
                                        const SizedBox(height: 4),
                                        Text(name,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Inter',
                                              fontSize: 26,
                                              fontWeight: FontWeight.w800,
                                            )),
                                      ],
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () =>
                                        Get.toNamed(AppRoutes.notifications),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white
                                            .withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(
                                          Icons.notifications_rounded,
                                          color: Colors.white,
                                          size: 20),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () =>
                                        _showLogoutConfirm(context, auth),
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.logout_rounded,
                                          color: Colors.white, size: 20),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF4ADE80),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      user?['employee_id'] != null
                                          ? 'ID: ${user!['employee_id']}'
                                          : user?['email'] as String? ??
                                              'Teacher',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
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
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
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
                            onTap: () => Get.toNamed(AppRoutes.attendance),
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
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(0, 24, 0, 12),
                      child: SectionHeader(title: 'Quick Actions'),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
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
                          onTap: () => Get.toNamed(AppRoutes.attendance),
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
                        padding: const EdgeInsets.fromLTRB(0, 24, 0, 12),
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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

                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Exit App?',
            style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
        content: const Text('Do you want to close the app?',
            style: TextStyle(fontFamily: 'Inter')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(fontFamily: 'Inter')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () {
              Navigator.pop(context);
              SystemNavigator.pop();
            },
            child: const Text('Exit',
                style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirm(BuildContext context, AuthController auth) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.rectangle,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with custom circular gradient background
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.danger.withOpacity(0.1),
                ),
                child: const Center(
                  child: Icon(
                    Icons.logout_rounded,
                    color: AppColors.danger,
                    size: 32,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Title
              const Text(
                'Logout',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              // Subtitle/Content
              const Text(
                'Are you sure you want to sign out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: Colors.grey.shade200),
                        foregroundColor: AppColors.textSecondary,
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.danger,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        auth.logout();
                      },
                      child: const Text(
                        'Logout',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 15,
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
            borderRadius: BorderRadius.circular(16),
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
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
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
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: AppColors.gradientOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.assignment_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hw['title'] as String? ?? 'Homework',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(
                    (hw['class'] as Map?)?['name'] as String? ??
                        hw['class_name'] as String? ??
                        '',
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
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
      );
}
