import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../utils/formatters.dart';

class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.radius = 22,
    this.gradient,
    this.borderColor,
    this.glowColor,
    this.onTap,
    this.blur = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double radius;
  final Gradient? gradient;
  final Color? borderColor;
  final Color? glowColor;
  final VoidCallback? onTap;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        color: gradient == null ? AppColors.surface : null,
        gradient: gradient,
        border: Border.all(color: borderColor ?? AppColors.line),
        boxShadow: [
          if (glowColor != null)
            BoxShadow(
              color: glowColor!.withValues(alpha: 0.18),
              blurRadius: 34,
              spreadRadius: -8,
              offset: const Offset(0, 10),
            ),
          const BoxShadow(
            color: AppColors.shadow,
            blurRadius: 24,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );

    final clipped = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: blur
          ? BackdropFilter(filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16), child: content)
          : content,
    );

    if (onTap == null) return clipped;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        splashColor: AppColors.mint.withValues(alpha: 0.06),
        highlightColor: AppColors.mint.withValues(alpha: 0.03),
        child: clipped,
      ),
    );
  }
}

class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color, this.size = 10, this.letterSpacing = 2.0});

  final String text;
  final Color? color;
  final double size;
  final double letterSpacing;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: size,
        letterSpacing: letterSpacing,
        fontWeight: FontWeight.w500,
        color: color ?? AppColors.textDim,
      ),
    );
  }
}

class SectionHeading extends StatelessWidget {
  const SectionHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.onAction,
    this.padding = const EdgeInsets.fromLTRB(2, 0, 2, 12),
  });

  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.headlineSmall),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, top: 4, bottom: 2),
                child: Row(
                  children: [
                    Text(
                      action!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.mint,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(Icons.arrow_forward_rounded, size: 14, color: AppColors.mint),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.color = AppColors.mint,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: dense ? 8 : 10, vertical: dense ? 4 : 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 10 : 12, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: dense ? 10 : 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.3,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class LiveDot extends StatefulWidget {
  const LiveDot({super.key, this.color = AppColors.mint, this.size = 8});

  final Color color;
  final double size;

  @override
  State<LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size * 2.6,
      height: widget.size * 2.6,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: widget.size * (1 + t * 1.6),
                height: widget.size * (1 + t * 1.6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: (1 - t) * 0.28),
                ),
              ),
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color,
                  boxShadow: [
                    BoxShadow(color: widget.color.withValues(alpha: 0.6), blurRadius: 8),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A self-updating digital clock text widget that ticks every second in real-time.
class LiveClockText extends StatefulWidget {
  const LiveClockText({
    super.key,
    required this.startAt,
    this.endAt,
    this.style,
  });

  final DateTime startAt;
  final DateTime? endAt;
  final TextStyle? style;

  @override
  State<LiveClockText> createState() => _LiveClockTextState();
}

class _LiveClockTextState extends State<LiveClockText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  void _startTimerIfNeeded() {
    if (widget.endAt == null) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void didUpdateWidget(covariant LiveClockText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.endAt != null) {
      _timer?.cancel();
      _timer = null;
    } else if (widget.startAt != oldWidget.startAt || _timer == null) {
      _startTimerIfNeeded();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final end = widget.endAt ?? DateTime.now();
    final diff = end.difference(widget.startAt);
    final duration = diff.isNegative ? Duration.zero : diff;
    return Text(
      Fmt.clock(duration),
      style: widget.style,
    );
  }
}

class BatteryPill extends StatelessWidget {
  const BatteryPill({super.key, required this.level, this.compact = false});

  final int level;
  final bool compact;

  Color get _color {
    if (level <= 15) return AppColors.coral;
    if (level <= 35) return AppColors.amber;
    return AppColors.mint;
  }

  IconData get _icon {
    if (level <= 10) return Icons.battery_alert_rounded;
    if (level <= 25) return Icons.battery_1_bar_rounded;
    if (level <= 50) return Icons.battery_3_bar_rounded;
    if (level <= 80) return Icons.battery_5_bar_rounded;
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 10, vertical: compact ? 4 : 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: _color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_icon, size: compact ? 13 : 15, color: _color),
          const SizedBox(width: 4),
          Text(
            '$level%',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w600,
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.seed = 'mint',
    this.showStatus = false,
    this.statusColor = AppColors.mint,
  });

  final String name;
  final double size;
  final String seed;
  final bool showStatus;
  final Color statusColor;

  @override
  Widget build(BuildContext context) {
    final gradient = seed == 'coral'
        ? const LinearGradient(colors: [AppColors.coral, AppColors.rose])
        : const LinearGradient(colors: [AppColors.mint, AppColors.cyan]);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: gradient,
              border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
            ),
            alignment: Alignment.center,
            child: Text(
              Fmt.initials(name),
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w700,
                fontSize: size * 0.34,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          if (showStatus)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: size * 0.28,
                height: size * 0.28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: statusColor,
                  border: Border.all(color: AppColors.ink, width: 2),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.unit,
    this.accent = AppColors.mint,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String value;
  final String label;
  final String? unit;
  final Color accent;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      radius: 18,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 14, color: accent),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.6,
                    color: AppColors.text,
                  ),
                ),
              ),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Text(
                  unit!,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    color: AppColors.textDim,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 5),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  const InfoRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.accent = AppColors.textMuted,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11.5,
                        height: 1.35,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.accent = AppColors.mint,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 16),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: accent.withValues(alpha: 0.08),
              border: Border.all(color: accent.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: accent, size: 26),
          ),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.headlineSmall, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 18), action!],
        ],
      ),
    );
  }
}

class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.width = 44, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 4,
      decoration: BoxDecoration(
        color: color ?? AppColors.lineStrong,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class StaggeredFade extends StatefulWidget {
  const StaggeredFade({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = 18,
  });

  final Widget child;
  final int index;
  final double offset;

  @override
  State<StaggeredFade> createState() => _StaggeredFadeState();
}

class _StaggeredFadeState extends State<StaggeredFade> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );
  late final Animation<double> _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: Offset(0, widget.offset / 100),
    end: Offset.zero,
  ).animate(_fade);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(Duration(milliseconds: 70 * widget.index), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _slide, child: widget.child),
    );
  }
}

class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.formatter,
    this.style,
    this.duration = const Duration(milliseconds: 700),
  });

  final double value;
  final String Function(double) formatter;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(formatter(animated), style: style),
    );
  }
}

class ProgressRing extends StatelessWidget {
  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 42,
    this.strokeWidth = 3.5,
    this.color = AppColors.mint,
    this.trackColor,
    this.child,
  });

  final double progress;
  final double size;
  final double strokeWidth;
  final Color color;
  final Color? trackColor;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingPainter(
          progress: progress.clamp(0, 1),
          strokeWidth: strokeWidth,
          color: color,
          trackColor: trackColor ?? AppColors.line,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter({
    required this.progress,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double progress;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(strokeWidth / 2, strokeWidth / 2, size.width - strokeWidth, size.height - strokeWidth);
    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawArc(rect, 0, 6.28318, false, track);
    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -1.5708,
        endAngle: 4.7124,
        colors: [color.withValues(alpha: 0.35), color],
      ).createShader(rect);
    canvas.drawArc(rect, -1.5708, 6.28318 * progress, false, paint);
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}
