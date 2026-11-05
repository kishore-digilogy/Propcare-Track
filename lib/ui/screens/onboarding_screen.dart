import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/widgets/buttons.dart';
import '../../core/widgets/logo.dart';
import '../../services/app_controller.dart';

/// Clean, attractive and minimalist onboarding screen with illustration and subtle animation.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  bool _finishing = false;

  late final AnimationController _entranceController;
  late final AnimationController _floatController;

  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Smooth entrance transition
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOut,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    // Gentle floating motion for the artwork
    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    )..repeat(reverse: true);

    _entranceController.forward();
  }

  @override
  void dispose() {
    _entranceController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    if (_finishing) return;
    setState(() => _finishing = true);
    await context.read<AppController>().markOnboardingSeen();
    if (mounted) setState(() => _finishing = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ─── Top Bar: Brand + Skip ────────────────────────────────
                  Row(
                    children: [
                      const AppLogo(size: 34),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'PROPCARE TRACK',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: Color(0xFF101828),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: _finishing ? null : _finish,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF64748B),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          minimumSize: const Size(0, 32),
                        ),
                        child: const Text(
                          'SKIP',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // ─── Hero Illustration Banner (Clean & Uncluttered) ──────
                  AnimatedBuilder(
                    animation: _floatController,
                    builder: (context, child) {
                      final floatOffset = math.sin(_floatController.value * math.pi) * 5;
                      return Container(
                        width: double.infinity,
                        height: 185,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Color(0xFFF0F9FF),
                              Color(0xFFE0F2FE),
                              Color(0xFFF8FAFC),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x060F172A),
                              blurRadius: 16,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Soft decorative background glow
                            Container(
                              width: 160,
                              height: 160,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white.withValues(alpha: 0.6),
                              ),
                            ),
                            // Floating Artwork
                            Transform.translate(
                              offset: Offset(0, floatOffset),
                              child: Image.asset(
                                'assets/branding/header_illustration.png',
                                width: 230,
                                height: 175,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // ─── Tag Pill ─────────────────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F1FC),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.location_on, size: 12, color: Color(0xFF0284C7)),
                        SizedBox(width: 4),
                        Text(
                          'FIELD LOG · LOCAL-FIRST',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // ─── Headline & Short Subtitle (Less Content) ─────────────
                  const Text(
                    'One app for\nyour field day.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 28,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF101828),
                      letterSpacing: -0.7,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Seamless attendance, site visits, and quiet background route tracking.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12.5,
                      height: 1.4,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // ─── 3 Clean Minimalist Feature Cards ─────────────────────
                  const _CleanFeatureCard(
                    icon: Icons.login_rounded,
                    iconBg: Color(0xFFE0F2FE),
                    iconColor: Color(0xFF0284C7),
                    title: 'Check in once',
                    subtitle: 'Tap in from anywhere to start your day.',
                  ),
                  const SizedBox(height: 10),
                  const _CleanFeatureCard(
                    icon: Icons.apartment_rounded,
                    iconBg: Color(0xFFF3E8FF),
                    iconColor: Color(0xFF7E3AF2),
                    title: 'Visit your sites',
                    subtitle: 'Automatic geofenced arrival and check-in.',
                  ),
                  const SizedBox(height: 10),
                  const _CleanFeatureCard(
                    icon: Icons.auto_stories_rounded,
                    iconBg: Color(0xFFFEF3C7),
                    iconColor: Color(0xFFD97706),
                    title: 'Read the day back',
                    subtitle: 'Replay your route story with distance and stops.',
                  ),
                  const SizedBox(height: 22),

                  // ─── Get Started Button ───────────────────────────────────
                  GradientButton(
                    label: 'Get started',
                    icon: Icons.arrow_forward_rounded,
                    loading: _finishing,
                    onPressed: _finishing ? null : _finish,
                  ),
                  const SizedBox(height: 10),
                  const Center(
                    child: Text(
                      'Background location continues while screen is locked.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Minimalist & Attractive Feature Card
// ─────────────────────────────────────────────────────────────────────────────
class _CleanFeatureCard extends StatelessWidget {
  const _CleanFeatureCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 19, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
