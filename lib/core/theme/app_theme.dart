import 'package:flutter/material.dart';

class AppColors {
  // Brand — purple → pink gradient
  static const primary = Color(0xFF9333EA);
  static const primaryDark = Color(0xFF7C22CE);
  static const primaryLight = Color(0xFFF5F0FF);
  static const secondary = Color(0xFFDB2777);
  static const accent = Color(0xFFDB2777);

  // Semantic
  static const danger = Color(0xFFEF4444);
  static const warning = Color(0xFFF97316);
  static const info = Color(0xFF3B82F6);
  static const success = Color(0xFF10B981);
  static const purple = Color(0xFF9333EA);

  // Surfaces — white background
  static const surface = Colors.white;
  static const surfaceAlt = Color(0xFFFAFAFA);
  static const card = Colors.white;

  // Text
  static const textPrimary = Color(0xFF1A1025);
  static const textSecondary = Color(0xFF64748B);
  static const textTertiary = Color(0xFF94A3B8);

  // Brand gradients
  static const gradientPrimary = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9333EA), Color(0xFFDB2777)],
  );

  static const gradientPrimarySoft = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF9333EA), Color(0xFFC026D3)],
  );

  static const gradientGreen = LinearGradient(
    colors: [Color(0xFF10B981), Color(0xFF059669)],
  );

  static const gradientOrange = LinearGradient(
    colors: [Color(0xFFF59E0B), Color(0xFFDB2777)],
  );

  static const gradientBlue = LinearGradient(
    colors: [Color(0xFF9333EA), Color(0xFF7C3AED)],
  );

  static const gradientRed = LinearGradient(
    colors: [Color(0xFFEF4444), Color(0xFFDB2777)],
  );
}

class AppTheme {
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          primary: AppColors.primary,
          secondary: AppColors.secondary,
          surface: Colors.white,
        ),
        fontFamily: 'Inter',
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          elevation: 0,
          centerTitle: false,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.textPrimary,
          surfaceTintColor: Colors.transparent,
          titleTextStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFF1F5F9)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: AppColors.surfaceAlt,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE8E0F0)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.secondary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.danger),
          ),
          labelStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              color: AppColors.textSecondary,
              fontFamily: 'Inter'),
          hintStyle: const TextStyle(
              fontWeight: FontWeight.normal,
              color: AppColors.textTertiary,
              fontFamily: 'Inter'),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: AppColors.primary,
            textStyle: const TextStyle(
                fontFamily: 'Inter', fontWeight: FontWeight.w600),
          ),
        ),
        chipTheme: ChipThemeData(
          backgroundColor: AppColors.primaryLight,
          selectedColor: AppColors.primary,
          labelStyle: const TextStyle(
              fontFamily: 'Inter', fontSize: 12, fontWeight: FontWeight.w500),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: Colors.white,
          selectedItemColor: AppColors.primary,
          unselectedItemColor: AppColors.textTertiary,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: TextStyle(
              fontFamily: 'Inter', fontSize: 11, fontWeight: FontWeight.w600),
          unselectedLabelStyle: TextStyle(
              fontWeight: FontWeight.normal, fontFamily: 'Inter', fontSize: 11),
        ),
        dividerTheme:
            const DividerThemeData(color: Color(0xFFF1F5F9), thickness: 1),
        tabBarTheme: const TabBarThemeData(
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          labelStyle:
              TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              TextStyle(fontFamily: 'Inter', fontWeight: FontWeight.w500),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
      );

  static ThemeData get dark => light;
}

// ── Reusable gradient container ───────────────────────────────
class GradientBox extends StatelessWidget {
  final Widget child;
  final Gradient gradient;
  final double borderRadius;
  final EdgeInsets padding;

  const GradientBox({
    required this.child,
    required this.gradient,
    this.borderRadius = 16,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: child,
      );
}

// ── Premium white card with soft shadow ───────────────────────
class PremiumCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? borderGradient;

  const PremiumCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.borderGradient,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (borderGradient != null) {
      return Container(
        decoration: BoxDecoration(
          gradient: borderGradient,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(radius - 1),
          ),
          child: child,
        ),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: const Color(0xFFF1F5F9)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}
