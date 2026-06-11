import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
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
    _ctrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 5))
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
            top: -120,
            right: -80,
            child: Container(
              width: Get.height / 2.36,
              height: Get.height / 2.36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            left: -60,
            child: Container(
              width: Get.height / 2.7,
              height: Get.height / 2.7,
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
                          width: Get.height / 6.3,
                          height: Get.height / 6.3,
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
                          width: Get.height / 7.87,
                          height: Get.height / 7.87,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: AppColors.primary.withOpacity(0.15),
                                width: Get.height / 378),
                          ),
                          child: ShaderMask(
                            shaderCallback: (bounds) =>
                                AppColors.gradientPrimary.createShader(bounds),
                            child: Icon(Icons.school_rounded,
                                size: Get.height / 15.75, color: Colors.white),
                          ),
                        ),
                      ]),
                      SizedBox(height: Get.height / 13.5),
                      ShaderMask(
                        shaderCallback: (bounds) =>
                            AppColors.gradientPrimary.createShader(bounds),
                        child: Text('School Teacher',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 32,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            )),
                      ),
                      SizedBox(height: Get.height / 94.5),
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
                    spacing: 8,
                    runSpacing: 8,
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
                      width: Get.height / 27,
                      height: Get.height / 27,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.primary.withOpacity(0.8),
                      ),
                    ),
                    SizedBox(height: Get.height / 63),
                    Text('Loading...',
                        style: TextStyle(
                          fontWeight: FontWeight.normal,
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        )),
                  ]),
                ),
                SizedBox(height: Get.height / 31.5),
                Text('v1.0.0  ·  SchoolMS',
                    style: TextStyle(
                      fontWeight: FontWeight.normal,
                      fontFamily: 'Inter',
                      fontSize: 11,
                      color: AppColors.textTertiary.withOpacity(0.7),
                    )),
                SizedBox(height: Get.height / 151.2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Powered by',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: Get.height / 63,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    SizedBox(
                      width: Get.height / 151.2,
                    ),
                    GestureDetector(
                      onTap: () async {
                        final Uri url = Uri.parse(
                            'https://www.emaadinfotech.com/get-in-touch');
                        await launchUrl(
                          url,
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      child: Text(
                        'Emaad Infotech®',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: Get.height / 63,
                          fontWeight: FontWeight.w500,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: Get.height / 47.25),
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
        padding: EdgeInsets.symmetric(
          horizontal: Get.height / 54,
          vertical: Get.height / 126,
        ),
        decoration: BoxDecoration(
          color: AppColors.primaryLight,
          borderRadius: BorderRadius.circular(
            Get.height / 37.8,
          ),
          border: Border.all(color: AppColors.primary.withOpacity(0.12)),
        ),
        child: Text(label,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            )),
      );
}
