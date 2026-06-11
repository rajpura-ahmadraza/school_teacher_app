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
                      SizedBox(height: Get.height / 37.8),
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
                    ],
                  ),
                ),
                const Spacer(flex: 2),
                SizedBox(height: Get.height / 7.56),
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

// ignore: unused_element
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
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              color: AppColors.primary,
              fontWeight: FontWeight.w600,
            )),
      );
}
