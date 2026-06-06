import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import '../../core/api/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

// ── Controller ────────────────────────────────────────────────
class HomeworkController extends GetxController {
  final _api = ApiClient.instance;

  final RxList<dynamic> classes = <dynamic>[].obs;
  final RxList<dynamic> subjects = <dynamic>[].obs;
  final RxList<dynamic> homeworkList = <dynamic>[].obs;
  final Rx<Map<String, dynamic>?> selectedClass = Rx(null);
  final RxBool classesLoading = true.obs;
  final RxBool listLoading = false.obs;
  final RxBool formSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadClasses();
  }

  Future<void> loadClasses() async {
    classesLoading.value = true;
    try {
      final resp = await _api.get('/classes');
      final raw = resp.data;
      classes.value = List<dynamic>.from(raw['data'] ?? raw ?? []);
    } catch (_) {}
    classesLoading.value = false;
  }

  Future<void> loadSubjects(int classId) async {
    try {
      final resp = await _api.get('/subjects', params: {'class_id': classId.toString()});
      final raw = resp.data;
      subjects.value = List<dynamic>.from(raw['data'] ?? raw ?? []);
    } catch (_) {}
  }

  Future<void> loadHomework(int? classId) async {
    listLoading.value = true;
    try {
      final params = <String, dynamic>{'per_page': '50'};
      if (classId != null) params['class_id'] = classId.toString();
      final resp = await _api.get('/homework', params: params);
      final raw = resp.data;
      homeworkList.value = List<dynamic>.from(raw['data'] ?? raw ?? []);
    } catch (_) {}
    listLoading.value = false;
  }

  Future<bool> submitHomework(Map<String, dynamic> payload, {int? existingId}) async {
    formSubmitting.value = true;
    try {
      if (existingId != null) {
        await _api.put('/homework/$existingId', payload);
      } else {
        await _api.post('/homework', payload);
      }
      formSubmitting.value = false;
      return true;
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger, colorText: Colors.white);
      formSubmitting.value = false;
      return false;
    }
  }

  Future<void> deleteHomework(int id) async {
    try {
      await _api.delete('/homework/$id');
      homeworkList.removeWhere((h) => (h as Map)['id'] == id);
      Get.snackbar('Done', 'Homework deleted',
          backgroundColor: AppColors.secondary, colorText: Colors.white);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger, colorText: Colors.white);
    }
  }
}

// ── Homework Screen ───────────────────────────────────────────
class HomeworkScreen extends StatelessWidget {
  const HomeworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(HomeworkController());
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
        title: const Text('Homework',
            style: TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
            onPressed: () async {
              await Get.toNamed(AppRoutes.homeworkForm);
              ctrl.loadHomework(ctrl.selectedClass.value?['id'] as int?);
            },
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.classesLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: AppColors.primary));
        }
        return Column(children: [
          // Class filter
          if (ctrl.classes.isNotEmpty)
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _ClassChip(
                      label: 'All',
                      selected: ctrl.selectedClass.value == null,
                      onTap: () {
                        ctrl.selectedClass.value = null;
                        ctrl.loadHomework(null);
                      },
                    ),
                    ...ctrl.classes.map((cls) {
                      final c = Map<String, dynamic>.from(cls as Map);
                      final sel = ctrl.selectedClass.value?['id'] == c['id'];
                      return _ClassChip(
                        label: '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}',
                        selected: sel,
                        onTap: () {
                          ctrl.selectedClass.value = c;
                          ctrl.loadHomework(c['id'] as int?);
                        },
                      );
                    }),
                  ],
                ),
              ),
            ),
          // Homework list
          Expanded(
            child: ctrl.listLoading.value
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ctrl.homeworkList.isEmpty
                    ? EmptyState(
                        icon: Icons.assignment_outlined,
                        title: 'No Homework',
                        subtitle: 'Tap + to add homework',
                        action: ElevatedButton.icon(
                          onPressed: () async {
                            await Get.toNamed(AppRoutes.homeworkForm);
                            ctrl.loadHomework(
                                ctrl.selectedClass.value?['id'] as int?);
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Add Homework'),
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12))),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ctrl.loadHomework(
                            ctrl.selectedClass.value?['id'] as int?),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: ctrl.homeworkList.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final hw = Map<String, dynamic>.from(
                                ctrl.homeworkList[i] as Map);
                            return Slidable(
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      await Get.toNamed(
                                          AppRoutes.homeworkForm,
                                          arguments: hw);
                                      ctrl.loadHomework(ctrl.selectedClass
                                          .value?['id'] as int?);
                                    },
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    icon: Icons.edit_rounded,
                                    label: 'Edit',
                                    borderRadius: const BorderRadius.horizontal(
                                        left: Radius.circular(14)),
                                  ),
                                  SlidableAction(
                                    onPressed: (_) async {
                                      final ok = await _confirm(ctx);
                                      if (ok) ctrl.deleteHomework(hw['id'] as int);
                                    },
                                    backgroundColor: AppColors.danger,
                                    foregroundColor: Colors.white,
                                    icon: Icons.delete_rounded,
                                    label: 'Delete',
                                    borderRadius: const BorderRadius.horizontal(
                                        right: Radius.circular(14)),
                                  ),
                                ],
                              ),
                              child: _HomeworkCard(hw: hw),
                            );
                          },
                        ),
                      ),
          ),
        ]);
      }),
    );
  }

  Future<bool> _confirm(BuildContext ctx) async {
    return await showDialog<bool>(
          context: ctx,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Homework?',
                style:
                    TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: Colors.white),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Delete')),
            ],
          ),
        ) ??
        false;
  }
}

class _ClassChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ClassChip(
      {required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: selected ? AppColors.gradientPrimary : null,
            color: selected ? null : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: selected ? Colors.transparent : Colors.grey.shade300),
          ),
          child: Text(label,
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: selected ? Colors.white : AppColors.textPrimary)),
        ),
      );
}

class _HomeworkCard extends StatelessWidget {
  final Map<String, dynamic> hw;
  const _HomeworkCard({required this.hw});

  @override
  Widget build(BuildContext context) {
    final subject = hw['subject'] as Map? ?? {};
    final cls = hw['class'] as Map? ?? hw['class_name'];
    final clsName = cls is Map
        ? '${cls['name'] ?? ''} ${cls['section'] != null ? '- ${cls['section']}' : ''}'
        : cls?.toString() ?? '';
    final dueDate = hw['due_date'] as String? ?? '';

    return Container(
      padding: const EdgeInsets.all(16),
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
        Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                gradient: AppColors.gradientOrange,
                borderRadius: BorderRadius.circular(12)),
            child:
                const Icon(Icons.assignment_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hw['title'] as String? ?? 'Homework',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              Text(
                  '${subject['name'] ?? 'Subject'} • $clsName',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ]),
          ),
          if (dueDate.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border:
                    Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Text(dueDate,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
            ),
        ]),
        if (hw['description'] != null && (hw['description'] as String).isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(hw['description'] as String,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary)),
        ],
        const SizedBox(height: 8),
        Row(children: [
          const Icon(Icons.drag_indicator_rounded,
              size: 14, color: AppColors.textTertiary),
          const SizedBox(width: 4),
          const Text('Swipe to edit or delete',
              style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: AppColors.textTertiary)),
        ]),
      ]),
    );
  }
}

// ── Homework Form Screen ──────────────────────────────────────
class HomeworkFormScreen extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const HomeworkFormScreen({this.existing, super.key});

  @override
  State<HomeworkFormScreen> createState() => _HomeworkFormScreenState();
}

class _HomeworkFormScreenState extends State<HomeworkFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _titleCtrl = TextEditingController(
      text: widget.existing?['title'] as String? ?? '');
  late final _descCtrl = TextEditingController(
      text: widget.existing?['description'] as String? ?? '');
  late final _dueDateCtrl = TextEditingController(
      text: widget.existing?['due_date'] as String? ?? '');

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  HomeworkController get ctrl => Get.find<HomeworkController>();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final cls = widget.existing!['class'] as Map?;
      if (cls != null) _selectedClass = Map<String, dynamic>.from(cls);
      final sub = widget.existing!['subject'] as Map?;
      if (sub != null) _selectedSubject = Map<String, dynamic>.from(sub);
      if (_selectedClass != null) {
        ctrl.loadSubjects(_selectedClass!['id'] as int);
      }
    }
    if (ctrl.classes.isEmpty) ctrl.loadClasses();
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _dueDateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: AppBar(
        flexibleSpace: Container(
            decoration: const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => Get.back(),
        ),
        title: Text(isEdit ? 'Edit Homework' : 'Add Homework',
            style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontWeight: FontWeight.w700)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Class dropdown
            Obx(() => DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedClass,
                  decoration: _inputDecoration('Class'),
                  items: ctrl.classes.map((c) {
                    final cls = Map<String, dynamic>.from(c as Map);
                    return DropdownMenuItem(
                        value: cls,
                        child: Text(
                            '${cls['name'] ?? ''} ${cls['section'] != null ? '- ${cls['section']}' : ''}',
                            style:
                                const TextStyle(fontFamily: 'Inter')));
                  }).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedClass = v;
                      _selectedSubject = null;
                    });
                    if (v != null) ctrl.loadSubjects(v['id'] as int);
                  },
                  validator: (v) => v == null ? 'Select a class' : null,
                )),
            const SizedBox(height: 16),
            // Subject dropdown
            Obx(() => DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedSubject,
                  decoration: _inputDecoration('Subject'),
                  items: ctrl.subjects.map((s) {
                    final sub = Map<String, dynamic>.from(s as Map);
                    return DropdownMenuItem(
                        value: sub,
                        child: Text(sub['name'] as String? ?? '',
                            style: const TextStyle(fontFamily: 'Inter')));
                  }).toList(),
                  onChanged: (v) => setState(() => _selectedSubject = v),
                  validator: (v) => v == null ? 'Select a subject' : null,
                )),
            const SizedBox(height: 16),
            // Title
            TextFormField(
              controller: _titleCtrl,
              decoration: _inputDecoration('Homework Title'),
              style: const TextStyle(fontFamily: 'Inter'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descCtrl,
              decoration: _inputDecoration('Description (optional)'),
              style: const TextStyle(fontFamily: 'Inter'),
              maxLines: 4,
            ),
            const SizedBox(height: 16),
            // Due date
            TextFormField(
              controller: _dueDateCtrl,
              readOnly: true,
              decoration: _inputDecoration('Due Date')
                  .copyWith(suffixIcon: const Icon(Icons.calendar_today_rounded)),
              style: const TextStyle(fontFamily: 'Inter'),
              onTap: () async {
                final p = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime.now(),
                  lastDate: DateTime(2030),
                );
                if (p != null) {
                  _dueDateCtrl.text =
                      '${p.year}-${p.month.toString().padLeft(2, '0')}-${p.day.toString().padLeft(2, '0')}';
                }
              },
              validator: (v) =>
                  (v == null || v.isEmpty) ? 'Select a due date' : null,
            ),
            const SizedBox(height: 28),
            Obx(() => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: ctrl.formSubmitting.value ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: ctrl.formSubmitting.value
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(isEdit ? 'Update Homework' : 'Add Homework',
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w700,
                                fontSize: 16)),
                  ),
                )),
          ]),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label) => InputDecoration(
        labelText: label,
        labelStyle:
            const TextStyle(fontFamily: 'Inter', color: AppColors.textSecondary),
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: AppColors.primary, width: 2)),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final payload = {
      'class_id': _selectedClass!['id'],
      'subject_id': _selectedSubject!['id'],
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'due_date': _dueDateCtrl.text,
    };
    final ok = await ctrl.submitHomework(
      payload,
      existingId: widget.existing?['id'] as int?,
    );
    if (ok) Get.back();
  }
}
