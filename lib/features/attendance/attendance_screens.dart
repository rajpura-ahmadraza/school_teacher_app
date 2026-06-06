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
    reportMonth.value =
        '${now.year}-${now.month.toString().padLeft(2, '0')}';
    loadClasses();
  }

  Future<void> loadClasses() async {
    classesLoading.value = true;
    try {
      final resp = await _api.get('/classes');
      final raw = resp.data;
      classes.value = List<dynamic>.from(raw['data'] ?? raw ?? []);
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
      final resp = await _api.get('/classes/$id/students');
      final raw = resp.data;
      final list = List<dynamic>.from(raw['data'] ?? raw ?? []);
      students.value = list;
      for (final s in list) {
        final sid = s['id'] as int;
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
      await _api.post('/attendance', {
        'class_id': selectedClass.value!['id'],
        'date': selectedDate.value,
        'records': records,
      });
      return true;
    } catch (e) {
      Get.snackbar('Error', e.toString(),
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
      final resp = await _api.get('/attendance/report', params: {
        'class_id': id.toString(),
        'month': reportMonth.value,
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
            decoration: const BoxDecoration(gradient: AppColors.gradientPrimary)),
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
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.all(16),
        child: Obx(() => SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: ctrl.classes.map((cls) {
                  final selected =
                      ctrl.selectedClass.value?['id'] == cls['id'];
                  return GestureDetector(
                    onTap: () => ctrl.loadStudents(
                        Map<String, dynamic>.from(cls as Map)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.only(right: 10),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: selected
                            ? AppColors.gradientPrimary
                            : null,
                        color: selected ? null : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Colors.transparent
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Text(
                        '${cls['name'] ?? cls['class_name'] ?? 'Class'}'
                        '${cls['section'] != null ? ' - ${cls['section']}' : ''}',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selected ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            )),
      );
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                  final sid = s['id'] as int;
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
            decoration: const BoxDecoration(gradient: AppColors.gradientPrimary)),
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
                    DropdownButtonFormField<Map<String, dynamic>>(
                      value: ctrl.reportClass.value,
                      decoration: InputDecoration(
                        labelText: 'Select Class',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                      ),
                      items: ctrl.classes.map((c) {
                        final cls = Map<String, dynamic>.from(c as Map);
                        return DropdownMenuItem(
                          value: cls,
                          child: Text(
                              '${cls['name'] ?? ''} ${cls['section'] != null ? '- ${cls['section']}' : ''}',
                              style:
                                  const TextStyle(fontFamily: 'Inter')),
                        );
                      }).toList(),
                      onChanged: (v) => ctrl.reportClass.value = v,
                    ),
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
                                    strokeWidth: 2,
                                    color: Colors.white))
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
                        child: CircularProgressIndicator(
                            color: AppColors.primary))
                    : ctrl.reportData.value == null
                        ? const EmptyState(
                            icon: Icons.bar_chart_rounded,
                            title: 'No Report',
                            subtitle: 'Select a class and month, then tap Generate Report',
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
    final students =
        List<dynamic>.from(data['students'] ?? data['records'] ?? []);
    final summary = data['summary'] as Map? ?? {};

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                  child: _SummaryCard(
                      'Working Days',
                      summary['total_days']?.toString() ?? '--',
                      AppColors.primary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryCard(
                      'Avg Present',
                      '${summary['avg_present'] ?? '--'}%',
                      AppColors.secondary)),
              const SizedBox(width: 10),
              Expanded(
                  child: _SummaryCard(
                      'Avg Absent',
                      '${summary['avg_absent'] ?? '--'}%',
                      AppColors.danger)),
            ]),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate(
            (ctx, i) {
              final s = students[i] as Map<String, dynamic>;
              final present = s['present'] as int? ?? 0;
              final total = s['total_days'] as int? ?? 1;
              final pct = total > 0 ? (present / total * 100).round() : 0;
              return Container(
                margin:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6)
                  ],
                ),
                child: Row(children: [
                  NetAvatar(
                    url: s['profile_photo'] as String?,
                    radius: 20,
                    fallbackLetter:
                        (s['name'] as String? ?? '?')[0],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(s['name'] as String? ?? 'Student',
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
