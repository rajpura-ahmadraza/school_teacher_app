import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
import '../providers/auth_provider.dart';

class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const dashboard = '/dashboard';
  static const students = '/students';
  static const studentDetail = '/students/:id';
  static const attendance = '/attendance';
  static const attendanceReport = '/attendance/report';
  static const homework = '/homework';
  static const homeworkForm = '/homework/form';
  static const timetable = '/timetable';
  static const leaves = '/leaves';
  static const gallery = '/gallery';
  static const calendar = '/calendar';
  static const busTracking = '/bus';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthListenable(ref),
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final initializing = auth.isInitializing;
      final loggedIn = auth.isAuthenticated;
      final loc = state.matchedLocation;

      if (initializing) {
        return loc == AppRoutes.splash ? null : AppRoutes.splash;
      }
      if (loc == AppRoutes.splash) return null;
      if (!loggedIn && loc != AppRoutes.login) return AppRoutes.login;
      if (loggedIn && loc == AppRoutes.login) return AppRoutes.dashboard;
      return null;
    },
    routes: [
      GoRoute(path: AppRoutes.splash, builder: (_, __) => const SplashScreen()),
      GoRoute(path: AppRoutes.login, builder: (_, __) => const LoginScreen()),
      GoRoute(
        path: AppRoutes.dashboard,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _showExitConfirm(context);
          },
          child: const DashboardScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.students,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const StudentsScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.studentDetail,
        builder: (_, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '0') ?? 0;
          return StudentDetailScreen(studentId: id);
        },
      ),
      GoRoute(
        path: AppRoutes.attendance,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const AttendanceScreen(),
        ),
      ),
      GoRoute(
          path: AppRoutes.attendanceReport,
          builder: (_, __) => const AttendanceReportScreen()),
      GoRoute(
        path: AppRoutes.homework,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const HomeworkScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.homeworkForm,
        builder: (_, state) {
          final extra = state.extra as Map<String, dynamic>?;
          return HomeworkFormScreen(existing: extra);
        },
      ),
      GoRoute(
        path: AppRoutes.timetable,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const TimetableScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.leaves,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const LeavesScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.gallery,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const GalleryScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.calendar,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const CalendarScreen(),
        ),
      ),
      GoRoute(
        path: AppRoutes.busTracking,
        builder: (context, __) => PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) context.go(AppRoutes.dashboard);
          },
          child: const BusTrackingScreen(),
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

void _showExitConfirm(BuildContext context) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Exit App?',
        style: TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
      ),
      content: const Text(
        'Do you want to close the app?',
        style: TextStyle(fontWeight: FontWeight.normal, fontFamily: 'Inter'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(
                  fontWeight: FontWeight.normal, fontFamily: 'Inter')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF9333EA),
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () {
            Navigator.pop(context);
            SystemNavigator.pop();
          },
          child: const Text('Exit',
              style:
                  TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w600)),
        ),
      ],
    ),
  );
}

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    ref.listen(authProvider, (_, __) => notifyListeners());
  }
}
