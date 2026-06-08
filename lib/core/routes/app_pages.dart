import 'package:get/get.dart';
import '../../features/auth/splash_screen.dart';
import '../../features/auth/login_screen.dart';
import '../../features/dashboard/dashboard_screen.dart';
import '../../features/students/students_screen.dart';
import '../../features/students/student_detail_screen.dart';
import '../../features/attendance/attendance_screen.dart';
import '../../features/attendance/attendance_report_screen.dart';
import '../../features/homework/homework_screen.dart';
import '../../features/homework/homework_form_screen.dart';
import '../../features/timetable/timetable_screen.dart';
import '../../features/leaves/leaves_screen.dart';
import '../../features/gallery/gallery_screen.dart';
import '../../features/calendar/calendar_screen.dart';
import '../../features/bus_tracking/bus_tracking_screen.dart';
import '../../features/notifications/notifications_screen.dart';
import '../bindings/app_binding.dart';
import 'app_routes.dart';

class AppPages {
  static final pages = [
    GetPage(
      name: AppRoutes.splash,
      page: () => const SplashScreen(),
      binding: AppBinding(),
    ),
    GetPage(
      name: AppRoutes.login,
      page: () => const LoginScreen(),
    ),
    GetPage(
      name: AppRoutes.dashboard,
      page: () => const DashboardScreen(),
    ),
    GetPage(
      name: AppRoutes.students,
      page: () => const StudentsScreen(),
    ),
    GetPage(
      name: AppRoutes.studentDetail,
      page: () => StudentDetailScreen(
            studentId: Get.arguments as int? ?? 0),
    ),
    GetPage(
      name: AppRoutes.attendance,
      page: () => const AttendanceScreen(),
    ),
    GetPage(
      name: AppRoutes.attendanceReport,
      page: () => const AttendanceReportScreen(),
    ),
    GetPage(
      name: AppRoutes.homework,
      page: () => const HomeworkScreen(),
    ),
    GetPage(
      name: AppRoutes.homeworkForm,
      page: () => HomeworkFormScreen(
            existing: Get.arguments as Map<String, dynamic>?),
    ),
    GetPage(
      name: AppRoutes.timetable,
      page: () => const TimetableScreen(),
    ),
    GetPage(
      name: AppRoutes.leaves,
      page: () => const LeavesScreen(),
    ),
    GetPage(
      name: AppRoutes.gallery,
      page: () => const GalleryScreen(),
    ),
    GetPage(
      name: AppRoutes.calendar,
      page: () => const CalendarScreen(),
    ),
    GetPage(
      name: AppRoutes.busTracking,
      page: () => const BusTrackingScreen(),
    ),
    GetPage(
      name: AppRoutes.notifications,
      page: () => const NotificationsScreen(),
    ),
  ];
}
