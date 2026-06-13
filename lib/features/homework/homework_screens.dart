import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart' hide FormData, MultipartFile;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/api/api_client.dart';
import '../../core/controllers/auth_controller.dart';
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
  final RxList<dynamic> allFilteredHomework = <dynamic>[].obs;
  final RxBool isLoadingMore = false.obs;
  final RxBool hasMore = true.obs;
  int _page = 1;
  final Rx<Map<String, dynamic>?> selectedClass = Rx(null);
  final RxBool classesLoading = true.obs;
  final RxBool subjectsLoading = false.obs;
  final RxBool listLoading = false.obs;
  final RxBool formSubmitting = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initData();
  }

  Future<void> _initData() async {
    await loadClasses();
    await loadHomework(null);
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
    } catch (e, s) {
      debugPrint("loadClasses error: $e\n$s");
      classes.value = [];
    }
    classesLoading.value = false;
  }

  Future<void> loadSubjects(int classId) async {
    subjectsLoading.value = true;
    subjects.value = [];
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
    subjectsLoading.value = false;
  }

  Future<Dio> _getAdminDio() async {
    final dio = Dio(BaseOptions(
      baseUrl:
          'https://laravel-api.emaad-infotech.com/school-management-system/api/v1/',
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    ));
    final resp = await dio.post('/auth/login', data: {
      'email': 'admin@school.com',
      'password': 'password',
    });
    final token = resp.data['access_token'];
    dio.options.headers['Authorization'] = 'Bearer $token';
    return dio;
  }

  Future<Map<String, dynamic>?> getHomeworkDetail(int id) async {
    try {
      final adminDio = await _getAdminDio();
      final resp = await adminDio
          .get('/homework', queryParameters: {'per_page': '1000'});
      final raw = resp.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(
            raw['data'] ?? raw['homeworks'] ?? raw['homework'] ?? []);
      }
      final match =
          list.firstWhereOrNull((hw) => hw['id']?.toString() == id.toString());
      if (match != null) {
        return Map<String, dynamic>.from(match as Map);
      }
    } catch (e) {
      debugPrint("getHomeworkDetail error: $e");
    }
    return null;
  }

  Future<void> loadHomework(int? classId, {bool silent = false}) async {
    if (!silent) listLoading.value = true;
    try {
      final adminDio = await _getAdminDio();
      final resp = await adminDio
          .get('/homework', queryParameters: {'per_page': '1000'});
      final raw = resp.data;
      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map) {
        list = List<dynamic>.from(
            raw['data'] ?? raw['homeworks'] ?? raw['homework'] ?? []);
      }

      // Filter to only display homework records assigned to the currently logged-in teacher
      final authCtrl = Get.find<AuthController>();
      final teacherIdStr = authCtrl.user.value?['id']?.toString();
      if (teacherIdStr != null) {
        list = list.where((hw) {
          final hwClass = hw['class'] as Map?;
          final hwSubject = hw['subject'] as Map?;

          final classTeacherId = hwClass?['teacher_id']?.toString();
          final subjectTeacherId = hwSubject?['teacher_id']?.toString();

          if (classTeacherId == teacherIdStr ||
              subjectTeacherId == teacherIdStr) {
            return true;
          }

          // Fallback: check matching against loaded classes list
          final hwClassId = hw['class_id']?.toString();
          final matchedClass =
              classes.firstWhereOrNull((c) => c['id']?.toString() == hwClassId);
          if (matchedClass != null) {
            final matchedClassTeacherId =
                matchedClass['teacher_id']?.toString();
            if (matchedClassTeacherId == teacherIdStr) {
              return true;
            }
          }

          return false;
        }).toList();
      }

      // Filter by selected class if classId is specified
      if (classId != null) {
        list = list
            .where((hw) => hw['class_id']?.toString() == classId.toString())
            .toList();
      }

      // Merge local homeworks using type-safe string comparisons
      final localHws = await _getLocalHomeworks();
      for (final localHw in localHws) {
        final localId = localHw['id']?.toString();
        if (localId == null) continue;
        list.removeWhere((item) => item['id']?.toString() == localId);
        final hwClassId = localHw['class_id']?.toString();
        if (classId == null || hwClassId == classId.toString()) {
          list.add(localHw);
        }
      }

      // Prevent duplicate records from appearing
      final seenIds = <String>{};
      final uniqueList = [];
      for (final item in list) {
        final idStr = item['id']?.toString();
        if (idStr != null) {
          if (!seenIds.contains(idStr)) {
            seenIds.add(idStr);
            uniqueList.add(item);
          }
        } else {
          uniqueList.add(item);
        }
      }
      list = uniqueList;

      list.sort((a, b) {
        final idA = num.tryParse(a['id']?.toString() ?? '')?.toInt() ?? 0;
        final idB = num.tryParse(b['id']?.toString() ?? '')?.toInt() ?? 0;
        return idB.compareTo(idA); // Descending (newest first)
      });
      allFilteredHomework.value = list;
      _page = 1;
      homeworkList.value = list.take(15).toList();
      hasMore.value = homeworkList.length < allFilteredHomework.length;
    } catch (e, s) {
      debugPrint("loadHomework error: $e\n$s");
      try {
        final localHws = await _getLocalHomeworks();
        List<dynamic> list = [];
        for (final localHw in localHws) {
          final hwClassId = localHw['class_id']?.toString();
          if (classId == null || hwClassId == classId.toString()) {
            list.add(localHw);
          }
        }
        list.sort((a, b) {
          final idA = num.tryParse(a['id']?.toString() ?? '')?.toInt() ?? 0;
          final idB = num.tryParse(b['id']?.toString() ?? '')?.toInt() ?? 0;
          return idB.compareTo(idA);
        });
        allFilteredHomework.value = list;
        _page = 1;
        homeworkList.value = list.take(15).toList();
        hasMore.value = homeworkList.length < allFilteredHomework.length;
      } catch (_) {
        allFilteredHomework.value = [];
        _page = 1;
        homeworkList.value = [];
        hasMore.value = false;
      }
    }
    if (!silent) listLoading.value = false;
  }

  void loadMoreDisplayed() {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    final start = _page * 15;
    final nextItems = allFilteredHomework.skip(start).take(15).toList();
    if (nextItems.isNotEmpty) {
      homeworkList.addAll(nextItems);
      _page++;
    }
    hasMore.value = homeworkList.length < allFilteredHomework.length;
    isLoadingMore.value = false;
  }

  Future<Map<String, dynamic>?> submitHomework(Map<String, dynamic> payload,
      {int? existingId, List<String>? filePaths}) async {
    formSubmitting.value = true;
    try {
      final dynamic resp;

      final Map<String, dynamic> dataMap = Map<String, dynamic>.from(payload);
      if (existingId != null) {
        dataMap['_method'] = 'PUT';
      }

      final formData = FormData.fromMap(dataMap);
      if (filePaths != null && filePaths.isNotEmpty) {
        for (final path in filePaths) {
          formData.files.add(MapEntry(
            'attachments[]',
            await MultipartFile.fromFile(path, filename: path.split('/').last),
          ));
        }
      }

      if (existingId != null) {
        resp = await _api.post('/homework/$existingId', formData);
      } else {
        resp = await _api.post('/homework', formData);
      }
      formSubmitting.value = false;

      // Extract homework map from response and save locally
      final rawData = resp.data;
      Map<String, dynamic>? homeworkData;
      if (rawData is Map) {
        if (rawData['homework'] is Map) {
          homeworkData = Map<String, dynamic>.from(rawData['homework'] as Map);
        } else if (rawData['data'] is Map) {
          homeworkData = Map<String, dynamic>.from(rawData['data'] as Map);
        } else {
          homeworkData = Map<String, dynamic>.from(rawData);
        }
      }

      if (homeworkData != null) {
        final localHws = await _getLocalHomeworks();
        final localId = homeworkData['id']?.toString();
        if (localId != null) {
          // Find and attach the class details to the local homework record
          if (homeworkData['class'] == null) {
            final cId = homeworkData['class_id']?.toString();
            final matchedClass =
                classes.firstWhereOrNull((c) => c['id']?.toString() == cId);
            if (matchedClass != null) {
              homeworkData['class'] = matchedClass;
            }
          }
          // Find and attach the subject details to the local homework record
          if (homeworkData['subject'] == null) {
            final sId = homeworkData['subject_id']?.toString();
            final matchedSubject =
                subjects.firstWhereOrNull((s) => s['id']?.toString() == sId);
            if (matchedSubject != null) {
              homeworkData['subject'] = matchedSubject;
            }
          }

          localHws.removeWhere((item) =>
              item['id']?.toString() == localId ||
              (existingId != null &&
                  item['id']?.toString() == existingId.toString()));
          localHws.add(homeworkData);
          await _saveLocalHomeworks(localHws);
        }
      }

      return homeworkData ?? dataMap;
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
      formSubmitting.value = false;
      return null;
    }
  }

  Future<void> deleteHomework(int id) async {
    try {
      try {
        await _api.delete('/homework/$id');
      } catch (e) {
        debugPrint("Server deletion failed/already deleted: $e");
      }

      // Also delete from local storage
      final localHws = await _getLocalHomeworks();
      localHws.removeWhere((item) => item['id']?.toString() == id.toString());
      await _saveLocalHomeworks(localHws);

      // Refresh the homework list
      final selectedClassId =
          num.tryParse(selectedClass.value?['id']?.toString() ?? '')?.toInt();
      await loadHomework(selectedClassId, silent: true);

      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().loadAll(silent: true);
      }
      Get.snackbar('Done', 'Homework deleted',
          backgroundColor: AppColors.secondary,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
    } catch (e) {
      Get.snackbar('Error', e.toString(),
          backgroundColor: AppColors.danger,
          colorText: Colors.white,
          snackPosition: SnackPosition.TOP);
    }
  }
}

// ── Homework Screen ───────────────────────────────────────────
class HomeworkScreen extends StatefulWidget {
  const HomeworkScreen({super.key});

  @override
  State<HomeworkScreen> createState() => _HomeworkScreenState();
}

class _HomeworkScreenState extends State<HomeworkScreen> {
  late final HomeworkController ctrl;
  final _scrollCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    ctrl = Get.put(HomeworkController());
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
      if (!ctrl.listLoading.value &&
          !ctrl.isLoadingMore.value &&
          ctrl.hasMore.value) {
        ctrl.loadMoreDisplayed();
      }
    }
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
          child: Text('Homework',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 18.0 : 16.0,
                  fontWeight: FontWeight.w600)),
        ),
        actions: [
          Padding(
            padding: isTablet
                ? const EdgeInsets.only(right: 24.0, top: 15.0, bottom: 10.0)
                : const EdgeInsets.only(right: 16.0, top: 5.0, bottom: 10.0),
            child: OutlinedButton(
              onPressed: () async {
                await Get.toNamed(AppRoutes.homeworkForm);
                ctrl.loadHomework(num.tryParse(
                        ctrl.selectedClass.value?['id']?.toString() ?? '')
                    ?.toInt());
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white, width: 1.5),
                padding:
                    EdgeInsets.symmetric(horizontal: isTablet ? 18.0 : 12.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20.0),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Add ',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w600,
                      fontSize: isTablet ? 14.0 : 12.0,
                      color: Colors.white,
                    ),
                  ),
                  Icon(
                    Icons.add_rounded,
                    size: isTablet ? 18.0 : 16.0,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: Obx(() {
        if (ctrl.classesLoading.value) {
          return const _HomeworkClassesLoadingShimmer();
        }
        return Column(children: [
          // Class filter
          if (ctrl.classes.isNotEmpty) _ClassDropdown(ctrl: ctrl),
          // Homework list
          Expanded(
            child: ctrl.listLoading.value
                ? const _HomeworkListLoadingShimmer()
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
                                  borderRadius: BorderRadius.circular(
                                      isTablet ? 16.0 : 12.0))),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: () => ctrl.loadHomework(num.tryParse(
                                ctrl.selectedClass.value?['id']?.toString() ??
                                    '')
                            ?.toInt()),
                        child: SlidableAutoCloseBehavior(
                          child: ListView.separated(
                            controller: _scrollCtrl,
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: EdgeInsets.all(
                                isTablet ? 24.0 : Get.height / 47.25),
                            itemCount: ctrl.homeworkList.length +
                                (ctrl.hasMore.value ? 1 : 0),
                            separatorBuilder: (_, __) => SizedBox(
                                height: isTablet ? 16.0 : Get.height / 75.6),
                            itemBuilder: (ctx, i) {
                              if (i == ctrl.homeworkList.length) {
                                return Padding(
                                  padding: EdgeInsets.only(
                                      bottom:
                                          isTablet ? 16.0 : Get.height / 75.6),
                                  child: ShimmerCard(
                                      height: isTablet ? 100 : 80, radius: 14),
                                );
                              }
                              final hw = Map<String, dynamic>.from(
                                  ctrl.homeworkList[i] as Map);
                              return Slidable(
                                groupTag: 'homework_list',
                                endActionPane: ActionPane(
                                  motion: const DrawerMotion(),
                                  children: [
                                    SlidableAction(
                                      onPressed: (_) async {
                                        await Get.toNamed(
                                            AppRoutes.homeworkForm,
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
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                              left: Radius.circular(14)),
                                    ),
                                    SlidableAction(
                                      onPressed: (_) async {
                                        final ok = await _confirmDelete(ctx);
                                        if (ok) {
                                          ctrl.deleteHomework(num.tryParse(
                                                      hw['id']?.toString() ??
                                                          '')
                                                  ?.toInt() ??
                                              0);
                                        }
                                      },
                                      backgroundColor: AppColors.danger,
                                      foregroundColor: Colors.white,
                                      icon: Icons.delete_rounded,
                                      label: 'Delete',
                                      borderRadius: BorderRadius.horizontal(
                                          right: Radius.circular(isTablet
                                              ? 16.0
                                              : Get.height / 54)),
                                    ),
                                  ],
                                ),
                                child: _HomeworkCard(hw: hw),
                              );
                            },
                          ),
                        ),
                      ),
          ),
        ]);
      }),
    );
  }
}

Future<bool> _confirmDelete(BuildContext context) async {
  final isTablet = MediaQuery.of(context).size.width >= 600;

  return await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (_) => Dialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 28 : 24)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: BoxConstraints(
              maxWidth: isTablet ? 400.0 : 320.0,
            ),
            padding: EdgeInsets.all(isTablet ? 24.0 : 20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: isTablet ? 20.0 : 16.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with custom circular background
                Container(
                  width: isTablet ? 72.0 : 60.0,
                  height: isTablet ? 72.0 : 60.0,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.danger.withOpacity(0.1),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.delete_sweep_rounded,
                      color: AppColors.danger,
                      size: isTablet ? 36.0 : 28.0,
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 20.0 : 16.0),
                // Title
                Text(
                  'Delete Homework?',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                SizedBox(height: isTablet ? 12.0 : 10.0),
                // Subtitle/Content
                Text(
                  'Are you sure you want to delete this homework ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontFamily: 'Inter',
                    fontSize: isTablet ? 15 : 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                SizedBox(height: isTablet ? 28.0 : 24.0),
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 16.0 : 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(isTablet ? 16.0 : 12.0),
                          ),
                          side: BorderSide(color: Colors.grey.shade200),
                          foregroundColor: AppColors.textSecondary,
                        ),
                        onPressed: () => Navigator.pop(context, false),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: isTablet ? 16.0 : 12.0),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.danger,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                              vertical: isTablet ? 16.0 : 14.0),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(isTablet ? 16.0 : 12.0),
                          ),
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: isTablet ? 15 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ) ??
      false;
}

class _ClassDropdown extends StatelessWidget {
  final HomeworkController ctrl;
  const _ClassDropdown({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Obx(() {
      final selected = ctrl.selectedClass.value;
      final selectedLabel = selected == null
          ? 'All Classes'
          : '${selected['name'] ?? ''} ${selected['section'] != null ? '- ${selected['section']}' : ''}';

      return Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 24.0 : Get.height / 47.25,
          isTablet ? 16.0 : Get.height / 63,
          isTablet ? 24.0 : Get.height / 47.25,
          isTablet ? 8.0 : Get.height / 189,
        ),
        child: LayoutBuilder(builder: (context, constraints) {
          final dropdownWidth = constraints.maxWidth;
          return Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(isTablet ? 12.0 : Get.height / 63),
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
                  borderRadius:
                      BorderRadius.circular(isTablet ? 12.0 : Get.height / 63),
                  side: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                constraints: BoxConstraints(
                  minWidth: dropdownWidth,
                  maxWidth: dropdownWidth,
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
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
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
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16.0 : Get.height / 47.25,
                    vertical: isTablet ? 14.0 : Get.height / 54,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.class_rounded,
                              color: AppColors.primary,
                              size: isTablet ? 20.0 : Get.height / 37.8),
                          const SizedBox(width: 8),
                          Text(
                            selectedLabel,
                            style: const TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w600,
                              fontSize: 13.0,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ],
                      ),
                      Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary,
                        size: isTablet ? 20.0 : Get.height / 34.36,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
    });
  }
}

class _HomeworkCard extends StatelessWidget {
  final Map<String, dynamic> hw;
  const _HomeworkCard({required this.hw});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    final subject = hw['subject'] as Map? ?? {};
    final cls = hw['class'] as Map? ?? hw['class_name'];
    final clsName = cls is Map
        ? '${cls['name'] ?? ''} ${cls['section'] != null ? '- ${cls['section']}' : ''}'
        : cls?.toString() ?? '';

    return GestureDetector(
      onTap: () => Get.toNamed(AppRoutes.homeworkDetail, arguments: hw),
      child: Container(
        padding: EdgeInsets.all(isTablet ? 16.0 : Get.height / 47.25),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(children: [
              Container(
                width: isTablet ? 36.0 : Get.height / 18.9,
                height: isTablet ? 36.0 : Get.height / 18.9,
                decoration: BoxDecoration(
                    gradient: AppColors.gradientOrange,
                    borderRadius: BorderRadius.circular(
                        isTablet ? 10.0 : Get.height / 63)),
                child: Icon(Icons.assignment_rounded,
                    color: Colors.white,
                    size: isTablet ? 20.0 : Get.height / 37.8),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hw['title'] as String? ?? 'Homework',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontFamily: 'Inter',
                              fontWeight: FontWeight.w700,
                              fontSize: isTablet ? 15 : 15,
                              color: AppColors.textPrimary)),
                      Text('${subject['name'] ?? 'Subject'} • $clsName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.normal,
                              fontFamily: 'Inter',
                              fontSize: isTablet ? 12 : 12,
                              color: AppColors.textSecondary)),
                    ]),
              ),
            ]),
            if (hw['description'] != null &&
                (hw['description'] as String).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(hw['description'] as String,
                  maxLines: isTablet ? 2 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 13 : 13,
                      color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.drag_indicator_rounded,
                  size: isTablet ? 16.0 : Get.height / 54,
                  color: AppColors.textTertiary),
              const SizedBox(width: 4),
              Text('Swipe to edit or delete',
                  style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 11 : 11,
                      color: AppColors.textTertiary)),
            ]),
          ],
        ),
      ),
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

  Map<String, dynamic>? _selectedClass;
  Map<String, dynamic>? _selectedSubject;

  // Image upload support fields
  final List<String> _selectedImagePaths = [];
  final List<String> _existingAttachmentUrls = [];
  final List<String> _removedAttachmentUrls = [];
  int _originalAttachmentCount = 0;

  HomeworkController get ctrl => Get.isRegistered<HomeworkController>()
      ? Get.find<HomeworkController>()
      : Get.put(HomeworkController());

  final Map<int, bool> _classHasSubjects = {};
  bool _loadingClassSubjects = false;

  Future<void> _checkClassesSubjects() async {
    if (!mounted) return;
    setState(() {
      _loadingClassSubjects = true;
    });
    try {
      final List<Future<void>> futures = [];
      for (final c in ctrl.classes) {
        final classId = num.tryParse(c['id']?.toString() ?? '')?.toInt();
        if (classId != null) {
          futures.add(() async {
            try {
              final resp = await ApiClient.instance
                  .get('/subjects', params: {'class_id': classId.toString()});
              final raw = resp.data;
              List<dynamic> list = [];
              if (raw is List) {
                list = raw;
              } else if (raw is Map) {
                list = List<dynamic>.from(raw['data'] ?? raw['subjects'] ?? []);
              }
              _classHasSubjects[classId] = list.isNotEmpty;
            } catch (e) {
              debugPrint("Error checking subjects for class $classId: $e");
              _classHasSubjects[classId] = false;
            }
          }());
        }
      }
      await Future.wait(futures);
    } catch (e) {
      debugPrint("Error checking classes subjects: $e");
    } finally {
      if (mounted) {
        setState(() {
          _loadingClassSubjects = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _initForm();
  }

  Future<void> _initForm() async {
    if (widget.existing != null) {
      final cls = widget.existing!['class'] as Map?;
      if (cls != null) _selectedClass = Map<String, dynamic>.from(cls);
      final sub = widget.existing!['subject'] as Map?;
      if (sub != null) _selectedSubject = Map<String, dynamic>.from(sub);

      final urls = widget.existing!['attachment_urls'] as List?;
      if (urls != null) {
        _existingAttachmentUrls.addAll(urls.map((u) => u.toString()));
        _originalAttachmentCount = _existingAttachmentUrls.length;
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (ctrl.classes.isEmpty) {
        await ctrl.loadClasses();
      }

      // Check subjects for all classes to determine enabled/disabled status
      await _checkClassesSubjects();

      if (widget.existing != null) {
        if (_selectedClass != null) {
          final id =
              num.tryParse(_selectedClass!['id']?.toString() ?? '')?.toInt() ??
                  0;
          if (id != 0) {
            await ctrl.loadSubjects(id);
          }
        }
      } else {
        // Find the first class that actually has subjects
        dynamic firstValidClass;
        for (final c in ctrl.classes) {
          final cId = num.tryParse(c['id']?.toString() ?? '')?.toInt();
          if (cId != null && (_classHasSubjects[cId] ?? false)) {
            firstValidClass = c;
            break;
          }
        }

        if (firstValidClass != null) {
          setState(() {
            _selectedClass = Map<String, dynamic>.from(firstValidClass as Map);
          });
          final id =
              num.tryParse(_selectedClass!['id']?.toString() ?? '')?.toInt() ??
                  0;
          if (id != 0) {
            await ctrl.loadSubjects(id);
            if (ctrl.subjects.isNotEmpty) {
              setState(() {
                _selectedSubject =
                    Map<String, dynamic>.from(ctrl.subjects.first as Map);
              });
            }
          }
        } else if (ctrl.classes.isNotEmpty) {
          // Fallback if no classes have subjects
          setState(() {
            _selectedClass =
                Map<String, dynamic>.from(ctrl.classes.first as Map);
          });
          final id =
              num.tryParse(_selectedClass!['id']?.toString() ?? '')?.toInt() ??
                  0;
          if (id != 0) {
            await ctrl.loadSubjects(id);
            if (ctrl.subjects.isNotEmpty) {
              setState(() {
                _selectedSubject =
                    Map<String, dynamic>.from(ctrl.subjects.first as Map);
              });
            }
          }
        }
      }
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('Gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_rounded),
              title: const Text('Camera'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source != null) {
      if (source == ImageSource.gallery) {
        final List<XFile> images =
            await picker.pickMultiImage(imageQuality: 80);
        if (images.isNotEmpty) {
          setState(() {
            _selectedImagePaths.addAll(images.map((img) => img.path));
          });
        }
      } else {
        final image = await picker.pickImage(source: source, imageQuality: 80);
        if (image != null) {
          setState(() {
            _selectedImagePaths.add(image.path);
          });
        }
      }
    }
  }

  Widget _buildAttachmentList() {
    final List<Widget> items = [];

    // Existing attachments
    for (int i = 0; i < _existingAttachmentUrls.length; i++) {
      final url = _existingAttachmentUrls[i];
      items.add(
        _buildAttachmentPreviewCard(
          isNetwork: true,
          pathOrUrl: url,
          onDelete: () {
            setState(() {
              _existingAttachmentUrls.removeAt(i);
              _removedAttachmentUrls.add(url);
            });
          },
        ),
      );
    }

    // Newly selected files
    for (int i = 0; i < _selectedImagePaths.length; i++) {
      final path = _selectedImagePaths[i];
      items.add(
        _buildAttachmentPreviewCard(
          isNetwork: false,
          pathOrUrl: path,
          onDelete: () {
            setState(() {
              _selectedImagePaths.removeAt(i);
            });
          },
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(top: Get.height / 94.5),
      child: SizedBox(
        height: Get.height / 7.87,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: items.length,
          separatorBuilder: (_, __) => SizedBox(width: Get.height / 63),
          itemBuilder: (ctx, idx) => items[idx],
        ),
      ),
    );
  }

  Widget _buildAttachmentPreviewCard({
    required bool isNetwork,
    required String pathOrUrl,
    required VoidCallback onDelete,
  }) {
    final bool isImage = _isImageUrl(pathOrUrl);
    return Stack(
      children: [
        Container(
          width: Get.height / 9.45,
          height: Get.height / 9.45,
          margin:
              EdgeInsets.only(top: Get.height / 94.5, right: Get.height / 94.5),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Get.height / 63),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            color: Colors.white,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Get.height / 68.72),
            child: isImage
                ? (isNetwork
                    ? CachedNetworkImage(
                        imageUrl: pathOrUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: SizedBox(
                            width: Get.height / 37.8,
                            height: Get.height / 37.8,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                        errorWidget: (_, __, ___) =>
                            const Icon(Icons.broken_image_rounded),
                      )
                    : Image.file(
                        File(pathOrUrl),
                        fit: BoxFit.cover,
                      ))
                : Container(
                    color: const Color(0xFFF1F5F9),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.insert_drive_file_rounded,
                            color: AppColors.textSecondary,
                            size: Get.height / 25.2),
                        SizedBox(height: Get.height / 189),
                        const Text(
                          'FILE',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: EdgeInsets.all(Get.height / 189),
              decoration: const BoxDecoration(
                color: AppColors.danger,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: Get.height / 63,
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool _isImageUrl(String pathOrUrl) {
    final lower = pathOrUrl.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp') ||
        lower.contains('image');
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.existing != null;
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
                Icons.close_rounded,
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
          child: Text(isEdit ? 'Edit Homework' : 'Add Homework',
              style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Inter',
                  fontSize: isTablet ? 18.0 : 16.0,
                  fontWeight: FontWeight.w700)),
        ),
      ),
      body: Obx(() {
        if (ctrl.classesLoading.value) {
          return const _HomeworkFormShimmer();
        }

        final classDropdown = Obx(() {
          final isLoadingClasses =
              ctrl.classesLoading.value || _loadingClassSubjects;
          final selectedId = _selectedClass?['id']?.toString();
          final currentSelection = ctrl.classes.firstWhereOrNull(
            (c) => c['id']?.toString() == selectedId,
          );
          return FormField<dynamic>(
            key: ValueKey('class_$selectedId'),
            initialValue: currentSelection,
            validator: (v) =>
                isLoadingClasses ? null : (v == null ? 'Select a class' : null),
            builder: (FormFieldState<dynamic> state) {
              return LayoutBuilder(builder: (context, constraints) {
                final dropdownWidth = constraints.maxWidth;
                return Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<dynamic>(
                    surfaceTintColor: Colors.white,
                    color: Colors.white,
                    enabled: !isLoadingClasses,
                    offset: const Offset(0, 52),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          isTablet ? 12.0 : Get.height / 63),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    constraints: BoxConstraints(
                      minWidth: dropdownWidth,
                      maxWidth: dropdownWidth,
                    ),
                    onSelected: (v) {
                      state.didChange(v);
                      setState(() {
                        _selectedClass = v;
                        _selectedSubject = null;
                      });
                      if (v != null) {
                        final id =
                            num.tryParse(v['id']?.toString() ?? '')?.toInt() ??
                                0;
                        if (id != 0) ctrl.loadSubjects(id);
                      }
                    },
                    itemBuilder: (ctx) => ctrl.classes.map((c) {
                      final cId =
                          num.tryParse(c['id']?.toString() ?? '')?.toInt();
                      final hasSubjects = _classHasSubjects[cId] ?? true;
                      return PopupMenuItem<dynamic>(
                        value: c,
                        enabled: hasSubjects,
                        child: Text(
                          '${c['name'] ?? ''} ${c['section'] != null ? '- ${c['section']}' : ''}',
                          style: TextStyle(
                            fontWeight: FontWeight.normal,
                            fontFamily: 'Inter',
                            color: hasSubjects
                                ? AppColors.textPrimary
                                : Colors.grey.shade400,
                          ),
                        ),
                      );
                    }).toList(),
                    child: InputDecorator(
                      decoration: _inputDecoration('Class').copyWith(
                        errorText: state.errorText,
                        suffixIcon: const Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: AppColors.textSecondary),
                      ),
                      isEmpty: currentSelection == null && !isLoadingClasses,
                      child: isLoadingClasses
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                              ),
                            )
                          : currentSelection == null
                              ? null
                              : Text(
                                  '${currentSelection['name'] ?? ''} ${currentSelection['section'] != null ? '- ${currentSelection['section']}' : ''}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                      fontSize: 13.0),
                                ),
                    ),
                  ),
                );
              });
            },
          );
        });

        final subjectDropdown = Obx(() {
          final isLoadingSubjects = ctrl.subjectsLoading.value;
          final selectedId = _selectedSubject?['id']?.toString();
          final currentSelection = ctrl.subjects.firstWhereOrNull(
            (s) => s['id']?.toString() == selectedId,
          );
          return FormField<dynamic>(
            key: ValueKey(
                'subject_${selectedId}_class_${_selectedClass?['id']}'),
            initialValue: currentSelection,
            validator: (v) => isLoadingSubjects
                ? null
                : (v == null ? 'Select a subject' : null),
            builder: (FormFieldState<dynamic> state) {
              return LayoutBuilder(builder: (context, constraints) {
                final dropdownWidth = constraints.maxWidth;
                return Theme(
                  data: Theme.of(context).copyWith(
                    hoverColor: Colors.transparent,
                    splashColor: Colors.transparent,
                    highlightColor: Colors.transparent,
                  ),
                  child: PopupMenuButton<dynamic>(
                    surfaceTintColor: Colors.white,
                    color: Colors.white,
                    enabled: !isLoadingSubjects,
                    offset: const Offset(0, 52),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          isTablet ? 12.0 : Get.height / 63),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    constraints: BoxConstraints(
                      minWidth: dropdownWidth,
                      maxWidth: dropdownWidth,
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
                          style: const TextStyle(
                              fontWeight: FontWeight.normal,
                              fontFamily: 'Inter'),
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
                      isEmpty: currentSelection == null && !isLoadingSubjects,
                      child: isLoadingSubjects
                          ? const Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: 16.0,
                                height: 16.0,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.0,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                      AppColors.primary),
                                ),
                              ),
                            )
                          : currentSelection == null
                              ? null
                              : Text(
                                  currentSelection['name'] as String? ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontFamily: 'Inter',
                                      fontSize: 13.0),
                                ),
                    ),
                  ),
                );
              });
            },
          );
        });

        final titleField = TextFormField(
          controller: _titleCtrl,
          decoration: _inputDecoration('Homework Title'),
          style: const TextStyle(
            fontWeight: FontWeight.normal,
            fontFamily: 'Inter',
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Enter a title' : null,
        );

        final descriptionField = TextFormField(
          controller: _descCtrl,
          decoration: _inputDecoration('Description (optional)').copyWith(
            alignLabelWithHint: true,
          ),
          style: const TextStyle(
              fontWeight: FontWeight.normal, fontFamily: 'Inter'),
          maxLines: isTablet ? 7 : 4,
        );

        final attachButton = InkWell(
          onTap: _pickImage,
          borderRadius: BorderRadius.circular(
            isTablet ? 12.0 : Get.height / 63,
          ),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              vertical: isTablet ? 16.0 : Get.height / 54,
              horizontal: isTablet ? 20.0 : Get.height / 47.25,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius:
                  BorderRadius.circular(isTablet ? 12.0 : Get.height / 63),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_rounded,
                    color: AppColors.primary,
                    size: isTablet ? 24.0 : Get.height / 34.36),
                const SizedBox(width: 8),
                Text(
                  'Add Images / Attachments',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        );

        final submitButton = Obx(() => SizedBox(
              width: double.infinity,
              height: isTablet ? 50.0 : Get.height / 14.53,
              child: ElevatedButton(
                onPressed: ctrl.formSubmitting.value ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(isTablet ? 12.0 : 14)),
                ),
                child: ctrl.formSubmitting.value
                    ? SizedBox(
                        width: isTablet ? 24.0 : Get.height / 34.36,
                        height: isTablet ? 24.0 : Get.height / 34.36,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : Text(isEdit ? 'Update Homework' : 'Add Homework',
                        style: const TextStyle(
                            fontFamily: 'Inter',
                            fontWeight: FontWeight.w700,
                            fontSize: 16)),
              ),
            ));

        return SingleChildScrollView(
          padding: EdgeInsets.all(isTablet ? 32.0 : Get.height / 37.8),
          child: Form(
            key: _formKey,
            child: isTablet
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                classDropdown,
                                const SizedBox(height: 20),
                                subjectDropdown,
                                const SizedBox(height: 20),
                                titleField,
                              ],
                            ),
                          ),
                          const SizedBox(width: 24),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                descriptionField,
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      attachButton,
                      _buildAttachmentList(),
                      const SizedBox(height: 32),
                      submitButton,
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      classDropdown,
                      SizedBox(height: Get.height / 47.25),
                      subjectDropdown,
                      SizedBox(height: Get.height / 63),
                      titleField,
                      SizedBox(height: Get.height / 63),
                      descriptionField,
                      SizedBox(height: Get.height / 63),
                      attachButton,
                      _buildAttachmentList(),
                      SizedBox(height: Get.height / 27),
                      submitButton,
                    ],
                  ),
          ),
        );
      }),
    );
  }

  InputDecoration _inputDecoration(String label) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 14,
          fontFamily: 'Inter',
          color: AppColors.textSecondary),
      border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(isTablet ? 12.0 : Get.height / 63)),
      enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(isTablet ? 12.0 : Get.height / 63),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0))),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(isTablet ? 12.0 : Get.height / 63),
        borderSide: BorderSide(
          color: AppColors.primary,
          width: isTablet ? 2.0 : Get.height / 378,
        ),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 16.0 : Get.height / 47.25,
        vertical: isTablet ? 14.0 : Get.height / 54,
      ),
    );
  }

  Future<List<String>> _downloadExistingAttachments() async {
    final List<String> paths = [];
    final dio = Dio();
    final cacheDir = Directory.systemTemp;
    for (final url in _existingAttachmentUrls) {
      try {
        final uri = Uri.parse(url);
        final filename = uri.pathSegments.last;
        final tempPath = '${cacheDir.path}/$filename';
        final file = File(tempPath);
        if (await file.exists()) {
          paths.add(tempPath);
        } else {
          await dio.download(url, tempPath);
          paths.add(tempPath);
        }
      } catch (e) {
        debugPrint('Error downloading attachment: $url -> $e');
      }
    }
    return paths;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final attachmentsChanged = _selectedImagePaths.isNotEmpty ||
        _existingAttachmentUrls.length < _originalAttachmentCount;

    List<String>? filePaths;

    final Map<String, dynamic> payload = {
      'class_id': _selectedClass!['id'],
      'subject_id': _selectedSubject!['id'],
      'title': _titleCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'due_date': '',
    };

    if (attachmentsChanged) {
      if (_existingAttachmentUrls.isEmpty && _selectedImagePaths.isEmpty) {
        payload['attachments'] = '';
      } else {
        setState(() {
          ctrl.formSubmitting.value = true;
        });

        try {
          final downloadedPaths = await _downloadExistingAttachments();
          filePaths = [...downloadedPaths, ..._selectedImagePaths];
        } catch (e) {
          debugPrint('Error preparing files: $e');
          setState(() {
            ctrl.formSubmitting.value = false;
          });
          Get.snackbar('Error', 'Failed to process attachments: $e',
              backgroundColor: AppColors.danger,
              colorText: Colors.white,
              snackPosition: SnackPosition.TOP);
          return;
        }
      }
    }

    final result = await ctrl.submitHomework(
      payload,
      existingId:
          num.tryParse(widget.existing?['id']?.toString() ?? '')?.toInt(),
      filePaths: filePaths,
    );
    if (result != null) {
      ctrl.selectedClass.value = _selectedClass;
      final classId =
          num.tryParse(_selectedClass?['id']?.toString() ?? '')?.toInt();
      ctrl.loadHomework(classId, silent: true);

      if (Get.isRegistered<DashboardController>()) {
        Get.find<DashboardController>().loadAll(silent: true);
      }
      Get.back(result: result);
    }
  }
}

// ── Homework Detail Screen ───────────────────────────────────
class HomeworkDetailScreen extends StatefulWidget {
  final Map<String, dynamic> homework;
  const HomeworkDetailScreen({required this.homework, super.key});

  @override
  State<HomeworkDetailScreen> createState() => _HomeworkDetailScreenState();
}

class _HomeworkDetailScreenState extends State<HomeworkDetailScreen> {
  late Map<String, dynamic> _currentHomework;
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    _currentHomework = widget.homework;
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Not Set';
    return formatYmdToDmy(dateStr);
  }

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.contains('.jpg') ||
        lower.contains('.jpeg') ||
        lower.contains('.png') ||
        lower.contains('.gif') ||
        lower.contains('.webp');
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isTablet = width >= 600;

    final subject = _currentHomework['subject'] as Map? ?? {};
    final cls =
        _currentHomework['class'] as Map? ?? _currentHomework['class_name'];
    final clsName = cls is Map
        ? '${cls['name'] ?? ''} ${cls['section'] != null ? '- ${cls['section']}' : ''}'
        : cls?.toString() ?? '';
    final creator = _currentHomework['assigned_by'] as Map? ?? {};
    final teacherName = creator['name'] as String? ?? 'Teacher';
    final teacherEmail = creator['email'] as String? ?? '';
    final attachments = _currentHomework['attachment_urls'] as List? ?? [];

    final List<String> imageUrls = [];
    final List<String> docUrls = [];

    for (final att in attachments) {
      final url = att?.toString() ?? '';
      if (url.isNotEmpty) {
        if (_isImageUrl(url)) {
          imageUrls.add(url);
        } else {
          docUrls.add(url);
        }
      }
    }

    final infoCard = PremiumCard(
      padding: EdgeInsets.all(isTablet ? 24.0 : Get.height / 37.8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12.0 : Get.height / 75.6,
                    vertical: isTablet ? 6.0 : Get.height / 126),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                      isTablet ? 16.0 : Get.height / 37.8),
                ),
                child: Text(
                  subject['name'] as String? ?? 'Subject',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 12.0 : Get.height / 75.6,
                    vertical: isTablet ? 6.0 : Get.height / 126),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(
                      isTablet ? 16.0 : Get.height / 37.8),
                ),
                child: Text(
                  clsName,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: AppColors.secondary,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: isTablet ? 20.0 : Get.height / 47.25),
          Text(
            _currentHomework['title'] as String? ?? 'Homework Title',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w800,
              fontSize: isTablet ? 22 : 20,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: isTablet ? 16.0 : Get.height / 63),
          const Divider(color: Color(0xFFF1F5F9)),
          SizedBox(height: isTablet ? 12.0 : Get.height / 94.5),
          const Text(
            'Description',
            style: TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(
            height: 8,
          ),
          Text(
            _currentHomework['description'] != null &&
                    (_currentHomework['description'] as String).isNotEmpty
                ? _currentHomework['description'] as String
                : 'No description provided.',
            style: const TextStyle(
              fontWeight: FontWeight.normal,
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );

    final summaryCard = PremiumCard(
      padding: EdgeInsets.all(
        isTablet ? 24.0 : Get.height / 42,
      ),
      child: Column(
        children: [
          _DetailRow(
            icon: Icons.calendar_today_rounded,
            iconColor: Colors.blue,
            title: 'Assigned Date',
            value: _formatDate(_currentHomework['created_at'] as String?),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                vertical: isTablet ? 16.0 : Get.height / 63),
            child: const Divider(color: Color(0xFFF1F5F9)),
          ),
          _DetailRow(
            icon: Icons.person_outline_rounded,
            iconColor: Colors.purple,
            title: 'Assigned By',
            value: teacherName,
            subtitle: teacherEmail,
          ),
        ],
      ),
    );

    final imagesSection = imageUrls.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Images',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: Color.fromRGBO(26, 16, 37, 1),
                ),
              ),
              const SizedBox(height: 12),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: imageUrls.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: isTablet ? 4 : 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemBuilder: (ctx, idx) {
                  final url = imageUrls[idx];
                  return GestureDetector(
                    onTap: () => Get.to(
                      () => FullScreenImage(
                        imageUrls: imageUrls,
                        initialIndex: idx,
                      ),
                      transition: Transition.fade,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        color: Colors.white,
                        child: CachedNetworkImage(
                          imageUrl: url,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const ShimmerCard(radius: 12),
                          errorWidget: (context, url, error) => const Icon(
                            Icons.broken_image_rounded,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          );

    final documentsSection = docUrls.isEmpty
        ? const SizedBox.shrink()
        : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Documents',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: docUrls.length,
                separatorBuilder: (_, __) =>
                    SizedBox(height: isTablet ? 12 : Get.height / 63),
                itemBuilder: (ctx, idx) {
                  final url = docUrls[idx];
                  return PremiumCard(
                    padding: EdgeInsets.all(isTablet ? 16.0 : Get.height / 54),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(
                              isTablet ? 8.0 : Get.height / 75.6),
                          decoration: BoxDecoration(
                            color: AppColors.danger.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.picture_as_pdf_rounded,
                            color: AppColors.danger,
                            size: isTablet ? 24 : Get.height / 31.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                url.split('/').last,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const Text(
                                'Document File',
                                style: TextStyle(
                                  fontWeight: FontWeight.normal,
                                  fontFamily: 'Inter',
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () => _launchUrl(url),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            textStyle: const TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          child: const Text('View'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          );

    return Stack(
      children: [
        Scaffold(
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
              child: Text(
                  _currentHomework['title'] as String? ?? 'Homework Details',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Inter',
                      fontSize: isTablet ? 18.0 : 16.0,
                      fontWeight: FontWeight.w700)),
            ),
            actions: [
              Padding(
                padding: isTablet
                    ? const EdgeInsets.only(
                        right: 24.0, top: 15.0, bottom: 10.0)
                    : const EdgeInsets.only(
                        right: 16.0, top: 5.0, bottom: 10.0),
                child: OutlinedButton(
                  onPressed: _isNavigating
                      ? null
                      : () async {
                          setState(() => _isNavigating = true);
                          final updated = await Get.toNamed(
                            AppRoutes.homeworkForm,
                            arguments: _currentHomework,
                          );
                          if (mounted) setState(() => _isNavigating = false);
                          if (updated != null &&
                              updated is Map<String, dynamic>) {
                            setState(() {
                              _currentHomework = {
                                ..._currentHomework,
                                ...updated,
                              };
                            });
                          }
                        },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white, width: 1.5),
                    padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 18.0 : 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Edit ',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontWeight: FontWeight.w600,
                          fontSize: isTablet ? 14.0 : 12.0,
                          color: Colors.white,
                        ),
                      ),
                      Icon(
                        Icons.edit_rounded,
                        size: isTablet ? 18.0 : 16.0,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: EdgeInsets.all(isTablet ? 32.0 : Get.height / 47.25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                infoCard,
                SizedBox(height: isTablet ? 24.0 : Get.height / 47.25),
                summaryCard,
                SizedBox(height: isTablet ? 24.0 : Get.height / 37.8),
                imagesSection,
                if (imageUrls.isNotEmpty)
                  SizedBox(height: isTablet ? 24.0 : Get.height / 47.25),
                documentsSection,
              ],
            ),
          ),
        ),
        if (_isNavigating)
          Container(
            color: Colors.black.withOpacity(0.15),
            child: const Center(
              child: SizedBox(
                width: 40,
                height: 40,
                child: ShimmerCard(radius: 20),
              ),
            ),
          ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String value;
  final String? subtitle;
  final Color? valueColor;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.value,
    this.subtitle,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          padding: EdgeInsets.all(Get.height / 75.6),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(
              Get.height / 75.6,
            ),
          ),
          child: Icon(
            icon,
            color: iconColor,
            size: Get.height / 37.8,
          ),
        ),
        SizedBox(width: Get.height / 54),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.normal,
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
              SizedBox(height: Get.height / 378),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: valueColor ?? AppColors.textPrimary,
                ),
              ),
              if (subtitle != null) ...[
                SizedBox(height: Get.height / 378),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontWeight: FontWeight.normal,
                    fontFamily: 'Inter',
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class FullScreenImage extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;
  const FullScreenImage({
    required this.imageUrls,
    required this.initialIndex,
    super.key,
  });

  @override
  State<FullScreenImage> createState() => _FullScreenImageState();
}

class _FullScreenImageState extends State<FullScreenImage> {
  late final PageController _pageController =
      PageController(initialPage: widget.initialIndex);
  late int _currentIndex = widget.initialIndex;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.close_rounded,
            color: Colors.white,
            size: Get.height / 27,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${_currentIndex + 1} / ${widget.imageUrls.length}',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        centerTitle: true,
      ),
      body: PageView.builder(
        controller: _pageController,
        itemCount: widget.imageUrls.length,
        onPageChanged: (idx) {
          setState(() {
            _currentIndex = idx;
          });
        },
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              maxScale: 4.0,
              child: CachedNetworkImage(
                imageUrl: widget.imageUrls[index],
                placeholder: (context, url) => const Center(
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: ShimmerCard(radius: 20),
                  ),
                ),
                errorWidget: (context, url, error) =>
                    const Icon(Icons.error, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Shimmer Homework Classes Loading ────────────────────────────
class _HomeworkClassesLoadingShimmer extends StatelessWidget {
  const _HomeworkClassesLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24.0 : Get.height / 47.25),
      child: Column(
        children: [
          const ShimmerCard(height: 54, radius: 12),
          SizedBox(height: isTablet ? 24.0 : Get.height / 47.25),
          Expanded(
            child: ListView.separated(
              physics: const NeverScrollableScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (_, __) =>
                  SizedBox(height: isTablet ? 16.0 : Get.height / 75.6),
              itemBuilder: (_, __) =>
                  ShimmerCard(height: isTablet ? 100 : 80, radius: 14),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shimmer Homework List Loading ──────────────────────────────
class _HomeworkListLoadingShimmer extends StatelessWidget {
  const _HomeworkListLoadingShimmer();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return ListView.separated(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.all(isTablet ? 24.0 : Get.height / 47.25),
      itemCount: 6,
      separatorBuilder: (_, __) =>
          SizedBox(height: isTablet ? 16.0 : Get.height / 75.6),
      itemBuilder: (_, __) =>
          ShimmerCard(height: isTablet ? 100 : 80, radius: 14),
    );
  }
}

// ── Shimmer Homework Form Loading ──────────────────────────────
class _HomeworkFormShimmer extends StatelessWidget {
  const _HomeworkFormShimmer();

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: EdgeInsets.all(isTablet ? 32.0 : Get.height / 37.8),
      child: isTablet
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [
                          ShimmerCard(height: 54, radius: 12),
                          SizedBox(height: 20),
                          ShimmerCard(height: 54, radius: 12),
                          SizedBox(height: 20),
                          ShimmerCard(height: 54, radius: 12),
                          SizedBox(height: 20),
                          ShimmerCard(height: 54, radius: 12),
                        ],
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          ShimmerCard(height: 180, radius: 12),
                          SizedBox(height: 20),
                          ShimmerCard(height: 54, radius: 12),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                const ShimmerCard(height: 56, radius: 14),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerCard(height: 54, radius: 12),
                SizedBox(height: Get.height / 47.25),
                const ShimmerCard(height: 54, radius: 12),
                SizedBox(height: Get.height / 47.25),
                const ShimmerCard(height: 54, radius: 12),
                SizedBox(height: Get.height / 47.25),
                const ShimmerCard(height: 100, radius: 12),
                SizedBox(height: Get.height / 47.25),
                const ShimmerCard(height: 54, radius: 12),
                SizedBox(height: Get.height / 47.25),
                const ShimmerCard(height: 100, radius: 12),
                SizedBox(height: Get.height / 27),
                const ShimmerCard(height: 56, radius: 14),
              ],
            ),
    );
  }
}
