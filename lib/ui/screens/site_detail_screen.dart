import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/maps.dart';
import '../../data/models/place.dart';
import '../../services/app_controller.dart';
import '../screens/office_screen.dart';
import '../widgets/app_page.dart';

class SiteDetailScreen extends StatelessWidget {
  const SiteDetailScreen({super.key, required this.site});

  final Site site;

  Future<void> _checkIn(BuildContext context) async {
    final controller = context.read<AppController>();
    try {
      await controller.siteCheckIn(site);
      if (!context.mounted) return;
      AppSnack.show(context, 'Site check-in recorded at ${site.name}. Tracking continues.');
    } on AppException catch (error) {
      if (!context.mounted) return;
      AppSnack.show(context, error.message, error: true);
    }
  }

  Future<void> _checkOut(BuildContext context) async {
    final controller = context.read<AppController>();
    try {
      await controller.siteCheckOut();
      if (!context.mounted) return;
      AppSnack.show(context, 'Site check-out recorded. Overall tracking is still running.');
    } on AppException catch (error) {
      if (!context.mounted) return;
      AppSnack.show(context, error.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final office = controller.office;
    final distance = controller.distanceToSite(site);
    final inside = distance != null && controller.isInsideSite(site, distance);
    final activeVisit = controller.activeSiteVisit;
    final thisVisit = activeVisit?.siteId == site.id ? activeVisit : null;
    final otherVisit = activeVisit != null && activeVisit.siteId != site.id ? activeVisit : null;
    final anotherVisit = otherVisit != null;
    final attendanceActive = controller.isCheckedIn;
    final busy = controller.busy;
    final trail = controller.recentLocations.reversed.map((e) => e.point).toList(growable: false);
    final visits = controller.siteVisits.where((v) => v.siteId == site.id).toList();

    return AppPage(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: site.name,
            subtitle: '${site.code} · ${site.address}',
            trailing: BatteryPill(level: controller.battery),
          ),
          if (office != null)
            GlassPanel(
              radius: 26,
              padding: const EdgeInsets.all(14),
              glowColor: inside ? AppColors.mint : null,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: StatusPill(
                            label: thisVisit != null
                                ? 'YOU ARE ON SITE'
                                : inside
                                    ? 'AT SITE'
                                    : distance == null
                                        ? 'LOCATING'
                                        : 'REMOTE CHECK-IN',
                            color: thisVisit != null || inside
                                ? AppColors.mint
                                : distance == null
                                    ? AppColors.amber
                                    : AppColors.cyan,
                            icon: thisVisit != null ? Icons.apartment_rounded : Icons.near_me_outlined,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      MonoLabel('FENCE ${site.radiusMeters.round()} M'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  RadarMap(
                    office: office,
                    sites: [site],
                    current: controller.position,
                    accuracy: controller.accuracy,
                    trail: const [],
                    stationary: const [],
                    activeSiteId: activeVisit?.siteId,
                    height: 236,
                    showLegend: false,
                    siteOnly: true,
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _SiteFact(
                          label: 'DISTANCE',
                          value: distance == null ? '—' : Fmt.distance(distance),
                          accent: inside ? AppColors.mint : AppColors.cyan,
                        ),
                      ),
                      Container(width: 1, height: 30, color: AppColors.line),
                      Expanded(
                        child: _SiteFact(
                          label: 'ACCURACY',
                          value: controller.position == null ? '—' : '±${controller.accuracy.round()} m',
                          accent: AppColors.mint,
                        ),
                      ),
                      Container(width: 1, height: 30, color: AppColors.line),
                      Expanded(
                        child: _SiteFact(
                          label: 'VISITS',
                          value: '${visits.length}',
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
                value: geofenceProgress(distance, site.radiusMeters),
                minHeight: 5,
                backgroundColor: AppColors.ink3,
                valueColor: AlwaysStoppedAnimation(inside ? AppColors.mint : AppColors.cyan),
              ),
            ),
          const SizedBox(height: 18),
          if (thisVisit != null) ...[
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              borderColor: AppColors.coral.withValues(alpha: 0.3),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const LiveDot(color: AppColors.coral, size: 7),
                      const SizedBox(width: 7),
                      const Expanded(
                        child: Text(
                          'Site visit in progress',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            color: AppColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      StatusPill(
                        label: Fmt.clock(thisVisit.visitDuration),
                        color: AppColors.coral,
                        dense: true,
                        icon: Icons.timer_outlined,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  InfoRow(
                    icon: Icons.login_rounded,
                    title: 'Checked in at ${Fmt.time(thisVisit.checkInAt)}',
                    subtitle:
                        '${thisVisit.checkInAccuracy.round()} m accuracy · ${thisVisit.checkInBattery}% battery',
                    accent: AppColors.coral,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            HoldToConfirmButton(
              label: 'Hold to check out of site',
              holdLabel: 'Release to cancel…',
              icon: Icons.logout_rounded,
              color: AppColors.coral,
              enabled: !busy,
              onConfirmed: () => _checkOut(context),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Site check-out does not stop the office tracking session.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textDim),
              ),
            ),
          ] else if (!attendanceActive) ...[
            NoticeBanner(
              message: 'You need an active office attendance session before checking in at a site.',
              color: AppColors.amber,
              icon: Icons.info_outline_rounded,
            ),
            const SizedBox(height: 12),
            OutlineButton(
              label: 'Open office attendance',
              icon: Icons.business_rounded,
              color: AppColors.cyan,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const OfficeScreen()),
              ),
            ),
          ] else if (anotherVisit) ...[
            NoticeBanner(
              message: 'You are still checked in at ${otherVisit.siteName}. Check out there first.',
              color: AppColors.amber,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 12),
            OutlineButton(
              label: 'Close ${otherVisit.siteName} visit',
              icon: Icons.logout_rounded,
              color: AppColors.amber,
              onPressed: busy ? null : () => _checkOut(context),
            ),
          ] else ...[
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
                                : inside
                                ? 'INSIDE GEOFENCE · READY'
                                : 'OUTSIDE BOUNDARY',
                            color: distance == null
                                ? AppColors.amber
                                : inside
                                ? AppColors.mint
                                : AppColors.coral,
                            dense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    distance == null
                        ? 'Waiting for a GPS fix. Your site visit can only be started when inside the site geofence.'
                        : inside
                        ? 'You are inside ${site.name}. Ready to check in.'
                        : 'You are currently ${Fmt.distance(distance)} away from ${site.name}. Site check-in requires you to be within the ${site.radiusMeters.round()} m boundary.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            GradientButton(
              label: inside ? 'Start site visit' : 'Start site visit (Outside geofence)',
              icon: inside ? Icons.login_rounded : Icons.location_off_rounded,
              loading: busy,
              gradient: inside
                  ? null
                  : const LinearGradient(colors: [Color(0xFF94A3B8), Color(0xFF64748B)]),
              onPressed: busy ? null : () => _checkIn(context),
            ),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'Office tracking continues while you are on site.',
                style: TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textDim),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SectionHeading(title: 'Site record', subtitle: 'Assigned property details'),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.badge_outlined,
                  title: site.code,
                  subtitle: 'Unique site identifier',
                  accent: AppColors.violet,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.place_outlined,
                  title: site.address,
                  subtitle: '${site.latitude.toStringAsFixed(5)}, ${site.longitude.toStringAsFixed(5)}',
                  accent: AppColors.cyan,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.adjust_rounded,
                  title: '${site.radiusMeters.round()} m site radius',
                  subtitle: 'Configurable per site',
                  accent: AppColors.mint,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.history_rounded,
                  title: visits.isEmpty
                      ? 'No visits this session'
                      : '${visits.length} visit${visits.length == 1 ? "" : "s"} this session',
                  subtitle: visits.isEmpty
                      ? 'Check in when you arrive'
                      : 'Last at ${Fmt.time(visits.last.checkInAt)} · ${Fmt.duration(visits.last.visitDuration)}',
                  accent: AppColors.amber,
                ),
              ],
            ),
          ),
          if (controller.simulation) ...[
            const SizedBox(height: 22),
            SectionHeading(
              title: 'Demo controls',
              subtitle: 'Teleport the simulator to this site',
              action: 'Refresh',
              onAction: () => controller.refreshCurrentPosition(silent: true),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(
                  label: 'Jump to site',
                  icon: Icons.my_location_rounded,
                  onTap: () => controller.demoJumpToSite(site),
                ),
                PillButton(
                  label: 'Jump to office',
                  icon: Icons.business_rounded,
                  color: AppColors.cyan,
                  onTap: controller.demoJumpToOffice,
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

class _SiteFact extends StatelessWidget {
  const _SiteFact({required this.label, required this.value, required this.accent});

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
