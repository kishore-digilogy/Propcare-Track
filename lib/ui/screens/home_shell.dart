import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/widgets/background.dart';
import '../../services/app_controller.dart';
import '../screens/dashboard_screen.dart';
import '../screens/history_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/sites_screen.dart';
import '../sheets/session_sheets.dart';
import '../widgets/app_page.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  bool _promptedInterrupted = false;
  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptInterrupted());
  }

  void _maybePromptInterrupted() {
    if (!mounted) return;
    final controller = context.read<AppController>();
    if (controller.interrupted && !_promptedInterrupted) {
      _promptedInterrupted = true;
      showInterruptedSessionSheet(context);
    }
  }

  void _select(int index) {
    if (index == _index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();

    if (!controller.interrupted) {
      _promptedInterrupted = false;
    } else if (!_promptedInterrupted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptInterrupted());
    }

    if (controller.error != null && controller.error != _lastError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final message = controller.error;
        if (message == null) return;
        _lastError = message;
        AppSnack.show(context, message, error: true);
        controller.dismissError();
      });
    }

    return Scaffold(
      backgroundColor: AppColors.ink,
      extendBody: true,
      body: AppBackground(
        child: SafeArea(
          bottom: false,
          child: IndexedStack(
            index: _index,
            children: [
              DashboardScreen(onTabSelected: _select),
              const SitesScreen(),
              const HistoryScreen(),
              const ProfileScreen(),
            ],
          ),
        ),
      ),
      bottomNavigationBar: AppNavBar(index: _index, onChanged: _select),
    );
  }
}
