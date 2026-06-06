import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/api/api_client.dart';
import '../../core/routes/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';
import '../dashboard/dashboard_screen.dart';

// ── Controller ────────────────────────────────────────────────
class HomeworkController extends GetxController {
  final _api = ApiClient.instance;

  Future<List<Map<String, dynamic>>> _getLocalHomeworks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String>? stored = prefs.getStringList('local_homeworks');
      if (stored == null) return [];
      return stored
          .map((s) => Map<String, dynamic>.from(jsonDecode(s) as Map))
          .toList();
    } catch (e) {
      debugPrint("Error reading local homeworks: $e");
      return [];
    }
  }

  Future<void> _saveLocalHomeworks(List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<String> encoded = list.map((m) => jsonEncode(m)).toList();
      await prefs.setStringList('local_homeworks', encoded);
    } catch (e) {
      debugPrint("Error saving local homeworks: $e");
    }
  }

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
    loadHomework(null);
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
    } catch (e, s) {
      debugPrint("loadClasses error: $e\n$s");
      classes.value = [];
    }
    classesLoading.value = false;
  }

  Future<void> loadSubjects(int classId) async {
    try {
      final resp =
          await _api.get('/subjects', params: {'class_id': classId.toString()});
      final raw = resp.data;
      if (raw is List) {
        subjects.value = raw;
      } else if (raw is Map) {
        subjects.value =
            List<dynamic>.from(raw['data'] ?? raw['subjects'] ?? []);
      } else {
        subjects.value = [];
      }
    } catch (e, s) {
      debugPrint("loadSubjects error: $e\n$s");
      subjects.value = [];
    }
  }

  Future<void> loadHomework(int? classId, {bool silent = false}) async {
    if (!silent) listLoading.value = true;
    try {
      final params = <String, dynamic>{'per_page': '50'};
      if (classId != null) params['class_id'] = classId.toString();
      final resp = await _api.get('/homework', params: params);
      final raw = resp.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(
            raw['data'] ?? raw['homeworks'] ?? raw['homework'] ?? []);
      }

      // Merge local homeworks
      final localHws = await _getLocalHomeworks();
      for (final localHw in localHws) {
        final localId = localHw['id'];
        list.removeWhere((item) => item['id'] == localId);
        if (classId == null || localHw['class_id'] == classId) {
          list.add(localHw);
        }
      }

      list.sort((a, b) {
        final idA = num.tryParse(a['id']?.toString() ?? '')?.toInt() ?? 0;
        final idB = num.tryParse(b['id']?.toString() ?? '')?.toInt() ?? 0;
        return idB.compareTo(idA); // Descending (newest first)
      });
      homeworkList.value = list;
    } catch (e, s) {
      debugPrint("loadHomework error: $e\n$s");
      try {
        final localHws = await _getLocalHomeworks();
        List<dynamic> list = [];
        for (final localHw in localHws) {
          if (classId == null || localHw['class_id'] == classId) {
            list.add(localHw);
          }
        }
        list.sort((a, b) {
          final idA = num.tryParse(a['id']?.toString() ?? '')?.toInt() ?? 0;
          final idB = num.tryParse(b['id']?.toString() ?? '')?.toInt() ?? 0;
          return idB.compareTo(idA);
        });
        homeworkList.value = list;
      } catch (_) {
        homeworkList.value = [];
      }
    }
    if (!silent) listLoading.value = false;
  }

  Future<bool> submitHomework(Map<String, dynamic> payload,
      {int? existingId}) async {
    formSubmitting.value = true;
    try {
      final dynamic resp;
      if (existingId != null) {
        resp = await _api.put('/homework/$existingId', payload);
      } else {
        resp = await _api.post('/homework', payload);
      }
      formSubmitting.value = false;

      // Extract homework map from response and save locally
      final rawData = resp.data;
      final homeworkData = (rawData is Map && rawData['homework'] != null)
          ? Map<String, dynamic>.from(rawData['homework'] as Map)
          : (rawData is Map ? Map<String, dynamic>.from(rawData) : null);

      if (homeworkData != null) {
        final localHws = await _getLocalHomeworks();
        if (existingId != null) {
          localHws.removeWhere((item) => item['id'] == existingId);
        }
        localHws.add(homeworkData);
        await _saveLocalHomeworks(localHws);
      }

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

      // Also delete from local storage
      final localHws = await _getLocalHomeworks();
      localHws.removeWhere((item) => item['id'] == id);
      await _saveLocalHomeworks(localHws);

      homeworkList.removeWhere((h) => (h as Map)['id'] == id);
      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().loadAll(silent: true);
      }
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
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: () => Get.back(),
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
              ctrl.loadHomework(num.tryParse(
                      ctrl.selectedClass.value?['id']?.toString() ?? '')
                  ?.toInt());
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
          if (ctrl.classes.isNotEmpty) _ClassDropdown(ctrl: ctrl),
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
                            ctrl.loadHomework(num.tryParse(ctrl
                                        .selectedClass.value?['id']
                                        ?.toString() ??
                                    '')
                                ?.toInt());
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
                        onRefresh: () => ctrl.loadHomework(num.tryParse(
                                ctrl.selectedClass.value?['id']?.toString() ??
                                    '')
                            ?.toInt()),
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: ctrl.homeworkList.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (ctx, i) {
                            final hw = Map<String, dynamic>.from(
                                ctrl.homeworkList[i] as Map);
                            return Slidable(
                              endActionPane: ActionPane(
                                motion: const DrawerMotion(),
                                children: [
                                  SlidableAction(
                                    onPressed: (_) async {
                                      await Get.toNamed(AppRoutes.homeworkForm,
                                          arguments: hw);
                                      ctrl.loadHomework(num.tryParse(ctrl
                                                  .selectedClass.value?['id']
                                                  ?.toString() ??
                                              '')
                                          ?.toInt());
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
                                      if (ok)
                                        ctrl.deleteHomework(num.tryParse(
                                                    hw['id']?.toString() ?? '')
                                                ?.toInt() ??
                                            0);
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
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Text('Delete Homework?',
                style: TextStyle(
                    fontFamily: 'Inter', fontWeight: FontWeight.w700)),
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

class _ClassDropdown extends StatelessWidget {
  final HomeworkController ctrl;
  const _ClassDropdown({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final selected = ctrl.selectedClass.value;
      final selectedLabel = selected == null
          ? 'All Classes'
          : '${selected['name'] ?? ''} ${selected['section'] != null ? '- ${selected['section']}' : ''}';

      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ],
          ),
          child: Theme(
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
              onSelected: (v) {
                if (v == 'all') {
                  ctrl.selectedClass.value = null;
                  ctrl.loadHomework(null);
                } else {
                  final c = Map<String, dynamic>.from(v as Map);
                  ctrl.selectedClass.value = c;
                  ctrl.loadHomework(
                      num.tryParse(c['id']?.toString() ?? '')?.toInt());
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem<dynamic>(
                  value: 'all',
                  child: Row(
                    children: [
                      Icon(
                        Icons.all_inclusive_rounded,
                        color: ctrl.selectedClass.value == null
                            ? AppColors.primary
                            : AppColors.textSecondary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'All Classes',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: ctrl.selectedClass.value == null
                              ? FontWeight.w700
                              : FontWeight.w500,
                          color: ctrl.selectedClass.value == null
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                ...ctrl.classes.map((cls) {
                  final c = Map<String, dynamic>.from(cls as Map);
                  final isSelected =
                      ctrl.selectedClass.value?['id']?.toString() ==
                          c['id']?.toString();
                  final label =
                      '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}';
                  return PopupMenuItem<dynamic>(
                    value: c,
                    child: Row(
                      children: [
                        Icon(
                          Icons.class_rounded,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          label,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontWeight:
                                isSelected ? FontWeight.w700 : FontWeight.w500,
                            color: isSelected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.class_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Text(
                          selectedLabel,
                          style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: AppColors.textSecondary,
                      size: 22,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    });
  }
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
            child: const Icon(Icons.assignment_rounded,
                color: Colors.white, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(hw['title'] as String? ?? 'Homework',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                      color: AppColors.textPrimary)),
              Text('${subject['name'] ?? 'Subject'} • $clsName',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ]),
          ),
          if (dueDate.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Text(dueDate,
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.warning)),
            ),
        ]),
        if (hw['description'] != null &&
            (hw['description'] as String).isNotEmpty) ...[
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
        const Row(children: [
          Icon(Icons.drag_indicator_rounded,
              size: 14, color: AppColors.textTertiary),
          SizedBox(width: 4),
          Text('Swipe to edit or delete',
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
  late final _titleCtrl =
      TextEditingController(text: widget.existing?['title'] as String? ?? '');
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
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final id =
              num.tryParse(_selectedClass!['id']?.toString() ?? '')?.toInt() ??
                  0;
          if (id != 0) {
            ctrl.loadSubjects(id);
          }
        });
      }
    }
    if (ctrl.classes.isEmpty && !ctrl.classesLoading.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ctrl.loadClasses();
      });
    }
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
            decoration:
                const BoxDecoration(gradient: AppColors.gradientPrimary)),
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
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Class dropdown
            // Class dropdown
            Obx(() {
              final selectedId = _selectedClass?['id']?.toString();
              final currentSelection = ctrl.classes.firstWhereOrNull(
                (c) => c['id']?.toString() == selectedId,
              );
              return FormField<dynamic>(
                key: ValueKey('class_$selectedId'),
                initialValue: currentSelection,
                validator: (v) => v == null ? 'Select a class' : null,
                builder: (FormFieldState<dynamic> state) {
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
                        minWidth: MediaQuery.of(context).size.width - 40,
                        maxWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      onSelected: (v) {
                        state.didChange(v);
                        setState(() {
                          _selectedClass = v;
                          _selectedSubject = null;
                        });
                        if (v != null) {
                          final id = num.tryParse(v['id']?.toString() ?? '')
                                  ?.toInt() ??
                              0;
                          if (id != 0) ctrl.loadSubjects(id);
                        }
                      },
                      itemBuilder: (ctx) => ctrl.classes.map((c) {
                        return PopupMenuItem<dynamic>(
                          value: c,
                          child: Text(
                              '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}',
                              style: const TextStyle(fontFamily: 'Inter')),
                        );
                      }).toList(),
                      child: InputDecorator(
                        decoration: _inputDecoration('Class').copyWith(
                          errorText: state.errorText,
                          suffixIcon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary),
                        ),
                        isEmpty: currentSelection == null,
                        child: currentSelection == null
                            ? null
                            : Text(
                                '${currentSelection['name'] ?? ''} ${currentSelection['section'] != null ? '- ${currentSelection['section']}' : ''}',
                                style: const TextStyle(
                                    fontFamily: 'Inter', fontSize: 14),
                              ),
                      ),
                    ),
                  );
                },
              );
            }),
            const SizedBox(height: 16),
            // Subject dropdown
            Obx(() {
              final selectedId = _selectedSubject?['id']?.toString();
              final currentSelection = ctrl.subjects.firstWhereOrNull(
                (s) => s['id']?.toString() == selectedId,
              );
              return FormField<dynamic>(
                key: ValueKey(
                    'subject_${selectedId}_class_${_selectedClass?['id']}'),
                initialValue: currentSelection,
                validator: (v) => v == null ? 'Select a subject' : null,
                builder: (FormFieldState<dynamic> state) {
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
                        minWidth: MediaQuery.of(context).size.width - 40,
                        maxWidth: MediaQuery.of(context).size.width - 40,
                      ),
                      onSelected: (v) {
                        state.didChange(v);
                        setState(() => _selectedSubject = v);
                      },
                      itemBuilder: (ctx) => ctrl.subjects.map((s) {
                        return PopupMenuItem<dynamic>(
                          value: s,
                          child: Text(
                            s['name'] as String? ?? '',
                            style: const TextStyle(fontFamily: 'Inter'),
                          ),
                        );
                      }).toList(),
                      child: InputDecorator(
                        decoration: _inputDecoration('Subject').copyWith(
                          errorText: state.errorText,
                          suffixIcon: const Icon(
                              Icons.keyboard_arrow_down_rounded,
                              color: AppColors.textSecondary),
                        ),
                        isEmpty: currentSelection == null,
                        child: currentSelection == null
                            ? null
                            : Text(
                                currentSelection['name'] as String? ?? '',
                                style: const TextStyle(
                                    fontFamily: 'Inter', fontSize: 14),
                              ),
                      ),
                    ),
                  );
                },
              );
            }),
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
              decoration: _inputDecoration('Due Date').copyWith(
                  suffixIcon: const Icon(Icons.calendar_today_rounded)),
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
        labelStyle: const TextStyle(
            fontFamily: 'Inter', color: AppColors.textSecondary),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.primary, width: 2)),
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
      existingId:
          num.tryParse(widget.existing?['id']?.toString() ?? '')?.toInt(),
    );
    if (ok) {
      // Update the active filter in HomeworkController to show the class that the homework was added/edited for
      ctrl.selectedClass.value = _selectedClass;
      final classId =
          num.tryParse(_selectedClass?['id']?.toString() ?? '')?.toInt();
      ctrl.loadHomework(classId, silent: true);

      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().loadAll(silent: true);
      }
      Get.back();
    }
  }
}
