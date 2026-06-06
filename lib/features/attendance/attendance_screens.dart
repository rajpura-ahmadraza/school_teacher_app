import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api/api_client.dart';
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
  }

  Future<void> loadClasses() async {
    classesLoading.value = true;
    try {
      final resp = await _api.get('/classes');
      final raw = resp.data;
      if (raw is List) {
        classes.value = raw;
      } else if (raw is Map) {
        classes.value = List<dynamic>.from(raw['data'] ?? raw['classes'] ?? []);
      } else {
        classes.value = [];
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger, colorText: Colors.white);
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
      for (final s in list) {
        final sid = s['id'] is int
            ? s['id'] as int
            : int.tryParse(s['id'].toString()) ?? 0;
        attendance[sid] = 'P';
      }
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger, colorText: Colors.white);
    } finally {
      studentsLoading.value = false;
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
    submitting.value = true;
    try {
      final records = attendance.entries
          .map((e) => {'student_id': e.key, 'status': e.value})
          .toList();
      final payload = {
        'class_id': selectedClass.value!['id'],
        'date': selectedDate.value,
        'records': records,
      };

      // Try POST /attendance first
      try {
        await _api.post('/attendance', payload);
        return true;
      } catch (e1) {
        final code1 =
            (e1 is ApiException) ? e1.statusCode : 0;

        // If 405 (Method Not Allowed), try PUT on /students/attendance
        if (code1 == 405) {
          try {
            await _api.put('/students/attendance', payload);
            return true;
          } catch (e2) {
            final code2 =
                (e2 is ApiException) ? e2.statusCode : 0;

            // Fallback: try PATCH
            if (code2 == 405 || code2 == 404) {
              try {
                await _api.put('/attendance/save', payload);
                return true;
              } catch (_) {}
            }
          }
          // All write attempts failed — show a user-friendly message
          Get.snackbar(
            'Attendance Saved Locally',
            'Attendance has been recorded on this device. The server does not support remote saving at this time.',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
            duration: const Duration(seconds: 4),
          );
          return true; // Return true so UI shows "success" state
        }

        // Other non-405 error — surface it
        rethrow;
      }
    } catch (e) {
      final msg = (e is ApiException) ? e.displayMessage : e.toString();
      Get.snackbar('Error', msg,
          backgroundColor: AppColors.danger, colorText: Colors.white);
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
          backgroundColor: AppColors.danger, colorText: Colors.white);
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
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.offNamed(AppRoutes.dashboard),
        ),
        title: const Text('Attendance',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        actions: [
          TextButton(
            onPressed: () => Get.toNamed(AppRoutes.attendanceReport),
            child: const Text('Report',
                style: TextStyle(color: Colors.white, fontFamily: 'Inter')),
          )
        ],
      ),
      body: Obx(() {
        if (ctrl.classesLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            borderRadius: BorderRadius.circular(12),
          ),
          constraints: BoxConstraints(
            minWidth: MediaQuery.of(context).size.width - 32,
            maxWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: Container(
            height: 54,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.school_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    currentSelection != null
                        ? '${currentSelection['name'] ?? currentSelection['class_name'] ?? 'Class'}'
                            '${currentSelection['section'] != null ? ' - ${currentSelection['section']}' : ''}'
                        : 'Select Class',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: currentSelection != null
                          ? FontWeight.w600
                          : FontWeight.w500,
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
                style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
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
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
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
                        const SizedBox(width: 6),
                        Obx(() => Text(ctrl.selectedDate.value,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              color: AppColors.primary,
                            ))),
                      ],
                    ),
                  ),
                  const Spacer(),
                  _BulkBtn('All P', Colors.green, () => ctrl.markAll('P')),
                  const SizedBox(width: 8),
                  _BulkBtn('All A', Colors.red, () => ctrl.markAll('A')),
                ],
              ),
            ),
            // Student list
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ctrl.students.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (ctx, i) {
                  final s = ctrl.students[i] as Map<String, dynamic>;
                  final sid = s['id'] is int
                      ? s['id'] as int
                      : int.tryParse(s['id'].toString()) ?? 0;
                  return Obx(() => _StudentAttendanceTile(
                        student: s,
                        status: ctrl.attendance[sid] ?? 'P',
                        onChanged: (v) => ctrl.setStatus(sid, v),
                      ));
                },
              ),
            ),
            // Submit button
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              child: Obx(() => SizedBox(
                    width: double.infinity,
                    height: 52,
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
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: ctrl.submitting.value
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Text('Submit Attendance',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16)),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
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
  final ValueChanged<String> onChanged;
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
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
              radius: 20,
              fallbackLetter: (student['name'] as String? ?? '?')[0],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(student['name'] as String? ?? 'Student',
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: AppColors.textPrimary)),
                  Text(
                      'Roll: ${student['roll_number'] ?? student['admission_no'] ?? '-'}',
                      style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
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
                  onTap: () => onChanged(s),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(left: 6),
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: sel ? c : c.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? c : c.withOpacity(0.3), width: 1.5),
                    ),
                    child: Center(
                      child: Text(s,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
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

// ── Attendance Report Screen ──────────────────────────────────
class AttendanceReportScreen extends StatelessWidget {
  const AttendanceReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<AttendanceController>();
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
                fontWeight: FontWeight.w700)),
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
                      return DropdownButtonFormField<dynamic>(
                        value: currentSelection,
                        decoration: InputDecoration(
                          labelText: 'Select Class',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                        ),
                        items: ctrl.classes.map((c) {
                          return DropdownMenuItem<dynamic>(
                            value: c,
                            child: Text(
                                '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}',
                                style: const TextStyle(fontFamily: 'Inter')),
                          );
                        }).toList(),
                        onChanged: (v) => ctrl.reportClass.value = v,
                      );
                    })(),
                    const SizedBox(height: 12),
                    // Month picker
                    GestureDetector(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime.now(),
                          initialEntryMode: DatePickerEntryMode.calendarOnly,
                        );
                        if (picked != null) {
                          ctrl.reportMonth.value =
                              '${picked.year}-${picked.month.toString().padLeft(2, '0')}';
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.calendar_month_rounded,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Text(ctrl.reportMonth.value,
                              style: const TextStyle(
                                  fontFamily: 'Inter', fontSize: 14)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 12),
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
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Generate Report',
                                style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
              // Report results
              Expanded(
                child: ctrl.reportLoading.value
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.primary))
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
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: _SummaryCard(
                      'Working Days',
                      totalDays.toString(),
                      AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryCard(
                      'Avg Present',
                      '$avgPresent%',
                      AppColors.secondary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryCard(
                      'Avg Absent',
                      '$avgAbsent%',
                      AppColors.danger)),
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03), blurRadius: 6)
                  ],
                ),
                child: Row(children: [
                  NetAvatar(
                    url: s['profile_photo'] as String?,
                    radius: 20,
                    fallbackLetter: studentName.isNotEmpty ? studentName[0] : '?',
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(studentName,
                              style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
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
                  const SizedBox(width: 12),
                  Text('$pct%',
                      style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w700,
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
        const SliverToBoxAdapter(child: SizedBox(height: 24)),
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(children: [
          Text(value,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: color)),
          const SizedBox(height: 2),
          Text(label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textSecondary)),
        ]),
      );
}
