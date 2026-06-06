import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
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

  Future<void> loadAll() async {
    isLoading.value = true;
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
      recentHomework.value = List<dynamic>.from(hd['data'] ?? hd ?? []);
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
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
          return RefreshIndicator(
            color: AppColors.primary,
            backgroundColor: Colors.white,
            onRefresh: () => ctrl.loadAll(),
            child: CustomScrollView(
              slivers: [
                // ── Header ──────────────────────────────────────
                SliverAppBar(
                  expandedHeight: 150,
                  pinned: true,
                  stretch: true,
                  backgroundColor: AppColors.primary,
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
                                    onTap: () => auth.logout(),
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
                      childAspectRatio: 1.35,
                      children: [
                        FadeInUp(
                          duration: const Duration(milliseconds: 300),
                          child: StatCard(
                            title: 'Total Students',
                            value: ctrl.dashData.value?['total_students']
                                    ?.toString() ??
                                '--',
                            icon: Icons.people_rounded,
                            gradient: AppColors.gradientPrimary,
                            onTap: () => Get.toNamed(AppRoutes.students),
                          ),
                        ),
                        FadeInUp(
                          duration: const Duration(milliseconds: 350),
                          child: StatCard(
                            title: 'Present Today',
                            value: ctrl.dashData.value?['present_today']
                                    ?.toString() ??
                                '--',
                            icon: Icons.check_circle_rounded,
                            gradient: AppColors.gradientGreen,
                            onTap: () => Get.toNamed(AppRoutes.attendance),
                          ),
                        ),
                        FadeInUp(
                          duration: const Duration(milliseconds: 400),
                          child: StatCard(
                            title: 'Homework',
                            value: ctrl.dashData.value?['pending_homework']
                                    ?.toString() ??
                                '--',
                            icon: Icons.assignment_rounded,
                            gradient: AppColors.gradientOrange,
                            onTap: () => Get.toNamed(AppRoutes.homework),
                          ),
                        ),
                        FadeInUp(
                          duration: const Duration(milliseconds: 450),
                          child: StatCard(
                            title: 'Leave Requests',
                            value: ctrl.pendingLeaves.length.toString(),
                            icon: Icons.event_busy_rounded,
                            gradient: AppColors.gradientRed,
                            onTap: () => Get.toNamed(AppRoutes.leaves),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Actions
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeader(title: 'Quick Actions'),
                          const SizedBox(height: 12),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: Row(children: [
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
                                onTap: () => Get.toNamed(AppRoutes.homework),
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
                            ]),
                          ),
                        ],
                      ),
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
                          onAction: () => Get.toNamed(AppRoutes.homework),
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
          margin: const EdgeInsets.only(right: 12),
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.2)),
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 6),
              Text(label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  )),
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
