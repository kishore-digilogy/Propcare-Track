import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  const AppTheme._();

  static ThemeData build() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: 'Poppins',
      scaffoldBackgroundColor: AppColors.ink,
      colorScheme: const ColorScheme.light(
        primary: AppColors.mint,
        onPrimary: Colors.white,
        secondary: AppColors.cyan,
        onSecondary: Colors.white,
        tertiary: AppColors.coral,
        surface: AppColors.surface,
        onSurface: AppColors.text,
        error: AppColors.coral,
        onError: Colors.white,
      ),
    );

    final textTheme = base.textTheme
        .apply(bodyColor: AppColors.text, displayColor: AppColors.text)
        .copyWith(
          displayLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 42,
            height: 1.05,
            fontWeight: FontWeight.w700,
            letterSpacing: -1.2,
            color: AppColors.text,
          ),
          displayMedium: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 33,
            height: 1.1,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.9,
            color: AppColors.text,
          ),
          displaySmall: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 26,
            height: 1.15,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.6,
            color: AppColors.text,
          ),
          headlineMedium: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 21,
            height: 1.25,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
            color: AppColors.text,
          ),
          headlineSmall: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17.5,
            height: 1.3,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.2,
            color: AppColors.text,
          ),
          titleLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 15.5,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          titleMedium: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.text,
          ),
          bodyLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14.5,
            height: 1.55,
            fontWeight: FontWeight.w400,
            color: AppColors.text,
          ),
          bodyMedium: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w400,
            color: AppColors.textMuted,
          ),
          bodySmall: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11.5,
            height: 1.5,
            fontWeight: FontWeight.w400,
            color: AppColors.textDim,
          ),
          labelLarge: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
          labelSmall: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9.5,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
            color: AppColors.textDim,
          ),
        );

    return base.copyWith(
      textTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: AppColors.line,
      dividerTheme: const DividerThemeData(color: AppColors.line, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.textMuted, size: 20),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: 'Poppins',
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.text,
        ),
        iconTheme: IconThemeData(color: AppColors.text, size: 22),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceHigh,
        hintStyle: const TextStyle(color: AppColors.textDim, fontSize: 13.5, fontWeight: FontWeight.w400),
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
        border: _border(AppColors.lineStrong),
        enabledBorder: _border(AppColors.lineStrong),
        focusedBorder: _border(AppColors.mint.withValues(alpha: 0.75), width: 1.4),
        errorBorder: _border(AppColors.coral.withValues(alpha: 0.7)),
        focusedErrorBorder: _border(AppColors.coral, width: 1.4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surface,
        contentTextStyle: const TextStyle(color: AppColors.text, fontFamily: 'Poppins', fontSize: 13),
        behavior: SnackBarBehavior.floating,
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.lineStrong),
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: AppColors.line),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        showDragHandle: false,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: textTheme.headlineSmall,
        contentTextStyle: textTheme.bodyMedium,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.mint,
        selectionColor: Color(0x445CF2B4),
        selectionHandleColor: AppColors.mint,
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: _FadeSlideTransitionBuilder(),
          TargetPlatform.iOS: _FadeSlideTransitionBuilder(),
          TargetPlatform.macOS: _FadeSlideTransitionBuilder(),
        },
      ),
    );
  }

  static OutlineInputBorder _border(Color color, {double width = 1}) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );
}

class _FadeSlideTransitionBuilder extends PageTransitionsBuilder {
  const _FadeSlideTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: child,
      ),
    );
  }
}
