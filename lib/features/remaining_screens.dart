import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../core/api/api_client.dart';
import '../core/controllers/auth_controller.dart';
import '../core/routes/app_routes.dart';
import '../core/theme/app_theme.dart';
import '../core/widgets/common_widgets.dart';

// ═══════════════════════════════════════════════════════════════
// TIMETABLE
// ═══════════════════════════════════════════════════════════════

class TimetableController extends GetxController {
  final _api = ApiClient.instance;
  final RxList<dynamic> classes = <dynamic>[].obs;
  final Rx<Map<String, dynamic>?> selectedClass = Rx(null);
  final RxList<dynamic> timetable = <dynamic>[].obs;
  final RxBool classesLoading = true.obs;
  final RxBool ttLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    classesLoading.value = true;
    try {
      final r = await _api.get('/classes');
      final raw = r.data;
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
      classes.value = list;
      if (list.isNotEmpty && selectedClass.value == null) {
        loadTimetable(Map<String, dynamic>.from(list.first as Map));
      }
    } catch (_) {
      classes.value = [];
    }
    classesLoading.value = false;
  }

  Future<void> loadTimetable(Map<String, dynamic> cls) async {
    selectedClass.value = cls;
    ttLoading.value = true;
    try {
      final id = cls['id'];
      final r =
          await _api.get('/timetable', params: {'class_id': id.toString()});
      final raw = r.data;
      if (raw is List) {
        timetable.value = raw;
      } else if (raw is Map) {
        final ttData = raw['data'] ?? raw['timetable'] ?? raw['timetables'];
        if (ttData is Map) {
          final List<dynamic> flatList = [];
          ttData.forEach((key, val) {
            if (val is List) {
              flatList.addAll(val);
            }
          });
          timetable.value = flatList;
        } else if (ttData is List) {
          timetable.value = ttData;
        } else {
          timetable.value = [];
        }
      } else {
        timetable.value = [];
      }
    } catch (_) {
      timetable.value = [];
    }
    ttLoading.value = false;
  }
}

class TimetableScreen extends StatelessWidget {
  const TimetableScreen({super.key});

  static const _days = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday'
  ];

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(TimetableController());
    return DefaultTabController(
      length: _days.length,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F8FC),
        appBar: AppBar(
          flexibleSpace: Container(
              decoration:
                  const BoxDecoration(gradient: AppColors.gradientPrimary)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
            onPressed: () => Get.offNamed(AppRoutes.dashboard),
          ),
          title: const Text('Timetable',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700)),
          bottom: TabBar(
            isScrollable: false,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            indicatorColor: Colors.white,
            labelStyle: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w600),
            tabs: _days.map((d) => Tab(text: d.substring(0, 3))).toList(),
          ),
        ),
        body: Obx(() {
          if (ctrl.classesLoading.value) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          return Column(children: [
            // Class picker
            if (ctrl.classes.isNotEmpty)
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(
                    horizontal: Get.height / 47.25,
                    vertical: Get.height / 75.6),
                width: double.infinity,
                child: DropdownMenu<dynamic>(
                  expandedInsets: EdgeInsets.zero,
                  initialSelection: ctrl.selectedClass.value?['id'],
                  hintText: 'Select Class',
                  textStyle: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: Get.height / 54,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  inputDecorationTheme: InputDecorationTheme(
                    filled: true,
                    fillColor: const Color(0xFFFAFAFA),
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: Get.height / 47.25,
                        vertical: Get.height / 75.6),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Get.height / 63),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Get.height / 63),
                      borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(Get.height / 63),
                      borderSide: const BorderSide(
                          color: AppColors.primary, width: 1.5),
                    ),
                  ),
                  menuStyle: const MenuStyle(
                    backgroundColor:
                        WidgetStatePropertyAll<Color>(Colors.white),
                  ),
                  onSelected: (dynamic newValue) {
                    if (newValue != null) {
                      final cls = ctrl.classes.firstWhere(
                        (c) => (c as Map)['id'] == newValue,
                        orElse: () => null,
                      );
                      if (cls != null) {
                        ctrl.loadTimetable(
                            Map<String, dynamic>.from(cls as Map));
                      }
                    }
                  },
                  dropdownMenuEntries:
                      ctrl.classes.map<DropdownMenuEntry<dynamic>>((cls) {
                    final c = Map<String, dynamic>.from(cls as Map);
                    final name = c['name'] ?? c['class_name'] ?? 'Class';
                    final section = c['section'] != null &&
                            c['section'].toString().trim().isNotEmpty
                        ? ' - ${c['section']}'
                        : '';
                    return DropdownMenuEntry<dynamic>(
                      value: c['id'],
                      label: '$name$section',
                      style: ButtonStyle(
                        textStyle: WidgetStateProperty.all(
                          TextStyle(
                            fontFamily: 'Inter',
                            fontSize: Get.height / 54,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            Expanded(
              child: ctrl.selectedClass.value == null
                  ? const EmptyState(
                      icon: Icons.calendar_view_week_rounded,
                      title: 'Select a Class',
                      subtitle: 'Choose a class to view the timetable')
                  : ctrl.ttLoading.value
                      ? const Center(
                          child: CircularProgressIndicator(
                              color: AppColors.primary))
                      : TabBarView(
                          children: _days.map((day) {
                            final targetDay = day.toLowerCase();
                            final selectedId =
                                ctrl.selectedClass.value?['id']?.toString();
                            final periods = ctrl.timetable.where((t) {
                              if (t is! Map) return false;

                              // Filter by selected class ID
                              final cId = t['class_id']?.toString();
                              if (selectedId != null &&
                                  cId != null &&
                                  cId != selectedId) {
                                return false;
                              }

                              final d = t['day']?.toString().toLowerCase();
                              final dn =
                                  t['day_name']?.toString().toLowerCase();

                              final isNumeric = int.tryParse(d ?? '') != null;
                              if (isNumeric) {
                                final dayIndex = _days.indexOf(day) + 1;
                                return int.parse(d!) == dayIndex;
                              }

                              return d == targetDay || dn == targetDay;
                            }).toList();
                            if (periods.isEmpty) {
                              return const EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  title: 'No Classes',
                                  subtitle:
                                      'No periods scheduled for this day');
                            }
                            return ListView.separated(
                              padding: EdgeInsets.all(Get.height / 47.25),
                              itemCount: periods.length,
                              separatorBuilder: (_, __) =>
                                  SizedBox(height: Get.height / 75.6),
                              itemBuilder: (ctx, i) {
                                final p = periods[i] as Map<String, dynamic>;
                                final subj = p['subject'] as Map? ?? {};
                                return Container(
                                  padding: EdgeInsets.all(Get.height / 47.25),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius:
                                        BorderRadius.circular(Get.height / 54),
                                    border: Border.all(
                                        color:
                                            AppColors.primary.withOpacity(0.1)),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withOpacity(0.03),
                                          blurRadius: 6)
                                    ],
                                  ),
                                  child: Row(children: [
                                    Container(
                                      width: Get.height / 15.75,
                                      height: Get.height / 15.75,
                                      decoration: BoxDecoration(
                                          gradient: AppColors.gradientPrimary,
                                          borderRadius: BorderRadius.circular(
                                              Get.height / 63)),
                                      child: Center(
                                        child: Text('${i + 1}',
                                            style: TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w800,
                                                fontSize: Get.height / 42)),
                                      ),
                                    ),
                                    SizedBox(width: Get.height / 54),
                                    Expanded(
                                      child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                                subj['name'] as String? ??
                                                    p['subject_name']
                                                        as String? ??
                                                    'Period',
                                                style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize:
                                                        Get.height / 50.4)),
                                            Text(
                                                '${formatTimeToAmPm(p['start_time'] as String?)} – ${formatTimeToAmPm(p['end_time'] as String?)}',
                                                style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize:
                                                        Get.height / 58.15,
                                                    color: AppColors
                                                        .textSecondary)),
                                          ]),
                                    ),
                                  ]),
                                );
                              },
                            );
                          }).toList(),
                        ),
            ),
          ]);
        }),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// LEAVES
// ═══════════════════════════════════════════════════════════════

class LeavesController extends GetxController {
  final _api = ApiClient.instance;
  final RxList<dynamic> leaves = <dynamic>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  final RxString filterStatus = 'pending'.obs;
  int _page = 1;

  @override
  void onInit() {
    super.onInit();
    loadLeaves(refresh: true);
  }

  Future<void> loadLeaves({bool refresh = false}) async {
    if (refresh) {
      _page = 1;
      hasMore.value = true;
      leaves.clear();
      isLoading.value = true;
    } else {
      if (isLoading.value || isLoadingMore.value || !hasMore.value) return;
      isLoadingMore.value = true;
    }

    try {
      final r = await _api.get('/leaves', params: {
        'status': filterStatus.value,
        'per_page': '15',
        'page': _page.toString(),
      });
      final raw = r.data;
      List<dynamic> list = [];
      int lastPage = 1;
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(raw['data'] ?? raw['leaves'] ?? []);
        lastPage = raw['last_page'] ?? 1;
      }

      leaves.addAll(list);
      hasMore.value = _page < lastPage && list.length == 15;
      _page++;
    } catch (_) {
      if (refresh) leaves.value = [];
    } finally {
      isLoading.value = false;
      isLoadingMore.value = false;
    }
  }

  Future<void> reviewLeave(int id, String status) async {
    try {
      await _api.put('/leaves/$id/review', {'status': status});
      final idx = leaves.indexWhere((l) => (l as Map)['id'] == id);
      if (idx != -1) leaves.removeAt(idx);
      Get.snackbar('Done', 'Leave $status',
          backgroundColor: AppColors.secondary, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger, colorText: Colors.white);
    }
  }
}

class LeavesScreen extends StatefulWidget {
  const LeavesScreen({super.key});

  @override
  State<LeavesScreen> createState() => _LeavesScreenState();
}

class _LeavesScreenState extends State<LeavesScreen> {
  late final LeavesController ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(LeavesController());
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
        ctrl.loadLeaves();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final statuses = ['pending', 'approved', 'rejected'];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.offNamed(AppRoutes.dashboard),
        ),
        title: const Text('Leave Requests',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
      ),
      body: Column(children: [
        // Status filter dropdown
        Container(
          color: Colors.white,
          padding:
              EdgeInsets.symmetric(horizontal: 16, vertical: Get.height / 75.6),
          width: double.infinity,
          child: Obx(() => DropdownMenu<String>(
                expandedInsets: EdgeInsets.zero,
                initialSelection: ctrl.filterStatus.value,
                requestFocusOnTap: false,
                enableSearch: false,
                textStyle: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 54,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                inputDecorationTheme: InputDecorationTheme(
                  filled: true,
                  fillColor: const Color(0xFFFAFAFA),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: Get.height / 47.25,
                      vertical: Get.height / 75.6),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Get.height / 63),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Get.height / 63),
                    borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Get.height / 63),
                    borderSide:
                        const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                menuStyle: const MenuStyle(
                  backgroundColor: WidgetStatePropertyAll<Color>(Colors.white),
                ),
                onSelected: (String? newValue) {
                  if (newValue != null && ctrl.filterStatus.value != newValue) {
                    ctrl.filterStatus.value = newValue;
                    ctrl.loadLeaves(refresh: true);
                  }
                },
                dropdownMenuEntries:
                    statuses.map<DropdownMenuEntry<String>>((s) {
                  return DropdownMenuEntry<String>(
                    value: s,
                    label: s[0].toUpperCase() + s.substring(1),
                    style: ButtonStyle(
                      textStyle: WidgetStateProperty.all(
                        TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 54,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              )),
        ),
        // List
        Expanded(
          child: Obx(() {
            if (ctrl.isLoading.value) {
              return const Center(
                  child: CircularProgressIndicator(color: AppColors.primary));
            }
            if (ctrl.leaves.isEmpty) {
              return EmptyState(
                icon: Icons.event_available_rounded,
                title: 'No ${ctrl.filterStatus.value} leaves',
                subtitle: 'All caught up!',
              );
            }
            return RefreshIndicator(
              onRefresh: () => ctrl.loadLeaves(refresh: true),
              child: ListView.separated(
                controller: _scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(Get.height / 47.25),
                itemCount: ctrl.leaves.length + (ctrl.hasMore.value ? 1 : 0),
                separatorBuilder: (_, __) =>
                    SizedBox(height: Get.height / 75.6),
                itemBuilder: (ctx, i) {
                  if (i == ctrl.leaves.length) {
                    return Center(
                      child: Padding(
                        padding:
                            EdgeInsets.symmetric(vertical: Get.height / 63),
                        child:
                            CircularProgressIndicator(color: AppColors.primary),
                      ),
                    );
                  }
                  final leave =
                      Map<String, dynamic>.from(ctrl.leaves[i] as Map);
                  return _LeaveCard(
                      leave: leave,
                      status: ctrl.filterStatus.value,
                      onReview: (newStatus) =>
                          ctrl.reviewLeave(leave['id'] as int, newStatus));
                },
              ),
            );
          }),
        ),
      ]),
    );
  }
}

class _LeaveCard extends StatelessWidget {
  final Map<String, dynamic> leave;
  final String status;
  final void Function(String) onReview;
  const _LeaveCard(
      {required this.leave, required this.status, required this.onReview});

  @override
  Widget build(BuildContext context) {
    final student = leave['student'] as Map? ?? {};
    final from = leave['from_date'] as String? ?? '';
    final to = leave['to_date'] as String? ?? '';
    final reason = leave['reason'] as String? ?? '';
    final statusColor = status == 'pending'
        ? AppColors.warning
        : status == 'approved'
            ? AppColors.success
            : AppColors.danger;
    final studentPhotoUrl = student['profile_photo'] as String? ??
        student['image'] as String? ??
        student['photo'] as String? ??
        student['avatar'] as String? ??
        student['admission_image'] as String? ??
        leave['profile_photo'] as String? ??
        leave['student_image'] as String? ??
        leave['image'] as String?;

    return Container(
      padding: EdgeInsets.all(Get.height / 47.25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(Get.height / 63),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: Get.height / 94.5,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NetAvatar(
            url: studentPhotoUrl,
            radius: Get.height / 34.36,
            fallbackLetter: (student['name'] as String? ?? '?')[0],
          ),
          SizedBox(width: Get.height / 63),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] as String? ?? 'Student',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: Get.height / 50.4)),
              Text('${formatYmdToDmy(from)} → ${formatYmdToDmy(to)}',
                  style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: Get.height / 63,
                      color: AppColors.textSecondary)),
            ]),
          ),
          StatusBadge(label: status, color: statusColor),
        ]),
        if (reason.isNotEmpty) ...[
          SizedBox(height: Get.height / 75.6),
          Text(reason,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: Get.height / 63,
                  color: AppColors.textSecondary)),
        ],
        if (status == 'pending') ...[
          SizedBox(height: Get.height / 63),
          Row(children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onReview('rejected'),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    vertical: Get.height / 75.6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(Get.height / 75.6),
                    border:
                        Border.all(color: AppColors.danger.withOpacity(0.25)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.close_rounded,
                            color: AppColors.danger, size: 16),
                        SizedBox(width: Get.height / 126),
                        Text('Reject',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: Get.height / 58.15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger)),
                      ]),
                ),
              ),
            ),
            SizedBox(width: Get.height / 75.6),
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onReview('approved'),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: Get.height / 75.6),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(Get.height / 75.6),
                    border:
                        Border.all(color: AppColors.success.withOpacity(0.25)),
                  ),
                  child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_rounded,
                            color: AppColors.success, size: 16),
                        SizedBox(width: Get.height / 126),
                        Text('Approve',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: Get.height / 58.15,
                                fontWeight: FontWeight.w600,
                                color: AppColors.success)),
                      ]),
                ),
              ),
            ),
          ]),
        ],
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// GALLERY
// ═══════════════════════════════════════════════════════════════

class GalleryController extends GetxController {
  final _api = ApiClient.instance;
  final RxList<dynamic> albums = <dynamic>[].obs;
  final RxBool isLoading = true.obs;
  final RxString selectedAlbum = 'all'.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final r = await _api.get('/gallery');
      final raw = r.data;
      if (raw is List) {
        final List<Map<String, dynamic>> grouped = [];
        for (var item in raw) {
          if (item is Map) {
            final title = item['title']?.toString() ??
                item['name']?.toString() ??
                'Album';
            final rawPhotos =
                List<dynamic>.from(item['photos'] ?? item['images'] ?? []);
            final photos = rawPhotos.map((p) {
              final pMap =
                  p is Map ? Map<String, dynamic>.from(p) : <String, dynamic>{};
              pMap['url'] = pMap['url'] ??
                  pMap['image_url'] ??
                  pMap['thumbnail_url'] ??
                  pMap['image_path'] ??
                  '';
              return pMap;
            }).toList();
            grouped.add({
              'title': title,
              'photos': photos,
            });
          }
        }
        albums.value = grouped;
      } else if (raw is Map) {
        // Extract photos
        List<dynamic> allPhotos = [];
        final photosNode = raw['photos'];
        if (photosNode is Map) {
          allPhotos = List<dynamic>.from(photosNode['data'] ?? []);
        } else if (photosNode is List) {
          allPhotos = photosNode;
        } else if (raw['data'] is List) {
          allPhotos = raw['data'];
        }

        // Extract album names
        List<String> albumNames = [];
        final albumsNode = raw['albums'];
        if (albumsNode is List) {
          albumNames = albumsNode.map((e) => e.toString()).toList();
        } else {
          albumNames = allPhotos
              .map((p) => (p is Map) ? p['album']?.toString() : null)
              .whereType<String>()
              .toSet()
              .toList();
        }

        // Group photos by album name
        final List<Map<String, dynamic>> grouped = [];
        for (final name in albumNames) {
          final photosInAlbum = allPhotos.where((p) {
            if (p is! Map) return false;
            final albumVal = p['album'];
            return albumVal?.toString().trim().toLowerCase() ==
                name.trim().toLowerCase();
          }).map((p) {
            final pMap = Map<String, dynamic>.from(p as Map);
            pMap['url'] = pMap['image_url'] ??
                pMap['thumbnail_url'] ??
                pMap['image_path'] ??
                '';
            return pMap;
          }).toList();

          grouped.add({
            'title': name,
            'photos': photosInAlbum,
          });
        }
        albums.value = grouped;
      } else {
        albums.value = [];
      }
    } catch (_) {
      albums.value = [];
    }

    // Validate if the currently selected album is still valid. If not, reset to 'all'
    if (selectedAlbum.value != 'all' &&
        !albumTitles.contains(selectedAlbum.value)) {
      selectedAlbum.value = 'all';
    }

    isLoading.value = false;
  }

  List<String> get albumTitles {
    final titles = <String>['all'];
    for (var a in albums) {
      if (a is Map) {
        final title = a['title']?.toString();
        if (title != null && title.isNotEmpty) {
          titles.add(title);
        }
      }
    }
    return titles.toSet().toList();
  }

  List<dynamic> get currentPhotos {
    if (selectedAlbum.value == 'all') {
      final allPhotos = <dynamic>[];
      for (var a in albums) {
        if (a is Map) {
          final photos = a['photos'] ?? a['images'];
          if (photos is List) {
            allPhotos.addAll(photos);
          }
        }
      }
      return allPhotos;
    } else {
      for (var a in albums) {
        if (a is Map &&
            a['title']?.toString().toLowerCase() ==
                selectedAlbum.value.toLowerCase()) {
          final photos = a['photos'] ?? a['images'];
          if (photos is List) {
            return photos;
          }
        }
      }
      return [];
    }
  }
}

class FullScreenImageViewer extends StatefulWidget {
  final List<dynamic> photos;
  final int initialIndex;

  const FullScreenImageViewer({
    super.key,
    required this.photos,
    required this.initialIndex,
  });

  @override
  State<FullScreenImageViewer> createState() => _FullScreenImageViewerState();
}

class _FullScreenImageViewerState extends State<FullScreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Swipeable/Zoomable view
          GestureDetector(
            onVerticalDragEnd: (details) {
              if (details.primaryVelocity != null &&
                  details.primaryVelocity! > 300) {
                Navigator.of(context).pop();
              }
            },
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              itemBuilder: (context, index) {
                final photo = widget.photos[index];
                final url =
                    (photo is Map ? photo['url'] : photo.toString()) ?? '';
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 3.0,
                  child: Center(
                    child: url.isEmpty
                        ? const Center(
                            child: Icon(Icons.broken_image_rounded,
                                color: Colors.grey, size: 64),
                          )
                        : CachedNetworkImage(
                            imageUrl: url,
                            fit: BoxFit.contain,
                            placeholder: (context, url) => const Center(
                              child: CircularProgressIndicator(
                                  color: Colors.white),
                            ),
                            errorWidget: (context, url, error) => Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image_rounded,
                                    color: Colors.grey, size: 64),
                                SizedBox(height: Get.height / 63),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: Get.height / 54),
                                ),
                              ],
                            ),
                          ),
                  ),
                );
              },
            ),
          ),

          // Navigation chevrons (if multiple photos)
          if (widget.photos.length > 1) ...[
            if (_currentIndex > 0)
              Positioned(
                left: Get.height / 47.25,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(Get.height / 94.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: const Icon(Icons.chevron_left_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
            if (_currentIndex < widget.photos.length - 1)
              Positioned(
                right: Get.height / 47.25,
                top: 0,
                bottom: 0,
                child: Center(
                  child: GestureDetector(
                    onTap: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    },
                    child: Container(
                      padding: EdgeInsets.all(Get.height / 94.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withOpacity(0.3),
                      ),
                      child: const Icon(Icons.chevron_right_rounded,
                          color: Colors.white, size: 36),
                    ),
                  ),
                ),
              ),
          ],

          // Top bar overlay with Close and Download buttons
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: Get.height / 47.25,
            right: Get.height / 47.25,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Close button
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Container(
                    padding: EdgeInsets.all(Get.height / 94.5),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.4),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: Get.height / 31.5,
                    ),
                  ),
                ),

                // Page Indicator
                if (widget.photos.length > 1)
                  Container(
                    padding: EdgeInsets.symmetric(
                        horizontal: Get.height / 63,
                        vertical: Get.height / 126),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.4),
                      borderRadius: BorderRadius.circular(Get.height / 47.25),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.photos.length}',
                      style: TextStyle(
                        color: Colors.white,
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: Get.height / 54,
                      ),
                    ),
                  )
                else
                  const SizedBox(),

                // Empty space to balance the Close button and keep Page Indicator centered
                SizedBox(width: Get.height / 18.9),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class GalleryScreen extends StatelessWidget {
  const GalleryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(GalleryController());
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        toolbarHeight: 90, // Height vadharo (80, 90, 100 je joiye te)
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leadingWidth: 60,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF9333EA),
                Color(0xFFDB2777),
              ],
            ),
          ),
        ),
        leading: Padding(
          padding: EdgeInsets.only(
            left: Get.height / 47.25,
            top: Get.height / 30.24,
            bottom: Get.height / 30.24,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: const Color.fromARGB(33, 255, 255, 255),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color.fromARGB(255, 255, 255, 255)
                      .withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Color.fromARGB(255, 255, 255, 255),
                size: 28,
              ),
              onPressed: () => Get.offNamed(AppRoutes.dashboard),
            ),
          ),
        ),
        title: Text(
          'Gallery',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: Get.height / 37.8,
          ),
        ),
      ),
      body: Stack(
        children: [
          Obx(() {
            if (ctrl.isLoading.value) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (ctrl.albums.isEmpty) {
              return const EmptyState(
                icon: Icons.photo_library_outlined,
                title: 'No Albums',
                subtitle: 'No gallery content available yet',
              );
            }
            final photos = ctrl.currentPhotos;
            return RefreshIndicator(
              onRefresh: ctrl.load,
              color: AppColors.primary,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Albums Section Row
                    Padding(
                      padding: EdgeInsets.symmetric(
                          horizontal: Get.height / 47.25,
                          vertical: Get.height / 63),
                      child: Row(
                        children: [
                          Container(
                            width: Get.height / 189,
                            height: Get.height / 94.5,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          SizedBox(width: Get.height / 94.5),
                          Text(
                            'Albums',
                            style: TextStyle(
                              fontSize: Get.height / 47.25,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Horizontal categories
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding:
                          EdgeInsets.symmetric(horizontal: Get.height / 47.25),
                      child: Row(
                        children: ctrl.albumTitles.map((title) {
                          final isSelected = ctrl.selectedAlbum.value == title;
                          return Padding(
                            padding: EdgeInsets.only(right: Get.height / 94.5),
                            child: GestureDetector(
                              onTap: () => ctrl.selectedAlbum.value = title,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: EdgeInsets.symmetric(
                                    horizontal: Get.height / 37.8,
                                    vertical: Get.height / 75.6),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.08),
                                  borderRadius:
                                      BorderRadius.circular(Get.height / 31.5),
                                ),
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: Get.height / 54,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.w500,
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                    SizedBox(height: Get.height / 47.25),

                    // Grid of image cards
                    photos.isEmpty
                        ? Container(
                            height: Get.height / 3.78,
                            alignment: Alignment.center,
                            child: Text(
                              'No photos in this album',
                              style: TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: Get.height / 54),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: EdgeInsets.symmetric(
                                horizontal: Get.height / 47.25,
                                vertical: Get.height / 94.5),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.0,
                            ),
                            itemCount: photos.length,
                            itemBuilder: (ctx, i) {
                              final photo = photos[i];
                              final url = (photo is Map
                                      ? photo['url']
                                      : photo.toString()) ??
                                  '';
                              return GestureDetector(
                                onTap: () => _openImage(context, photos, i),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(
                                        Get.height / 37.8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(
                                        Get.height / 37.8),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        url.isEmpty
                                            ? Container(
                                                color: AppColors.primaryLight,
                                                child: Icon(
                                                  Icons.broken_image_rounded,
                                                  color: AppColors.primary,
                                                  size: Get.height / 23.62,
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: url,
                                                fit: BoxFit.cover,
                                                placeholder: (context, url) =>
                                                    Container(
                                                  color: Colors.grey.shade100,
                                                  child: const Center(
                                                    child:
                                                        CircularProgressIndicator(
                                                            color: AppColors
                                                                .primary),
                                                  ),
                                                ),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        Container(
                                                  color: AppColors.primaryLight,
                                                  child: Icon(
                                                    Icons.broken_image_rounded,
                                                    color: AppColors.primary,
                                                    size: Get.height / 23.62,
                                                  ),
                                                ),
                                              ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                    SizedBox(height: Get.height / 23.62),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  void _openImage(
      BuildContext context, List<dynamic> photos, int initialIndex) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FullScreenImageViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
        fullscreenDialog: true,
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// CALENDAR
// ═══════════════════════════════════════════════════════════════

class CalendarController extends GetxController {
  final _api = ApiClient.instance;
  final RxList<dynamic> events = <dynamic>[].obs;
  final RxBool isLoading = true.obs;
  final Rx<DateTime> focusedMonth = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    loadEvents();
  }

  Future<void> loadEvents() async {
    isLoading.value = true;
    try {
      final m = focusedMonth.value;
      final r = await _api.get('/events', params: {
        'month': '${m.year}-${m.month.toString().padLeft(2, '0')}',
      });
      final raw = r.data;
      if (raw is List) {
        events.value = raw;
      } else if (raw is Map) {
        events.value = List<dynamic>.from(raw['data'] ?? raw['events'] ?? []);
      } else {
        events.value = [];
      }
    } catch (_) {
      events.value = [];
    }
    isLoading.value = false;
  }

  void prevMonth() {
    final m = focusedMonth.value;
    focusedMonth.value = DateTime(m.year, m.month - 1);
    loadEvents();
  }

  void nextMonth() {
    final m = focusedMonth.value;
    focusedMonth.value = DateTime(m.year, m.month + 1);
    loadEvents();
  }
}

class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(CalendarController());
    final monthNames = [
      '',
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.offNamed(AppRoutes.dashboard),
        ),
        title: const Text('School Calendar',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
      ),
      body: Obx(() => Column(children: [
            // Month navigator
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                  horizontal: Get.height / 47.25, vertical: Get.height / 63),
              child: Row(children: [
                IconButton(
                  onPressed: ctrl.prevMonth,
                  icon: const Icon(Icons.chevron_left_rounded,
                      color: AppColors.primary),
                ),
                Expanded(
                  child: Text(
                    '${monthNames[ctrl.focusedMonth.value.month]} ${ctrl.focusedMonth.value.year}',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: Get.height / 47.25,
                        color: AppColors.textPrimary),
                  ),
                ),
                IconButton(
                  onPressed: ctrl.nextMonth,
                  icon: const Icon(Icons.chevron_right_rounded,
                      color: AppColors.primary),
                ),
              ]),
            ),
            // Events list
            Expanded(
              child: ctrl.isLoading.value
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : ctrl.events.isEmpty
                      ? const EmptyState(
                          icon: Icons.event_outlined,
                          title: 'No Events',
                          subtitle: 'No events this month')
                      : RefreshIndicator(
                          onRefresh: ctrl.loadEvents,
                          child: ListView.separated(
                            padding: EdgeInsets.all(Get.height / 47.25),
                            itemCount: ctrl.events.length,
                            separatorBuilder: (_, __) =>
                                SizedBox(height: Get.height / 75.6),
                            itemBuilder: (ctx, i) {
                              final ev = ctrl.events[i] as Map<String, dynamic>;
                              final date = ev['date'] as String? ?? '';
                              final type = ev['type'] as String? ?? 'event';
                              final color = type == 'holiday'
                                  ? AppColors.danger
                                  : type == 'exam'
                                      ? AppColors.warning
                                      : AppColors.primary;
                              return Container(
                                padding: EdgeInsets.all(Get.height / 63),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius:
                                      BorderRadius.circular(Get.height / 54),
                                  border:
                                      Border.all(color: color.withOpacity(0.2)),
                                  boxShadow: [
                                    BoxShadow(
                                        color: Colors.black.withOpacity(0.03),
                                        blurRadius: 6)
                                  ],
                                ),
                                child: Row(children: [
                                  Container(
                                    width: 15.75,
                                    padding: EdgeInsets.all(Get.height / 94.5),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(
                                          Get.height / 63),
                                    ),
                                    child: Column(children: [
                                      Text(
                                          date.length >= 10
                                              ? date.substring(8, 10)
                                              : '--',
                                          style: TextStyle(
                                              color: color,
                                              fontFamily: 'Inter',
                                              fontWeight: FontWeight.w800,
                                              fontSize: Get.height / 54)),
                                      Text(
                                          date.length >= 7
                                              ? monthNames[int.tryParse(date
                                                          .substring(5, 7)) ??
                                                      1]
                                                  .substring(0, 3)
                                              : '--',
                                          style: TextStyle(
                                              color: color,
                                              fontFamily: 'Inter',
                                              fontSize: Get.height / 75.6)),
                                    ]),
                                  ),
                                  SizedBox(width: Get.height / 54),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              ev['title'] as String? ?? 'Event',
                                              style: TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w700,
                                                  fontSize:
                                                      Get.height / 58.15)),
                                          if (ev['description'] != null)
                                            Text(ev['description'] as String,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: Get.height / 63,
                                                    color: AppColors
                                                        .textSecondary)),
                                        ]),
                                  ),
                                  StatusBadge(label: type, color: color),
                                ]),
                              );
                            },
                          ),
                        ),
            ),
          ])),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// BUS TRACKING
// ═══════════════════════════════════════════════════════════════

class BusController extends GetxController {
  final _api = ApiClient.instance;
  final RxList<dynamic> buses = <dynamic>[].obs;
  final RxBool isLoading = true.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  Future<void> load() async {
    isLoading.value = true;
    try {
      final r = await _api.get('/bus-tracking');
      buses.value = List<dynamic>.from(r.data['data'] ?? r.data ?? []);
    } catch (_) {}
    isLoading.value = false;
  }
}

class BusTrackingScreen extends StatelessWidget {
  const BusTrackingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(BusController());
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.offNamed(AppRoutes.dashboard),
        ),
        title: const Text('Bus Tracking',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: ctrl.load,
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.isLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        if (ctrl.buses.isEmpty) {
          return const EmptyState(
              icon: Icons.directions_bus_rounded,
              title: 'No Buses',
              subtitle: 'No bus routes assigned');
        }
        return RefreshIndicator(
          onRefresh: ctrl.load,
          child: ListView.separated(
            padding: EdgeInsets.all(Get.height / 47.25),
            itemCount: ctrl.buses.length,
            separatorBuilder: (_, __) => SizedBox(height: Get.height / 75.6),
            itemBuilder: (ctx, i) {
              final bus = ctrl.buses[i] as Map<String, dynamic>;
              final driver = bus['driver'] as Map? ?? {};
              final status = bus['status'] as String? ?? 'idle';
              final statusColor = status == 'running'
                  ? AppColors.secondary
                  : status == 'stopped'
                      ? AppColors.danger
                      : AppColors.textSecondary;
              return Container(
                padding: EdgeInsets.all(Get.height / 47.25),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(Get.height / 47.25),
                  border: Border.all(color: statusColor.withOpacity(0.2)),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03), blurRadius: 8)
                  ],
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                          width: Get.height / 15.75,
                          height: Get.height / 15.75,
                          decoration: BoxDecoration(
                              gradient: AppColors.gradientPrimary,
                              borderRadius:
                                  BorderRadius.circular(Get.height / 63)),
                          child: Icon(Icons.directions_bus_rounded,
                              color: Colors.white, size: Get.height / 31.5),
                        ),
                        SizedBox(width: Get.height / 54),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    bus['bus_number'] as String? ??
                                        'Bus ${i + 1}',
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: Get.height / 47.25)),
                                Text(
                                    bus['route'] as String? ??
                                        'Route not assigned',
                                    style: TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: Get.height / 63,
                                        color: AppColors.textSecondary)),
                              ]),
                        ),
                        StatusBadge(label: status, color: statusColor),
                      ]),
                      Divider(height: Get.height / 37.8),
                      Row(children: [
                        Icon(Icons.person_rounded,
                            size: Get.height / 47.25,
                            color: AppColors.textSecondary),
                        SizedBox(width: Get.height / 126),
                        Text('Driver: ${driver['name'] as String? ?? 'N/A'}',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: Get.height / 58.15,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        if (driver['phone'] != null)
                          Row(children: [
                            Icon(Icons.phone_rounded,
                                size: Get.height / 47.25,
                                color: AppColors.primary),
                            SizedBox(width: Get.height / 189),
                            Text(driver['phone'] as String,
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: Get.height / 58.15,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      ]),
                      if (bus['last_location'] != null) ...[
                        SizedBox(height: Get.height / 94.5),
                        Row(children: [
                          Icon(Icons.location_on_rounded,
                              size: Get.height / 47.25,
                              color: AppColors.danger),
                          SizedBox(width: Get.height / 126),
                          Expanded(
                            child: Text(bus['last_location'] as String,
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: Get.height / 63,
                                    color: AppColors.textSecondary)),
                          ),
                        ]),
                      ],
                    ]),
              );
            },
          ),
        );
      }),
    );
  }
}
