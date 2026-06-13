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
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        toolbarHeight: isTablet ? 65.0 : 55.0,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            top: isTablet ? 15.0 : 5.0,
            bottom: 10.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => Get.offNamed(AppRoutes.dashboard),
            ),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(
            top: isTablet ? 15.0 : 5.0,
            bottom: 10.0,
          ),
          child: Text('Attendance',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 18.0 : 14.0,
                  fontWeight: FontWeight.w600)),
        ),
        actions: [
          Padding(
            padding: EdgeInsets.only(
              top: isTablet ? 15.0 : 5.0,
              bottom: 10.0,
            ),
            child: TextButton(
              onPressed: () => Get.toNamed(AppRoutes.attendanceReport),
              child: Text('Report',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 16.0 : 14.0,
                      color: Colors.white,
                      fontFamily: 'Inter')),
            ),
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
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    return Container(
      color: Colors.white,
      padding: EdgeInsets.only(
        top: 5.0,
        bottom: isTablet ? 20.0 : 12.0,
        left: isTablet ? 32.0 : 16.0,
        right: isTablet ? 32.0 : 16.0,
      ),
      child: Obx(() {
        final selectedId = ctrl.selectedClass.value?['id'];
        final currentSelection = ctrl.classes.firstWhereOrNull(
          (c) => c['id'] == selectedId,
        );

        return LayoutBuilder(
          builder: (context, boxConstraints) {
            final localWidth = boxConstraints.maxWidth;
            return PopupMenuButton<dynamic>(
              color: Colors.white,
              offset: const Offset(0, 54),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  isTablet ? 12.0 : 8.0,
                ),
              ),
              constraints: BoxConstraints(
                minWidth: localWidth,
                maxWidth: localWidth,
              ),
              child: Container(
                height: isTablet ? 60.0 : 54.0,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20.0 : 12.0,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(
                    isTablet ? 12.0 : 8.0,
                  ),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.school_rounded,
                      color: AppColors.primary,
                      size: isTablet ? 28.0 : 22.0,
                    ),
                    SizedBox(
                      width: isTablet ? 16.0 : 12.0,
                    ),
                    Expanded(
                      child: Text(
                        currentSelection != null
                            ? '${currentSelection['name'] ?? currentSelection['class_name'] ?? 'Class'}'
                                '${currentSelection['section'] != null ? ' - ${currentSelection['section']}' : ''}'
                            : 'Select Class',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: isTablet ? 17.0 : 15.0,
                          fontWeight: FontWeight.w600,
                          color: currentSelection != null
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: isTablet ? 28.0 : 24.0,
                    ),
                  ],
                ),
              ),
              itemBuilder: (ctx) => ctrl.classes.map((cls) {
                final name = cls['name'] ?? cls['class_name'] ?? 'Class';
                final sec =
                    cls['section'] != null ? ' - ${cls['section']}' : '';
                return PopupMenuItem<dynamic>(
                  value: cls,
                  child: Text(
                    '$name$sec',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 16.0 : 14.0,
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
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    return Obx(() {
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
              horizontal: isTablet ? 32.0 : 16.0,
              vertical: isTablet ? 16.0 : 10.0,
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.tryParse(ctrl.selectedDate.value) ??
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
                      Icon(Icons.calendar_today_rounded,
                          size: isTablet ? 20.0 : 16.0,
                          color: AppColors.primary),
                      SizedBox(width: isTablet ? 10.0 : 6.0),
                      Obx(() => Text(formatYmdToDmy(ctrl.selectedDate.value),
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 15.0 : 12.0,
                            color: AppColors.primary,
                          ))),
                    ],
                  ),
                ),
                const Spacer(),
                if (!ctrl.isPastDate) ...[
                  _BulkBtn('All P', Colors.green, () => ctrl.markAll('P')),
                  SizedBox(width: isTablet ? 12.0 : 8.0),
                  _BulkBtn('All A', Colors.red, () => ctrl.markAll('A')),
                ] else
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16.0 : 12.0,
                      vertical: isTablet ? 8.0 : 6.0,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(
                        isTablet ? 12.0 : 8.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_rounded,
                          size: isTablet ? 18.0 : 14.0,
                          color: Colors.blue,
                        ),
                        SizedBox(
                          width: isTablet ? 8.0 : 4.0,
                        ),
                        Text(
                          'View Only',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: isTablet ? 14.0 : 12.0,
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
              left: isTablet ? 32.0 : 16.0,
              right: isTablet ? 32.0 : 16.0,
              top: isTablet ? 12.0 : 8.0,
              bottom: isTablet ? 16.0 : 12.0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isTablet ? 28.0 : 22.0,
                      height: isTablet ? 28.0 : 22.0,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        borderRadius:
                            BorderRadius.circular(isTablet ? 6.0 : 4.0),
                      ),
                      child: Center(
                        child: Text(
                          'P',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 12.0 : 10.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 8.0 : 6.0),
                    Text(
                      'Present',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 12.0 : 10.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: isTablet ? 32.0 : 20.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isTablet ? 28.0 : 22.0,
                      height: isTablet ? 28.0 : 22.0,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius:
                            BorderRadius.circular(isTablet ? 6.0 : 4.0),
                      ),
                      child: Center(
                        child: Text(
                          'A',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 12.0 : 10.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 8.0 : 6.0),
                    Text(
                      'Absent',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 12.0 : 10.0,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                SizedBox(width: isTablet ? 32.0 : 20.0),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: isTablet ? 28.0 : 22.0,
                      height: isTablet ? 28.0 : 22.0,
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius:
                            BorderRadius.circular(isTablet ? 6.0 : 4.0),
                      ),
                      child: Center(
                        child: Text(
                          'L',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 12.0 : 10.0,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 8.0 : 6.0),
                    Text(
                      'Late',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 12.0 : 10.0,
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
                isTablet ? 32.0 : 16.0,
              ),
              itemCount: ctrl.students.length,
              separatorBuilder: (_, __) => SizedBox(
                height: isTablet ? 14.0 : 10.0,
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
                isTablet ? 32.0 : 16.0,
                0,
                isTablet ? 32.0 : 16.0,
                isTablet ? 32.0 : 20.0,
              ),
              child: Obx(() => SizedBox(
                    width: double.infinity,
                    height: isTablet ? 60.0 : 48.0,
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
                                BorderRadius.circular(isTablet ? 16.0 : 10.0)),
                      ),
                      child: ctrl.submitting.value
                          ? SizedBox(
                              width: isTablet ? 28.0 : 22.0,
                              height: isTablet ? 28.0 : 22.0,
                              child: const CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : Text('Submit Attendance',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w500,
                                  fontSize: isTablet ? 16.0 : 14.0)),
                    ),
                  )),
            ),
        ],
      );
    });
  }
}

class _BulkBtn extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _BulkBtn(this.label, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 16.0 : 12.0,
          vertical: isTablet ? 10.0 : 6.0,
        ),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(
            isTablet ? 12.0 : 8.0,
          ),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 14.0 : 12.0,
                color: color)),
      ),
    );
  }
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
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Container(
      padding: EdgeInsets.all(isTablet ? 16.0 : 12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16.0 : 10.0),
        border: Border.all(color: _statusColor.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(
        children: [
          NetAvatar(
            url: student['profile_photo'] as String?,
            radius: isTablet ? 28.0 : 20.0,
            fallbackLetter: (student['name'] as String? ?? '?')[0],
          ),
          SizedBox(width: isTablet ? 16.0 : 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(student['name'] as String? ?? 'Student',
                    style: TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w600,
                        fontSize: isTablet ? 16.0 : 13.0,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 2.0),
                Text(
                    'Roll: ${student['roll_number'] ?? student['admission_no'] ?? '-'}',
                    style: TextStyle(
                        fontWeight: FontWeight.w400,
                        fontFamily: 'Inter',
                        fontSize: isTablet ? 13.0 : 10.0,
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
                  width: isTablet ? 48.0 : 38.0,
                  height: isTablet ? 48.0 : 38.0,
                  decoration: BoxDecoration(
                    color: sel ? c : c.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0),
                    border: Border.all(
                        color: sel ? c : c.withOpacity(0.3), width: 1.5),
                  ),
                  child: Center(
                    child: Text(s,
                        style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: isTablet ? 16.0 : 14.0,
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
}

Future<void> _showMonthYearPicker(
    BuildContext context, AttendanceController ctrl) async {
  final now = DateTime.now();
  final isTablet = MediaQuery.of(context).size.width >= 600;
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
                fontSize: isTablet ? 20.0 : 18.0,
              ),
            ),
            content: SizedBox(
              width: isTablet ? 360.0 : 280.0,
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
                          fontSize: isTablet ? 22.0 : 20.0,
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
                    height: isTablet ? 20.0 : 16.0,
                  ),
                  // Month Grid
                  SizedBox(
                    height: isTablet ? 240.0 : 210.0,
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

  Widget _buildClassSelector(
      BuildContext context, bool isTablet, double width) {
    final selectedId = ctrl.reportClass.value?['id'];
    final currentSelection = ctrl.classes.firstWhereOrNull(
      (c) => c['id'] == selectedId,
    );
    final label = currentSelection != null
        ? '${currentSelection['name'] ?? ''} ${currentSelection['section'] != null ? '- ${currentSelection['section']}' : ''}'
        : 'Select Class';

    return LayoutBuilder(
      builder: (context, boxConstraints) {
        final localWidth = boxConstraints.maxWidth;
        return Theme(
          data: Theme.of(context).copyWith(
            hoverColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent,
          ),
          child: SizedBox(
            height: isTablet ? 60.0 : 48.0,
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
                minWidth: localWidth,
                maxWidth: localWidth,
              ),
              onSelected: (v) => ctrl.reportClass.value = v,
              itemBuilder: (ctx) => ctrl.classes.map((c) {
                return PopupMenuItem<dynamic>(
                  value: c,
                  child: Text(
                    '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}',
                    style: TextStyle(
                        fontSize: isTablet ? 15.0 : 13.0,
                        fontWeight: FontWeight.w500,
                        fontFamily: 'Inter'),
                  ),
                );
              }).toList(),
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0)),
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16.0 : 12.0,
                      vertical: isTablet ? 16.0 : 12.0),
                  suffixIcon: Icon(Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: isTablet ? 28.0 : 24.0),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 15.0 : 13.0),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMonthPicker(BuildContext context, bool isTablet) {
    return GestureDetector(
      onTap: () => _showMonthYearPicker(context, ctrl),
      child: SizedBox(
        height: isTablet ? 60.0 : 48.0,
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0)),
            contentPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16.0 : 12.0,
                vertical: isTablet ? 16.0 : 12.0),
            suffixIcon: Icon(Icons.calendar_month_rounded,
                color: AppColors.primary, size: isTablet ? 28.0 : 24.0),
          ),
          child: Text(
            formatYmToMy(ctrl.reportMonth.value),
            style: TextStyle(
                fontWeight: FontWeight.w500,
                fontFamily: 'Inter',
                fontSize: isTablet ? 15.0 : 13.0),
          ),
        ),
      ),
    );
  }

  Widget _buildGenerateButton(bool isTablet) {
    return ElevatedButton(
      onPressed: ctrl.reportLoading.value ? null : () => ctrl.loadReport(),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: isTablet ? 16.0 : 12.0),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 12.0 : 8.0)),
      ),
      child: ctrl.reportLoading.value
          ? SizedBox(
              width: isTablet ? 26.0 : 20.0,
              height: isTablet ? 26.0 : 20.0,
              child: const CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : Text('Generate Report',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 16.0 : 14.0,
                  fontWeight: FontWeight.w500)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        toolbarHeight: isTablet ? 65.0 : 55.0,
        flexibleSpace: Container(
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: Padding(
          padding: EdgeInsets.only(
            left: 8.0,
            right: 8.0,
            top: isTablet ? 15.0 : 5.0,
            bottom: 10.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.white,
                size: 24,
              ),
              onPressed: () => Get.back(),
            ),
          ),
        ),
        title: Padding(
          padding: EdgeInsets.only(
            top: isTablet ? 15.0 : 5.0,
            bottom: 10.0,
          ),
          child: Text('Attendance Report',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 18.0 : 16.0,
                  fontWeight: FontWeight.w500)),
        ),
      ),
      body: Obx(() => Column(
            children: [
              // Filters
              Container(
                color: Colors.white,
                padding: EdgeInsets.only(
                  top: isTablet ? 20.0 : 5.0,
                  bottom: isTablet ? 24.0 : 16.0,
                  left: isTablet ? 24.0 : 16.0,
                  right: isTablet ? 24.0 : 16.0,
                ),
                child: isTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                              child: _buildClassSelector(
                                  context, isTablet, width)),
                          const SizedBox(width: 16.0),
                          Expanded(child: _buildMonthPicker(context, isTablet)),
                          const SizedBox(width: 16.0),
                          SizedBox(
                            width: 200.0,
                            height: 60.0,
                            child: _buildGenerateButton(isTablet),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          _buildClassSelector(context, isTablet, width),
                          const SizedBox(height: 12.0),
                          _buildMonthPicker(context, isTablet),
                          const SizedBox(height: 16.0),
                          SizedBox(
                            width: double.infinity,
                            height: 48.0,
                            child: _buildGenerateButton(isTablet),
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
    final isTablet = MediaQuery.of(context).size.width >= 600;
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
            padding: EdgeInsets.all(isTablet ? 32.0 : 16.0),
            child: Row(children: [
              Expanded(
                  child: _SummaryCard(
                      'School Days', totalDays.toString(), AppColors.primary)),
              SizedBox(width: isTablet ? 16.0 : 8.0),
              Expanded(
                  child: _SummaryCard(
                      'Avg Present', '$avgPresent%', AppColors.secondary)),
              SizedBox(width: isTablet ? 16.0 : 8.0),
              Expanded(
                  child: _SummaryCard(
                      'Avg Absent', '$avgAbsent%', AppColors.danger)),
            ]),
          ),
        ),
        SliverPadding(
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32.0 : 16.0,
          ),
          sliver: isTablet
              ? SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio: 4.5,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => _StudentReportTile(
                      student: students[i] as Map<String, dynamic>,
                      isTablet: true,
                    ),
                    childCount: students.length,
                  ),
                )
              : SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: _StudentReportTile(
                        student: students[i] as Map<String, dynamic>,
                        isTablet: false,
                      ),
                    ),
                    childCount: students.length,
                  ),
                ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: isTablet ? 40.0 : 24.0)),
      ],
    );
  }
}

class _StudentReportTile extends StatelessWidget {
  final Map<String, dynamic> student;
  final bool isTablet;

  const _StudentReportTile({required this.student, required this.isTablet});

  @override
  Widget build(BuildContext context) {
    final present = (student['present'] as num?)?.toInt() ?? 0;
    final total = (student['total_days'] as num?)?.toInt() ?? 1;
    final pct = (student['percentage'] as num?)?.round() ??
        (total > 0 ? (present / total * 100).round() : 0);
    final studentName = student['student_name'] as String? ??
        student['name'] as String? ??
        'Student';

    return Container(
      padding: EdgeInsets.all(isTablet ? 16.0 : 14.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isTablet ? 16.0 : 12.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
          )
        ],
      ),
      child: Row(
        children: [
          NetAvatar(
            url: student['profile_photo'] as String?,
            radius: isTablet ? 24.0 : 20.0,
            fallbackLetter: studentName.isNotEmpty ? studentName[0] : '?',
          ),
          SizedBox(width: isTablet ? 14.0 : 12.0),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  studentName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isTablet ? 15.0 : 14.0,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isTablet ? 6.0 : 4.0),
                LinearProgressIndicator(
                  value: pct / 100,
                  backgroundColor: Colors.grey.shade200,
                  color: pct >= 75
                      ? AppColors.secondary
                      : pct >= 50
                          ? AppColors.warning
                          : AppColors.danger,
                ),
              ],
            ),
          ),
          SizedBox(width: isTablet ? 14.0 : 12.0),
          Text(
            '$pct%',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w600,
              fontSize: isTablet ? 15.0 : 14.0,
              color: pct >= 75
                  ? AppColors.secondary
                  : pct >= 50
                      ? AppColors.warning
                      : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Container(
      padding: EdgeInsets.all(isTablet ? 20.0 : 14.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(isTablet ? 20.0 : 14.0),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(children: [
        Text(value,
            style: TextStyle(
                fontFamily: 'Inter',
                fontWeight: FontWeight.w600,
                fontSize: isTablet ? 22.0 : 16.0,
                color: color)),
        SizedBox(height: isTablet ? 6.0 : 2.0),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.w400,
                fontFamily: 'Inter',
                fontSize: isTablet ? 13.0 : 11.0,
                color: AppColors.textSecondary)),
      ]),
    );
  }
}

// ── Shimmer Classes Loading Screen ──────────────────────────────
class _ClassesLoadingShimmer extends StatelessWidget {
  const _ClassesLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: EdgeInsets.all(isTablet ? 32.0 : 16.0),
      child: Column(
        children: [
          ShimmerCard(height: isTablet ? 60.0 : 54.0, radius: 12),
          SizedBox(height: isTablet ? 16.0 : 12.0),
          Row(
            children: [
              const ShimmerCard(width: 100, height: 20, radius: 6),
              const Spacer(),
              const ShimmerCard(width: 60, height: 26, radius: 8),
              SizedBox(width: isTablet ? 12.0 : 8.0),
              const ShimmerCard(width: 60, height: 26, radius: 8),
            ],
          ),
          SizedBox(height: isTablet ? 24.0 : 16.0),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (_, __) =>
                  SizedBox(height: isTablet ? 12.0 : 8.0),
              itemBuilder: (_, __) =>
                  ShimmerCard(height: isTablet ? 80.0 : 70.0, radius: 12),
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
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: EdgeInsets.symmetric(
            horizontal: isTablet ? 32.0 : 16.0,
            vertical: isTablet ? 16.0 : 10.0,
          ),
          child: Row(
            children: [
              const ShimmerCard(width: 100, height: 20, radius: 6),
              const Spacer(),
              const ShimmerCard(width: 60, height: 26, radius: 8),
              SizedBox(width: isTablet ? 12.0 : 8.0),
              const ShimmerCard(width: 60, height: 26, radius: 8),
            ],
          ),
        ),
        Expanded(
          child: ListView.separated(
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(isTablet ? 32.0 : 16.0),
            itemCount: 6,
            separatorBuilder: (_, __) =>
                SizedBox(height: isTablet ? 12.0 : 8.0),
            itemBuilder: (_, __) =>
                ShimmerCard(height: isTablet ? 80.0 : 70.0, radius: 12),
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
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(isTablet ? 32.0 : 16.0),
          child: Row(
            children: [
              Expanded(
                  child:
                      ShimmerCard(height: isTablet ? 70.0 : 60.0, radius: 12)),
              SizedBox(width: isTablet ? 16.0 : 8.0),
              Expanded(
                  child:
                      ShimmerCard(height: isTablet ? 70.0 : 60.0, radius: 12)),
              SizedBox(width: isTablet ? 16.0 : 8.0),
              Expanded(
                  child:
                      ShimmerCard(height: isTablet ? 70.0 : 60.0, radius: 12)),
            ],
          ),
        ),
        Expanded(
          child: isTablet
              ? GridView.builder(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16.0,
                    mainAxisSpacing: 12.0,
                    childAspectRatio: 4.5,
                  ),
                  itemCount: 6,
                  itemBuilder: (_, __) => const ShimmerCard(radius: 16),
                )
              : ListView.separated(
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  itemCount: 5,
                  separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                  itemBuilder: (_, __) =>
                      const ShimmerCard(height: 64.0, radius: 12),
                ),
        ),
      ],
    );
  }
}
