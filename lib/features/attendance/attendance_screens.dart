import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api/api_client.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

// ── Controller ────────────────────────────────────────────────
class AttendanceController extends GetxController {
  final _api = ApiClient.instance;

  // Shared
  final RxList<dynamic> classes = <dynamic>[].obs;
  final RxBool classesLoading = true.obs;

  // Attendance marking
  final Rx<Map<String, dynamic>?> selectedClass = Rx(null);
  final RxList<dynamic> students = <dynamic>[].obs;
  final RxBool studentsLoading = false.obs;
  final RxMap<int, String> attendance = <int, String>{}.obs; // id -> P/A/L
  final RxBool submitting = false.obs;
  final RxString selectedDate = ''.obs;

  bool get isPastDate {
    try {
      final dateStr = selectedDate.value;
      if (dateStr.isEmpty) return false;
      final parsed = DateTime.parse(dateStr);
      final today = DateTime.now();
      final todayOnlyDate = DateTime(today.year, today.month, today.day);
      final parsedOnlyDate = DateTime(parsed.year, parsed.month, parsed.day);
      return parsedOnlyDate.isBefore(todayOnlyDate);
    } catch (_) {
      return false;
    }
  }

  // Report
  final Rx<Map<String, dynamic>?> reportData = Rx(null);
  final RxBool reportLoading = false.obs;
  final RxString reportMonth = ''.obs;
  final Rx<Map<String, dynamic>?> reportClass = Rx(null);

  @override
  void onInit() {
    super.onInit();
    final now = DateTime.now();
    selectedDate.value =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    reportMonth.value = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    loadClasses();

    ever(selectedDate, (_) {
      fetchAttendanceForSelectedDate();
    });
  }

  Future<void> loadClasses() async {
    classesLoading.value = true;
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
      classes.value = list;
      if (list.isNotEmpty) {
        final firstCls = Map<String, dynamic>.from(list.first as Map);
        if (selectedClass.value == null) {
          loadStudents(firstCls);
        }
        if (reportClass.value == null) {
          reportClass.value = firstCls;
        }
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
    } finally {
      classesLoading.value = false;
    }
  }

  Future<void> loadStudents(Map<String, dynamic> cls) async {
    selectedClass.value = cls;
    attendance.clear();
    studentsLoading.value = true;
    try {
      final id = cls['id'];
      final resp = await _api.get('/students',
          params: {'class_id': id.toString(), 'per_page': '100'});
      final raw = resp.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(raw['data'] ?? raw['students'] ?? []);
      }
      students.value = list;
      await fetchAttendanceForSelectedDate();
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
    } finally {
      studentsLoading.value = false;
    }
  }

  Future<void> fetchAttendanceForSelectedDate() async {
    final cls = selectedClass.value;
    if (cls == null) return;
    final classId = cls['id'];
    final date = selectedDate.value;
    if (date.isEmpty) return;

    try {
      final resp = await _api.get('/attendance',
          params: {'class_id': classId.toString(), 'date': date});
      final raw = resp.data;
      List<dynamic> records = [];
      if (raw is List) {
        records = raw;
      } else if (raw is Map) {
        records = List<dynamic>.from(raw['data'] ?? []);
      }

      final Map<int, String> existing = {};
      for (final r in records) {
        final sid = r['student_id'] is int
            ? r['student_id'] as int
            : int.tryParse(r['student_id'].toString()) ?? 0;
        final status = r['status']?.toString().toLowerCase();
        if (sid != 0 && status != null) {
          if (status == 'present') {
            existing[sid] = 'P';
          } else if (status == 'absent') {
            existing[sid] = 'A';
          } else if (status == 'late') {
            existing[sid] = 'L';
          }
        }
      }

      for (final s in students) {
        final sid = s['id'] is int
            ? s['id'] as int
            : int.tryParse(s['id'].toString()) ?? 0;
        if (existing.containsKey(sid)) {
          attendance[sid] = existing[sid]!;
        } else {
          attendance[sid] = '';
        }
      }
    } catch (e) {
      debugPrint('Error fetching attendance: $e');
    }
  }

  void setStatus(int studentId, String status) {
    attendance[studentId] = status;
  }

  void markAll(String status) {
    for (final k in attendance.keys.toList()) {
      attendance[k] = status;
    }
  }

  Future<bool> submitAttendance() async {
    final unmarkedCount = attendance.values.where((v) => v.isEmpty).length;
    if (unmarkedCount > 0) {
      Get.snackbar('Validation Error',
          'Please mark attendance for all students before submitting.',
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return false;
    }
    submitting.value = true;
    try {
      final records = attendance.entries.map((e) {
        final studentId = e.key;
        final statusVal = e.value;
        final apiStatus = statusVal == 'P'
            ? 'present'
            : statusVal == 'A'
                ? 'absent'
                : 'late';
        return {
          'student_id': studentId,
          'status': apiStatus,
        };
      }).toList();

      final payload = {
        'class_id': selectedClass.value!['id'],
        'date': selectedDate.value,
        'attendance': records,
      };

      await _api.post('/attendance/mark-class', payload);
      return true;
    } catch (e) {
      final msg = (e is ApiException) ? e.displayMessage : e.toString();
      Get.snackbar('Error', msg,
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      return false;
    } finally {
      submitting.value = false;
    }
  }

  Future<void> loadReport() async {
    if (reportClass.value == null) return;
    reportLoading.value = true;
    reportData.value = null;
    try {
      final id = reportClass.value!['id'];
      final parts = reportMonth.value.split('-');
      final yearStr = parts[0];
      final monthStr = parts.length > 1 ? parts[1] : '1';
      final yearInt = int.tryParse(yearStr) ?? DateTime.now().year;
      final monthInt = int.tryParse(monthStr) ?? DateTime.now().month;

      final resp = await _api.get('/attendance/report', params: {
        'class_id': id.toString(),
        'month': monthInt.toString(),
        'year': yearInt.toString(),
      });
      final raw = resp.data;
      reportData.value = Map<String, dynamic>.from(raw['data'] ?? raw);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
    } finally {
      reportLoading.value = false;
    }
  }
}

// ── Attendance Screen ─────────────────────────────────────────
class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(AttendanceController());
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_rounded,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Get.offNamed(AppRoutes.dashboard),
        ),
        title: Text('Attendance',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        actions: [
          TextButton(
            onPressed: () => Get.toNamed(AppRoutes.attendanceReport),
            child: const Text('Report',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                    fontFamily: 'Inter')),
          )
        ],
      ),
      body: Obx(() {
        if (ctrl.classesLoading.value) {
          return const _ClassesLoadingShimmer();
        }
        if (ctrl.classes.isEmpty) {
          return const EmptyState(
            icon: Icons.school_outlined,
            title: 'No Classes',
            subtitle: 'No classes assigned to you',
          );
        }
        return Column(
          children: [
            _ClassPicker(ctrl: ctrl),
            Expanded(child: _AttendanceBody(ctrl: ctrl)),
          ],
        );
      }),
    );
  }
}

class _ClassPicker extends StatelessWidget {
  final AttendanceController ctrl;
  const _ClassPicker({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(
        horizontal: Get.height / 47.25,
        vertical: Get.height / 63,
      ),
      child: Obx(() {
        final selectedId = ctrl.selectedClass.value?['id'];
        final currentSelection = ctrl.classes.firstWhereOrNull(
          (c) => c['id'] == selectedId,
        );

        return PopupMenuButton<dynamic>(
          color: Colors.white,
          offset: const Offset(0, 54),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              Get.height / 63,
            ),
          ),
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: Container(
            height: 54,
            padding: EdgeInsets.symmetric(
              horizontal: Get.height / 63,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(
                Get.height / 63,
              ),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: Get.height / 37.8,
                ),
                SizedBox(
                  width: Get.height / 63,
                ),
                Expanded(
                  child: Text(
                    currentSelection != null
                        ? '${currentSelection['name'] ?? currentSelection['class_name'] ?? 'Class'}'
                            '${currentSelection['section'] != null ? ' - ${currentSelection['section']}' : ''}'
                        : 'Select Class',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15.0,
                      fontWeight: currentSelection != null
                          ? FontWeight.w600
                          : FontWeight.w600,
                      color: currentSelection != null
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  color: AppColors.textSecondary,
                ),
              ],
            ),
          ),
          itemBuilder: (ctx) => ctrl.classes.map((cls) {
            final name = cls['name'] ?? cls['class_name'] ?? 'Class';
            final sec = cls['section'] != null ? ' - ${cls['section']}' : '';
            return PopupMenuItem<dynamic>(
              value: cls,
              child: Text(
                '$name$sec',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15.0,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            );
          }).toList(),
          onSelected: (v) {
            if (v != null) {
              ctrl.loadStudents(Map<String, dynamic>.from(v as Map));
            }
          },
        );
      }),
    );
  }
}

class _AttendanceBody extends StatelessWidget {
  final AttendanceController ctrl;
  const _AttendanceBody({required this.ctrl});

  @override
  Widget build(BuildContext context) => Obx(() {
        if (ctrl.selectedClass.value == null) {
          return const EmptyState(
            icon: Icons.touch_app_rounded,
            title: 'Select a Class',
            subtitle: 'Tap a class above to mark attendance',
          );
        }
        if (ctrl.studentsLoading.value) {
          return const _StudentsLoadingShimmer();
        }
        if (ctrl.students.isEmpty) {
          return const EmptyState(
            icon: Icons.people_outline,
            title: 'No Students',
            subtitle: 'No students found in this class',
          );
        }
        return Column(
          children: [
            // Date & bulk actions bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: Get.height / 47.25,
                vertical: Get.height / 75.6,
              ),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate:
                            DateTime.tryParse(ctrl.selectedDate.value) ??
                                DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now(),
                      );
                      if (picked != null) {
                        ctrl.selectedDate.value =
                            '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            size: 16, color: AppColors.primary),
                        SizedBox(width: Get.height / 126),
                        Obx(() => Text(formatYmdToDmy(ctrl.selectedDate.value),
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 12.0,
                              color: AppColors.primary,
                            ))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (!ctrl.isPastDate) ...[
                    _BulkBtn('All P', Colors.green, () => ctrl.markAll('P')),
                    SizedBox(width: Get.height / 94.5),
                    _BulkBtn('All A', Colors.red, () => ctrl.markAll('A')),
                  ] else
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: Get.height / 63,
                        vertical: Get.height / 126,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          Get.height / 94.5,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_rounded,
                            size: Get.height / 58.15,
                            color: Colors.blue,
                          ),
                          SizedBox(
                            width: Get.height / 189,
                          ),
                          Text(
                            'View Only',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Legend bar
            Container(
              color: Colors.white,
              padding: EdgeInsets.only(
                left: Get.height / 47.25,
                right: Get.height / 47.25,
                top: Get.height / 94.5,
                bottom: Get.height / 63,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: Get.height / 38,
                        height: Get.height / 38,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(Get.height / 189),
                        ),
                        child: Center(
                          child: Text(
                            'P',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: Get.height / 126),
                      Text(
                        'Present',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: Get.height / 47.25),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: Get.height / 38,
                        height: Get.height / 38,
                        decoration: BoxDecoration(
                          color: Colors.red,
                          borderRadius: BorderRadius.circular(Get.height / 189),
                        ),
                        child: Center(
                          child: Text(
                            'A',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: Get.height / 126),
                      Text(
                        'Absent',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(width: Get.height / 47.25),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: Get.height / 38,
                        height: Get.height / 38,
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(Get.height / 189),
                        ),
                        child: Center(
                          child: Text(
                            'L',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: Get.height / 126),
                      Text(
                        'Late',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 10,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Student list
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.all(
                  Get.height / 47.25,
                ),
                itemCount: ctrl.students.length,
                separatorBuilder: (_, __) => SizedBox(
                  height: Get.height / 94.5,
                ),
                itemBuilder: (ctx, i) {
                  final s = ctrl.students[i] as Map<String, dynamic>;
                  final sid = s['id'] is int
                      ? s['id'] as int
                      : int.tryParse(s['id'].toString()) ?? 0;
                  return Obx(() => _StudentAttendanceTile(
                        student: s,
                        status: ctrl.attendance[sid] ?? '',
                        onChanged: ctrl.isPastDate
                            ? null
                            : (v) => ctrl.setStatus(sid, v),
                      ));
                },
              ),
            ),
            // Submit button
            if (!ctrl.isPastDate)
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Get.height / 47.25,
                  0,
                  Get.height / 47.25,
                  Get.height / 31.5,
                ),
                child: Obx(() => SizedBox(
                      width: double.infinity,
                      height: Get.height / 14.53,
                      child: ElevatedButton(
                        onPressed: ctrl.submitting.value
                            ? null
                            : () async {
                                final ok = await ctrl.submitAttendance();
                                if (ok && context.mounted) {
                                  showToast(context, 'Attendance saved!');
                                }
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(Get.height / 54)),
                        ),
                        child: ctrl.submitting.value
                            ? SizedBox(
                                width: Get.height / 34.36,
                                height: Get.height / 34.36,
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : Text('Submit Attendance',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500,
                                    fontSize: 14)),
                      ),
                    )),
              ),
          ],
        );
      });
}

class _BulkBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BulkBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: Get.height / 63,
            vertical: Get.height / 126,
          ),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              Get.height / 94.5,
            ),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: color)),
        ),
      );
}

class _StudentAttendanceTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final String status;
  final ValueChanged<String>? onChanged;
  const _StudentAttendanceTile(
      {required this.student, required this.status, required this.onChanged});

  Color get _statusColor {
    switch (status) {
      case 'P':
        return Colors.green;
      case 'A':
        return Colors.red;
      case 'L':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(Get.height / 63),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(Get.height / 54),
          border: Border.all(color: _statusColor.withOpacity(0.25)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: Get.height / 126,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            NetAvatar(
              url: student['profile_photo'] as String?,
              radius: Get.height / 37.8,
              fallbackLetter: (student['name'] as String? ?? '?')[0],
            ),
            SizedBox(width: Get.height / 63),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student['name'] as String? ?? 'Student',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                          color: AppColors.textPrimary)),
                  Text(
                      'Roll: ${student['roll_number'] ?? student['admission_no'] ?? '-'}',
                      style: TextStyle(
                          fontWeight: FontWeight.w400,
                          fontFamily: 'Inter',
                          fontSize: 10,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            Row(
              children: ['P', 'A', 'L'].map((s) {
                final sel = status == s;
                final c = s == 'P'
                    ? Colors.green
                    : s == 'A'
                        ? Colors.red
                        : Colors.orange;
                return GestureDetector(
                  onTap: onChanged == null ? null : () => onChanged!(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 6),
                    width: Get.height / 21,
                    height: Get.height / 21,
                    decoration: BoxDecoration(
                      color: sel ? c : c.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(Get.height / 75.6),
                      border: Border.all(
                          color: sel ? c : c.withOpacity(0.3), width: 1.5),
                    ),
                    child: Center(
                      child: Text(s,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                              color: sel ? Colors.white : c)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}

Future<void> _showMonthYearPicker(
    BuildContext context, AttendanceController ctrl) async {
  final now = DateTime.now();
  final initialYm = ctrl.reportMonth.value.split('-');
  int tempYear = initialYm.isNotEmpty
      ? (int.tryParse(initialYm[0]) ?? now.year)
      : now.year;
  int tempMonth = initialYm.length > 1
      ? (int.tryParse(initialYm[1]) ?? now.month)
      : now.month;

  final months = [
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

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            surfaceTintColor: Colors.white,
            backgroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(
              'Select Month & Year',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: 18,
              ),
            ),
            content: SizedBox(
              width: Get.width / 2.36,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year Selection Row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: tempYear > 2020
                            ? () => setState(() => tempYear--)
                            : null,
                        icon: const Icon(Icons.chevron_left_rounded,
                            color: AppColors.primary),
                      ),
                      Text(
                        '$tempYear',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      IconButton(
                        onPressed: tempYear < now.year
                            ? () => setState(() => tempYear++)
                            : null,
                        icon: const Icon(Icons.chevron_right_rounded,
                            color: AppColors.primary),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: Get.height / 47.25,
                  ),
                  // Month Grid
                  SizedBox(
                    height: Get.height / 3.78,
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 8,
                        mainAxisSpacing: 8,
                        childAspectRatio: 2.2,
                      ),
                      itemCount: 12,
                      itemBuilder: (ctx, index) {
                        final mNum = index + 1;
                        final isSelected = tempMonth == mNum;
                        final isFutureMonth =
                            tempYear == now.year && mNum > now.month;

                        return GestureDetector(
                          onTap: isFutureMonth
                              ? null
                              : () => setState(() => tempMonth = mNum),
                          child: Container(
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : isFutureMonth
                                      ? Colors.grey.shade100
                                      : Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade300,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                months[index].substring(0, 3),
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isSelected
                                      ? Colors.white
                                      : isFutureMonth
                                          ? Colors.grey.shade400
                                          : AppColors.textPrimary,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  ctrl.reportMonth.value =
                      '$tempYear-${tempMonth.toString().padLeft(2, '0')}';
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, fontFamily: 'Inter')),
              ),
            ],
          );
        },
      );
    },
  );
}

// ── Attendance Report Screen ──────────────────────────────────
class AttendanceReportScreen extends StatefulWidget {
  const AttendanceReportScreen({super.key});

  @override
  State<AttendanceReportScreen> createState() => _AttendanceReportScreenState();
}

class _AttendanceReportScreenState extends State<AttendanceReportScreen> {
  late final AttendanceController ctrl;

  @override
  void initState() {
    super.initState();
    ctrl = Get.find<AttendanceController>();
    final now = DateTime.now();
    ctrl.reportMonth.value =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    ctrl.reportData.value =
        null; // Clear previous report data when entering screen
  }

  @override
  Widget build(BuildContext context) {
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
          onPressed: () => Get.back(),
        ),
        title: const Text('Attendance Report',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 16,
                fontWeight: FontWeight.w500)),
      ),
      body: Obx(() => Column(
            children: [
              // Filters
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Class selector
                    (() {
                      final selectedId = ctrl.reportClass.value?['id'];
                      final currentSelection = ctrl.classes.firstWhereOrNull(
                        (c) => c['id'] == selectedId,
                      );
                      final label = currentSelection != null
                          ? '${currentSelection['name'] ?? ''} ${currentSelection['section'] != null ? '- ${currentSelection['section']}' : ''}'
                          : 'Select Class';

                      return Theme(
                        data: Theme.of(context).copyWith(
                          hoverColor: Colors.transparent,
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                        ),
                        child: PopupMenuButton<dynamic>(
                          surfaceTintColor: Colors.white,
                          color: Colors.white,
                          offset: const Offset(0, 52),
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: const BorderSide(color: Color(0xFFE2E8F0)),
                          ),
                          constraints: BoxConstraints(
                            minWidth: MediaQuery.of(context).size.width - 32,
                            maxWidth: MediaQuery.of(context).size.width - 32,
                          ),
                          onSelected: (v) => ctrl.reportClass.value = v,
                          itemBuilder: (ctx) => ctrl.classes.map((c) {
                            return PopupMenuItem<dynamic>(
                              value: c,
                              child: Text(
                                '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    fontFamily: 'Inter'),
                              ),
                            );
                          }).toList(),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Select Class',
                              border: OutlineInputBorder(
                                  borderRadius:
                                      BorderRadius.circular(Get.height / 63)),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: Get.height / 63,
                                  vertical: Get.height / 75.6),
                              suffixIcon: const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  color: AppColors.textSecondary),
                            ),
                            child: Text(
                              label,
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  fontSize: 13),
                            ),
                          ),
                        ),
                      );
                    })(),
                    SizedBox(height: Get.height / 63),
                    // Month picker
                    GestureDetector(
                      onTap: () => _showMonthYearPicker(context, ctrl),
                      child: Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(Get.height / 63),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(Get.height / 63),
                        ),
                        child: Row(children: [
                          Icon(Icons.calendar_month_rounded,
                              size: Get.height / 54, color: AppColors.primary),
                          SizedBox(width: Get.height / 94.5),
                          Text(formatYmToMy(ctrl.reportMonth.value),
                              style: TextStyle(
                                  fontWeight: FontWeight.w500,
                                  fontFamily: 'Inter',
                                  fontSize: 13)),
                        ]),
                      ),
                    ),
                    SizedBox(height: Get.height / 63),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: ctrl.reportLoading.value
                            ? null
                            : () => ctrl.loadReport(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: ctrl.reportLoading.value
                            ? SizedBox(
                                width: Get.height / 37.8,
                                height: Get.height / 37.8,
                                child: const CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Generate Report',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w500)),
                      ),
                    ),
                  ],
                ),
              ),
              // Report results
              Expanded(
                child: ctrl.reportLoading.value
                    ? const _ReportLoadingShimmer()
                    : ctrl.reportData.value == null
                        ? const EmptyState(
                            icon: Icons.bar_chart_rounded,
                            title: 'No Report',
                            subtitle:
                                'Select a class and month, then tap Generate Report',
                          )
                        : _ReportBody(data: ctrl.reportData.value!),
              ),
            ],
          )),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportBody({required this.data});

  @override
  Widget build(BuildContext context) {
    final students = List<dynamic>.from(
        data['report'] ?? data['students'] ?? data['records'] ?? []);

    // Dynamically calculate summary stats from student list
    final int totalDays = students.isNotEmpty
        ? students
            .map((s) => (s['total_days'] as num?)?.toInt() ?? 0)
            .reduce((a, b) => a > b ? a : b)
        : 0;

    int totalPresentDays = 0;
    int totalWorkingDays = 0;
    for (final s in students) {
      totalPresentDays += ((s['present'] as num?)?.toInt() ?? 0);
      totalWorkingDays += ((s['total_days'] as num?)?.toInt() ?? 0);
    }

    final int avgPresent = totalWorkingDays > 0
        ? (totalPresentDays / totalWorkingDays * 100).round()
        : 0;
    final int avgAbsent = totalWorkingDays > 0 ? 100 - avgPresent : 0;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(Get.height / 47.25),
            child: Row(children: [
              Expanded(
                  child: _SummaryCard(
                      'School Days', totalDays.toString(), AppColors.primary)),
              SizedBox(width: Get.height / 75.6),
              Expanded(
                  child: _SummaryCard(
                      'Avg Present', '$avgPresent%', AppColors.secondary)),
              SizedBox(width: Get.height / 75.6),
              Expanded(
                  child: _SummaryCard(
                      'Avg Absent', '$avgAbsent%', AppColors.danger)),
            ]),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final s = students[i] as Map<String, dynamic>;
              final present = (s['present'] as num?)?.toInt() ?? 0;
              final total = (s['total_days'] as num?)?.toInt() ?? 1;
              final pct = (s['percentage'] as num?)?.round() ??
                  (total > 0 ? (present / total * 100).round() : 0);
              final studentName = s['student_name'] as String? ??
                  s['name'] as String? ??
                  'Student';

              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: Get.height / 47.25,
                  vertical: Get.height / 189,
                ),
                padding: EdgeInsets.all(Get.height / 54),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(
                    Get.height / 54,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: Get.height / 126,
                    )
                  ],
                ),
                child: Row(children: [
                  NetAvatar(
                    url: s['profile_photo'] as String?,
                    radius: Get.height / 37.8,
                    fallbackLetter:
                        studentName.isNotEmpty ? studentName[0] : '?',
                  ),
                  SizedBox(width: Get.height / 63),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600)),
                          SizedBox(height: Get.height / 189),
                          LinearProgressIndicator(
                            value: pct / 100,
                            backgroundColor: Colors.grey.shade200,
                            color: pct >= 75
                                ? AppColors.secondary
                                : pct >= 50
                                    ? AppColors.warning
                                    : AppColors.danger,
                          ),
                        ]),
                  ),
                  SizedBox(width: Get.height / 63),
                  Text('$pct%',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          color: pct >= 75
                              ? AppColors.secondary
                              : pct >= 50
                                  ? AppColors.warning
                                  : AppColors.danger)),
                ]),
              );
            },
            childCount: students.length,
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: Get.height / 31.5)),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.all(Get.height / 54),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(Get.height / 54),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w400,
                  fontSize: 16,
                  color: color)),
          SizedBox(height: Get.height / 378),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontWeight: FontWeight.w400,
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
        ]),
      );
}

// ── Shimmer Classes Loading Screen ──────────────────────────────
class _ClassesLoadingShimmer extends StatelessWidget {
  const _ClassesLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(Get.height / 47.25),
      child: Column(
        children: [
          const ShimmerCard(height: 54, radius: 12),
          SizedBox(height: Get.height / 63),
          Row(
            children: [
              const ShimmerCard(width: 100, height: 20, radius: 6),
              const Spacer(),
              const ShimmerCard(width: 60, height: 26, radius: 8),
              SizedBox(width: Get.height / 94.5),
              const ShimmerCard(width: 60, height: 26, radius: 8),
            ],
          ),
          SizedBox(height: Get.height / 47.25),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (_, __) => SizedBox(height: Get.height / 94.5),
              itemBuilder: (_, __) => const ShimmerCard(height: 70, radius: 12),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer Students Loading Screen ──────────────────────────────
class _StudentsLoadingShimmer extends StatelessWidget {
  const _StudentsLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: Get.height / 47.25,
            vertical: Get.height / 75.6,
          ),
          child: Row(
            children: [
              const ShimmerCard(width: 100, height: 20, radius: 6),
              const Spacer(),
              const ShimmerCard(width: 60, height: 26, radius: 8),
              SizedBox(width: Get.height / 94.5),
              const ShimmerCard(width: 60, height: 26, radius: 8),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(Get.height / 47.25),
            itemCount: 6,
            separatorBuilder: (_, __) => SizedBox(height: Get.height / 94.5),
            itemBuilder: (_, __) => const ShimmerCard(height: 70, radius: 12),
          ),
        ),
      ],
    );
  }
}

// ── Shimmer Report Loading Screen ──────────────────────────────
class _ReportLoadingShimmer extends StatelessWidget {
  const _ReportLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(Get.height / 47.25),
          child: Row(
            children: [
              Expanded(child: const ShimmerCard(height: 60, radius: 12)),
              SizedBox(width: Get.height / 75.6),
              Expanded(child: const ShimmerCard(height: 60, radius: 12)),
              SizedBox(width: Get.height / 75.6),
              Expanded(child: const ShimmerCard(height: 60, radius: 12)),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(horizontal: Get.height / 47.25),
            itemCount: 5,
            separatorBuilder: (_, __) => SizedBox(height: Get.height / 94.5),
            itemBuilder: (_, __) => const ShimmerCard(height: 64, radius: 12),
          ),
        ),
      ],
    );
  }
}
