import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/site_thumbnail_image.dart';
import '../../data/models/day_story.dart';
import '../../data/models/place.dart';
import '../../data/models/tracking.dart';
import '../../services/app_controller.dart';
import '../screens/day_story_screen.dart';
import '../screens/live_tracking_screen.dart';
import '../screens/office_screen.dart';
import '../screens/site_detail_screen.dart';
import '../sheets/session_sheets.dart';
import '../widgets/app_page.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, required this.onTabSelected});

  final ValueChanged<int> onTabSelected;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final employee = controller.employee;
    final office = controller.office;
    if (employee == null || office == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.mint),
      );
    }

    final attendance = controller.attendance;
    final active = controller.isCheckedIn;
    final interrupted = controller.interrupted;
    final live = controller.isTrackingLive;
    final stats = controller.todayStats;
    final distance = controller.distanceToOffice;
    final inside = distance != null && controller.isInsideOffice(distance);
    final trail = controller.recentLocations.reversed
        .map((e) => e.point)
        .toList(growable: false);

    return TabBody(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Top Header with Greeting & Image 2 Illustration ─────────
          _DashboardHeader(
            greeting: _greeting(),
            name: employee.firstName,
            dateStr: Fmt.dateLong(DateTime.now()),
          ),
          const SizedBox(height: 12),

          // ─── Notice & Interrupted Session Banners ─────────────────────
          if (controller.notice != null) ...[
            NoticeBanner(
              message: controller.notice!,
              color: AppColors.mint,
              icon: Icons.check_circle_outline_rounded,
              onDismiss: controller.dismissNotice,
            ),
            const SizedBox(height: 14),
          ],
          if (interrupted) ...[
            NoticeBanner(
              message:
                  'Your last session was interrupted by logout. Resume it or close it to start a new day.',
              color: AppColors.amber,
              icon: Icons.history_toggle_off_rounded,
              action: TextButton(
                onPressed: () => showInterruptedSessionSheet(context),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.amber,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 30),
                ),
                child: const Text(
                  'RESOLVE',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 9,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ─── Check-In / Check-Out Action Card ─────────────────────────
          _CheckInCard(
            active: active,
            interrupted: interrupted,
            live: live,
            battery: controller.battery,
            simulation: controller.simulation,
            attendance: attendance,
            office: office,
            activeSiteName: controller.activeSiteVisit?.siteName,
            distance: distance,
            inside: inside,
            trail: trail,
            sites: controller.sites,
            currentPosition: controller.position,
            accuracy: controller.accuracy,
            stationary: controller.todayStationary,
            activeSiteId: controller.activeSiteVisit?.siteId,
            onCheckIn: () => _openOffice(context),
            onLiveMap: () => _openLive(context),
            onCheckOut: () => _openOffice(context),
            onResolve: () => showInterruptedSessionSheet(context),
            onSiteCheckIn: () => _handleSiteCheckIn(context),
            onSiteCheckOut: () => _handleSiteCheckOut(context),
          ),
          const SizedBox(height: 16),

          // ─── 2x2 Metric Cards Grid (Matching Image 1) ─────────────────
          Row(
            children: [
              Expanded(
                child: _HomeMetricCard(
                  icon: Icons.directions_walk_rounded,
                  iconColor: const Color(0xFF0E9F6E),
                  iconBg: const Color(0xFFE8FDF0),
                  borderColor: const Color(0xFFE2F7E9),
                  cardBg: const Color(0xFFF7FDF9),
                  value: Fmt.distance(stats.distanceMeters),
                  label: 'Distance walked',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeMetricCard(
                  icon: Icons.apartment_rounded,
                  iconColor: const Color(0xFF7E3AF2),
                  iconBg: const Color(0xFFF3E8FF),
                  borderColor: const Color(0xFFF0E5FC),
                  cardBg: const Color(0xFFFAF7FD),
                  value: '${stats.siteVisits}',
                  label: 'Site visits',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _HomeMetricCard(
                  icon: Icons.schedule_rounded,
                  iconColor: const Color(0xFFD97706),
                  iconBg: const Color(0xFFFEF3C7),
                  borderColor: const Color(0xFFFDF0CD),
                  cardBg: const Color(0xFFFFFDF5),
                  value: Fmt.durationCompact(stats.stationary),
                  label: 'Stationary time',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _HomeMetricCard(
                  icon: Icons.route_rounded,
                  iconColor: const Color(0xFF0284C7),
                  iconBg: const Color(0xFFE0F2FE),
                  borderColor: const Color(0xFFDCF0FA),
                  cardBg: const Color(0xFFF4FAFD),
                  value: '${stats.locations}',
                  label: 'Breadcrumbs',
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ─── Assigned Sites Section (Matching Image 1) ────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.location_on, size: 19, color: Color(0xFF0F172A)),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Assigned sites',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onTabSelected(1),
                child: const Text(
                  'View all →',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 142,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: controller.sites.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final site = controller.sites[index];
                final siteDistance = controller.distanceToSite(site);
                final activeSite =
                    controller.activeSiteVisit?.siteId == site.id;
                return _AssignedSiteCard(
                  site: site,
                  siteDistance: siteDistance,
                  activeSite: activeSite,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => SiteDetailScreen(site: site),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // ─── Sessions Today (Multi-Session Breakdown) ──────────────────
          if (controller.todaySessions.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sessions today',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${controller.todaySessions.length} check-in session${controller.todaySessions.length == 1 ? "" : "s"} recorded today',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _openStory(context),
                  child: const Text(
                    'View map →',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final s in controller.todaySessions) ...[
              _TodaySessionCard(
                session: s,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DayStoryScreen(
                      date: DateTime.now(),
                      initialSessionIndex: s.sessionIndex,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 14),
          ],

          // ─── Today's Story Section (Matching Image 1) ─────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 19,
                      color: Color(0xFF0284C7),
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Today’s story',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _openStory(context),
                child: const Text(
                  'Open story →',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'A running timeline of the day',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x080F172A),
                  blurRadius: 16,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: _TodayTimeline(controller: controller),
          ),
          const SizedBox(height: 20),

          // ─── Local-First Phase 1 Card (Matching Image 1) ───────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 14,
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
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.lightbulb_outline_rounded,
                    size: 20,
                    color: Color(0xFF0284C7),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Local-first · Phase 1',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${controller.pendingSync} records queued for a future sync. Nothing leaves this device.',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          height: 1.35,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openStory(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DayStoryScreen(date: DateTime.now())),
    );
  }

  void _openOffice(BuildContext context) {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const OfficeScreen()));
  }

  void _openLive(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const LiveTrackingScreen(standalone: true),
      ),
    );
  }

  Future<void> _handleSiteCheckIn(BuildContext context) async {
    final controller = context.read<AppController>();
    final insideSite = controller.findSiteUserIsInside();
    if (insideSite != null) {
      try {
        await controller.siteCheckIn(insideSite);
        if (!context.mounted) return;
        AppSnack.show(
          context,
          'Checked into ${insideSite.name}. Site visit active.',
        );
      } on AppException catch (e) {
        if (!context.mounted) return;
        AppSnack.show(context, e.message, error: true);
      }
    } else {
      final closest = controller.findClosestSite();
      final msg = closest != null
          ? 'You are not inside any assigned site.\n\nNearest site: ${closest.site.name} (${Fmt.distance(closest.distance)} away).\n\nSite check-in is only allowed when you are physically inside the site geofence boundary (${closest.site.radiusMeters.round()} m).'
          : 'You are not inside any assigned site.\n\nSite check-in is only allowed when you are physically inside the site geofence boundary.';
      if (!context.mounted) return;
      showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.location_off_rounded, color: Color(0xFFD97706)),
              SizedBox(width: 8),
              Text(
                'Outside Site Geofence',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                  color: Color(0xFF101828),
                ),
              ),
            ],
          ),
          content: Text(
            msg,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12.5,
              height: 1.5,
              color: Color(0xFF475569),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Understood',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0284C7),
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _handleSiteCheckOut(BuildContext context) async {
    final controller = context.read<AppController>();
    try {
      await controller.siteCheckOut();
      if (!context.mounted) return;
      AppSnack.show(
        context,
        'Site check-out complete. Background tracking continues.',
      );
    } on AppException catch (e) {
      if (!context.mounted) return;
      AppSnack.show(context, e.message, error: true);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Header with Greeting & Right Illustration (Image 2)
// ─────────────────────────────────────────────────────────────────────────────
class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({
    required this.greeting,
    required this.name,
    required this.dateStr,
  });

  final String greeting;
  final String name;
  final String dateStr;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Illustration on top-right, aligned with header
          Positioned(
            right: -6,
            bottom: -6,
            child: Image.asset(
              'assets/branding/header_illustration.png',
              width: 148,
              height: 128,
              fit: BoxFit.contain,
              alignment: Alignment.bottomRight,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Field Log • Today pill
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4.5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F1FC),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_on, size: 13, color: Color(0xFF0284C7)),
                    SizedBox(width: 4),
                    Text(
                      'Field Log • Today',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0284C7),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 15,
                      color: Color(0xFF0284C7),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // Greeting
              Text(
                '$greeting,\n$name.',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF101828),
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 8),
              // Calendar date
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 13,
                    color: Color(0xFF64748B),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Text(
                      dateStr,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Check-In / Check-Out Action Card
// ─────────────────────────────────────────────────────────────────────────────
class _CheckInCard extends StatelessWidget {
  const _CheckInCard({
    required this.active,
    required this.interrupted,
    required this.live,
    required this.battery,
    required this.simulation,
    required this.attendance,
    required this.office,
    required this.activeSiteName,
    required this.distance,
    required this.inside,
    required this.trail,
    required this.sites,
    required this.currentPosition,
    required this.accuracy,
    required this.stationary,
    required this.activeSiteId,
    required this.onCheckIn,
    required this.onLiveMap,
    required this.onCheckOut,
    required this.onResolve,
    this.onSiteCheckIn,
    this.onSiteCheckOut,
  });

  final bool active;
  final bool interrupted;
  final bool live;
  final int battery;
  final bool simulation;
  final dynamic attendance;
  final dynamic office;
  final String? activeSiteName;
  final double? distance;
  final bool inside;
  final List<dynamic> trail;
  final List<Site> sites;
  final dynamic currentPosition;
  final double? accuracy;
  final List<StationaryEvent> stationary;
  final String? activeSiteId;
  final VoidCallback onCheckIn;
  final VoidCallback onLiveMap;
  final VoidCallback onCheckOut;
  final VoidCallback onResolve;
  final VoidCallback? onSiteCheckIn;
  final VoidCallback? onSiteCheckOut;

  @override
  Widget build(BuildContext context) {
    if (interrupted) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFFD97706).withValues(alpha: 0.3),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x0C0F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                const StatusPill(
                  label: 'INTERRUPTED',
                  color: AppColors.amber,
                  icon: Icons.history_toggle_off_rounded,
                ),
                const Spacer(),
                BatteryPill(level: battery, compact: true),
              ],
            ),
            const SizedBox(height: 12),
            OutlineButton(
              label: 'Resolve session',
              icon: Icons.history_toggle_off_rounded,
              color: AppColors.amber,
              onPressed: onResolve,
            ),
          ],
        ),
      );
    }

    if (active) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: live
                ? const Color(0xFF0E9F6E).withValues(alpha: 0.35)
                : const Color(0xFFE2E8F0),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: live ? const Color(0x0E0E9F6E) : const Color(0x0A0F172A),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  StatusPill(
                    label: live ? 'TRACKING LIVE' : 'TRACKING PAUSED',
                    color: live
                        ? const Color(0xFF0E9F6E)
                        : const Color(0xFFCC4129),
                    icon: live
                        ? Icons.radar_rounded
                        : Icons.pause_circle_outline_rounded,
                  ),
                  const SizedBox(width: 8),
                  BatteryPill(level: battery, compact: true),
                  if (simulation) ...[
                    const SizedBox(width: 8),
                    const StatusPill(
                      label: 'DEMO',
                      color: Color(0xFF7E3AF2),
                      dense: true,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const MonoLabel('ON DUTY'),
                      const SizedBox(height: 4),
                      if (attendance != null)
                        LiveClockText(
                          startAt: attendance.checkInAt,
                          endAt: attendance.checkOutAt,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 27,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: Color(0xFF101828),
                          ),
                        )
                      else
                        const Text(
                          '00:00:00',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 27,
                            height: 1,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.8,
                            color: Color(0xFF101828),
                          ),
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    MonoLabel(
                      'SINCE ${Fmt.time(attendance?.checkInAt).toUpperCase()}',
                    ),
                    const SizedBox(height: 4),
                    Text(
                      activeSiteName ?? office.name,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            if (activeSiteName != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3E8FF),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFD8B4FE)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: const BoxDecoration(
                        color: Color(0xFF7E3AF2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.apartment_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'AT SITE',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: Color(0xFF7E3AF2),
                            ),
                          ),
                          Text(
                            activeSiteName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF101828),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (onSiteCheckOut != null)
                      InkWell(
                        onTap: onSiteCheckOut,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4.5,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF7E3AF2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Site Out',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ] else if (onSiteCheckIn != null) ...[
              const SizedBox(height: 10),
              InkWell(
                onTap: onSiteCheckIn,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFAF5FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE9D5FF),
                      width: 1.1,
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.apartment_rounded,
                        size: 15,
                        color: Color(0xFF7E3AF2),
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Site Check-in',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF7E3AF2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: GradientButton(
                    label: 'Live map',
                    icon: Icons.radar_rounded,
                    height: 48,
                    onPressed: onLiveMap,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlineButton(
                    label: 'Check out',
                    icon: Icons.logout_rounded,
                    color: const Color(0xFFCC4129),
                    onPressed: onCheckOut,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // When NOT checked in
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x080F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          GradientButton(
            label: 'Check in for the day',
            icon: Icons.login_rounded,
            onPressed: onCheckIn,
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                inside
                    ? Icons.check_circle_rounded
                    : Icons.location_on_outlined,
                size: 13,
                color: inside
                    ? const Color(0xFF0E9F6E)
                    : const Color(0xFF0284C7),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  distance == null
                      ? 'Waiting for a GPS fix'
                      : inside
                      ? 'At ${office.name} · ${Fmt.distance(distance!)} away'
                      : 'Remote check-in · ${Fmt.distance(distance!)} from ${office.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: inside
                        ? const Color(0xFF0E9F6E)
                        : const Color(0xFF0284C7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 2x2 Metric Tile (Matching Image 1)
// ─────────────────────────────────────────────────────────────────────────────
class _HomeMetricCard extends StatelessWidget {
  const _HomeMetricCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.borderColor,
    required this.cardBg,
    required this.value,
    required this.label,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final Color borderColor;
  final Color cardBg;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: const [
          BoxShadow(
            color: Color(0x050F172A),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 21,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF101828),
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Assigned Site Card (Matching Image 1)
// ─────────────────────────────────────────────────────────────────────────────
class _AssignedSiteCard extends StatelessWidget {
  const _AssignedSiteCard({
    required this.site,
    required this.siteDistance,
    required this.activeSite,
    required this.onTap,
  });

  final Site site;
  final double? siteDistance;
  final bool activeSite;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 295,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: activeSite
                  ? const Color(0xFF0E9F6E).withValues(alpha: 0.4)
                  : const Color(0xFFE8EEF5),
              width: 1.2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x080F172A),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Left Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Code Pill
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        site.code.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Name
                    Text(
                      site.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Radius
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 13,
                          color: Color(0xFF16A34A),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '${site.radiusMeters.round()} m radius',
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    // Distance
                    Text(
                      activeSite
                          ? 'You are on site'
                          : siteDistance == null
                          ? 'Locating…'
                          : Fmt.distance(siteDistance!),
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: activeSite
                            ? const Color(0xFF0E9F6E)
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Right Illustration with Active Pill
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 3,
                          backgroundColor: Color(0xFF16A34A),
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Active',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  SiteThumbnailImage(
                    siteName: site.name,
                    address: site.address,
                    width: 106,
                    height: 74,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Building Graphic for Site Cards (Matching Image 1)
// ─────────────────────────────────────────────────────────────────────────────
class _SiteBuildingGraphic extends StatelessWidget {
  const _SiteBuildingGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 106,
      height: 74,
      child: CustomPaint(painter: _BuildingVectorPainter()),
    );
  }
}

class _BuildingVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sky backdrop circle
    final skyPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(6, 4, size.width - 12, size.height - 10),
        const Radius.circular(28),
      ),
      skyPaint,
    );

    // 2. Center modern building facade
    final buildingBase = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.fill;
    final buildingSide = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.fill;
    final windowPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final roofAccent = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    // Building side (isometric right angle)
    final sidePath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.16)
      ..lineTo(size.width * 0.82, size.height * 0.28)
      ..lineTo(size.width * 0.82, size.height * 0.86)
      ..lineTo(size.width * 0.54, size.height * 0.90)
      ..close();
    canvas.drawPath(sidePath, buildingSide);

    // Building front (isometric left angle)
    final frontPath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.16)
      ..lineTo(size.width * 0.26, size.height * 0.28)
      ..lineTo(size.width * 0.26, size.height * 0.86)
      ..lineTo(size.width * 0.54, size.height * 0.90)
      ..close();
    canvas.drawPath(frontPath, buildingBase);

    // Roof topper
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.50, size.height * 0.10, 8, 6),
      roofAccent,
    );

    // Windows on front face (3 rows of 2)
    for (var row = 0; row < 4; row++) {
      final yOffset = size.height * (0.34 + row * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.32, yOffset, 8, 6),
          const Radius.circular(1.5),
        ),
        windowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.44, yOffset + 2, 8, 6),
          const Radius.circular(1.5),
        ),
        windowPaint,
      );
    }

    // Windows on side face
    final sideWindowPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;
    for (var row = 0; row < 4; row++) {
      final yOffset = size.height * (0.36 + row * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.59, yOffset + 2, 7, 5),
          const Radius.circular(1.5),
        ),
        sideWindowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.70, yOffset, 7, 5),
          const Radius.circular(1.5),
        ),
        sideWindowPaint,
      );
    }

    // 3. Green lawn curve at bottom
    final grassPaint = Paint()
      ..color = const Color(0xFF86EFAC)
      ..style = PaintingStyle.fill;
    final grassPath = Path()
      ..moveTo(4, size.height * 0.88)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.82,
        size.width - 4,
        size.height * 0.88,
      )
      ..lineTo(size.width - 4, size.height)
      ..lineTo(4, size.height)
      ..close();
    canvas.drawPath(grassPath, grassPaint);

    // 4. Little round trees at sides
    final treeCrown = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    final trunkPaint = Paint()
      ..color = const Color(0xFF92400E)
      ..style = PaintingStyle.fill;

    // Left tree
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.16, size.height * 0.78, 3, 10),
      trunkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.175, size.height * 0.74),
      9,
      treeCrown,
    );

    // Right tree
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.86, size.height * 0.78, 3, 10),
      trunkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.875, size.height * 0.74),
      9,
      treeCrown,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Story Blank State Graphic (Matching Image 1)
// ─────────────────────────────────────────────────────────────────────────────
class _BlankBookIllustration extends StatelessWidget {
  const _BlankBookIllustration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 72,
      height: 48,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE0F2FE).withValues(alpha: 0.7),
            ),
          ),
          const Icon(
            Icons.menu_book_rounded,
            size: 34,
            color: Color(0xFF38BDF8),
          ),
          const Positioned(
            top: 2,
            right: 12,
            child: Icon(Icons.auto_awesome, size: 13, color: Color(0xFFF59E0B)),
          ),
          const Positioned(
            top: 8,
            left: 10,
            child: Icon(Icons.auto_awesome, size: 9, color: Color(0xFFFBBF24)),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Today's Running Timeline
// ─────────────────────────────────────────────────────────────────────────────
class _TodayTimeline extends StatelessWidget {
  const _TodayTimeline({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final events = <_TeaserEvent>[];
    final sessions = controller.todaySessions;

    if (sessions.isNotEmpty) {
      for (final s in sessions) {
        final prefix = sessions.length > 1
            ? 'Session ${s.sessionIndex} · '
            : '';
        events.add(
          _TeaserEvent(
            time: s.checkInAt,
            title: '${prefix}Office check-in',
            subtitle:
                '${s.attendance.checkInAccuracy.round()} m accuracy · ${s.attendance.checkInBattery}% battery',
            icon: Icons.login_rounded,
            color: const Color(0xFF0284C7),
          ),
        );
        for (final visit in s.siteVisits) {
          events.add(
            _TeaserEvent(
              time: visit.checkInAt,
              title: '${prefix}Reached ${visit.siteName}',
              subtitle: 'Site check-in',
              icon: Icons.apartment_rounded,
              color: const Color(0xFF7E3AF2),
            ),
          );
          if (visit.checkOutAt != null) {
            events.add(
              _TeaserEvent(
                time: visit.checkOutAt!,
                title: '${prefix}Left ${visit.siteName}',
                subtitle: Fmt.duration(visit.visitDuration),
                icon: Icons.directions_walk_rounded,
                color: const Color(0xFF7E3AF2),
              ),
            );
          }
        }
        for (final stop in s.stationaryEvents) {
          if (stop.durationSeconds < 20) continue;
          events.add(
            _TeaserEvent(
              time: stop.startAt,
              title:
                  '${prefix}Stationary for ${Fmt.durationCompact(stop.duration)}',
              subtitle: '${stop.radiusMeters.round()} m radius',
              icon: Icons.pause_circle_outline_rounded,
              color: const Color(0xFFD97706),
            ),
          );
        }
        if (s.checkOutAt != null) {
          events.add(
            _TeaserEvent(
              time: s.checkOutAt!,
              title: '${prefix}Office check-out',
              subtitle: Fmt.duration(s.duration),
              icon: Icons.logout_rounded,
              color: const Color(0xFFCC4129),
            ),
          );
        }
      }
    } else {
      final attendance = controller.todayAttendance;
      if (attendance != null) {
        events.add(
          _TeaserEvent(
            time: attendance.checkInAt,
            title: 'Office check-in',
            subtitle:
                '${attendance.checkInAccuracy.round()} m accuracy · ${attendance.checkInBattery}% battery',
            icon: Icons.login_rounded,
            color: const Color(0xFF0284C7),
          ),
        );
      }
      for (final visit in controller.todayVisits) {
        events.add(
          _TeaserEvent(
            time: visit.checkInAt,
            title: 'Reached ${visit.siteName}',
            subtitle: 'Site check-in',
            icon: Icons.apartment_rounded,
            color: const Color(0xFF7E3AF2),
          ),
        );
        if (visit.checkOutAt != null) {
          events.add(
            _TeaserEvent(
              time: visit.checkOutAt!,
              title: 'Left ${visit.siteName}',
              subtitle: Fmt.duration(visit.visitDuration),
              icon: Icons.directions_walk_rounded,
              color: const Color(0xFF7E3AF2),
            ),
          );
        }
      }
      for (final stop in controller.todayStationary) {
        if (stop.durationSeconds < 20) continue;
        events.add(
          _TeaserEvent(
            time: stop.startAt,
            title: 'Stationary for ${Fmt.durationCompact(stop.duration)}',
            subtitle: '${stop.radiusMeters.round()} m radius',
            icon: Icons.pause_circle_outline_rounded,
            color: const Color(0xFFD97706),
          ),
        );
      }
      if (attendance?.checkOutAt != null) {
        events.add(
          _TeaserEvent(
            time: attendance!.checkOutAt!,
            title: 'Office check-out',
            subtitle: Fmt.duration(attendance.workedDuration),
            icon: Icons.logout_rounded,
            color: const Color(0xFFCC4129),
          ),
        );
      }
    }
    events.sort((a, b) => a.time.compareTo(b.time));

    // When empty matching Image 1
    if (events.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            _BlankBookIllustration(),
            SizedBox(height: 12),
            Text(
              'The page is still blank.',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Color(0xFF0F172A),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Check in to begin today’s story. You can check in from anywhere.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 11.5,
                color: Color(0xFF64748B),
              ),
            ),
          ],
        ),
      );
    }

    final visible = events.length > 8
        ? events.sublist(events.length - 8)
        : events;
    return Column(
      children: [
        for (var i = 0; i < visible.length; i++)
          _TimelineRow(
            event: visible[i],
            first: i == 0,
            last: i == visible.length - 1,
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Multi-Session Card (Session 1, 2, 3...)
// ─────────────────────────────────────────────────────────────────────────────
class _TodaySessionCard extends StatelessWidget {
  const _TodaySessionCard({required this.session, required this.onTap});

  final DaySession session;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = session.isCompleted
        ? const Color(0xFF0E9F6E)
        : session.isInterrupted
        ? const Color(0xFFD97706)
        : const Color(0xFF0284C7);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: session.isActive
                ? const Color(0xFF0E9F6E).withValues(alpha: 0.35)
                : const Color(0xFFE8EEF5),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 12,
              offset: Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    session.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                StatusPill(
                  label: session.status.label.toUpperCase(),
                  color: statusColor,
                  dense: true,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${Fmt.time(session.checkInAt)} → ${session.checkOutAt != null ? Fmt.time(session.checkOutAt) : "Live now"}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Worked ${Fmt.duration(session.duration)} · ${Fmt.distance(session.stats.distanceMeters)}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.route_rounded,
                        size: 13,
                        color: Color(0xFF0284C7),
                      ),
                      SizedBox(width: 4),
                      Text(
                        'VIEW MAP',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (session.siteVisits.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final v in session.siteVisits)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8FF),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${v.siteName} (${Fmt.duration(v.visitDuration)})',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7E3AF2),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TeaserEvent {
  const _TeaserEvent({
    required this.time,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final DateTime time;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.event,
    required this.first,
    required this.last,
  });

  final _TeaserEvent event;
  final bool first;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 26,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 6,
                  color: first ? Colors.transparent : const Color(0xFFDEE5EF),
                ),
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: event.color.withValues(alpha: 0.18),
                    border: Border.all(color: event.color, width: 1.5),
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: last ? Colors.transparent : const Color(0xFFDEE5EF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          event.subtitle,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 10,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Fmt.time(event.time),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
