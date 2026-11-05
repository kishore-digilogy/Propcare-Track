import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/errors/app_exception.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/geo_address_text.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/logo.dart';
import '../../core/widgets/maps.dart';
import '../../data/models/day_story.dart';
import '../../data/models/tracking.dart';
import '../../services/app_controller.dart';
import '../widgets/app_page.dart';

class DayStoryScreen extends StatefulWidget {
  const DayStoryScreen({super.key, required this.date, this.initialSessionIndex});

  final DateTime date;
  final int? initialSessionIndex;

  @override
  State<DayStoryScreen> createState() => _DayStoryScreenState();
}

class _DayStoryScreenState extends State<DayStoryScreen> {
  late Future<DayStory> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppController>().storyFor(widget.date);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      child: FutureBuilder<DayStory>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const SizedBox(
              height: 460,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.mint),
                    ),
                    SizedBox(height: 14),
                    MonoLabel('BINDING THE DAY', color: AppColors.textDim),
                  ],
                ),
              ),
            );
          }
          if (snapshot.hasError) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(title: Fmt.dayLabel(widget.date), subtitle: Fmt.dateLong(widget.date)),
                NoticeBanner(
                  message: snapshot.error is AppException
                      ? (snapshot.error as AppException).message
                      : 'This story could not be loaded. $snapshot',
                  color: AppColors.coral,
                  icon: Icons.error_outline_rounded,
                ),
              ],
            );
          }
          final story = snapshot.data!;
          return _StoryView(
            story: story,
            initialSessionIndex: widget.initialSessionIndex,
          );
        },
      ),
    );
  }
}

class _StoryView extends StatefulWidget {
  const _StoryView({required this.story, this.initialSessionIndex});

  final DayStory story;
  final int? initialSessionIndex;

  @override
  State<_StoryView> createState() => _StoryViewState();
}

class _StoryViewState extends State<_StoryView> {
  int? _selectedSessionIndex;

  @override
  void initState() {
    super.initState();
    if (widget.initialSessionIndex != null &&
        widget.story.sessions.any((s) => s.sessionIndex == widget.initialSessionIndex)) {
      _selectedSessionIndex = widget.initialSessionIndex;
    } else if (widget.story.sessions.length == 1) {
      _selectedSessionIndex = 1;
    } else {
      _selectedSessionIndex = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = widget.story;
    final sessions = story.sessions;
    final activeStory = _selectedSessionIndex == null ? story : story.forSession(_selectedSessionIndex!);
    final activeSession = _selectedSessionIndex == null ? null : story.sessionByIndex(_selectedSessionIndex!);

    final attendance = activeStory.attendance ?? story.attendance;
    final statusColor = attendance == null
        ? AppColors.textDim
        : attendance.status.name == 'completed'
            ? AppColors.mint
            : attendance.status.name == 'interrupted'
                ? AppColors.amber
                : AppColors.cyan;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: Fmt.dayLabel(story.date),
          subtitle: Fmt.dateLong(story.date),
          trailing: StatusPill(
            label: attendance?.status.label.toUpperCase() ?? 'NO SESSION',
            color: statusColor,
            dense: true,
          ),
        ),
        if (sessions.isNotEmpty) ...[
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              children: [
                if (sessions.length > 1) ...[
                  Builder(builder: (context) {
                    final isSelected = _selectedSessionIndex == null;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSessionIndex = null),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF101828) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF101828) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x22101828),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  )
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x0A0F172A),
                                    blurRadius: 4,
                                  ),
                                ],
                        ),
                        child: Center(
                          child: Text(
                            'All Sessions (${sessions.length})',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: isSelected ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ],
                for (final s in sessions) ...[
                  Builder(builder: (context) {
                    final isSelected = _selectedSessionIndex == s.sessionIndex;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedSessionIndex = s.sessionIndex),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF101828) : Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? const Color(0xFF101828) : const Color(0xFFE2E8F0),
                            width: 1.2,
                          ),
                          boxShadow: isSelected
                              ? const [
                                  BoxShadow(
                                    color: Color(0x22101828),
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  )
                                ]
                              : const [
                                  BoxShadow(
                                    color: Color(0x0A0F172A),
                                    blurRadius: 4,
                                  ),
                                ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: s.isCompleted
                                    ? const Color(0xFF10B981)
                                    : s.isInterrupted
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFF0284C7),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Session ${s.sessionIndex} · ${Fmt.time(s.checkInAt)}${s.checkOutAt != null ? " → ${Fmt.time(s.checkOutAt)}" : " (Live)"}',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: isSelected ? Colors.white : const Color(0xFF1E293B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (activeSession != null) ...[
          GlassPanel(
            radius: 22,
            padding: const EdgeInsets.all(14),
            borderColor: AppColors.cyan.withValues(alpha: 0.3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.cyan.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        activeSession.label.toUpperCase(),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: AppColors.cyan,
                        ),
                      ),
                    ),
                    const Spacer(),
                    StatusPill(
                      label: activeSession.status.label.toUpperCase(),
                      color: activeSession.isCompleted
                          ? AppColors.mint
                          : activeSession.isInterrupted
                              ? AppColors.amber
                              : AppColors.cyan,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MonoLabel('CHECK-IN'),
                          const SizedBox(height: 3),
                          Text(
                            Fmt.time(activeSession.checkInAt),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.text,
                            ),
                          ),
                          Text(
                            '±${activeSession.attendance.checkInAccuracy.round()} m · ${activeSession.attendance.checkInBattery}%',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 42, color: AppColors.line),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MonoLabel('CHECK-OUT'),
                          const SizedBox(height: 3),
                          Text(
                            activeSession.checkOutAt != null
                                ? Fmt.time(activeSession.checkOutAt)
                                : 'Still active',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: activeSession.checkOutAt != null ? AppColors.text : AppColors.cyan,
                            ),
                          ),
                          Text(
                            'Worked ${Fmt.duration(activeSession.duration)}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(width: 1, height: 42, color: AppColors.line),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const MonoLabel('DISTANCE'),
                          const SizedBox(height: 3),
                          Text(
                            Fmt.distance(activeSession.stats.distanceMeters),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.mint,
                            ),
                          ),
                          Text(
                            '${activeSession.siteVisits.length} site visit${activeSession.siteVisits.length == 1 ? "" : "s"}',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 9.5,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.lineStrong),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x1A0A7F5B), Color(0x0A0B7CB8), Color(0xFFFFFFFF)],
            ),
            boxShadow: [
              BoxShadow(color: AppColors.mint.withValues(alpha: 0.08), blurRadius: 42, spreadRadius: -12),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: MonoLabel(
                        _selectedSessionIndex == null
                            ? 'DAY STORY · ALL SESSIONS ROUTE REPLAY'
                            : 'SESSION $_selectedSessionIndex · ROUTE REPLAY',
                        color: AppColors.mint,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  if (activeStory.session != null)
                    StatusPill(
                      label: activeStory.session!.platform.toUpperCase(),
                      color: AppColors.violet,
                      dense: true,
                      icon: Icons.memory_rounded,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                activeStory.isEmpty
                    ? 'A page left blank.'
                    : _selectedSessionIndex == null
                        ? 'Full day in\nthe field.'
                        : 'Session $_selectedSessionIndex in\nthe field.',
                style: Theme.of(context).textTheme.displayMedium?.copyWith(fontSize: 32),
              ),
              const SizedBox(height: 6),
              Text(
                activeStory.isEmpty
                    ? 'No attendance, breadcrumbs or site visits were recorded.'
                    : '${activeStory.locations.length} breadcrumbs · ${activeStory.siteVisits.length} site visit${activeStory.siteVisits.length == 1 ? "" : "s"} · ${Fmt.distance(activeStory.stats.distanceMeters)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              RouteStoryMap(
                key: ValueKey('story-map-${_selectedSessionIndex ?? "all"}'),
                story: activeStory,
                height: 360,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StoryFact(
                      label: 'ON DUTY',
                      value: Fmt.duration(activeStory.stats.tracking),
                      accent: AppColors.cyan,
                    ),
                  ),
                  Container(width: 1, height: 34, color: AppColors.line),
                  Expanded(
                    child: _StoryFact(
                      label: 'DISTANCE',
                      value: Fmt.distance(activeStory.stats.distanceMeters),
                      accent: AppColors.mint,
                    ),
                  ),
                  Container(width: 1, height: 34, color: AppColors.line),
                  Expanded(
                    child: _StoryFact(
                      label: 'STATIONARY',
                      value: Fmt.durationCompact(
                        activeStory.stats.stationarySeconds >
                                (activeStory.stats.trackingSeconds > 0
                                    ? activeStory.stats.trackingSeconds
                                    : 86400)
                            ? Duration(
                                seconds: activeStory.stats.trackingSeconds > 0
                                    ? activeStory.stats.trackingSeconds
                                    : 86400)
                            : activeStory.stats.stationary,
                      ),
                      accent: AppColors.amber,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: MetricTile(
                icon: Icons.apartment_rounded,
                value: '${activeStory.siteVisits.length}',
                label: 'Site visits',
                accent: AppColors.violet,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                icon: Icons.pause_circle_outline_rounded,
                value: '${activeStory.stationaryEvents.where((e) => e.durationSeconds >= 20).length}',
                label: 'Detected stops',
                accent: AppColors.amber,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: MetricTile(
                icon: Icons.my_location_rounded,
                value: activeStory.stats.avgAccuracy == null
                    ? '—'
                    : '±${activeStory.stats.avgAccuracy!.round()}',
                unit: activeStory.stats.avgAccuracy == null ? null : 'm',
                label: 'Avg accuracy',
                accent: AppColors.cyan,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SectionHeading(
          title: _selectedSessionIndex == null
              ? 'All Chapters'
              : 'Session $_selectedSessionIndex Chapters',
          subtitle: activeStory.events.isEmpty
              ? 'No moments recorded'
              : '${activeStory.events.length} moments, step-by-step',
        ),
        if (activeStory.events.isEmpty)
          const GlassPanel(
            radius: 22,
            padding: EdgeInsets.all(6),
            child: EmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Nothing to narrate',
              message: 'This session has no attendance events.',
              accent: AppColors.violet,
            ),
          )
        else
          for (var i = 0; i < activeStory.events.length; i++)
            StaggeredFade(
              index: i,
              child: _StoryChapter(
                event: activeStory.events[i],
                index: i,
                last: i == activeStory.events.length - 1,
              ),
            ),
        if (activeStory.siteVisits.isNotEmpty) ...[
          const SizedBox(height: 24),
          SectionHeading(
            title: _selectedSessionIndex == null ? 'Site ledger' : 'Session $_selectedSessionIndex Sites',
            subtitle: 'Every arrival and departure',
          ),
          for (final visit in activeStory.siteVisits) ...[
            GlassPanel(
              radius: 20,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AppColors.violet.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.apartment_rounded, size: 17, color: AppColors.violet),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              visit.siteName,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: AppColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${Fmt.time(visit.checkInAt)} → ${Fmt.time(visit.checkOutAt)}',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 9,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      StatusPill(
                        label: Fmt.duration(visit.visitDuration),
                        color: visit.isActive ? AppColors.coral : AppColors.violet,
                        dense: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _SmallFact(label: 'CHECK-IN', value: '±${visit.checkInAccuracy.round()} m'),
                      const SizedBox(width: 16),
                      _SmallFact(label: 'BATTERY', value: '${visit.checkInBattery}%'),
                      const SizedBox(width: 16),
                      _SmallFact(
                        label: 'COORDINATES',
                        value:
                            '${visit.checkInLatitude.toStringAsFixed(4)}, ${visit.checkInLongitude.toStringAsFixed(4)}',
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
          ],
        ],
        if (activeStory.stationaryEvents.any((e) => e.durationSeconds >= 20)) ...[
          const SizedBox(height: 14),
          SectionHeading(
            title: _selectedSessionIndex == null ? 'Stationary moments' : 'Session $_selectedSessionIndex Stops',
            subtitle: '20 s threshold · GPS jitter filtered',
          ),
          GlassPanel(
            radius: 20,
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 8),
            child: Column(
              children: [
                for (var i = 0; i < activeStory.stationaryEvents.length; i++)
                  if (activeStory.stationaryEvents[i].durationSeconds >= 20)
                    _StationaryChapter(
                      event: activeStory.stationaryEvents[i],
                      last: i == activeStory.stationaryEvents.length - 1,
                    ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 22),
        Center(
          child: Column(
            children: [
              const AppLogo(size: 40),
              const SizedBox(height: 10),
              const MonoLabel('END OF STORY', color: AppColors.textDim, letterSpacing: 3),
              const SizedBox(height: 5),
              Text(
                'Generated offline from ${activeStory.locations.length} breadcrumbs',
                style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textDim),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

class _StoryFact extends StatelessWidget {
  const _StoryFact({required this.label, required this.value, required this.accent});

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MonoLabel(label, size: 7.5, letterSpacing: 1.3),
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

class _SmallFact extends StatelessWidget {
  const _SmallFact({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MonoLabel(label, size: 7, letterSpacing: 1),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: AppColors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryChapter extends StatelessWidget {
  const _StoryChapter({required this.event, required this.index, required this.last});

  final StoryEvent event;
  final int index;
  final bool last;

  (IconData, Color) get _style => switch (event.kind) {
        StoryEventKind.officeCheckIn => (Icons.login_rounded, AppColors.cyan),
        StoryEventKind.officeCheckOut => (Icons.logout_rounded, AppColors.coral),
        StoryEventKind.siteCheckIn => (Icons.apartment_rounded, AppColors.violet),
        StoryEventKind.siteCheckOut => (Icons.directions_walk_rounded, AppColors.violet),
        StoryEventKind.stationary => (Icons.pause_circle_outline_rounded, AppColors.amber),
        StoryEventKind.sessionInterrupted => (Icons.history_toggle_off_rounded, AppColors.amber),
        StoryEventKind.logout => (Icons.power_settings_new_rounded, AppColors.coral),
      };

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _style;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.12),
                    border: Border.all(color: color.withValues(alpha: 0.34)),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Expanded(
                  child: Container(
                    width: 1.5,
                    color: last ? Colors.transparent : AppColors.lineStrong,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: GlassPanel(
                radius: 18,
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        MonoLabel(
                          'CHAPTER ${(index + 1).toString().padLeft(2, '0')}',
                          color: color,
                          size: 8,
                          letterSpacing: 1.4,
                        ),
                        const Spacer(),
                        Text(
                          Fmt.time(event.time),
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.title,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        height: 1.25,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      event.subtitle,
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10.5, color: AppColors.textMuted),
                    ),
                    if (event.point != null) ...[
                      const SizedBox(height: 6),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.location_on_outlined, size: 13, color: color),
                          const SizedBox(width: 4),
                          Expanded(
                            child: GeoAddressText(
                              latitude: event.point!.latitude,
                              longitude: event.point!.longitude,
                              fallbackText: event.subtitle,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (event.battery != null || event.duration != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (event.duration != null) ...[
                            Icon(Icons.timer_outlined, size: 11, color: color),
                            const SizedBox(width: 4),
                            Text(
                              Fmt.duration(event.duration!),
                              style: TextStyle(fontFamily: 'Poppins', fontSize: 8.5, color: color),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (event.battery != null) ...[
                            const Icon(Icons.battery_5_bar_rounded, size: 11, color: AppColors.textDim),
                            const SizedBox(width: 4),
                            Text(
                              '${event.battery}%',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 8.5,
                                color: AppColors.textDim,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StationaryChapter extends StatelessWidget {
  const _StationaryChapter({required this.event, required this.last});

  final StationaryEvent event;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              const Icon(Icons.pause_circle_outline_rounded, size: 16, color: AppColors.amber),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Stayed ${Fmt.duration(event.duration)}',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${Fmt.time(event.startAt)} → ${Fmt.time(event.endAt)} · ${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)} · ${event.radiusMeters.round()} m radius',
                      style: const TextStyle(fontFamily: 'Poppins', fontSize: 10, color: AppColors.textDim),
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
