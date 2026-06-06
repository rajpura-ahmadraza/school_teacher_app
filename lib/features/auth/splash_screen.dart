import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/controllers/auth_controller.dart';
import '../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _fade;
  late Animation<double> _scale;
  late Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 5))
      ..forward();

    _fade = CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.0, 0.6, curve: Curves.easeOut));
    _scale = Tween<double>(begin: 0.65, end: 1.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut)));
    _slide = Tween<double>(begin: 24, end: 0).animate(CurvedAnimation(
        parent: _ctrl, curve: const Interval(0.3, 1.0, curve: Curves.easeOut)));

    // AuthController will handle navigation automatically via onInit
    Get.put<AuthController>(AuthController(), permanent: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120, right: -80,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -100, left: -60,
            child: Container(
              width: 280, height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.06),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: padding.top, bottom: padding.bottom),
            child: Column(
              children: [
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _fade,
                    child: ScaleTransition(scale: _scale, child: child),
                  ),
                  child: Column(
                    children: [
                      Stack(alignment: Alignment.center, children: [
                        Container(
                          width: 120, height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppColors.gradientPrimary,
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.secondary.withOpacity(0.25),
                                blurRadius: 28,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          width: 96, height: 96,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.15), width: 2),
                          ),
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.gradientPrimary.createShader(bounds),
                            child: const Icon(Icons.school_rounded,
                                size: 48, color: Colors.white),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 28),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.gradientPrimary.createShader(bounds),
                        child: const Text('School Teacher',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                      ),
                      const SizedBox(height: 8),
                      Text('Manage · Teach · Inspire',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary.withOpacity(0.9),
                            letterSpacing: 1.2,
                          )),
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) => FadeTransition(
                    opacity: _fade,
                    child: Transform.translate(
                        offset: Offset(0, _slide.value), child: child),
                  ),
                  child: const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8, runSpacing: 8,
                    children: [
                      _Pill('Attendance'),
                      _Pill('Homework'),
                      _Pill('Students'),
                      _Pill('Timetable'),
                      _Pill('Leaves'),
                    ],
                  ),
                ),
                const Spacer(flex: 1),
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, child) =>
                      FadeTransition(opacity: _fade, child: child),
                  child: Column(children: [
                    SizedBox(
                      width: 28, height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary.withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text('Loading...',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        )),
                  ]),
                ),
                const SizedBox(height: 24),
                Text('v1.0.0  ·  SchoolMS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textTertiary.withOpacity(0.7),
                    )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  const _Pill(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Text(label,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            )),
      );
}
