import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';
import '../../services/app_controller.dart';
import '../widgets/app_page.dart';

Future<void> showInterruptedSessionSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    (context) => const _InterruptedSessionSheet(),
  );
}

class _InterruptedSessionSheet extends StatefulWidget {
  const _InterruptedSessionSheet();

  @override
  State<_InterruptedSessionSheet> createState() => _InterruptedSessionSheetState();
}

class _InterruptedSessionSheetState extends State<_InterruptedSessionSheet> {
  bool _working = false;
  String? _error;

  Future<void> _resume() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await context.read<AppController>().resumeInterruptedSession();
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _close() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      await context.read<AppController>().closeInterruptedSession();
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final attendance = controller.attendance;
    return SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.amber.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.history_toggle_off_rounded, color: AppColors.amber, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Unfinished session', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    const MonoLabel('RECOVERY REQUIRED', color: AppColors.amber, size: 8.5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'You logged out while the day was still open. All breadcrumbs, site visits and battery logs were preserved. Choose how to continue.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          GlassPanel(
            radius: 18,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.login_rounded,
                  title: 'Checked in ${Fmt.time(attendance?.checkInAt)}',
                  subtitle: Fmt.dateLong(attendance?.checkInAt),
                  accent: AppColors.cyan,
                ),
                const Divider(height: 16),
                InfoRow(
                  icon: Icons.route_rounded,
                  title: '${controller.session?.locationCount ?? 0} points captured',
                  subtitle: 'Tracking was stopped at logout',
                  accent: AppColors.violet,
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            NoticeBanner(message: _error!, color: AppColors.coral, icon: Icons.error_outline_rounded),
          ],
          const SizedBox(height: 18),
          GradientButton(
            label: 'Resume this session',
            icon: Icons.play_arrow_rounded,
            loading: _working,
            onPressed: _working ? null : _resume,
          ),
          const SizedBox(height: 10),
          OutlineButton(
            label: 'Close session and keep records',
            icon: Icons.archive_outlined,
            color: AppColors.textMuted,
            onPressed: _working ? null : _close,
          ),
          const SizedBox(height: 10),
          const Text(
            'Closing marks the session "closed manually". It is never recorded as an office check-out.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10, height: 1.45, color: AppColors.textDim),
          ),
        ],
      ),
    );
  }
}

Future<void> showLogoutSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    (context) => const _LogoutSheet(),
  );
}

class _LogoutSheet extends StatefulWidget {
  const _LogoutSheet();

  @override
  State<_LogoutSheet> createState() => _LogoutSheetState();
}

class _LogoutSheetState extends State<_LogoutSheet> {
  bool _working = false;
  String? _error;

  Future<void> _logout() async {
    setState(() {
      _working = true;
      _error = null;
    });
    final controller = context.read<AppController>();
    try {
      await controller.logout();
      if (mounted) Navigator.of(context).pop();
    } on AppException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (error) {
      if (mounted) setState(() => _error = 'Logout failed. $error');
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final tracking = controller.isTrackingLive;
    final onSite = controller.activeSiteVisit;
    return SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coral.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.coral.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.logout_rounded, color: AppColors.coral, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Leave the field app?', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    const MonoLabel('YOU CAN SIGN BACK IN ANY TIME', color: AppColors.textDim, size: 8.5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tracking) ...[
            NoticeBanner(
              message:
                  'Background tracking is live. Logging out stops it and marks this session Interrupted. This is not an office check-out.',
              color: AppColors.coral,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
          ],
          if (onSite != null) ...[
            NoticeBanner(
              message: 'Your open visit at ${onSite.siteName} will be closed at logout.',
              color: AppColors.amber,
              icon: Icons.location_on_outlined,
            ),
            const SizedBox(height: 12),
          ],
          Text(
            'Attendance, site visits, location breadcrumbs, stationary events and battery logs are preserved locally. You can resume or close an interrupted session after signing back in.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            NoticeBanner(message: _error!, color: AppColors.coral, icon: Icons.error_outline_rounded),
          ],
          const SizedBox(height: 20),
          HoldToConfirmButton(
            label: tracking ? 'Hold to stop tracking & log out' : 'Hold to log out',
            holdLabel: 'Keep holding…',
            icon: Icons.logout_rounded,
            color: AppColors.coral,
            enabled: !_working,
            onConfirmed: _logout,
          ),
          const SizedBox(height: 10),
          OutlineButton(
            label: 'Stay signed in',
            icon: Icons.arrow_back_rounded,
            color: AppColors.textMuted,
            onPressed: _working ? null : () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }
}

Future<void> showPermissionSheet(BuildContext context) {
  return showAppSheet<void>(
    context,
    (context) => const _PermissionSheet(),
  );
}

class _PermissionSheet extends StatefulWidget {
  const _PermissionSheet();

  @override
  State<_PermissionSheet> createState() => _PermissionSheetState();
}

class _PermissionSheetState extends State<_PermissionSheet> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      await context.read<AppController>().requestPermissions();
    } finally {
      if (mounted) setState(() => _requesting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final report = controller.permissions;
    final issues = report?.issues ?? const <String>[];
    return SheetShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.cyan.withValues(alpha: 0.12),
                  border: Border.all(color: AppColors.cyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.shield_outlined, color: AppColors.cyan, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Field permissions', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 2),
                    const MonoLabel('BACKGROUND TRACKING NEEDS THESE', color: AppColors.textDim, size: 8.5),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (issues.isEmpty)
            const NoticeBanner(
              message: 'All permissions are in place. Background tracking can run reliably.',
              color: AppColors.mint,
              icon: Icons.verified_rounded,
            )
          else
            for (final issue in issues) ...[
              InfoRow(
                icon: Icons.radio_button_unchecked_rounded,
                title: issue,
                accent: AppColors.amber,
              ),
            ],
          const SizedBox(height: 8),
          const Text(
            'On Android, choose "Allow all the time" for location. On iOS, choose "Always" and enable Precise Location. Battery optimisation may also pause tracking on some devices.',
            style: TextStyle(fontFamily: 'Poppins', fontSize: 10.5, height: 1.5, color: AppColors.textDim),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'Request permissions',
            icon: Icons.lock_open_rounded,
            loading: _requesting,
            onPressed: _requesting ? null : _request,
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlineButton(
                  label: 'App settings',
                  icon: Icons.settings_outlined,
                  color: AppColors.textMuted,
                  onPressed: controller.openAppSettingsPage,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlineButton(
                  label: 'Location settings',
                  icon: Icons.gps_fixed_rounded,
                  color: AppColors.textMuted,
                  onPressed: controller.openLocationSettingsPage,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
