import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shimmer/shimmer.dart';
import '../theme/app_theme.dart';

// ── Stat card with gradient ───────────────────────────────────
class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Gradient gradient;
  final VoidCallback? onTap;

  const StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.gradient,
    this.onTap,
    super.key,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color:
                    (gradient as LinearGradient).colors.first.withOpacity(0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 12),
              Text(value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Inter',
                  )),
              const SizedBox(height: 2),
              Text(title,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                  )),
            ],
          ),
        ),
      );
}

// ── Section header ────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
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
                Text(title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      fontStyle: FontStyle.italic,
                      color: AppColors.textPrimary,
                    )),
              ],
            ),
            if (actionLabel != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(actionLabel!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontFamily: 'Inter',
                    )),
              ),
          ],
        ),
      );
}

// ── Info row ──────────────────────────────────────────────────
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;

  const InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                      fontWeight: FontWeight.normal,
                      fontSize: 11,
                      color: AppColors.textSecondary,
                      fontFamily: 'Inter',
                    )),
                Text(value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      fontFamily: 'Inter',
                      color: valueColor ?? AppColors.textPrimary,
                    )),
              ],
            ),
          ),
        ],
      );
}

// ── Status badge ──────────────────────────────────────────────
class StatusBadge extends StatelessWidget {
  final String label;
  final Color color;

  const StatusBadge({required this.label, required this.color, super.key});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Text(label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              fontFamily: 'Inter',
            )),
      );
}

// ── Gradient AppBar ───────────────────────────────────────────
class GradientAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showBack;
  final List<Widget>? actions;
  final Widget? bottom;
  final double expandedHeight;

  const GradientAppBar({
    required this.title,
    this.showBack = true,
    this.actions,
    this.bottom,
    this.expandedHeight = kToolbarHeight,
    super.key,
  });

  @override
  Size get preferredSize => Size.fromHeight(expandedHeight);

  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(gradient: AppColors.gradientPrimary),
        child: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: showBack,
          leading: showBack
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_rounded,
                      color: Colors.white, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null,
          title: Text(title,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'Inter',
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          actions: actions,
        ),
      );
}

// ── Shimmer loading card ──────────────────────────────────────
class ShimmerCard extends StatelessWidget {
  final double height;
  final double? width;
  final double radius;

  const ShimmerCard({
    this.height = 80,
    this.width,
    this.radius = 12,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Shimmer.fromColors(
        baseColor: Colors.grey.shade200,
        highlightColor: Colors.grey.shade100,
        child: Container(
          height: height,
          width: width ?? double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius),
          ),
        ),
      );
}

// ── Empty state ───────────────────────────────────────────────
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
    super.key,
  });

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: AppColors.primary),
              ),
              const SizedBox(height: 20),
              Text(title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 8),
              Text(subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  )),
              if (action != null) ...[const SizedBox(height: 24), action!],
            ],
          ),
        ),
      );
}

// ── Error state ───────────────────────────────────────────────
class ErrorState extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const ErrorState({required this.error, required this.onRetry, super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.danger),
              const SizedBox(height: 16),
              const Text('Something went wrong',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    fontFamily: 'Inter',
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(height: 8),
              Text(error.toString(),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.normal,
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    fontFamily: 'Inter',
                  )),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

// ── Network Avatar ────────────────────────────────────────────
class NetAvatar extends StatelessWidget {
  final String? url;
  final double radius;
  final String fallbackLetter;

  const NetAvatar({
    this.url,
    this.radius = 24,
    this.fallbackLetter = '?',
    super.key,
  });

  String _resolveUrl(String path) {
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    const base =
        'https://laravel-api.emaad-infotech.com/school-management-system/';
    var cleanPath = path.startsWith('/') ? path.substring(1) : path;

    // Prefix 'storage/' if no standard folder prefix is present
    if (!cleanPath.startsWith('storage/') &&
        !cleanPath.startsWith('public/') &&
        !cleanPath.startsWith('uploads/') &&
        !cleanPath.startsWith('images/')) {
      cleanPath = 'storage/' + cleanPath;
    }

    return '$base$cleanPath';
  }

  @override
  Widget build(BuildContext context) {
    final avatarText =
        fallbackLetter.isNotEmpty ? fallbackLetter[0].toUpperCase() : '?';
    final fallbackWidget = CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primaryLight,
      child: Text(
        avatarText,
        style: TextStyle(
          fontFamily: 'Inter',
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.7,
          color: AppColors.primary,
        ),
      ),
    );

    if (url == null || url!.isEmpty) {
      return fallbackWidget;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: CachedNetworkImage(
        imageUrl: _resolveUrl(url!),
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (context, url) => fallbackWidget,
        errorWidget: (context, url, error) => fallbackWidget,
      ),
    );
  }
}

// ── Toast helper ──────────────────────────────────────────────
void showToast(BuildContext context, String message, {bool isError = false}) {
  Get.snackbar(
    isError ? 'Error' : 'Success',
    message,
    backgroundColor: isError ? AppColors.danger : AppColors.success,
    colorText: Colors.white,
    snackPosition: SnackPosition.TOP,
    margin: const EdgeInsets.all(16),
    borderRadius: 12,
  );
}

// ── Date Formatting Utilities ──────────────────────────────────
String formatYmdToDmy(String? ymdStr) {
  if (ymdStr == null || ymdStr.trim().isEmpty) return '';
  try {
    String clean = ymdStr.trim();
    if (clean.contains('T')) {
      clean = clean.split('T')[0];
    } else if (clean.contains(' ')) {
      clean = clean.split(' ')[0];
    }
    final parts = clean.split('-');
    if (parts.length == 3) {
      final year = parts[0];
      final month = parts[1].padLeft(2, '0');
      final day = parts[2].padLeft(2, '0');
      return '$day/$month/$year';
    }
    final dt = DateTime.parse(ymdStr);
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  } catch (_) {
    return ymdStr;
  }
}

String formatDmyToYmd(String? dmyStr) {
  if (dmyStr == null || dmyStr.trim().isEmpty) return '';
  try {
    final parts = dmyStr.trim().split('/');
    if (parts.length == 3) {
      final day = parts[0].padLeft(2, '0');
      final month = parts[1].padLeft(2, '0');
      final year = parts[2];
      return '$year-$month-$day';
    }
  } catch (_) {}
  return dmyStr;
}

String formatYmToMy(String? ymStr) {
  if (ymStr == null || ymStr.trim().isEmpty) return '';
  try {
    final parts = ymStr.trim().split('-');
    if (parts.length >= 2) {
      final year = parts[0];
      final monthInt = int.tryParse(parts[1]);
      if (monthInt != null && monthInt >= 1 && monthInt <= 12) {
        const shortMonths = [
          'Jan',
          'Feb',
          'Mar',
          'Apr',
          'May',
          'Jun',
          'Jul',
          'Aug',
          'Sep',
          'Oct',
          'Nov',
          'Dec'
        ];
        final monthName = shortMonths[monthInt - 1];
        return '$monthName-$year';
      }
      final month = parts[1].padLeft(2, '0');
      return '$month-$year';
    }
  } catch (_) {}
  return ymStr;
}

String formatDateTimeToDmy(DateTime? dt) {
  if (dt == null) return '';
  return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
}

String formatTimeToAmPm(String? timeStr) {
  if (timeStr == null || timeStr.trim().isEmpty) return '';
  try {
    final clean = timeStr.trim();
    final parts = clean.split(':');
    if (parts.isNotEmpty) {
      int hour = int.tryParse(parts[0]) ?? 0;
      int minute = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;

      final period = hour >= 12 ? 'PM' : 'AM';

      int displayHour = hour % 12;
      if (displayHour == 0) {
        displayHour = 12;
      }

      final minuteStr = minute.toString().padLeft(2, '0');
      final hourStr = displayHour.toString().padLeft(2, '0');
      return '$hourStr:$minuteStr $period';
    }
  } catch (_) {}
  return timeStr;
}
