import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';

class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.gradient,
    this.foregroundColor = Colors.white,
    this.height = 54,
    this.expand = true,
    this.radius = 16,
    this.trailing,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final Gradient? gradient;
  final Color foregroundColor;
  final double height;
  final bool expand;
  final double radius;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final child = AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: enabled || loading ? 1 : 0.45,
      child: Container(
        height: height,
        padding: EdgeInsets.symmetric(horizontal: compact ? 16 : 22),
        decoration: BoxDecoration(
          gradient: gradient ?? AppColors.aurora,
          borderRadius: BorderRadius.circular(radius),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: (gradient == null ? AppColors.mint : AppColors.coral).withValues(alpha: 0.22),
                    blurRadius: 26,
                    spreadRadius: -6,
                    offset: const Offset(0, 8),
                  ),
                ]
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Positioned(
              top: 0,
              left: 12,
              right: 12,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.white.withValues(alpha: 0),
                    Colors.white.withValues(alpha: 0.5),
                    Colors.white.withValues(alpha: 0),
                  ]),
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (loading)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: foregroundColor),
                  )
                else if (icon != null) ...[
                  Icon(icon, size: 18, color: foregroundColor),
                  const SizedBox(width: 9),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: compact ? 13 : 14.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.1,
                      color: foregroundColor,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
              ],
            ),
          ],
        ),
      ),
    );

    final button = GestureDetector(
      onTap: enabled ? onPressed : null,
      behavior: HitTestBehavior.opaque,
      child: child,
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class OutlineButton extends StatelessWidget {
  const OutlineButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.color = AppColors.text,
    this.height = 50,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color color;
  final double height;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = GestureDetector(
      onTap: onPressed,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: height,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: AppColors.lineStrong),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadow,
              blurRadius: 16,
              spreadRadius: -6,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: color),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

class IconBubble extends StatelessWidget {
  const IconBubble({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 42,
    this.color = AppColors.text,
    this.background,
    this.badge,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color color;
  final Color? background;
  final int? badge;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final content = Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background ?? AppColors.surfaceHigh,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.lineStrong),
          ),
          child: Icon(icon, size: size * 0.45, color: color),
        ),
        if (badge != null && badge! > 0)
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.surface, width: 1.5),
              ),
              child: Text(
                badge! > 99 ? '99+' : '$badge',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 8,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
    if (onTap == null) return content;
    return Tooltip(
      message: tooltip ?? '',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: content,
        ),
      ),
    );
  }
}

/// Press-and-hold confirmation used for irreversible session actions.
/// The fill communicates progress; releasing early cancels safely.
class HoldToConfirmButton extends StatefulWidget {
  const HoldToConfirmButton({
    super.key,
    required this.label,
    required this.holdLabel,
    required this.onConfirmed,
    this.icon = Icons.power_settings_new_rounded,
    this.color = AppColors.coral,
    this.holdDuration = const Duration(milliseconds: 1300),
    this.enabled = true,
  });

  final String label;
  final String holdLabel;
  final VoidCallback onConfirmed;
  final IconData icon;
  final Color color;
  final Duration holdDuration;
  final bool enabled;

  @override
  State<HoldToConfirmButton> createState() => _HoldToConfirmButtonState();
}

class _HoldToConfirmButtonState extends State<HoldToConfirmButton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.holdDuration,
  );
  bool _confirmed = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) _complete();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _start() {
    if (!widget.enabled || _confirmed) return;
    HapticFeedback.selectionClick();
    _controller.forward();
  }

  void _cancel() {
    if (_confirmed) return;
    _controller.reverse();
  }

  Future<void> _complete() async {
    if (_confirmed) return;
    _confirmed = true;
    HapticFeedback.mediumImpact();
    widget.onConfirmed();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (mounted) {
      _confirmed = false;
      _controller.reset();
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final progress = _controller.value;
        return Listener(
          onPointerDown: (_) => _start(),
          onPointerUp: (_) => _cancel(),
          onPointerCancel: (_) => _cancel(),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: widget.enabled ? 1 : 0.4,
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: widget.color.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: widget.color.withValues(alpha: 0.32)),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  FractionallySizedBox(
                    widthFactor: progress,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            widget.color.withValues(alpha: 0.22),
                            widget.color.withValues(alpha: 0.55),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          progress > 0.85 ? Icons.check_rounded : widget.icon,
                          size: 18,
                          color: widget.color,
                        ),
                        const SizedBox(width: 9),
                        Flexible(
                          child: Text(
                            progress > 0.05 ? widget.holdLabel : widget.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              color: widget.color,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class PillButton extends StatelessWidget {
  const PillButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color = AppColors.mint,
    this.filled = false,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: filled ? color : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: color.withValues(alpha: filled ? 0.9 : 0.28)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: filled ? Colors.white : color),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: filled ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
