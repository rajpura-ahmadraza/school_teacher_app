import 'package:get/get.dart';
import '../../core/controllers/auth_controller.dart';
import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';


import '../../core/theme/app_theme.dart';
import '../../core/widgets/common_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passFocus = FocusNode();
  bool _emailHasFocus = false;
  bool _passHasFocus = false;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() {
      setState(() {
        _emailHasFocus = _emailFocus.hasFocus;
      });
    });
    _passFocus.addListener(() {
      setState(() {
        _passHasFocus = _passFocus.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final err = await Get.find<AuthController>()
        .login(_emailCtrl.text, _passCtrl.text);
    if (err != null && mounted) showToast(context, err, isError: true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = Get.find<AuthController>();
    final size = MediaQuery.of(context).size;

    return Obx(() {
    final isLoading = auth.isLoading.value;
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.07),
              ),
            ),
          ),
          Positioned(
            top: size.height * 0.2,
            right: -100,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.06),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.05),
              ),
            ),
          ),

          // ── Main Content Scrollable Area ──────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 10),

                    // Tilted Creative Logo & Header
                    FadeInDown(
                      duration: const Duration(milliseconds: 850),
                      child: Column(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              // Tilted glow backing card
                              Transform.rotate(
                                angle: -0.1,
                                child: Container(
                                  width: 82,
                                  height: 82,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(22),
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF9333EA),
                                        Color(0xFFDB2777)
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFDB2777)
                                            .withOpacity(0.3),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.12),
                                    width: 1.5,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.1),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ShaderMask(
                                  shaderCallback: (bounds) =>
                                      AppColors.gradientPrimary
                                          .createShader(bounds),
                                  child: const Icon(
                                    Icons.school_rounded,
                                    size: 38,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),
                          // Title with Gradient accent
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'TEACHER',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.textPrimary,
                                  letterSpacing: -0.8,
                                ),
                              ),
                              ShaderMask(
                                shaderCallback: (bounds) =>
                                    AppColors.gradientPrimary.createShader(bounds),
                                child: const Text(
                                  ' PORTAL',
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 28,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.8,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Access your class management dashboard',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w400,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 38),

                    // ── Borderless Glass Form Card ────────────────────────
                    FadeInUp(
                      duration: const Duration(milliseconds: 850),
                      delay: const Duration(milliseconds: 100),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withOpacity(0.08),
                              blurRadius: 32,
                              offset: const Offset(0, 12),
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 32),
                          child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // EMAIL INPUT WRAPPER WITH FOCUS GLOW
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: _emailHasFocus
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFF9333EA)
                                                      .withOpacity(0.12),
                                                  blurRadius: 16,
                                                  spreadRadius: 2,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: TextFormField(
                                        controller: _emailCtrl,
                                        focusNode: _emailFocus,
                                        keyboardType:
                                            TextInputType.emailAddress,
                                        textInputAction: TextInputAction.next,
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                        cursorColor: AppColors.secondary,
                                        decoration: InputDecoration(
                                          labelText: 'Email Address',
                                          labelStyle: const TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                          floatingLabelStyle: const TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          prefixIcon: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            margin: const EdgeInsets.all(10),
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: _emailHasFocus
                                                  ? AppColors.primaryLight
                                                  : AppColors.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _emailHasFocus
                                                    ? AppColors.primary
                                                        .withOpacity(0.3)
                                                    : const Color(0xFFE8E0F0),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.email_outlined,
                                              size: 18,
                                              color: _emailHasFocus
                                                  ? AppColors.secondary
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                          filled: true,
                                          fillColor: AppColors.surfaceAlt,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE8E0F0),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppColors.secondary,
                                              width: 2,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppColors.danger,
                                              width: 2,
                                            ),
                                          ),
                                          errorStyle: const TextStyle(
                                            color: AppColors.danger,
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.trim().isEmpty) {
                                            return 'Email is required';
                                          }
                                          if (!v.contains('@')) {
                                            return 'Enter a valid email';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 22),

                                    // PASSWORD INPUT WRAPPER WITH FOCUS GLOW
                                    AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        boxShadow: _passHasFocus
                                            ? [
                                                BoxShadow(
                                                  color: const Color(0xFFDB2777)
                                                      .withOpacity(0.12),
                                                  blurRadius: 16,
                                                  spreadRadius: 2,
                                                )
                                              ]
                                            : [],
                                      ),
                                      child: TextFormField(
                                        controller: _passCtrl,
                                        focusNode: _passFocus,
                                        obscureText: _obscure,
                                        textInputAction: TextInputAction.done,
                                        onFieldSubmitted: (_) => _login(),
                                        style: const TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 15,
                                          color: AppColors.textPrimary,
                                        ),
                                        cursorColor: AppColors.secondary,
                                        decoration: InputDecoration(
                                          labelText: 'Password',
                                          labelStyle: const TextStyle(
                                            color: AppColors.textSecondary,
                                          ),
                                          floatingLabelStyle: const TextStyle(
                                            color: AppColors.secondary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          prefixIcon: AnimatedContainer(
                                            duration: const Duration(
                                                milliseconds: 300),
                                            margin: const EdgeInsets.all(10),
                                            padding: const EdgeInsets.all(7),
                                            decoration: BoxDecoration(
                                              color: _passHasFocus
                                                  ? AppColors.primaryLight
                                                  : AppColors.surfaceAlt,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              border: Border.all(
                                                color: _passHasFocus
                                                    ? AppColors.secondary
                                                        .withOpacity(0.3)
                                                    : const Color(0xFFE8E0F0),
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.lock_outlined,
                                              size: 18,
                                              color: _passHasFocus
                                                  ? AppColors.primary
                                                  : AppColors.textTertiary,
                                            ),
                                          ),
                                          suffixIcon: IconButton(
                                            icon: Icon(
                                              _obscure
                                                  ? Icons.visibility_outlined
                                                  : Icons
                                                      .visibility_off_outlined,
                                              size: 20,
                                              color: AppColors.textTertiary,
                                            ),
                                            onPressed: () => setState(
                                                () => _obscure = !_obscure),
                                          ),
                                          filled: true,
                                          fillColor: AppColors.surfaceAlt,
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: Color(0xFFE8E0F0),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppColors.secondary,
                                              width: 2,
                                            ),
                                          ),
                                          errorBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppColors.danger,
                                            ),
                                          ),
                                          focusedErrorBorder:
                                              OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(18),
                                            borderSide: const BorderSide(
                                              color: AppColors.danger,
                                              width: 2,
                                            ),
                                          ),
                                          errorStyle: const TextStyle(
                                            color: AppColors.danger,
                                          ),
                                        ),
                                        validator: (v) {
                                          if (v == null || v.isEmpty) {
                                            return 'Password is required';
                                          }
                                          return null;
                                        },
                                      ),
                                    ),

                                    const SizedBox(height: 36),

                                    // GLOWING GRADIENT ACTION BUTTON
                                    AnimatedOpacity(
                                      opacity: isLoading ? 0.6 : 1.0,
                                      duration:
                                          const Duration(milliseconds: 200),
                                      child: Container(
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: AppColors.gradientPrimary,
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppColors.secondary
                                                  .withOpacity(0.4),
                                              blurRadius: 20,
                                              offset: const Offset(0, 6),
                                            ),
                                          ],
                                        ),
                                        child: ElevatedButton(
                                          onPressed: isLoading ? null : _login,
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            shadowColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(18),
                                            ),
                                          ),
                                          child: isLoading
                                              ? const SizedBox(
                                                  width: 22,
                                                  height: 22,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth: 2.5,
                                                    color: Colors.white,
                                                  ),
                                                )
                                              : const Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'Sign In',
                                                      style: TextStyle(
                                                        fontFamily: 'Inter',
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        letterSpacing: 0.5,
                                                      ),
                                                    ),
                                                    SizedBox(width: 8),
                                                    Icon(
                                                      Icons
                                                          .arrow_forward_rounded,
                                                      size: 18,
                                                      color: Colors.white,
                                                    ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
    });
  }
}
