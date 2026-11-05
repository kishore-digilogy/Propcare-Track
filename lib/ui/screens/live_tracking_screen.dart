import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/geo_address_text.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/maps.dart';
import '../../data/models/tracking.dart';
import '../../services/app_controller.dart';
import '../screens/office_screen.dart';
import '../sheets/session_sheets.dart';
import '../widgets/app_page.dart';

class LiveTrackingScreen extends StatelessWidget {
  const LiveTrackingScreen({super.key, this.standalone = false});

  /// When true the screen is pushed as its own route with a back button.
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final session = controller.session;
    final active = controller.isCheckedIn;
    final interrupted = controller.interrupted;
    final live = controller.isTrackingLive;
    final office = controller.office;
    final trail = controller.recentLocations.reversed.map((e) => e.point).toList(growable: false);
    final levels = controller.batteryLogs.reversed.map((log) => log.level).toList(growable: false);

    if (office == null) {
      return const Center(child: CircularProgressIndicator(color: AppColors.mint));
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!standalone)
          TabHeader(
            eyebrow: 'BACKGROUND ENGINE',
            title: 'The radar,\nright now.',
            subtitle: session == null ? 'No tracking session yet' : 'Session started ${Fmt.time(session.startedAt)}',
            trailing: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (live ? AppColors.mint : AppColors.textDim).withValues(alpha: 0.1),
                border: Border.all(color: (live ? AppColors.mint : AppColors.textDim).withValues(alpha: 0.3)),
              ),
              child: Icon(
                live ? Icons.radar_rounded : Icons.radar_outlined,
                color: live ? AppColors.mint : AppColors.textDim,
                size: 22,
              ),
            ),
          ),
          if (interrupted) ...[
            NoticeBanner(
              message: 'Tracking is stopped because the session was interrupted by logout.',
              color: AppColors.amber,
              icon: Icons.pause_circle_outline_rounded,
              action: TextButton(
                onPressed: () => showInterruptedSessionSheet(context),
                style: TextButton.styleFrom(foregroundColor: AppColors.amber),
                child: const Text('RESOLVE'),
              ),
            ),
            const SizedBox(height: 14),
          ] else if (active && !live) ...[
            const NoticeBanner(
              message: 'The attendance session is active but background tracking is paused. Open office attendance to resume.',
              color: AppColors.coral,
              icon: Icons.warning_amber_rounded,
            ),
            const SizedBox(height: 14),
          ],
          GlassPanel(
            radius: 28,
            padding: const EdgeInsets.all(14),
            glowColor: live ? AppColors.mint : null,
            child: Column(
              children: [
                Builder(
                  builder: (context) {
                    final visitedSiteIds = controller.siteVisits.map((v) => v.siteId).toSet();
                    final relevantSites = controller.sites.where((s) =>
                      visitedSiteIds.contains(s.id) || s.id == controller.activeSiteVisit?.siteId
                    ).toList();

                    return RadarMap(
                      office: office,
                      sites: relevantSites,
                      current: controller.position,
                      accuracy: controller.accuracy,
                      trail: trail,
                      stationary: controller.todayStationary,
                      activeSiteId: controller.activeSiteVisit?.siteId,
                      height: 420,
                      showLegend: false,
                    );
                  },
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: StatusPill(
                          label: live ? 'STREAMING' : active ? 'PAUSED' : 'OFFLINE',
                          color: live ? AppColors.mint : active ? AppColors.coral : AppColors.textDim,
                          icon: live ? Icons.sensors_rounded : Icons.sensors_off_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    MonoLabel(
                      controller.positionSimulated ? 'SIMULATED FIX' : 'GPS FIX',
                      color: controller.positionSimulated ? AppColors.violet : AppColors.cyan,
                      size: 8.5,
                    ),
                    const SizedBox(width: 8),
                    BatteryPill(level: controller.battery, compact: true),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _LiveFact(
                        label: 'LATITUDE',
                        value: controller.position == null
                            ? '—'
                            : controller.position!.latitude.toStringAsFixed(5),
                        accent: AppColors.mint,
                      ),
                    ),
                    Expanded(
                      child: _LiveFact(
                        label: 'LONGITUDE',
                        value: controller.position == null
                            ? '—'
                            : controller.position!.longitude.toStringAsFixed(5),
                        accent: AppColors.mint,
                      ),
                    ),
                    Expanded(
                      child: _LiveFact(
                        label: 'ACCURACY',
                        value: controller.position == null ? '—' : '±${controller.accuracy.round()} m',
                        accent: controller.accuracy > AppConfig.poorAccuracyMeters ? AppColors.amber : AppColors.cyan,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _LiveFact(
                        label: 'UPDATED',
                        value: Fmt.relative(controller.positionAt),
                        accent: AppColors.violet,
                      ),
                    ),
                    Expanded(
                      child: _LiveFact(
                        label: 'POINTS',
                        value: '${session?.locationCount ?? 0}',
                        accent: AppColors.cyan,
                      ),
                    ),
                    Expanded(
                      child: _LiveFact(
                        label: 'DISTANCE',
                        value: Fmt.distance(session?.distanceMeters ?? controller.todayStats.distanceMeters),
                        accent: AppColors.mint,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 28,
                        height: 28,
                        decoration: const BoxDecoration(
                          color: Color(0xFFE0F2FE),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.location_on_rounded, size: 15, color: Color(0xFF0284C7)),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'CURRENT ADDRESS',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(height: 1.5),
                            controller.position == null
                                ? const Text('Locating address…', style: TextStyle(fontFamily: 'Poppins', fontSize: 11, color: Color(0xFF64748B)))
                                : GeoAddressText(
                                    latitude: controller.position!.latitude,
                                    longitude: controller.position!.longitude,
                                    fallbackText: controller.currentAddress,
                                    maxLines: 2,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (session == null)
            GlassPanel(
              radius: 22,
              padding: const EdgeInsets.all(6),
              child: EmptyState(
                icon: Icons.radar_rounded,
                title: 'No live session',
                message: 'Check in to start the native background tracking engine.',
                action: GradientButton(
                  label: 'Open office attendance',
                  icon: Icons.business_rounded,
                  height: 46,
                  expand: false,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OfficeScreen()),
                  ),
                ),
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: MetricTile(
                    icon: Icons.timer_outlined,
                    value: Fmt.clock(session.liveDuration),
                    label: 'Session uptime',
                    accent: AppColors.cyan,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: MetricTile(
                    icon: Icons.pause_circle_outline_rounded,
                    value: Fmt.durationCompact(controller.todayStats.stationary),
                    label: 'Stationary today',
                    accent: AppColors.amber,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SectionHeading(
              title: 'Battery trace',
              subtitle: '${controller.batteryLogs.length} checkpoints logged',
              action: 'Refresh',
              onAction: controller.refreshToday,
            ),
            GlassPanel(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                children: [
                  BatterySparkline(
                    levels: levels.isEmpty ? [controller.battery, controller.battery] : levels,
                    color: controller.battery <= 20 ? AppColors.coral : AppColors.mint,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      MonoLabel('START ${session.startBattery}%'),
                      const Spacer(),
                      MonoLabel('NOW ${controller.battery}%', color: AppColors.mint),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            SectionHeading(
              title: 'Stationary events',
              subtitle: '20 s threshold · 30 m tolerance',
              action: '${controller.stationaryEvents.length}',
            ),
            if (controller.stationaryEvents.isEmpty)
              const GlassPanel(
                radius: 20,
                padding: EdgeInsets.all(6),
                child: EmptyState(
                  icon: Icons.pause_circle_outline_rounded,
                  title: 'No stops detected yet',
                  message: 'A stop is recorded after 20 seconds inside a 30 m radius, with GPS jitter filtered out.',
                  accent: AppColors.amber,
                ),
              )
            else
              GlassPanel(
                radius: 20,
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
                child: Column(
                  children: [
                    for (var i = 0; i < controller.stationaryEvents.length; i++)
                      _StationaryRow(
                        event: controller.stationaryEvents[controller.stationaryEvents.length - 1 - i],
                        last: i == controller.stationaryEvents.length - 1,
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 22),
            SectionHeading(
              title: 'Recent breadcrumbs',
              subtitle: 'Newest first · ${controller.recentLocations.length} shown',
            ),
            GlassPanel(
              radius: 20,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
              child: controller.recentLocations.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 18),
                      child: Text(
                        'Waiting for the first location fix…',
                        style: TextStyle(fontFamily: 'Poppins', fontSize: 11.5, color: AppColors.textDim),
                      ),
                    )
                  : Column(
                      children: [
                        for (var i = 0; i < controller.recentLocations.length; i++)
                          _BreadcrumbRow(
                            record: controller.recentLocations[i],
                            last: i == controller.recentLocations.length - 1,
                          ),
                      ],
                    ),
            ),
          ],
          const SizedBox(height: 22),
          SectionHeading(title: 'Tracking engine', subtitle: 'How this session is being captured'),
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
            child: Column(
              children: [
                InfoRow(
                  icon: Icons.memory_rounded,
                  title: controller.simulation ? 'Simulated platform' : 'Native background service',
                  subtitle: controller.simulation
                      ? 'Deterministic demo route on this desktop build'
                      : 'Kotlin foreground service / Swift Core Location',
                  accent: AppColors.violet,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.schedule_rounded,
                  title: '${AppConfig.locationIntervalMs ~/ 1000} s cadence · ${AppConfig.distanceFilterMeters.round()} m filter',
                  subtitle: 'Stationary after ${AppConfig.stationaryThreshold.inSeconds} s inside ${AppConfig.stationaryRadiusMeters.round()} m',
                  accent: AppColors.cyan,
                ),
                const Divider(height: 1),
                InfoRow(
                  icon: Icons.cloud_off_rounded,
                  title: '${controller.pendingSync} records pending sync',
                  subtitle: 'Local queue retained across force-close and reboot',
                  accent: AppColors.mint,
                ),
              ],
            ),
          ),
          if (controller.simulation) ...[
            const SizedBox(height: 22),
            SectionHeading(title: 'Demo controls', subtitle: 'Drive the simulated journey'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                PillButton(
                  label: 'Jump to office',
                  icon: Icons.business_rounded,
                  onTap: controller.demoJumpToOffice,
                ),
                for (final site in controller.sites)
                  PillButton(
                    label: 'Jump to ${site.code}',
                    icon: Icons.apartment_rounded,
                    color: AppColors.violet,
                    onTap: () => controller.demoJumpToSite(site),
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
    );

    if (standalone) {
      return AppPage(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const PageHeader(
              title: 'Live map',
              subtitle: 'Route, signal and battery',
            ),
            content,
          ],
        ),
      );
    }
    return TabBody(child: content);
  }
}

class _LiveFact extends StatelessWidget {
  const _LiveFact({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MonoLabel(label, size: 7.5, letterSpacing: 1.2),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: accent,
          ),
        ),
      ],
    );
  }
}

class _StationaryRow extends StatelessWidget {
  const _StationaryRow({required this.event, required this.last});

  final StationaryEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final color = event.isActive ? AppColors.coral : AppColors.amber;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(Icons.pause_circle_outline_rounded, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${event.isActive ? "Currently stationary" : "Stopped"} · ${Fmt.duration(event.duration)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    GeoAddressText(
                      latitude: event.latitude,
                      longitude: event.longitude,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    const SizedBox(height: 1.5),
                    Text(
                      '${Fmt.time(event.startAt)} → ${Fmt.time(event.endAt)} · ${event.radiusMeters.round()} m radius',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 9.5, color: AppColors.textDim),
                    ),
                  ],
                ),
              ),
              Text(
                '±${event.accuracy.round()} m',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}

class _BreadcrumbRow extends StatelessWidget {
  const _BreadcrumbRow({required this.record, required this.last});

  final LocationRecord record;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 4),
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: record.source == 'simulated' ? AppColors.violet : AppColors.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GeoAddressText(
                      latitude: record.latitude,
                      longitude: record.longitude,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${record.latitude.toStringAsFixed(5)}, ${record.longitude.toStringAsFixed(5)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        color: AppColors.textDim,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  '±${record.accuracy.round()} m',
                  style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, color: AppColors.cyan),
                ),
              ),
              const SizedBox(width: 8),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: SizedBox(
                  width: 52,
                  child: Text(
                    Fmt.time(record.recordedAt),
                    textAlign: TextAlign.right,
                    style: const TextStyle(fontFamily: 'Poppins', fontSize: 9, color: AppColors.textDim),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!last) const Divider(height: 1),
      ],
    );
  }
}
