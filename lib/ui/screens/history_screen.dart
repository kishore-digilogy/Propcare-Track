import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/geo_address_text.dart';
import '../../data/models/attendance.dart';
import '../../data/models/day_story.dart';
import '../../services/app_controller.dart';
import '../screens/day_story_screen.dart';
import '../screens/office_screen.dart';
import '../widgets/app_page.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final history = controller.history;
    final totalDistance = history.fold<double>(0, (sum, day) => sum + day.stats.distanceMeters);
    final totalSites = history.fold<int>(0, (sum, day) => sum + day.siteVisitCount);
    final totalSeconds = history.fold<int>(0, (sum, day) => sum + day.stats.trackingSeconds);

    return TabBody(
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 118),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Header ────────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F1FC),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history_rounded, size: 13, color: Color(0xFF0284C7)),
                  SizedBox(width: 4),
                  Text(
                    'FIELD ARCHIVE · ACTIVITY LOG',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Days that\nadd up.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 27,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF101828),
                    letterSpacing: -0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: controller.pendingSync > 0
                      ? const Color(0xFFFEF3C7)
                      : const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: controller.pendingSync > 0
                        ? const Color(0xFFFDE68A)
                        : const Color(0xFF86EFAC),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      controller.pendingSync > 0
                          ? Icons.cloud_off_rounded
                          : Icons.cloud_done_rounded,
                      size: 14,
                      color: controller.pendingSync > 0
                          ? const Color(0xFFD97706)
                          : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      controller.pendingSync > 0
                          ? '${controller.pendingSync} PENDING'
                          : 'ALL SYNCED',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: controller.pendingSync > 0
                            ? const Color(0xFFD97706)
                            : const Color(0xFF16A34A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            history.isEmpty
                ? 'Completed and interrupted days live here'
                : '${history.length} recorded day${history.length == 1 ? "" : "s"} · newest first',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Overview Hero Card ───────────────────────────────────────────
          if (history.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: _HeroStat(
                          icon: Icons.directions_walk_rounded,
                          iconColor: const Color(0xFF0E9F6E),
                          iconBg: const Color(0xFFE8FDF0),
                          label: 'TOTAL DISTANCE',
                          value: Fmt.distance(totalDistance),
                        ),
                      ),
                      Container(width: 1.2, height: 44, color: const Color(0xFFF1F5F9)),
                      Expanded(
                        child: _HeroStat(
                          icon: Icons.apartment_rounded,
                          iconColor: const Color(0xFF7E3AF2),
                          iconBg: const Color(0xFFF3E8FF),
                          label: 'SITE VISITS',
                          value: '$totalSites',
                        ),
                      ),
                      Container(width: 1.2, height: 44, color: const Color(0xFFF1F5F9)),
                      Expanded(
                        child: _HeroStat(
                          icon: Icons.schedule_rounded,
                          iconColor: const Color(0xFF0284C7),
                          iconBg: const Color(0xFFE0F2FE),
                          label: 'ON DUTY',
                          value: Fmt.durationCompact(Duration(seconds: totalSeconds)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Activity Streak bar
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Row(
                      children: [
                        for (var i = 0; i < history.length.clamp(1, 14); i++)
                          Expanded(
                            child: Container(
                              height: 5,
                              margin: EdgeInsets.only(
                                right: i == history.length.clamp(1, 14) - 1 ? 0 : 3,
                              ),
                              decoration: BoxDecoration(
                                color: i.isEven
                                    ? const Color(0xFF0E9F6E).withValues(alpha: 0.65)
                                    : const Color(0xFF0284C7).withValues(alpha: 0.5),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // ─── Day Archive Section ─────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Day archive',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Tap any day to replay its route story',
                        style: TextStyle(
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
                  onTap: controller.refreshToday,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Refresh',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                      SizedBox(width: 3),
                      Icon(Icons.arrow_forward_rounded, size: 14, color: Color(0xFF0284C7)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (final day in history) ...[
              _DayCard(summary: day),
              const SizedBox(height: 14),
            ],
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
              ),
              child: Column(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3E8FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_stories_outlined,
                      size: 28,
                      color: Color(0xFF7E3AF2),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'The archive is empty',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Finish an office attendance session and the day will be written into a route story you can replay any time.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const OfficeScreen()),
                    ),
                    icon: const Icon(Icons.business_rounded, size: 17),
                    label: const Text('Open office attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),

          // ─── Local Storage Card ───────────────────────────────────────────
          const Row(
            children: [
              Icon(Icons.storage_rounded, size: 18, color: Color(0xFF0F172A)),
              SizedBox(width: 6),
              Text(
                'Local storage',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A),
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(
            'Phase 1 keeps every record on this device',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 11.5,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<Map<String, Object?>>(
            future: controller.storageStats(),
            builder: (context, snapshot) {
              final data = snapshot.data;
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x060F172A),
                      blurRadius: 14,
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
                            color: const Color(0xFFDCFCE7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.storage_rounded,
                            size: 19,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'propcare_track.db',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                'SQLite Offline-First Storage',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'LOCAL ONLY',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Counters
                    Row(
                      children: [
                        Expanded(
                          child: _StoreCountTile(
                            label: 'Sessions',
                            value: data?['attendance'] ?? 0,
                            icon: Icons.login_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StoreCountTile(
                            label: 'GPS Fixes',
                            value: data?['locations'] ?? 0,
                            icon: Icons.route_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StoreCountTile(
                            label: 'Stops',
                            value: data?['stationary'] ?? 0,
                            icon: Icons.pause_circle_outline_rounded,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _StoreCountTile(
                            label: 'Battery Logs',
                            value: data?['battery'] ?? 0,
                            icon: Icons.battery_charging_full_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 10),
                    const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.shield_outlined, size: 14, color: Color(0xFF94A3B8)),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Every row carries a Pending / Synced / Failed status so the Phase 2 API can upload without a schema migration.',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10.5,
                              height: 1.45,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Overview Hero Stat Column
// ─────────────────────────────────────────────────────────────────────────────
class _HeroStat extends StatelessWidget {
  const _HeroStat({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 17, color: iconColor),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: Color(0xFF101828),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
            color: Color(0xFF64748B),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Day Card with Step-by-Step Sessions
// ─────────────────────────────────────────────────────────────────────────────
class _DayCard extends StatelessWidget {
  const _DayCard({required this.summary});

  final DaySummary summary;

  @override
  Widget build(BuildContext context) {
    final attendance = summary.attendance;
    final statusColor = attendance.status == AttendanceStatus.completed
        ? const Color(0xFF16A34A)
        : attendance.status == AttendanceStatus.interrupted
        ? const Color(0xFFD97706)
        : const Color(0xFF64748B);

    final statusBg = attendance.status == AttendanceStatus.completed
        ? const Color(0xFFDCFCE7)
        : attendance.status == AttendanceStatus.interrupted
        ? const Color(0xFFFEF3C7)
        : const Color(0xFFF1F5F9);

    final onDutySec = summary.stats.trackingSeconds;
    final stationarySec = summary.stats.stationarySeconds.clamp(0, onDutySec > 0 ? onDutySec : 86400);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DayStoryScreen(date: summary.date)),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: const Color(0xFFE8EEF5), width: 1.2),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 14,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Badge
                Container(
                  width: 50,
                  height: 56,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${summary.date.day}',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 20,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        Fmt.dateShort(summary.date).split(' ')[1].toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF16A34A),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              Fmt.dayLabel(summary.date),
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (summary.sessions.length > 1) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6.5, vertical: 2.5),
                              margin: const EdgeInsets.only(right: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF3E8FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '${summary.sessions.length} SESSIONS',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF7E3AF2),
                                ),
                              ),
                            ),
                          ],
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: statusBg,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              attendance.status.label.toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF64748B)),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${Fmt.time(attendance.checkInAt)} → ${Fmt.time(attendance.checkOutAt)} · ${Fmt.duration(summary.stats.tracking)} on duty',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Facts row
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _MetricBadge(
                            icon: Icons.directions_walk_rounded,
                            label: Fmt.distance(summary.stats.distanceMeters),
                            color: const Color(0xFF16A34A),
                            bg: const Color(0xFFF0FDF4),
                            border: const Color(0xFFDCFCE7),
                          ),
                          _MetricBadge(
                            icon: Icons.apartment_rounded,
                            label: '${summary.siteVisitCount} site visits',
                            color: const Color(0xFF7E3AF2),
                            bg: const Color(0xFFFAF5FF),
                            border: const Color(0xFFF3E8FF),
                          ),
                          _MetricBadge(
                            icon: Icons.pause_circle_outline_rounded,
                            label: Fmt.durationCompact(Duration(seconds: stationarySec)),
                            color: const Color(0xFFD97706),
                            bg: const Color(0xFFFFFBEB),
                            border: const Color(0xFFFEF3C7),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Step-by-Step Sessions
            if (summary.sessions.isNotEmpty) ...[
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    const Icon(Icons.timeline_rounded, size: 13, color: Color(0xFF0284C7)),
                    const SizedBox(width: 5),
                    Text(
                      'STEP-BY-STEP SESSIONS (${summary.sessions.length})',
                      style: const TextStyle(
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
              const SizedBox(height: 8),
              for (final s in summary.sessions)
                _SessionCard(session: s, date: summary.date),
            ],

            // Replay day action link
            const SizedBox(height: 10),
            const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Replay day story',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0284C7),
                  ),
                ),
                SizedBox(width: 3),
                Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF0284C7)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.icon,
    required this.label,
    required this.color,
    required this.bg,
    required this.border,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color bg;
  final Color border;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoreCountTile extends StatelessWidget {
  const _StoreCountTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final Object value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
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
// Step-by-Step Session Card & Timeline
// ─────────────────────────────────────────────────────────────────────────────
class _SessionCard extends StatefulWidget {
  const _SessionCard({
    required this.session,
    required this.date,
  });

  final DaySessionSummary session;
  final DateTime date;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  bool _expanded = true;

  @override
  Widget build(BuildContext context) {
    final s = widget.session;
    final steps = s.steps;

    final statusColor = s.status == AttendanceStatus.completed
        ? const Color(0xFF16A34A)
        : s.status == AttendanceStatus.interrupted
            ? const Color(0xFFD97706)
            : const Color(0xFF0284C7);

    final statusBg = s.status == AttendanceStatus.completed
        ? const Color(0xFFDCFCE7)
        : s.status == AttendanceStatus.interrupted
            ? const Color(0xFFFEF3C7)
            : const Color(0xFFE0F2FE);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0EDFC),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.label.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${Fmt.time(s.checkInAt)} → ${s.checkOutAt != null ? Fmt.time(s.checkOutAt) : "Live"} · ${Fmt.duration(s.duration)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        s.status.label.toUpperCase(),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 8,
                          fontWeight: FontWeight.w700,
                          color: statusColor,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DayStoryScreen(
                            date: widget.date,
                            initialSessionIndex: s.sessionIndex,
                          ),
                        ),
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.route_rounded, size: 11, color: Color(0xFF0284C7)),
                            SizedBox(width: 3),
                            Text(
                              'MAP',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 8.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      _expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18,
                      color: const Color(0xFF94A3B8),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Timeline Body
          if (_expanded) ...[
            const Divider(height: 1, color: Color(0xFFE2E8F0)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
              child: Column(
                children: [
                  for (var i = 0; i < steps.length; i++)
                    _TimelineStepTile(
                      step: steps[i],
                      isFirst: i == 0,
                      isLast: i == steps.length - 1,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TimelineStepTile extends StatelessWidget {
  const _TimelineStepTile({
    required this.step,
    required this.isFirst,
    required this.isLast,
  });

  final SessionStep step;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final (icon, color, bg, badgeLabel) = switch (step.type) {
      SessionStepType.checkIn => (
        Icons.login_rounded,
        const Color(0xFF16A34A),
        const Color(0xFFDCFCE7),
        'CHECK IN',
      ),
      SessionStepType.hold => (
        Icons.pause_circle_filled_rounded,
        const Color(0xFFD97706),
        const Color(0xFFFEF3C7),
        'HOLD',
      ),
      SessionStepType.siteClockIn => (
        Icons.apartment_rounded,
        const Color(0xFF7E3AF2),
        const Color(0xFFF3E8FF),
        'SITE IN',
      ),
      SessionStepType.siteClockOut => (
        Icons.exit_to_app_rounded,
        const Color(0xFF4F46E5),
        const Color(0xFFEEF2FF),
        'SITE OUT',
      ),
      SessionStepType.checkOut => (
        Icons.check_circle_rounded,
        const Color(0xFF0F172A),
        const Color(0xFFE2E8F0),
        'CLOCK OUT',
      ),
    };

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timeline indicator track & node
          SizedBox(
            width: 22,
            child: Column(
              children: [
                if (!isFirst)
                  Container(width: 2, height: 6, color: const Color(0xFFCBD5E1))
                else
                  const SizedBox(height: 6),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: bg,
                    shape: BoxShape.circle,
                    border: Border.all(color: color, width: 1.4),
                  ),
                  child: Icon(icon, size: 9.5, color: color),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFCBD5E1)),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Content
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 10, top: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: bg,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          badgeLabel,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 7.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: color,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                      Text(
                        Fmt.time(step.time),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                  if (step.location != null) ...[
                    const SizedBox(height: 1.5),
                    GeoAddressText(
                      latitude: step.location!.latitude,
                      longitude: step.location!.longitude,
                      fallbackText: step.subtitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      '${step.location!.latitude.toStringAsFixed(4)}, ${step.location!.longitude.toStringAsFixed(4)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 8.5,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ] else if (step.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 1.5),
                    Text(
                      step.subtitle,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
