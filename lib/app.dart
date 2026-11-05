import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config/app_config.dart';
import 'core/theme/app_theme.dart';
import 'services/app_controller.dart';
import 'ui/screens/home_shell.dart';
import 'ui/screens/login_screen.dart';
import 'ui/screens/onboarding_screen.dart';
import 'ui/screens/splash_screen.dart';

class PropCareApp extends StatefulWidget {
  const PropCareApp({super.key});

  @override
  State<PropCareApp> createState() => _PropCareAppState();
}

class _PropCareAppState extends State<PropCareApp> with WidgetsBindingObserver {
  Timer? _splashTimer;
  bool _minimumSplashElapsed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _splashTimer = Timer(const Duration(milliseconds: 1900), () {
      if (mounted) setState(() => _minimumSplashElapsed = true);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _splashTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = context.read<AppController>();
      if (controller.employee != null) {
        unawaited(controller.onAppResume());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.build(),
      scrollBehavior: const _AppScrollBehavior(),
      home: _Root(showSplash: !_minimumSplashElapsed),
    );
  }
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _Root extends StatelessWidget {
  const _Root({required this.showSplash});

  final bool showSplash;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    Widget child;
    if (showSplash || controller.booting) {
      child = const SplashScreen(key: ValueKey('splash'));
    } else if (!controller.onboardingSeen) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (controller.employee == null) {
      child = const LoginScreen(key: ValueKey('login'));
    } else {
      child = const HomeShell(key: ValueKey('home'));
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 520),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.015),
          end: Offset.zero,
        ).animate(animation);
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: child,
    );
  }
}
