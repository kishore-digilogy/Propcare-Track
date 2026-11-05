import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/maps.dart';
import '../../services/app_controller.dart';
import '../sheets/session_sheets.dart';
import '../widgets/app_page.dart';

class OfficeScreen extends StatefulWidget {
  const OfficeScreen({super.key});

  @override
  State<OfficeScreen> createState() => _OfficeScreenState();
}

class _OfficeScreenState extends State<OfficeScreen> {
  @override
  void initState() {
    super.initState();
    // The map on this page must show the employee's real current location,
    // not just the office pin or a stale fix from an earlier session.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppController>().refreshCurrentPosition(silent: true);
    });
  }

  Future<void> _checkIn(BuildContext context) async {
    final controller = context.read<AppController>();
    try {
      await controller.officeCheckIn();
      if (!context.mounted) return;
      AppSnack.show(context, 'Check-in recorded. Background tracking is live.');
      Navigator.of(context).maybePop();
    } on AppException catch (error) {
      if (!context.mounted) return;
      AppSnack.show(context, error.message, error: true);
    }
  }

  Future<void> _checkOut(BuildContext context) async {
    final controller = context.read<AppController>();
    try {
      await controller.officeCheckOut();
      if (!context.mounted) return;
      AppSnack.show(context, 'Check-out complete. Tracking stopped.');
      Navigator.of(context).maybePop();
    } on AppException catch (error) {
      if (!context.mounted) return;
      AppSnack.show(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final office = controller.office;
    if (office == null) {
      return const AppPage(
        child: Center(child: CircularProgressIndicator(color: AppColors.mint)),
      );
    }
    final attendance = controller.attendance;
    final today = controller.todayAttendance;
    final active = controller.isCheckedIn;
    final interrupted = controller.interrupted;
    final distance = controller.distanceToOffice;
    final inside = distance != null && controller.isInsideOffice(distance);
    final report = controller.permissions;
    final issues = report?.issues ?? const <String>[];
    final busy = controller.busy;

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: controller.hasOpenAttendance ? 'Check out' : 'Check in',
            trailing: BatteryPill(level: controller.battery),
          ),
          GlassPanel(
            radius: 26,
            padding: const EdgeInsets.all(14),
            glowColor: inside ? AppColors.mint : null,
            child: Column(
              children: [
                Row(
                  children: [
                    StatusPill(
                      label: inside
                          ? 'AT OFFICE'
                          : distance == null
                          ? 'LOCATING'
                          : 'REMOTE CHECK-IN',
                      color: inside
                          ? AppColors.mint
                          : distance == null
                          ? AppColors.amber
                          : AppColors.cyan,
                      icon: inside
                          ? Icons.check_circle_rounded
                          : Icons.public_rounded,
                    ),
                    const Spacer(),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: MonoLabel(
                          'RADIUS ${office.radiusMeters.round()} M',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                RadarMap(
                  office: office,
                  sites: const [],
                  current: controller.position,
                  accuracy: controller.accuracy,
                  trail: const [],
                  stationary: const [],
                  height: 250,
                  showLegend: false,
                  officeOnly: true,
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _Fact(
                        label: 'DISTANCE',
                        value: distance == null ? '—' : Fmt.distance(distance),
                        accent: inside ? AppColors.mint : AppColors.cyan,
                      ),
                    ),
                    Container(width: 1, height: 30, color: AppColors.line),
                    Expanded(
                      child: _Fact(
                        label: 'ACCURACY',
                        value: controller.position == null
                            ? '—'
                            : '±${controller.accuracy.round()} m',
                        accent:
                            controller.accuracy > AppConfig.poorAccuracyMeters
                            ? AppColors.amber
                            : AppColors.mint,
                      ),
                    ),
                    Container(width: 1, height: 30, color: AppColors.line),
                    Expanded(
                      child: _Fact(
                        label: 'FENCE',
                        value: '${office.radiusMeters.round()} m',
                        accent: AppColors.violet,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (distance != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: geofenceProgress(distance, office.radiusMeters),
                minHeight: 5,
                backgroundColor: AppColors.ink3,
                valueColor: AlwaysStoppedAnimation(
                  inside ? AppColors.mint : AppColors.cyan,
                ),
              ),
            ),
          const SizedBox(height: 18),
          if (interrupted) ...[
            NoticeBanner(
              message:
                  'This session is interrupted. Resume or close it before starting a new day.',
              color: AppColors.amber,
              icon: Icons.history_toggle_off_rounded,
            ),
            const SizedBox(height: 12),
            OutlineButton(
              label: 'Resolve interrupted session',
              icon: Icons.history_toggle_off_rounded,
              color: AppColors.amber,
              onPressed: () => showInterruptedSessionSheet(context),
            ),
          ] else if (active) ...[
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LiveDot(),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          controller.isTrackingLive
                              ? 'Background tracking is live'
                              : 'Tracking is paused',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: controller.isTrackingLive
                                ? AppColors.mint
                                : AppColors.coral,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        label: Fmt.clock(
                          attendance?.workedDuration ?? Duration.zero,
                        ),
                        color: AppColors.cyan,
                        dense: true,
                        icon: Icons.timer_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  InfoRow(
                    icon: Icons.login_rounded,
                    title: 'Checked in at ${Fmt.time(attendance?.checkInAt)}',
                    subtitle:
                        '${attendance?.checkInAccuracy.round()} m accuracy · ${attendance?.checkInBattery}% battery · ${Fmt.dateShort(attendance?.checkInAt)}',
                    accent: AppColors.cyan,
                  ),
                  const Divider(height: 16),
                  InfoRow(
                    icon: Icons.route_rounded,
                    title:
                        '${controller.session?.locationCount ?? 0} breadcrumbs · ${Fmt.distance(controller.todayStats.distanceMeters)}',
                    subtitle: controller.activeSiteVisit == null
                        ? 'No open site visit'
                        : 'On site at ${controller.activeSiteVisit!.siteName}',
                    accent: AppColors.violet,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            const MonoLabel('END OF DAY'),
            const SizedBox(height: 8),
            HoldToConfirmButton(
              label: 'Hold to check out',
              holdLabel: 'Release to cancel…',
              icon: Icons.logout_rounded,
              color: AppColors.coral,
              enabled: !busy,
              onConfirmed: () => _checkOut(context),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check-out closes the attendance record and stops native background tracking. Any open site visit is closed first.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 10.5,
                height: 1.45,
                color: AppColors.textDim,
              ),
            ),
          ] else ...[
            if (today != null && today.checkOutAt != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: NoticeBanner(
                  message:
                      'Day closed at ${Fmt.time(today.checkOutAt)} · ${Fmt.duration(today.workedDuration)} on duty. You can still start another session if needed.',
                  color: AppColors.mint,
                  icon: Icons.task_alt_rounded,
                ),
              ),
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const MonoLabel('LOCATION STAMP'),
                      const Spacer(),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: StatusPill(
                            label: distance == null
                                ? 'LOCATING'
                                : 'READY TO CHECK IN',
                            color: distance == null
                                ? AppColors.amber
                                : AppColors.mint,
                            dense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    distance == null
                        ? 'Waiting for a GPS fix. Your check-in will be stamped as soon as a location is available.'
                        : 'Check in from anywhere — at the office, at home or on the road. Your current location, GPS accuracy and battery level will be stamped on the record.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: 'Check in now',
              icon: Icons.login_rounded,
              loading: busy,
              onPressed: busy ? null : () => _checkIn(context),
            ),
            const SizedBox(height: 9),
            const Center(
              child: Text(
                'Check-in starts the native background tracking session.',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 10,
                  color: AppColors.textDim,
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeading(
            title: 'Tracking readiness',
            subtitle: report == null
                ? 'Checking permissions…'
                : report.isReady
                ? 'All systems ready'
                : '${issues.length} item(s) need attention',
            action: 'Fix',
            onAction: () => showPermissionSheet(context),
          ),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                _Requirement(
                  label: 'Location services',
                  detail: 'GPS must be switched on',
                  ok: report?.locationServiceEnabled ?? false,
                ),
                _Requirement(
                  label: 'Foreground location',
                  detail: 'Stamps your location on attendance',
                  ok: report?.foreground ?? false,
                ),
                _Requirement(
                  label: 'Background location',
                  detail: '"Always allow" keeps tracking alive',
                  ok: report?.background ?? false,
                ),
                _Requirement(
                  label: 'Notifications',
                  detail: 'Shows the ongoing tracking service',
                  ok: report?.notifications ?? false,
                  last: true,
                ),
              ],
            ),
          ),
          if (controller.simulation) ...[
            const SizedBox(height: 22),
            SectionHeading(
              title: 'Demo controls',
              subtitle: 'Desktop simulator · teleport to the office',
              action: 'Refresh',
              onAction: () => controller.refreshCurrentPosition(silent: true),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(
                  label: 'Jump to office',
                  icon: Icons.my_location_rounded,
                  onTap: controller.demoJumpToOffice,
                ),
                PillButton(
                  label: 'Refresh fix',
                  icon: Icons.refresh_rounded,
                  color: AppColors.cyan,
                  onTap: () => controller.refreshCurrentPosition(silent: true),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

class _Fact extends StatelessWidget {
  const _Fact({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonoLabel(label, size: 8, letterSpacing: 1.4),
        const SizedBox(height: 5),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _Requirement extends StatelessWidget {
  const _Requirement({
    required this.label,
    required this.detail,
    required this.ok,
    this.last = false,
  });

  final String label;
  final String detail;
  final bool ok;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InfoRow(
          icon: ok ? Icons.check_circle_rounded : Icons.error_outline_rounded,
          title: label,
          subtitle: detail,
          accent: ok ? AppColors.mint : AppColors.amber,
          trailing: StatusPill(
            label: ok ? 'READY' : 'ACTION',
            color: ok ? AppColors.mint : AppColors.amber,
            dense: true,
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}
