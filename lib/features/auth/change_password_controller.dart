import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/api/api_client.dart';
import '../../core/theme/app_theme.dart';

class ChangePasswordController extends GetxController {
  // ── Controllers ─────────────────────────────────────
  final currentCtrl = TextEditingController();
  final newCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  // ── Password Visibility ─────────────────────────────
  RxBool obscureCurrent = true.obs;
  RxBool obscureNew = true.obs;
  RxBool obscureConfirm = true.obs;

  // ── Error Variables (LIKE LOGIN) ────────────────────
  RxString currentError = ''.obs;
  RxString newError = ''.obs;
  RxString confirmError = ''.obs;

  // ── Loading state ───────────────────────────────────
  RxBool isLoading = false.obs;

  // ── Toggle Visibility ───────────────────────────────
  void toggleCurrent() => obscureCurrent.toggle();
  void toggleNew() => obscureNew.toggle();
  void toggleConfirm() => obscureConfirm.toggle();

  // ── CURRENT PASSWORD VALIDATION ─────────────────────
  void validateCurrent(String value) {
    if (value.isEmpty) {
      currentError.value = "Enter current password";
    } else if (value.length < 6) {
      currentError.value = "Password must be at least 6 characters";
    } else {
      currentError.value = '';
    }
  }

  // ── NEW PASSWORD VALIDATION ─────────────────────────
  void validateNew(String value) {
    if (value.isEmpty) {
      newError.value = "Enter new password";
    } else if (value.length < 6) {
      newError.value = "Password must be at least 6 characters";
    } else {
      newError.value = '';
    }
  }

  // ── CONFIRM PASSWORD VALIDATION ─────────────────────
  void validateConfirm(String value) {
    if (value.isEmpty) {
      confirmError.value = "Confirm your password";
    } else if (value != newCtrl.text.trim()) {
      confirmError.value = "Passwords do not match";
    } else {
      confirmError.value = '';
    }
  }

  // ── SUBMIT FUNCTION ─────────────────────────────────
  void submit() {
    validateCurrent(currentCtrl.text);
    validateNew(newCtrl.text);
    validateConfirm(confirmCtrl.text);

    if (currentError.value.isEmpty &&
        newError.value.isEmpty &&
        confirmError.value.isEmpty) {
      changePassword();
    }
  }

  // ── CLEANUP ────────────────────────────────────────
  @override
  void onClose() {
    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
    super.onClose();
  }

  // ── API CALL ─────────────────────────
  void changePassword() async {
    isLoading.value = true;
    try {
      var params = {
        "current_password": currentCtrl.text.trim(),
        "new_password": newCtrl.text.trim(),
        "new_password_confirmation": confirmCtrl.text.trim(),
      };

      final response =
          await ApiClient.instance.put('/auth/change-password', params);

      final successMsg =
          response.data['message'] as String? ?? "Password updated successfully";

      isLoading.value = false;

      // Clear
      currentCtrl.clear();
      newCtrl.clear();
      confirmCtrl.clear();

      Get.snackbar(
        'Success',
        successMsg,
        backgroundColor: AppColors.success,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } on ApiException catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        e.displayMessage,
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    } catch (e) {
      isLoading.value = false;
      Get.snackbar(
        'Error',
        'Something went wrong',
        backgroundColor: AppColors.danger,
        colorText: Colors.white,
        snackPosition: SnackPosition.TOP,
        margin: const EdgeInsets.all(16),
        borderRadius: 12,
      );
    }
  }
}
