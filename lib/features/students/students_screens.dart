import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

// ── Controller ────────────────────────────────────────────────
class StudentsController extends GetxController {
  final _api = ApiClient.instance;

  final RxList<dynamic> students = <dynamic>[].obs;
  final Rx<Map<String, dynamic>?> studentDetail = Rx(null);
  final RxBool isLoading = false.obs;
  final RxBool isDetailLoading = false.obs;
  final RxBool hasMore = true.obs;
  final RxString error = ''.obs;
  final RxInt total = 0.obs;

  int _page = 1;
  String _search = '';

  @override
  void onInit() {
    super.onInit();
    loadStudents(refresh: true);
  }

  Future<void> loadStudents({bool refresh = false, String search = ''}) async {
    if (refresh) {
      _page = 1;
      _search = search;
      students.clear();
      hasMore.value = true;
    }
    if (!hasMore.value) return;
    isLoading.value = true;
    error.value = '';
    try {
      final params = <String, dynamic>{
        'per_page': '20',
        'page': _page.toString(),
      };
      if (_search.isNotEmpty) params['search'] = _search;
      final resp = await _api.get('/students', params: params);
      final raw = resp.data;
      final List<dynamic> list =
          List<dynamic>.from(raw['data'] as List? ?? raw as List? ?? []);
      final lastPage = _asInt(raw['last_page']) ?? 1;
      total.value = _asInt(raw['total']) ?? students.length + list.length;
      students.addAll(list);
      hasMore.value = _page < lastPage;
      _page++;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> loadStudentDetail(int id) async {
    isDetailLoading.value = true;
    studentDetail.value = null;
    error.value = '';
    try {
      final resp = await _api.get('/students/$id');
      final raw = resp.data;
      studentDetail.value = Map<String, dynamic>.from(
        raw['data'] as Map? ?? raw['student'] as Map? ?? raw as Map? ?? {},
      );
    } catch (e) {
      error.value = e.toString();
    } finally {
      isDetailLoading.value = false;
    }
  }
}

int? _asInt(dynamic v) {
  if (v is int) return v;
  if (v is String) return int.tryParse(v);
  return null;
}

// ── Students Screen ───────────────────────────────────────────
class StudentsScreen extends StatefulWidget {
  const StudentsScreen({super.key});

  @override
  State<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends State<StudentsScreen> {
  late final StudentsController ctrl;
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(StudentsController());
    _scrollCtrl.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!ctrl.isLoading.value && ctrl.hasMore.value) {
        ctrl.loadStudents();
      }
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        body: Column(children: [
          // ── Header ──────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 22),
                child: Row(children: [
                  GestureDetector(
                    onTap: () => Get.offNamed(AppRoutes.dashboard),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_ios_rounded,
                          color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Students',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white)),
                        Text('Manage your class roster',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: Colors.white70)),
                      ],
                    ),
                  ),
                  Obx(() => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${ctrl.total.value}',
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white)),
                      )),
                ]),
              ),
            ),
          ),
          // ── Search bar ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              onChanged: (v) =>
                  ctrl.loadStudents(refresh: true, search: v),
              style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search by name or roll number…',
                hintStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    color: AppColors.textTertiary),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: AppColors.textTertiary, size: 22),
                suffixIcon: Obx(() => _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          ctrl.loadStudents(refresh: true);
                        })
                    : const SizedBox.shrink()),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none),
              ),
            ),
          ),
          // ── List ──────────────────────────────────────────────
          Expanded(
            child: Obx(() {
              if (ctrl.isLoading.value && ctrl.students.isEmpty) {
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: 8,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, __) => const ShimmerCard(height: 78),
                );
              }
              if (ctrl.error.value.isNotEmpty && ctrl.students.isEmpty) {
                return ErrorState(
                    error: ctrl.error.value,
                    onRetry: () => ctrl.loadStudents(refresh: true));
              }
              if (ctrl.students.isEmpty) {
                return const EmptyState(
                    icon: Icons.people_outline,
                    title: 'No Students',
                    subtitle: 'No students found');
              }
              return RefreshIndicator(
                onRefresh: () => ctrl.loadStudents(
                    refresh: true, search: _searchCtrl.text),
                child: ListView.separated(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  itemCount:
                      ctrl.students.length + (ctrl.hasMore.value ? 1 : 0),
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    if (i == ctrl.students.length) {
                      return const Center(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: CircularProgressIndicator(
                                  color: AppColors.primary)));
                    }
                    final s = ctrl.students[i] as Map<String, dynamic>;
                    return FadeInUp(
                      duration: Duration(milliseconds: 200 + (i % 10) * 30),
                      child: _StudentCard(student: s),
                    );
                  },
                ),
              );
            }),
          ),
        ]),
      );
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final cls = student['class'] as Map? ?? {};
    final clsName = cls['name'] as String? ?? student['class_name'] as String? ?? '';
    final section = cls['section'] as String? ?? '';
    final roll = student['roll_number'] ?? student['admission_no'] ?? '-';

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.studentDetail,
          arguments: student['id'] as int? ?? 0),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(children: [
          NetAvatar(
            url: student['profile_photo'] as String?,
            radius: 26,
            fallbackLetter: (student['name'] as String? ?? '?')[0],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] as String? ?? 'Student',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text(
                  '$clsName${section.isNotEmpty ? ' – $section' : ''}  •  Roll: $roll',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ]),
          ),
          const Icon(Icons.chevron_right_rounded,
              color: AppColors.textTertiary),
        ]),
      ),
    );
  }
}

// ── Student Detail Screen ─────────────────────────────────────
class StudentDetailScreen extends StatefulWidget {
  final int studentId;
  const StudentDetailScreen({required this.studentId, super.key});

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen> {
  late final StudentsController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.find<StudentsController>();
    ctrl.loadStudentDetail(widget.studentId);
  }

  @override
  Widget build(BuildContext context) => Obx(() {
        if (ctrl.isDetailLoading.value) {
          return const Scaffold(
              body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)));
        }
        if (ctrl.error.value.isNotEmpty && ctrl.studentDetail.value == null) {
          return Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_rounded),
                onPressed: () => Get.back(),
              ),
            ),
            body: ErrorState(
              error: ctrl.error.value,
              onRetry: () => ctrl.loadStudentDetail(widget.studentId),
            ),
          );
        }
        final s = ctrl.studentDetail.value ?? {};
        return _DetailBody(student: s);
      });
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> student;
  const _DetailBody({required this.student});

  @override
  Widget build(BuildContext context) {
    final cls = student['class'] as Map? ?? {};
    final parent = student['parent'] as Map? ?? student['guardian'] as Map? ?? {};
    final address = student['address'] as String? ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: CustomScrollView(slivers: [
        SliverAppBar(
          expandedHeight: 240,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(children: [
              Container(
                  decoration: const BoxDecoration(
                      gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
              ))),
              Center(
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 40),
                      NetAvatar(
                        url: student['profile_photo'] as String?,
                        radius: 44,
                        fallbackLetter:
                            (student['name'] as String? ?? '?')[0],
                      ),
                      const SizedBox(height: 12),
                      Text(student['name'] as String? ?? 'Student',
                          style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: 22)),
                      Text(
                          '${cls['name'] ?? ''} ${cls['section'] != null ? '– ${cls['section']}' : ''}',
                          style: const TextStyle(
                              color: Colors.white70,
                              fontFamily: 'Inter',
                              fontSize: 14)),
                    ]),
              ),
            ]),
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Get.back(),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              _InfoSection(title: 'Student Info', rows: [
                InfoRow(
                    icon: Icons.badge_rounded,
                    label: 'Roll Number',
                    value: student['roll_number']?.toString() ??
                        student['admission_no']?.toString() ?? '-'),
                const SizedBox(height: 12),
                InfoRow(
                    icon: Icons.wc_rounded,
                    label: 'Gender',
                    value: student['gender'] as String? ?? '-'),
                const SizedBox(height: 12),
                InfoRow(
                    icon: Icons.cake_rounded,
                    label: 'Date of Birth',
                    value: student['dob'] as String? ??
                        student['date_of_birth'] as String? ?? '-'),
                if (address.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  InfoRow(
                      icon: Icons.home_rounded,
                      label: 'Address',
                      value: address),
                ],
              ]),
              const SizedBox(height: 16),
              if (parent.isNotEmpty)
                _InfoSection(title: 'Parent / Guardian', rows: [
                  InfoRow(
                      icon: Icons.person_rounded,
                      label: 'Name',
                      value: parent['name'] as String? ?? '-'),
                  const SizedBox(height: 12),
                  InfoRow(
                      icon: Icons.phone_rounded,
                      label: 'Phone',
                      value: parent['phone'] as String? ??
                          parent['mobile'] as String? ?? '-'),
                  if (parent['email'] != null) ...[
                    const SizedBox(height: 12),
                    InfoRow(
                        icon: Icons.email_rounded,
                        label: 'Email',
                        value: parent['email'] as String),
                  ],
                ]),
              const SizedBox(height: 32),
            ]),
          ),
        ),
      ]),
    );
  }
}

class _InfoSection extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  const _InfoSection({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 16),
          ...rows,
        ]),
      );
}
