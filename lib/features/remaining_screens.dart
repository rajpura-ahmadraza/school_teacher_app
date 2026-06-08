import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import '../core/api/api_client.dart';
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
      if (raw is List) {
        classes.value = raw;
      } else if (raw is Map) {
        classes.value = List<dynamic>.from(raw['data'] ?? raw['classes'] ?? []);
      } else {
        classes.value = [];
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
        timetable.value = List<dynamic>.from(
            raw['data'] ?? raw['timetable'] ?? raw['timetables'] ?? []);
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
            isScrollable: true,
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: ctrl.classes.map((cls) {
                      final c = Map<String, dynamic>.from(cls as Map);
                      final sel = ctrl.selectedClass.value?['id'] == c['id'];
                      return GestureDetector(
                        onTap: () => ctrl.loadTimetable(c),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.only(right: 8),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: sel ? AppColors.gradientPrimary : null,
                            color: sel ? null : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: sel
                                    ? Colors.transparent
                                    : Colors.grey.shade300),
                          ),
                          child: Text('${c['name'] ?? ''}',
                              style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: sel
                                      ? Colors.white
                                      : AppColors.textPrimary)),
                        ),
                      );
                    }).toList(),
                  ),
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
                            final dayIndex = _days.indexOf(day) + 1;
                            final periods = ctrl.timetable
                                .where((t) =>
                                    (t as Map)['day'] == dayIndex ||
                                    (t)['day_name'] == day)
                                .toList();
                            if (periods.isEmpty) {
                              return const EmptyState(
                                  icon: Icons.event_busy_rounded,
                                  title: 'No Classes',
                                  subtitle:
                                      'No periods scheduled for this day');
                            }
                            return ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: periods.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (ctx, i) {
                                final p = periods[i] as Map<String, dynamic>;
                                final subj = p['subject'] as Map? ?? {};
                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(14),
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
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                          gradient: AppColors.gradientPrimary,
                                          borderRadius:
                                              BorderRadius.circular(12)),
                                      child: Center(
                                        child: Text('${i + 1}',
                                            style: const TextStyle(
                                                color: Colors.white,
                                                fontFamily: 'Inter',
                                                fontWeight: FontWeight.w800,
                                                fontSize: 18)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
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
                                                style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 15)),
                                            Text(
                                                '${p['start_time'] ?? ''} – ${p['end_time'] ?? ''}',
                                                style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 13,
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
  final RxBool isLoading = true.obs;
  final RxString filterStatus = 'pending'.obs;

  @override
  void onInit() {
    super.onInit();
    loadLeaves();
  }

  Future<void> loadLeaves() async {
    isLoading.value = true;
    try {
      final r = await _api.get('/leaves',
          params: {'status': filterStatus.value, 'per_page': '50'});
      final raw = r.data;
      if (raw is List) {
        leaves.value = raw;
      } else if (raw is Map) {
        leaves.value = List<dynamic>.from(raw['data'] ?? raw['leaves'] ?? []);
      } else {
        leaves.value = [];
      }
    } catch (_) {
      leaves.value = [];
    }
    isLoading.value = false;
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

class LeavesScreen extends StatelessWidget {
  const LeavesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(LeavesController());
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
        // Status filter tabs
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Obx(() => Row(
                children: statuses.map((s) {
                  final sel = ctrl.filterStatus.value == s;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        ctrl.filterStatus.value = s;
                        ctrl.loadLeaves();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          gradient: sel ? AppColors.gradientPrimary : null,
                          color: sel ? null : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(s[0].toUpperCase() + s.substring(1),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: sel
                                    ? Colors.white
                                    : AppColors.textSecondary)),
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
              onRefresh: ctrl.loadLeaves,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: ctrl.leaves.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (ctx, i) {
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
            ? AppColors.secondary
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          NetAvatar(
            url: student['profile_photo'] as String?,
            radius: 22,
            fallbackLetter: (student['name'] as String? ?? '?')[0],
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(student['name'] as String? ?? 'Student',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontWeight: FontWeight.w700,
                      fontSize: 15)),
              Text('$from → $to',
                  style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary)),
            ]),
          ),
          StatusBadge(label: status, color: statusColor),
        ]),
        if (reason.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(reason,
              style: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary)),
        ],
        if (status == 'pending') ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => onReview('rejected'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: AppColors.danger.withOpacity(0.25)),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.close_rounded,
                            color: AppColors.danger, size: 16),
                        SizedBox(width: 6),
                        Text('Reject',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.danger)),
                      ]),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => onReview('approved'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.secondary.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: AppColors.secondary.withOpacity(0.25)),
                  ),
                  child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_rounded,
                            color: AppColors.secondary, size: 16),
                        SizedBox(width: 6),
                        Text('Approve',
                            style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.secondary)),
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
                            errorWidget: (context, url, error) => const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.broken_image_rounded,
                                    color: Colors.grey, size: 64),
                                SizedBox(height: 12),
                                Text(
                                  'Failed to load image',
                                  style: TextStyle(
                                      color: Colors.white, fontSize: 14),
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
                left: 16,
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
                      padding: const EdgeInsets.all(8),
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
                right: 16,
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
                      padding: const EdgeInsets.all(8),
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
        ],
      ),
    );
  }

  Future<void> _downloadImage(String url) async {
    if (url.isEmpty) return;
    try {
      Get.showOverlay(
        asyncFunction: () async {
          final dio = Dio();
          final tempDir = await getTemporaryDirectory();
          final filename = url.split('/').last.split('?').first;
          final savePath = '${tempDir.path}/$filename';

          await dio.download(url, savePath);

          Get.snackbar(
            'Success',
            'Image downloaded successfully!',
            backgroundColor: AppColors.success,
            colorText: Colors.white,
            mainButton: TextButton(
              onPressed: () => OpenFile.open(savePath),
              child: const Text('OPEN',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
        },
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download image: $e',
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
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
          padding: const EdgeInsets.only(
            left: 16.0,
            top: 8.0,
            bottom: 8.0,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              padding: EdgeInsets.zero,
              icon: const Icon(
                Icons.chevron_left_rounded,
                color: Colors.black,
                size: 28,
              ),
              onPressed: () => Get.offNamed(AppRoutes.dashboard),
            ),
          ),
        ),
        title: const Text(
          'Gallery',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Inter',
            fontWeight: FontWeight.w700,
            fontSize: 20,
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Albums',
                            style: TextStyle(
                              fontSize: 16,
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
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: ctrl.albumTitles.map((title) {
                          final isSelected = ctrl.selectedAlbum.value == title;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: GestureDetector(
                              onTap: () => ctrl.selectedAlbum.value = title,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.primary
                                      : AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 14,
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

                    const SizedBox(height: 16),

                    // Grid of image cards
                    photos.isEmpty
                        ? Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: const Text(
                              'No photos in this album',
                              style: TextStyle(
                                  color: AppColors.textSecondary, fontSize: 14),
                            ),
                          )
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
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
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(20),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        url.isEmpty
                                            ? Container(
                                                color: AppColors.primaryLight,
                                                child: const Icon(
                                                  Icons.broken_image_rounded,
                                                  color: AppColors.primary,
                                                  size: 32,
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
                                                  child: const Icon(
                                                    Icons.broken_image_rounded,
                                                    color: AppColors.primary,
                                                    size: 32,
                                                  ),
                                                ),
                                              ),

                                        // Floating download button
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () => _downloadImage(url),
                                            child: Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.2),
                                                    blurRadius: 6,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                Icons.download_rounded,
                                                color: Colors.white,
                                                size: 16,
                                              ),
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
                    const SizedBox(height: 32),
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

  Future<void> _downloadImage(String url) async {
    if (url.isEmpty) return;
    try {
      Get.showOverlay(
        asyncFunction: () async {
          final dio = Dio();
          final tempDir = await getTemporaryDirectory();
          final filename = url.split('/').last.split('?').first;
          final savePath = '${tempDir.path}/$filename';

          await dio.download(url, savePath);

          Get.snackbar(
            'Success',
            'Image downloaded successfully!',
            backgroundColor: AppColors.success,
            colorText: Colors.white,
            mainButton: TextButton(
              onPressed: () => OpenFile.open(savePath),
              child: const Text('OPEN',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          );
        },
        loadingWidget: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to download image: $e',
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
      );
    }
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                    style: const TextStyle(
                        fontFamily: 'Inter',
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
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
                            padding: const EdgeInsets.all(16),
                            itemCount: ctrl.events.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
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
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
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
                                    width: 48,
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
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
                                              fontSize: 18)),
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
                                              fontSize: 10)),
                                    ]),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                              ev['title'] as String? ?? 'Event',
                                              style: const TextStyle(
                                                  fontFamily: 'Inter',
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 15)),
                                          if (ev['description'] != null)
                                            Text(ev['description'] as String,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                    fontFamily: 'Inter',
                                                    fontSize: 12,
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
            padding: const EdgeInsets.all(16),
            itemCount: ctrl.buses.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
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
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              gradient: AppColors.gradientPrimary,
                              borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.directions_bus_rounded,
                              color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    bus['bus_number'] as String? ??
                                        'Bus ${i + 1}',
                                    style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontWeight: FontWeight.w700,
                                        fontSize: 16)),
                                Text(
                                    bus['route'] as String? ??
                                        'Route not assigned',
                                    style: const TextStyle(
                                        fontFamily: 'Inter',
                                        fontSize: 12,
                                        color: AppColors.textSecondary)),
                              ]),
                        ),
                        StatusBadge(label: status, color: statusColor),
                      ]),
                      const Divider(height: 20),
                      Row(children: [
                        const Icon(Icons.person_rounded,
                            size: 16, color: AppColors.textSecondary),
                        const SizedBox(width: 6),
                        Text('Driver: ${driver['name'] as String? ?? 'N/A'}',
                            style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        const Spacer(),
                        if (driver['phone'] != null)
                          Row(children: [
                            const Icon(Icons.phone_rounded,
                                size: 16, color: AppColors.primary),
                            const SizedBox(width: 4),
                            Text(driver['phone'] as String,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13,
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600)),
                          ]),
                      ]),
                      if (bus['last_location'] != null) ...[
                        const SizedBox(height: 8),
                        Row(children: [
                          const Icon(Icons.location_on_rounded,
                              size: 16, color: AppColors.danger),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(bus['last_location'] as String,
                                style: const TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 12,
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
