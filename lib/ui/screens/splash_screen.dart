import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/background.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: const Interval(0.15, 1, curve: Curves.easeOutCubic));
    final rise = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(fade);

    return Scaffold(
      backgroundColor: AppColors.ink,
      body: AppBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 20, 28, 26),
            child: Column(
              children: [
                const Spacer(flex: 3),
                FadeTransition(
                  opacity: fade,
                  child: SlideTransition(
                    position: rise,
                    child: Column(
                      children: [
                        const OrbitLoader(size: 132),
                        const SizedBox(height: 30),
                        Text(
                          'PROPCARE',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 30,
                            height: 1,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 5,
                            color: AppColors.text,
                            shadows: [
                              Shadow(color: AppColors.mint.withValues(alpha: 0.18), blurRadius: 26),
                            ],
                          ),
                        ),
                        const SizedBox(height: 9),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(width: 26, height: 1, color: AppColors.mint.withValues(alpha: 0.5)),
                            const SizedBox(width: 10),
                            const Text(
                              'TRACK',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                letterSpacing: 6,
                                fontWeight: FontWeight.w600,
                                color: AppColors.mint,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Container(width: 26, height: 1, color: AppColors.mint.withValues(alpha: 0.5)),
                          ],
                        ),
                        const SizedBox(height: 22),
                        Text(
                          AppConfig.appTagline,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            height: 1.5,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(flex: 4),
                FadeTransition(
                  opacity: fade,
                  child: Column(
                    children: [
                      const _BootLine(),
                      const SizedBox(height: 22),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const MonoLabel('OFFLINE FIRST', color: AppColors.textDim),
                            Container(
                              width: 3,
                              height: 3,
                              margin: const EdgeInsets.symmetric(horizontal: 9),
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.textDim),
                            ),
                            MonoLabel(AppConfig.version, color: AppColors.textDim),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BootLine extends StatefulWidget {
  const _BootLine();

  @override
  State<_BootLine> createState() => _BootLineState();
}

class _BootLineState extends State<_BootLine> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          width: 168,
          height: 2,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return Stack(
                children: [
                  Container(color: AppColors.line),
                  FractionallySizedBox(
                    widthFactor: 0.42,
                    child: Transform.translate(
                      offset: Offset((_controller.value * 2 - 0.5) * 168, 0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(colors: [Colors.transparent, AppColors.mint, Colors.transparent]),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: 14),
        const MonoLabel('INITIALIZING SECURE FIELD LOG', color: AppColors.textDim, letterSpacing: 2.6),
      ],
    );
  }
}
