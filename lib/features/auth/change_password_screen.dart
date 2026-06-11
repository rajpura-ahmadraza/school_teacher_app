import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import 'change_password_controller.dart';

class ChangePasswordScreen extends StatelessWidget {
  ChangePasswordScreen({super.key});

  final controller = Get.put(ChangePasswordController());

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 14.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => Get.back(),
                      child: Container(
                        padding: const EdgeInsets.all(10.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18.0,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                    const Text(
                      "Change Password",
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'Inter',
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 40.0),
                  ],
                ),
              ).animate().fade(duration: 300.ms).slideY(begin: -0.2),

              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    children: [
                      /// Current Password
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("Current Password"),
                          Obx(
                            () => TextFormField(
                              controller: controller.currentCtrl,
                              obscureText: controller.obscureCurrent.value,
                              onChanged: controller.validateCurrent,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration(
                                hint: "Enter current password",
                                icon: Icons.lock_outline_rounded,
                                isObscure: controller.obscureCurrent.value,
                                onToggle: controller.toggleCurrent,
                              ),
                            ),
                          ),
                          Obx(
                            () => controller.currentError.value.isEmpty
                                ? const SizedBox()
                                : _errorText(controller.currentError.value),
                          ),
                        ],
                      ).animate(delay: 100.ms).fade().slideY(begin: 0.2),

                      const SizedBox(height: 20.0),

                      /// New Password
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("New Password"),
                          Obx(
                            () => TextFormField(
                              controller: controller.newCtrl,
                              obscureText: controller.obscureNew.value,
                              onChanged: controller.validateNew,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration(
                                hint: "Enter new password",
                                icon: Icons.lock_outline_rounded,
                                isObscure: controller.obscureNew.value,
                                onToggle: controller.toggleNew,
                              ),
                            ),
                          ),
                          Obx(
                            () => controller.newError.value.isEmpty
                                ? const SizedBox()
                                : _errorText(controller.newError.value),
                          ),
                        ],
                      ).animate(delay: 200.ms).fade().slideY(begin: 0.2),

                      const SizedBox(height: 20.0),

                      /// Confirm Password
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _sectionLabel("Confirm Password"),
                          Obx(
                            () => TextFormField(
                              controller: controller.confirmCtrl,
                              obscureText: controller.obscureConfirm.value,
                              onChanged: controller.validateConfirm,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 16.0,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: _inputDecoration(
                                hint: "Enter confirm password",
                                icon: Icons.lock_outline_rounded,
                                isObscure: controller.obscureConfirm.value,
                                onToggle: controller.toggleConfirm,
                              ),
                            ),
                          ),
                          Obx(
                            () => controller.confirmError.value.isEmpty
                                ? const SizedBox()
                                : _errorText(controller.confirmError.value),
                          ),
                        ],
                      ).animate(delay: 300.ms).fade().slideY(begin: 0.2),

                      const SizedBox(height: 30.0),

                      // Update Password Button
                      Obx(() => SizedBox(
                                height: 50.0,
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: controller.isLoading.value
                                      ? null
                                      : controller.submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(18.0),
                                    ),
                                  ),
                                  child: controller.isLoading.value
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Text(
                                          "Update Password",
                                          style: TextStyle(
                                            fontFamily: 'Inter',
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                ),
                              ))
                          .animate(delay: 400.ms)
                          .fade()
                          .slideY(begin: 0.2)
                          .scale(begin: const Offset(0.95, 0.95)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Section Label ────────────────────────────
  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15.0),
      child: Row(
        children: [
          Container(
            width: 4.0,
            height: 18.0,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2.0),
            ),
          ),
          const SizedBox(width: 6.0),
          Text(
            text,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15.0,
              letterSpacing: -0.4,
              fontStyle: FontStyle.italic,
              color: AppColors.textPrimary,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }

  // ── Error Text ────────────────────────────
  Widget _errorText(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 6.0, left: 8.0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontFamily: 'Inter',
            color: Colors.red,
            fontSize: 12.0,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    ).animate().fade(duration: 200.ms).slideY(begin: -0.1);
  }

  // ── Input Decoration ────────────────────────────
  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 13.0,
        color: Colors.grey,
      ),
      prefixIcon: Icon(
        icon,
        size: 20.0,
      ),
      suffixIcon: IconButton(
        icon: Icon(
          isObscure ? Icons.visibility_off : Icons.visibility,
          size: 20.0,
        ),
        onPressed: onToggle,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: BorderSide(
          color: Colors.grey.shade300,
          width: 1.2,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(
          color: AppColors.primary,
          width: 1.6,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16.0),
        borderSide: const BorderSide(color: Colors.red),
      ),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16.0,
        vertical: 16.0,
      ),
    );
  }
}
