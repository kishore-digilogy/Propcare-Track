import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The PropCare mark: a gradient location pin inside a survey orbit.
/// Drawn in code so it stays crisp at every size and can animate.
class AppLogo extends StatelessWidget {
  const AppLogo({
    super.key,
    this.size = 56,
    this.showWordmark = false,
    this.animate = false,
    this.glow = true,
  });

  final double size;
  final bool showWordmark;
  final bool animate;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final mark = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _LogoPainter(glow: glow)),
    );
    if (!showWordmark) return mark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'PROPCARE',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: size * 0.28,
                letterSpacing: size * 0.035,
                height: 1,
                color: AppColors.text,
              ),
            ),
            SizedBox(height: size * 0.07),
            Text(
              'TRACK',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                fontSize: size * 0.15,
                letterSpacing: size * 0.075,
                height: 1,
                color: AppColors.mint.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final cx = s / 2;
    final cy = s * 0.46;
    final r = s * 0.205;
    final tipY = s * 0.82;

    if (glow) {
      final glowPaint = Paint()
        ..color = AppColors.mint.withValues(alpha: 0.2)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.09);
      canvas.drawCircle(Offset(cx, cy), r * 0.9, glowPaint);
    }

    // Orbit ring
    final orbitRect = Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.36);
    final dimRing = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.012
      ..color = AppColors.text.withValues(alpha: 0.12);
    canvas.drawCircle(Offset(cx, cy), s * 0.36, dimRing);

    final brightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.018
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [AppColors.mint, AppColors.cyan])
          .createShader(orbitRect);
    canvas.drawArc(orbitRect, -math.pi * 0.55, math.pi * 0.72, false, brightPaint);

    final coralPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round
      ..color = AppColors.coral;
    canvas.drawArc(orbitRect, math.pi * 0.18, math.pi * 0.16, false, coralPaint);

    // Orbit dot
    final dotAngle = math.pi * 0.26;
    final dotCenter = Offset(cx + math.cos(dotAngle) * s * 0.36, cy + math.sin(dotAngle) * s * 0.36);
    canvas.drawCircle(dotCenter, s * 0.055, Paint()..color = AppColors.coral.withValues(alpha: 0.18));
    canvas.drawCircle(dotCenter, s * 0.026, Paint()..color = AppColors.coral);

    // Pin body
    final pin = Path()
      ..moveTo(cx, tipY)
      ..cubicTo(cx - r * 1.02, cy + r * 0.52, cx - r * 1.12, cy - r * 1.02, cx, cy - r * 1.18)
      ..cubicTo(cx + r * 1.12, cy - r * 1.02, cx + r * 1.02, cy + r * 0.52, cx, tipY)
      ..close();
    final pinRect = Rect.fromLTRB(cx - r * 1.2, cy - r * 1.3, cx + r * 1.2, tipY);
    final pinPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AppColors.mint, AppColors.cyan],
      ).createShader(pinRect);
    canvas.drawPath(pin, pinPaint);

    // Core
    canvas.drawCircle(Offset(cx, cy), r * 0.47, Paint()..color = AppColors.surface);
    canvas.drawCircle(Offset(cx, cy), r * 0.22, Paint()..color = AppColors.coral);
    canvas.drawCircle(
      Offset(cx, cy),
      r * 0.22,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.012
        ..color = AppColors.coral.withValues(alpha: 0.35),
    );
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) => oldDelegate.glow != glow;
}

/// Rotating orbital loader used on splash and while booting.
class OrbitLoader extends StatefulWidget {
  const OrbitLoader({super.key, this.size = 120, this.label});

  final double size;
  final String? label;

  @override
  State<OrbitLoader> createState() => _OrbitLoaderState();
}

class _OrbitLoaderState extends State<OrbitLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 4),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              RotationTransition(
                turns: _controller,
                child: CustomPaint(
                  size: Size(widget.size, widget.size),
                  painter: _OrbitRingPainter(),
                ),
              ),
              AppLogo(size: widget.size * 0.52),
            ],
          ),
        ),
        if (widget.label != null) ...[
          const SizedBox(height: 18),
          Text(
            widget.label!,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              letterSpacing: 3,
              color: AppColors.textDim,
            ),
          ),
        ],
      ],
    );
  }
}

class _OrbitRingPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.44;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = AppColors.text.withValues(alpha: 0.1);
    canvas.drawCircle(center, r, base);
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2
      ..shader = const LinearGradient(colors: [AppColors.mint, AppColors.cyan])
          .createShader(Rect.fromCircle(center: center, radius: r));
    canvas.drawArc(Rect.fromCircle(center: center, radius: r), 0, math.pi * 0.45, false, arc);
    canvas.drawCircle(center + Offset(0, -r), 3, Paint()..color = AppColors.mint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
