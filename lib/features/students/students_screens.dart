import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
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

  // Standard / Class filter
  final RxList<Map<String, dynamic>> classList = <Map<String, dynamic>>[].obs;
  final Rx<Map<String, dynamic>?> selectedClass = Rx(null); // null = All

  int _page = 1;
  String _search = '';

  @override
  void onInit() {
    super.onInit();
    _loadAllStudentsForClasses();
    loadStudents(refresh: true);
  }

  // Fetch ALL students (no class filter) and extract unique classes for dropdown
  Future<void> _loadAllStudentsForClasses() async {
    try {
      // Fetch up to 200 students to extract all teacher-visible classes
      final resp = await _api.get('/students', params: {
        'per_page': '200',
        'page': '1',
      });
      final raw = resp.data;
      final List<dynamic> allStudents =
          List<dynamic>.from(raw['data'] as List? ?? raw as List? ?? []);

      // Extract unique classes from students
      final Map<dynamic, Map<String, dynamic>> seen = {};
      for (final s in allStudents) {
        final cls = (s as Map)['class'] as Map?;
        if (cls == null) continue;
        final id = cls['id'];
        if (id != null && !seen.containsKey(id)) {
          seen[id] = {
            'id': id,
            'name': cls['name'] as String? ?? 'Class',
            'section': cls['section'] as String? ?? '',
          };
        }
      }

      // Sort by name then section
      final sorted = seen.values.toList()
        ..sort((a, b) {
          final nameCompare =
              (a['name'] as String).compareTo(b['name'] as String);
          if (nameCompare != 0) return nameCompare;
          return (a['section'] as String).compareTo(b['section'] as String);
        });

      classList.value = sorted;
    } catch (_) {
      // silently ignore
    }
  }

  Future<void> loadStudents({
    bool refresh = false,
    String search = '',
    Map<String, dynamic>? classFilter,
    bool keepClass = false,
  }) async {
    if (refresh) {
      _page = 1;
      _search = search;
      students.clear();
      hasMore.value = true;
      if (!keepClass && classFilter != null) {
        selectedClass.value = classFilter;
      }
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
      final cls = selectedClass.value;
      if (cls != null) {
        final id = cls['id'];
        if (id != null) params['class_id'] = id.toString();
      }
      final resp = await _api.get('/students', params: params);
      final raw = resp.data;
      List<dynamic> list =
          List<dynamic>.from(raw['data'] as List? ?? raw as List? ?? []);
      final lastPage = _asInt(raw['last_page']) ?? 1;
      total.value = _asInt(raw['total']) ?? students.length + list.length;
      // ── Name-only filter: exclude admission_no matches ────────
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        list = list.where((s) {
          final name = ((s as Map)['name'] as String? ?? '').toLowerCase();
          return name.contains(q);
        }).toList();
      }
      // Deduplicate: only add students whose ID is not already in the list
      final existingIds = students
          .map((s) => (s as Map)['id'])
          .toSet();
      final uniqueList = list.where((s) {
        final id = (s as Map)['id'];
        return id != null && !existingIds.contains(id);
      }).toList();
      students.addAll(uniqueList);
      hasMore.value = _page < lastPage;
      _page++;
    } catch (e) {
      error.value = e.toString();
    } finally {
      isLoading.value = false;
    }
  }

  void selectClass(Map<String, dynamic>? cls) {
    selectedClass.value = cls;
    loadStudents(refresh: true, search: _search, keepClass: true);
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

  Future<bool> uploadStudentPhoto(int id, String filePath) async {
    try {
      final formData = dio.FormData.fromMap({
        'profile_photo': await dio.MultipartFile.fromFile(filePath),
      });
      await _api.post('/students/$id/upload-photo', formData);
      await loadStudentDetail(id);
      return true;
    } catch (_) {
      try {
        final formData = dio.FormData.fromMap({
          'photo': await dio.MultipartFile.fromFile(filePath),
          '_method': 'PUT',
        });
        await _api.post('/students/$id', formData);
        await loadStudentDetail(id);
        return true;
      } catch (_) {
        return false;
      }
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
  final _stdDropdownKey = GlobalKey();
  OverlayEntry? _dropdownOverlay;
  bool _dropdownOpen = false;

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(StudentsController());
    _scrollCtrl.addListener(_onScroll);
    _searchCtrl.addListener(() {
      setState(() {});
    });
  }

  void _onScroll() {
    if (_scrollCtrl.position.pixels >=
        _scrollCtrl.position.maxScrollExtent - 200) {
      if (!ctrl.isLoading.value && ctrl.hasMore.value) {
        ctrl.loadStudents();
      }
    }
  }

  void _openDropdown() {
    if (_dropdownOpen) {
      _closeDropdown();
      return;
    }
    final renderBox =
        _stdDropdownKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final offset = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _dropdownOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: _closeDropdown,
        child: Stack(
          children: [
            Positioned(
              left: offset.dx,
              top: offset.dy + size.height + 4,
              width: size.width,
              child: Material(
                color: Colors.transparent,
                child: _StandardDropdownPanel(
                  ctrl: ctrl,
                  onSelect: (cls) {
                    ctrl.selectClass(cls);
                    _closeDropdown();
                    setState(() {});
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
    Overlay.of(context).insert(_dropdownOverlay!);
    setState(() => _dropdownOpen = true);
  }

  void _closeDropdown() {
    _dropdownOverlay?.remove();
    _dropdownOverlay = null;
    if (mounted) setState(() => _dropdownOpen = false);
  }

  @override
  void dispose() {
    _closeDropdown();
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
          // ── Search bar + Standard Dropdown (same row) ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Row(children: [
              // Search field (expanded)
              Expanded(
                child: SizedBox(
                  height: 48,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => ctrl.loadStudents(
                        refresh: true, search: v, keepClass: true),
                    style:
                        const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Search by name',
                      hintStyle: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          color: AppColors.textTertiary),
                      prefixIcon: const Icon(Icons.search_rounded,
                          color: AppColors.textTertiary, size: 20),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon:
                                  const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchCtrl.clear();
                                ctrl.loadStudents(
                                    refresh: true, keepClass: true);
                              })
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 0),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Compact Standard dropdown button
              Obx(() {
                final selected = ctrl.selectedClass.value;
                String label;
                if (selected == null) {
                  label = 'All';
                } else {
                  final name = selected['name'] as String? ?? 'Std';
                  final section = selected['section'] as String? ?? '';
                  label = section.isNotEmpty ? '$name-$section' : name;
                }
                return GestureDetector(
                  key: _stdDropdownKey,
                  onTap: _openDropdown,
                  child: Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: _dropdownOpen
                          ? const Color(0xFF9333EA)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _dropdownOpen
                            ? const Color(0xFF9333EA)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.class_outlined,
                          size: 16,
                          color: _dropdownOpen
                              ? Colors.white
                              : const Color(0xFF9333EA)),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _dropdownOpen
                                ? Colors.white
                                : AppColors.textPrimary),
                      ),
                      const SizedBox(width: 4),
                      AnimatedRotation(
                        turns: _dropdownOpen ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(Icons.keyboard_arrow_down_rounded,
                            color: _dropdownOpen
                                ? Colors.white
                                : AppColors.textTertiary,
                            size: 18),
                      ),
                    ]),
                  ),
                );
              }),
            ]),
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
                    refresh: true,
                    search: _searchCtrl.text,
                    keepClass: true),
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

// ── Standard Dropdown Panel (Overlay) ────────────────────────
class _StandardDropdownPanel extends StatelessWidget {
  final StudentsController ctrl;
  final void Function(Map<String, dynamic>?) onSelect;
  const _StandardDropdownPanel(
      {required this.ctrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final classes = ctrl.classList;
      final selected = ctrl.selectedClass.value;

      return Container(
        constraints: const BoxConstraints(maxHeight: 260),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── All option ──
                _DropdownItem(
                  label: 'All',
                  isSelected: selected == null,
                  onTap: () => onSelect(null),
                ),
                if (classes.isNotEmpty)
                  const Divider(height: 1, indent: 16, endIndent: 16),
                ...classes.map((cls) {
                  final name = cls['name'] as String? ?? 'Class';
                  final section = cls['section'] as String? ?? '';
                  final fullLabel = section.isNotEmpty ? '$name - $section' : name;
                  final isSelected =
                      selected != null && selected['id'] == cls['id'];
                  return _DropdownItem(
                    label: fullLabel,
                    isSelected: isSelected,
                    onTap: () => onSelect(cls),
                  );
                }),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _DropdownItem extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  const _DropdownItem(
      {required this.label,
      required this.isSelected,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        color: isSelected
            ? const Color(0xFF9333EA).withOpacity(0.07)
            : Colors.transparent,
        child: Row(children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight:
                    isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF9333EA)
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_rounded,
                color: Color(0xFF9333EA), size: 18),
        ]),
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final Map<String, dynamic> student;
  const _StudentCard({required this.student});

  @override
  Widget build(BuildContext context) {
    final cls = student['class'] as Map? ?? {};
    final clsName =
        cls['name'] as String? ?? student['class_name'] as String? ?? '';
    final section = cls['section'] as String? ?? '';
    final photoUrl = student['profile_photo'] as String? ??
        student['image'] as String? ??
        student['photo'] as String? ??
        student['avatar'] as String? ??
        student['admission_image'] as String?;

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
            url: photoUrl,
            radius: 26,
            fallbackLetter: (student['name'] as String? ?? '?')[0],
          ),
          const SizedBox(width: 14),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] as String? ?? 'Student',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 2),
              Text('$clsName${section.isNotEmpty ? ' – $section' : ''}',
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
    final parent =
        student['parent'] as Map? ?? student['guardian'] as Map? ?? {};
    final address = student['address'] as String? ?? '';
    final photoUrl = student['profile_photo'] as String? ??
        student['image'] as String? ??
        student['photo'] as String? ??
        student['avatar'] as String? ??
        student['admission_image'] as String?;

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
                        url: photoUrl,
                        radius: 44,
                        fallbackLetter: (student['name'] as String? ?? '?')[0],
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
                    icon: Icons.wc_rounded,
                    label: 'Gender',
                    value: (() {
                      final g = student['gender'] as String?;
                      if (g == null || g.isEmpty) return '-';
                      return g[0].toUpperCase() + g.substring(1).toLowerCase();
                    })()),
                const SizedBox(height: 12),
                InfoRow(
                    icon: Icons.cake_rounded,
                    label: 'Date of Birth',
                    value: student['dob'] == null &&
                            student['date_of_birth'] == null
                        ? '-'
                        : formatYmdToDmy(student['dob'] as String? ??
                            student['date_of_birth'] as String?)),
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
                          parent['mobile'] as String? ??
                          '-'),
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
