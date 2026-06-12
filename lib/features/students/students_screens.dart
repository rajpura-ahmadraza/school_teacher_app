import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart' as dio;
import 'package:shimmer/shimmer.dart';
import '../../core/api/api_client.dart';
import '../../core/controllers/auth_controller.dart';
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

  // Fetch ALL classes assigned to the teacher for the dropdown
  Future<void> _loadAllStudentsForClasses() async {
    try {
      final resp = await _api.get('/classes');
      final raw = resp.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(raw['data'] ?? raw['classes'] ?? []);
      }

      final authCtrl = Get.find<AuthController>();
      final teacherIdStr = authCtrl.user.value?['id']?.toString();
      if (teacherIdStr != null) {
        list = list
            .where((c) => c['teacher_id']?.toString() == teacherIdStr)
            .toList();
      }

      final List<Map<String, dynamic>> resolved = [];
      for (final c in list) {
        if (c is Map) {
          resolved.add({
            'id': c['id'],
            'name':
                c['name'] as String? ?? c['class_name'] as String? ?? 'Class',
            'section': c['section'] as String? ?? '',
          });
        }
      }

      // Sort by name then section
      resolved.sort((a, b) {
        final nameCompare =
            (a['name'] as String).compareTo(b['name'] as String);
        if (nameCompare != 0) return nameCompare;
        return (a['section'] as String).compareTo(b['section'] as String);
      });

      classList.value = resolved;
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
      final existingIds = students.map((s) => (s as Map)['id']).toSet();
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
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    return Scaffold(
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
              padding: EdgeInsets.fromLTRB(
                isTablet ? 24.0 : Get.height / 37.8,
                isTablet ? 16.0 : Get.height / 63,
                isTablet ? 24.0 : Get.height / 37.8,
                isTablet ? 20.0 : Get.height / 34.36,
              ),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Get.offNamed(AppRoutes.dashboard),
                  child: Container(
                    width: isTablet ? 40.0 : Get.height / 18.9,
                    height: isTablet ? 40.0 : Get.height / 18.9,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(
                          isTablet ? 12.0 : Get.height / 63),
                    ),
                    child: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: isTablet ? 20.0 : Get.height / 42),
                  ),
                ),
                SizedBox(width: isTablet ? 16.0 : Get.height / 54),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Students',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 26 : 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white)),
                      Text('Manage your class roster',
                          style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 14 : 13,
                              color: Colors.white70)),
                    ],
                  ),
                ),
                Obx(() => Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 16.0 : Get.height / 63,
                          vertical: isTablet ? 8.0 : Get.height / 94.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(
                            isTablet ? 12.0 : Get.height / 63),
                      ),
                      child: Text('${ctrl.total.value}',
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 18 : 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    )),
              ]),
            ),
          ),
        ),
        // ── Search bar + Standard Dropdown (same row) ─────────────
        Padding(
          padding: EdgeInsets.fromLTRB(
            isTablet ? 24.0 : Get.height / 47.25,
            isTablet ? 20.0 : Get.height / 54,
            isTablet ? 24.0 : Get.height / 47.25,
            isTablet ? 12.0 : Get.height / 94.5,
          ),
          child: Row(children: [
            // Search field (expanded)
            Expanded(
              child: SizedBox(
                height: isTablet ? 48.0 : Get.height / 15.75,
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => ctrl.loadStudents(
                      refresh: true, search: v, keepClass: true),
                  style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                      fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Search by name',
                    hintStyle: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: Icon(Icons.search_rounded,
                        color: AppColors.textTertiary,
                        size: isTablet ? 20.0 : Get.height / 37.8),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear_rounded,
                                size: isTablet ? 20.0 : Get.height / 47.25),
                            onPressed: () {
                              _searchCtrl.clear();
                              ctrl.loadStudents(refresh: true, keepClass: true);
                            })
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 16.0 : Get.height / 63,
                        vertical: 0),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                            isTablet ? 12.0 : Get.height / 63),
                        borderSide: BorderSide.none),
                  ),
                ),
              ),
            ),
            SizedBox(width: isTablet ? 16.0 : Get.height / 75.6),
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
                  height: isTablet ? 48.0 : Get.height / 15.75,
                  width: isTablet ? 140.0 : Get.height / 6.8,
                  padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 12.0 : Get.height / 84),
                  decoration: BoxDecoration(
                    color:
                        _dropdownOpen ? const Color(0xFF9333EA) : Colors.white,
                    borderRadius: BorderRadius.circular(
                        isTablet ? 12.0 : Get.height / 63),
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
                  child: Row(children: [
                    Icon(Icons.class_outlined,
                        size: isTablet ? 20.0 : Get.height / 47.25,
                        color: _dropdownOpen
                            ? Colors.white
                            : const Color(0xFF9333EA)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _dropdownOpen
                                ? Colors.white
                                : AppColors.textPrimary),
                      ),
                    ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: _dropdownOpen ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.keyboard_arrow_down_rounded,
                          color: _dropdownOpen
                              ? Colors.white
                              : AppColors.textTertiary,
                          size: isTablet ? 20.0 : Get.height / 42),
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
                padding: EdgeInsets.all(isTablet ? 24.0 : Get.height / 47.25),
                itemCount: 8,
                separatorBuilder: (_, __) =>
                    SizedBox(height: isTablet ? 16.0 : Get.height / 75.6),
                itemBuilder: (_, __) => ShimmerCard(
                    height: isTablet ? 80.0 : Get.height / 9.69, radius: 14),
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
                  refresh: true, search: _searchCtrl.text, keepClass: true),
              child: ListView.separated(
                controller: _scrollCtrl,
                padding: EdgeInsets.fromLTRB(
                  isTablet ? 24.0 : Get.height / 47.25,
                  isTablet ? 12.0 : Get.height / 189,
                  isTablet ? 24.0 : Get.height / 47.25,
                  isTablet ? 24.0 : Get.height / 37.8,
                ),
                itemCount: ctrl.students.length + (ctrl.hasMore.value ? 1 : 0),
                separatorBuilder: (_, __) =>
                    SizedBox(height: isTablet ? 16.0 : Get.height / 75.6),
                itemBuilder: (ctx, i) {
                  if (i == ctrl.students.length) {
                    return Padding(
                      padding: EdgeInsets.only(
                          bottom: isTablet ? 16.0 : Get.height / 75.6),
                      child: ShimmerCard(
                          height: isTablet ? 80.0 : Get.height / 9.69,
                          radius: 14),
                    );
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
}

// ── Standard Dropdown Panel (Overlay) ────────────────────────
class _StandardDropdownPanel extends StatelessWidget {
  final StudentsController ctrl;
  final void Function(Map<String, dynamic>?) onSelect;
  const _StandardDropdownPanel({required this.ctrl, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Obx(() {
      final classes = ctrl.classList;
      final selected = ctrl.selectedClass.value;

      return Container(
        constraints: BoxConstraints(maxHeight: Get.height / 2.90),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(isTablet ? 12.0 : Get.height / 54),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: isTablet ? 16.0 : Get.height / 47.25,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(isTablet ? 12.0 : 14),
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
                vertical: isTablet ? 8.0 : Get.height / 126),
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
                  final fullLabel =
                      section.isNotEmpty ? '$name - $section' : name;
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
      {required this.label, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 16.0 : Get.height / 47.25,
            vertical: isTablet ? 12.0 : Get.height / 58.15),
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
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected
                    ? const Color(0xFF9333EA)
                    : AppColors.textPrimary,
              ),
            ),
          ),
          if (isSelected)
            Icon(Icons.check_rounded,
                color: const Color(0xFF9333EA),
                size: isTablet ? 20.0 : Get.height / 42),
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
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
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
        padding: EdgeInsets.all(isTablet ? 16.0 : Get.height / 54),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.circular(isTablet ? 14.0 : Get.height / 47.25),
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
            radius: isTablet ? 24.0 : Get.height / 29.07,
            fallbackLetter: (student['name'] as String? ?? '?')[0],
          ),
          SizedBox(width: isTablet ? 16.0 : Get.height / 54),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] as String? ?? 'Student',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: isTablet ? 16 : 15,
                      color: AppColors.textPrimary)),
              const SizedBox(height: 4),
              Text('$clsName${section.isNotEmpty ? ' – $section' : ''}',
                  style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 13 : 12,
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
          return const _DetailShimmer();
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
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
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
          expandedHeight: isTablet ? 280 : 240,
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
                      SizedBox(height: isTablet ? 60.0 : Get.height / 18.9),
                      NetAvatar(
                        url: photoUrl,
                        radius: isTablet ? 64.0 : Get.height / 17.18,
                        fallbackLetter: (student['name'] as String? ?? '?')[0],
                      ),
                      SizedBox(height: isTablet ? 12.0 : Get.height / 63),
                      Text(student['name'] as String? ?? 'Student',
                          style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w800,
                              fontSize: isTablet ? 26 : 22)),
                      Text(
                          '${cls['name'] ?? ''} ${cls['section'] != null ? '– ${cls['section']}' : ''}',
                          style: TextStyle(
                              fontWeight: FontWeight.normal,
                              color: Colors.white70,
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 16 : 14)),
                    ]),
              ),
            ]),
          ),
          leading: UnconstrainedBox(
            child: GestureDetector(
              onTap: () => Get.back(),
              child: Container(
                width: isTablet ? 40.0 : Get.height / 18.9,
                height: isTablet ? 40.0 : Get.height / 18.9,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.16),
                  borderRadius:
                      BorderRadius.circular(isTablet ? 12.0 : Get.height / 63),
                ),
                child: Center(
                  child: Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white,
                      size: isTablet ? 20.0 : Get.height / 42),
                ),
              ),
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 32.0 : Get.height / 47.25),
            child: Column(
              children: [
                _InfoSection(
                  title: 'Student Info',
                  rows: [
                    InfoRow(
                      icon: Icons.wc_rounded,
                      label: 'Gender',
                      value: (() {
                        final g = student['gender'] as String?;
                        if (g == null || g.isEmpty) return '-';
                        return g[0].toUpperCase() +
                            g.substring(1).toLowerCase();
                      })(),
                    ),
                    SizedBox(height: isTablet ? 16.0 : Get.height / 63),
                    InfoRow(
                      icon: Icons.cake_rounded,
                      label: 'Date of Birth',
                      value: student['dob'] == null &&
                              student['date_of_birth'] == null
                          ? '-'
                          : formatYmdToDmy(student['dob'] as String? ??
                              student['date_of_birth'] as String?),
                    ),
                    if (address.isNotEmpty) ...[
                      SizedBox(height: isTablet ? 16.0 : Get.height / 63),
                      InfoRow(
                        icon: Icons.home_rounded,
                        label: 'Address',
                        value: address,
                      ),
                    ],
                  ],
                ),
                SizedBox(height: isTablet ? 24.0 : Get.height / 47.25),
                if (parent.isNotEmpty) ...[
                  _InfoSection(
                    title: 'Parent / Guardian',
                    rows: [
                      InfoRow(
                        icon: Icons.person_rounded,
                        label: 'Name',
                        value: parent['name'] as String? ?? '-',
                      ),
                      SizedBox(height: isTablet ? 16.0 : Get.height / 63),
                      InfoRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: parent['phone'] as String? ??
                            parent['mobile'] as String? ??
                            '-',
                      ),
                      if (parent['email'] != null) ...[
                        SizedBox(height: isTablet ? 16.0 : Get.height / 63),
                        InfoRow(
                          icon: Icons.email_rounded,
                          label: 'Email',
                          value: parent['email'] as String,
                        ),
                      ],
                    ],
                  ),
                  SizedBox(height: isTablet ? 24.0 : 23.62),
                ],
              ],
            ),
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
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24.0 : Get.height / 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(isTablet ? 14.0 : Get.height / 47.25),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title,
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700,
                fontSize: isTablet ? 18 : 16,
                color: AppColors.textPrimary)),
        SizedBox(height: isTablet ? 20.0 : Get.height / 47.25),
        ...rows,
      ]),
    );
  }
}

// ── Shimmer Detail Loading Screen ──────────────────────────────
class _DetailShimmer extends StatelessWidget {
  const _DetailShimmer();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      body: CustomScrollView(
        physics: const NeverScrollableScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: isTablet ? 280 : 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
                      ),
                    ),
                  ),
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(height: isTablet ? 60.0 : Get.height / 18.9),
                        Shimmer.fromColors(
                          baseColor: Colors.white.withOpacity(0.25),
                          highlightColor: Colors.white.withOpacity(0.15),
                          child: Container(
                            width: isTablet ? 128.0 : (Get.height / 17.18) * 2,
                            height: isTablet ? 128.0 : (Get.height / 17.18) * 2,
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                        SizedBox(height: isTablet ? 12.0 : Get.height / 63),
                        Shimmer.fromColors(
                          baseColor: Colors.white.withOpacity(0.25),
                          highlightColor: Colors.white.withOpacity(0.15),
                          child: Container(
                            width: 140,
                            height: 20,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Shimmer.fromColors(
                          baseColor: Colors.white.withOpacity(0.2),
                          highlightColor: Colors.white.withOpacity(0.1),
                          child: Container(
                            width: 80,
                            height: 14,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            leading: UnconstrainedBox(
              child: GestureDetector(
                onTap: () => Get.back(),
                child: Container(
                  width: isTablet ? 40.0 : Get.height / 18.9,
                  height: isTablet ? 40.0 : Get.height / 18.9,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(
                        isTablet ? 12.0 : Get.height / 63),
                  ),
                  child: Center(
                    child: Icon(Icons.arrow_back_ios_rounded,
                        color: Colors.white,
                        size: isTablet ? 20.0 : Get.height / 42),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(isTablet ? 32.0 : Get.height / 47.25),
              child: Column(
                children: [
                  const _ShimmerSection(
                    title: 'Student Info',
                    itemCount: 3,
                  ),
                  SizedBox(height: isTablet ? 24.0 : Get.height / 47.25),
                  const _ShimmerSection(
                    title: 'Parent / Guardian',
                    itemCount: 3,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerSection extends StatelessWidget {
  final String title;
  final int itemCount;
  const _ShimmerSection({required this.title, required this.itemCount});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 24.0 : Get.height / 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(isTablet ? 14.0 : Get.height / 47.25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: isTablet ? 18 : 16,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: isTablet ? 20.0 : Get.height / 47.25),
          ...List.generate(itemCount, (index) {
            return Column(
              children: [
                Row(
                  children: [
                    const ShimmerCard(
                      width: 32,
                      height: 32,
                      radius: 8,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ShimmerCard(
                            width: 60,
                            height: 10,
                            radius: 4,
                          ),
                          const SizedBox(height: 6),
                          ShimmerCard(
                            width: index == 2 ? 180.0 : 120.0,
                            height: 14,
                            radius: 4,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (index < itemCount - 1)
                  SizedBox(height: isTablet ? 16.0 : Get.height / 63),
              ],
            );
          }),
        ],
      ),
    );
  }
}
