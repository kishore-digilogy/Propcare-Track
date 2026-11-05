import 'package:flutter/material.dart';

/// "Paper Atlas" palette — a bright, white-first control-room look.
/// Every surface is derived from white with soft ink-blue accents so the app
/// feels calm, readable and card-led in daylight.
class AppColors {
  const AppColors._();

  // Base surfaces. `ink` is the page, cards are pure white.
  static const Color ink = Color(0xFFFFFFFF);
  static const Color ink2 = Color(0xFFF7F9FC);
  static const Color ink3 = Color(0xFFEFF3F9);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFF4F7FC);

  // Signal colours, tuned for contrast on white.
  static const Color mint = Color(0xFF0A7F5B);
  static const Color mintDeep = Color(0xFF06664A);
  static const Color cyan = Color(0xFF0B7CB8);
  static const Color coral = Color(0xFFCC4129);
  static const Color amber = Color(0xFFA96200);
  static const Color violet = Color(0xFF5B50C9);
  static const Color rose = Color(0xFFC7356D);

  static const Color text = Color(0xFF101828);
  static const Color textMuted = Color(0xFF667085);
  static const Color textDim = Color(0xFF98A2B3);

  static const Color line = Color(0xFFEDF1F7);
  static const Color lineStrong = Color(0xFFDEE5EF);
  static const Color shadow = Color(0x14101828);

  static const Color success = mint;
  static const Color warning = amber;
  static const Color danger = coral;

  static const LinearGradient aurora = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [mint, cyan],
  );

  static const LinearGradient sunset = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [coral, Color(0xFFF59E0B)],
  );

  static const LinearGradient violetGlow = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [violet, cyan],
  );

  static const LinearGradient panel = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFF8FAFD)],
  );

  static Color withAlpha(Color color, double opacity) => color.withValues(alpha: opacity);
}
