import 'package:animate_do/animate_do.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final FocusNode _emailFocus = FocusNode();
  bool _emailHasFocus = false;
  bool _isLoading = false;
  bool _success = false;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(
        () => setState(() => _emailHasFocus = _emailFocus.hasFocus));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMsg = 'Email is required');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMsg = 'Enter a valid email address');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      await ApiClient.instance.post(
        '/auth/forgot-password',
        {'email': email},
      );

      setState(() {
        _isLoading = false;
        _success = true;
      });
    } on ApiException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMsg = e.displayMessage;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMsg = 'Something went wrong. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -120,
            left: -80,
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
            bottom: -80,
            right: -60,
            child: Container(
              width: Get.height / 3.15,
              height: Get.height / 3.15,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.06),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Get.height / 75.6,
                    vertical: Get.height / 126,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_rounded),
                        color: AppColors.textPrimary,
                        onPressed: () => Get.back(),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: Get.height / 31.5,
                        vertical: Get.height / 63,
                      ),
                      child: _success
                          ? _buildSuccessView()
                          : _buildFormView(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Form View ────────────────────────────────────────────────────
  Widget _buildFormView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Header
        FadeInDown(
          duration: const Duration(milliseconds: 700),
          child: Column(
            children: [
              Container(
                width: Get.height / 8,
                height: Get.height / 8,
                decoration: BoxDecoration(
                  gradient: AppColors.gradientPrimary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.25),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Colors.white,
                  size: 36,
                ),
              ),
              SizedBox(height: Get.height / 31.5),
              Text(
                'Forgot Password?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              SizedBox(height: Get.height / 94.5),
              Text(
                'Enter your registered email address.\nA password reset link will be sent to your inbox.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w400,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        SizedBox(height: Get.height / 19.89),

        // Form Card
        FadeInUp(
          duration: const Duration(milliseconds: 700),
          delay: const Duration(milliseconds: 100),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(Get.height / 27),
              border: Border.all(
                  color: const Color(0xFFF1F5F9), width: 1.5),
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
              padding: EdgeInsets.symmetric(
                horizontal: Get.height / 31.5,
                vertical: Get.height / 23.62,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Email Field
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      borderRadius:
                          BorderRadius.circular(Get.height / 42),
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
                    child: TextField(
                      controller: _emailCtrl,
                      focusNode: _emailFocus,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                      style: TextStyle(
                        fontWeight: FontWeight.normal,
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: AppColors.textPrimary,
                      ),
                      cursorColor: AppColors.secondary,
                      decoration: InputDecoration(
                        labelText: 'Email Address',
                        labelStyle: const TextStyle(
                          fontWeight: FontWeight.w300,
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        floatingLabelStyle: const TextStyle(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.w500,
                        ),
                        prefixIcon: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.all(10),
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: _emailHasFocus
                                ? AppColors.primaryLight
                                : AppColors.surfaceAlt,
                            borderRadius:
                                BorderRadius.circular(Get.height / 63),
                            border: Border.all(
                              color: _emailHasFocus
                                  ? AppColors.primary.withOpacity(0.3)
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
                              BorderRadius.circular(Get.height / 42),
                          borderSide: const BorderSide(
                              color: Color(0xFFE8E0F0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(Get.height / 42),
                          borderSide: const BorderSide(
                              color: AppColors.secondary, width: 2),
                        ),
                        errorBorder: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(Get.height / 42),
                          borderSide: const BorderSide(
                              color: AppColors.danger),
                        ),
                      ),
                    ),
                  ),

                  // Error message
                  if (_errorMsg != null) ...[
                    SizedBox(height: Get.height / 63),
                    Container(
                      padding: EdgeInsets.all(Get.height / 75.6),
                      decoration: BoxDecoration(
                        color: AppColors.danger.withOpacity(0.08),
                        borderRadius:
                            BorderRadius.circular(Get.height / 63),
                        border: Border.all(
                            color: AppColors.danger.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline_rounded,
                              color: AppColors.danger,
                              size: Get.height / 42),
                          SizedBox(width: Get.height / 94.5),
                          Expanded(
                            child: Text(
                              _errorMsg!,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                                color: AppColors.danger,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: Get.height / 21),

                  // Submit Button
                  AnimatedOpacity(
                    opacity: _isLoading ? 0.6 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppColors.gradientPrimary,
                        borderRadius:
                            BorderRadius.circular(Get.height / 42),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.secondary.withOpacity(0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(Get.height / 42),
                          ),
                        ),
                        child: _isLoading
                            ? SizedBox(
                                width: Get.height / 34.36,
                                height: Get.height / 34.36,
                                child: const CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.send_rounded,
                                      size: 18, color: Colors.white),
                                  SizedBox(width: Get.height / 94.5),
                                  const Text(
                                    'Send Reset Link',
                                    style: TextStyle(
                                      fontFamily: 'Inter',
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.3,
                                    ),
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

        SizedBox(height: Get.height / 31.5),

        // Back to login
        Center(
          child: GestureDetector(
            onTap: () => Get.back(),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.arrow_back_rounded,
                    size: 14, color: AppColors.primary),
                SizedBox(width: Get.height / 126),
                Text(
                  'Back to Sign In',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Success View ─────────────────────────────────────────────────
  Widget _buildSuccessView() {
    return FadeInUp(
      duration: const Duration(milliseconds: 600),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Success icon
          Center(
            child: Container(
              width: Get.height / 7,
              height: Get.height / 7,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF10B981).withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                color: Color(0xFF10B981),
                size: 44,
              ),
            ),
          ),

          SizedBox(height: Get.height / 31.5),

          Text(
            'Check Your Email!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
              letterSpacing: -0.5,
            ),
          ),

          SizedBox(height: Get.height / 94.5),

          Text(
            'A password reset link has been sent to',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
            ),
          ),

          SizedBox(height: Get.height / 189),

          Text(
            _emailCtrl.text.trim(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),

          SizedBox(height: Get.height / 94.5),

          Text(
            'Open your email and click the link\nto change your password.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w400,
              height: 1.6,
            ),
          ),

          SizedBox(height: Get.height / 21),

          // Back to Sign In button
          Container(
            height: 56,
            decoration: BoxDecoration(
              gradient: AppColors.gradientPrimary,
              borderRadius: BorderRadius.circular(Get.height / 42),
              boxShadow: [
                BoxShadow(
                  color: AppColors.secondary.withOpacity(0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: () => Get.back(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Get.height / 42),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.login_rounded,
                      size: 18, color: Colors.white),
                  SizedBox(width: Get.height / 94.5),
                  const Text(
                    'Back to Sign In',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: Get.height / 47.25),

          // Resend option
          Center(
            child: GestureDetector(
              onTap: () => setState(() {
                _success = false;
                _errorMsg = null;
              }),
              child: Text(
                'Didn\'t receive the email? Try again',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
