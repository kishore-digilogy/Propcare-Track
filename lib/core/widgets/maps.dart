import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../data/models/day_story.dart';
import '../../data/models/place.dart';
import '../../data/models/tracking.dart';
import '../theme/app_colors.dart';
import '../utils/geo.dart';
import 'google_route_map.dart';

/// Animated radar map that plots the office, assigned sites, the live position
/// and the walked trail. Deliberately offline — no map tiles required.
class RadarMap extends StatefulWidget {
  const RadarMap({
    super.key,
    required this.office,
    required this.sites,
    this.current,
    this.accuracy = 0,
    this.trail = const [],
    this.stationary = const [],
    this.activeSiteId,
    this.height = 360,
    this.compact = false,
    this.showLegend = true,
    this.siteOnly = false,
    this.officeOnly = false,
  });

  final OfficeConfig office;
  final List<Site> sites;
  final GeoPoint? current;
  final double accuracy;
  final List<GeoPoint> trail;
  final List<StationaryEvent> stationary;
  final String? activeSiteId;
  final double height;
  final bool compact;
  final bool showLegend;
  final bool siteOnly;
  final bool officeOnly;

  @override
  State<RadarMap> createState() => _RadarMapState();
}

class _RadarMapState extends State<RadarMap> with SingleTickerProviderStateMixin {
  // Only the offline painter needs a ticker. On mobile the Google Map is used
  // instead, so the controller must not be created lazily in dispose().
  AnimationController? _sweep;

  @override
  void initState() {
    super.initState();
    if (!supportsGoogleMaps) {
      _sweep = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 7),
      )..repeat();
    }
  }

  @override
  void dispose() {
    _sweep?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (supportsGoogleMaps) {
      return GoogleRouteMap(
        office: widget.office,
        sites: widget.sites,
        route: widget.trail,
        stationaryEvents: widget.stationary,
        current: widget.current,
        accuracy: widget.accuracy,
        activeSiteId: widget.activeSiteId,
        height: widget.height,
        showTag: widget.showLegend,
        radius: widget.compact ? 18 : 24,
        siteOnly: widget.siteOnly,
        officeOnly: widget.officeOnly,
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.compact ? 18 : 24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FBFE), Color(0xFFEEF5FB), Color(0xFFF2FAF6)],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _sweep!,
              builder: (context, _) => CustomPaint(
                painter: _RadarPainter(
                  office: widget.office,
                  sites: widget.officeOnly ? const [] : widget.sites,
                  current: widget.current,
                  accuracy: widget.accuracy,
                  trail: (widget.siteOnly || widget.officeOnly) ? const [] : widget.trail,
                  activeSiteId: widget.activeSiteId,
                  sweep: _sweep!.value,
                  compact: widget.compact,
                ),
              ),
            ),
            Positioned(
              top: 12,
              left: 12,
              child: _GlassTag(
                icon: Icons.radar_rounded,
                label: widget.current == null ? 'LOCATING' : 'LIVE RADAR',
                color: widget.current == null ? AppColors.amber : AppColors.mint,
                live: widget.current != null,
              ),
            ),
            Positioned(
              top: 12,
              right: 12,
              child: _GlassTag(
                icon: Icons.my_location_rounded,
                label: widget.current == null
                    ? 'NO FIX'
                    : '±${widget.accuracy.round()} m',
                color: widget.current == null ? AppColors.textDim : AppColors.cyan,
              ),
            ),
            if (widget.showLegend)
              Positioned(
                left: 12,
                right: 12,
                bottom: 10,
                child: Row(
                  children: [
                    _LegendDot(color: AppColors.mint, label: 'You'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppColors.cyan, label: 'Office'),
                    const SizedBox(width: 12),
                    _LegendDot(color: AppColors.violet, label: 'Sites'),
                    const Spacer(),
                    if (widget.trail.length > 1)
                      Text(
                        '${widget.trail.length} points',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 8,
                          letterSpacing: 0.8,
                          color: AppColors.textDim,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GlassTag extends StatelessWidget {
  const _GlassTag({required this.icon, required this.label, required this.color, this.live = false});

  final IconData icon;
  final String label;
  final Color color;
  final bool live;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.lineStrong),
        boxShadow: const [
          BoxShadow(color: AppColors.shadow, blurRadius: 10, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (live)
            Container(
              width: 5,
              height: 5,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [BoxShadow(color: color, blurRadius: 6)],
              ),
            )
          else
            Icon(icon, size: 11, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 8,
              letterSpacing: 1.1,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 9,
            fontWeight: FontWeight.w600,
            color: AppColors.textMuted,
          ),
        ),
      ],
    );
  }
}

class _RadarPainter extends CustomPainter {
  _RadarPainter({
    required this.office,
    required this.sites,
    required this.current,
    required this.accuracy,
    required this.trail,
    required this.activeSiteId,
    required this.sweep,
    required this.compact,
  });

  final OfficeConfig office;
  final List<Site> sites;
  final GeoPoint? current;
  final double accuracy;
  final List<GeoPoint> trail;
  final String? activeSiteId;
  final double sweep;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final pad = EdgeInsets.fromLTRB(compact ? 26 : 34, compact ? 44 : 52, compact ? 26 : 34, compact ? 34 : 40);
    final projection = _Projection(
      points: [
        office.point,
        ...sites.map((s) => s.point),
        if (current != null) current!,
        ...trail,
      ],
      size: size,
      padding: pad,
    );

    _paintGrid(canvas, size, projection);
    final officePx = projection.project(office.point);

    _paintRings(canvas, size, officePx);
    _paintSweep(canvas, size, officePx);
    _paintConnections(canvas, projection, officePx);

    if (trail.length > 1) {
      _paintTrail(canvas, projection);
    }

    if (current != null) {
      final currentPx = projection.project(current!);
      _paintAccuracy(canvas, projection, currentPx);
      _paintCurrent(canvas, currentPx);
    }

    _paintOffice(canvas, officePx);
    for (var i = 0; i < sites.length; i++) {
      final site = sites[i];
      final px = projection.project(site.point);
      _paintSite(canvas, px, i + 1, site.name, active: site.id == activeSiteId, compact: compact);
    }
  }

  void _paintGrid(Canvas canvas, Size size, _Projection projection) {
    final paint = Paint()
      ..color = AppColors.text.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    const divisions = 5;
    for (var i = 1; i < divisions; i++) {
      final y = size.height * i / divisions;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
      final x = size.width * i / divisions;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
  }

  void _paintRings(Canvas canvas, Size size, Offset center) {
    final maxR = math.min(size.width, size.height) * 0.62;
    for (var i = 1; i <= 3; i++) {
      final r = maxR * i / 3;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.cyan.withValues(alpha: 0.2);
      canvas.drawCircle(center, r, paint);
      final dash = Paint()
        ..color = AppColors.cyan.withValues(alpha: 0.38)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(center.dx, center.dy - r - 3), Offset(center.dx, center.dy - r + 3), dash);
    }
  }

  void _paintSweep(Canvas canvas, Size size, Offset center) {
    final angle = sweep * math.pi * 2;
    final radius = math.max(size.width, size.height) * 0.78;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final wedge = Paint()
      ..shader = SweepGradient(
        startAngle: angle - 0.9,
        endAngle: angle,
        colors: [AppColors.mint.withValues(alpha: 0), AppColors.mint.withValues(alpha: 0.12)],
        transform: GradientRotation(angle - 0.9),
      ).createShader(rect);
    canvas.drawArc(rect, angle - 0.9, 0.9, true, wedge);
    final edge = Paint()
      ..shader = LinearGradient(
        colors: [AppColors.mint.withValues(alpha: 0), AppColors.mint.withValues(alpha: 0.5)],
      ).createShader(Rect.fromPoints(center, center + Offset(math.cos(angle) * radius, math.sin(angle) * radius)))
      ..strokeWidth = 1.2;
    canvas.drawLine(center, center + Offset(math.cos(angle) * radius, math.sin(angle) * radius), edge);
  }

  void _paintConnections(Canvas canvas, _Projection projection, Offset officePx) {
    for (final site in sites) {
      final px = projection.project(site.point);
      _dashedLine(
        canvas,
        officePx,
        px,
        Paint()
          ..color = AppColors.text.withValues(alpha: 0.14)
          ..strokeWidth = 1,
        dash: 4,
        gap: 5,
      );
    }
  }

  void _paintTrail(Canvas canvas, _Projection projection) {
    final path = Path();
    for (var i = 0; i < trail.length; i++) {
      final p = projection.project(trail[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prev = projection.project(trail[i - 1]);
        final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
    }
    final last = projection.project(trail.last);
    path.lineTo(last.dx, last.dy);
    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..strokeCap = StrokeCap.round
      ..color = AppColors.mint.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    canvas.drawPath(path, glow);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [AppColors.cyan, AppColors.mint])
          .createShader(Offset.zero & const Size(400, 400));
    canvas.drawPath(path, line);
  }

  void _paintAccuracy(Canvas canvas, _Projection projection, Offset center) {
    final metersPerPixel = projection.metersPerPixel;
    final radius = (accuracy / metersPerPixel).clamp(10.0, 90.0);
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = AppColors.mint.withValues(alpha: 0.055),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = AppColors.mint.withValues(alpha: 0.22),
    );
  }

  void _paintCurrent(Canvas canvas, Offset center) {
    final pulse = (math.sin(sweep * math.pi * 2) + 1) / 2;
    canvas.drawCircle(center, 8 + pulse * 9, Paint()..color = AppColors.mint.withValues(alpha: 0.12 * (1 - pulse)));
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.mint.withValues(alpha: 0.35),
    );
    canvas.drawCircle(center, 9, Paint()..color = AppColors.mint.withValues(alpha: 0.18));
    canvas.drawCircle(center, 5, Paint()..color = Colors.white);
    canvas.drawCircle(center, 5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.4..color = AppColors.mint);
  }

  void _paintOffice(Canvas canvas, Offset center) {
    canvas.drawCircle(center, 11, Paint()..color = AppColors.cyan.withValues(alpha: 0.16));
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppColors.cyan.withValues(alpha: 0.7),
    );
    final rect = RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: 9, height: 9), const Radius.circular(2));
    canvas.drawRRect(rect, Paint()..color = AppColors.cyan);
    _label(canvas, 'OFFICE', center + const Offset(0, 17), AppColors.cyan, align: TextAlign.center, size: 7.5);
  }

  void _paintSite(Canvas canvas, Offset center, int index, String name,
      {required bool active, required bool compact}) {
    final color = active ? AppColors.coral : AppColors.violet;
    if (active) {
      canvas.drawCircle(center, 15, Paint()..color = color.withValues(alpha: 0.16));
    }
    canvas.drawCircle(center, 9.5, Paint()..color = AppColors.surface);
    canvas.drawCircle(
      center,
      9.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.85),
    );
    _label(canvas, '$index', center, color, align: TextAlign.center, size: 8, bold: true, offsetY: -4.8);
    if (!compact) {
      _chipLabel(canvas, name, center + const Offset(0, 18), color);
    }
  }

  void _chipLabel(Canvas canvas, String text, Offset at, Color color) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontFamily: 'Poppins', fontSize: 8.5, fontWeight: FontWeight.w600, color: AppColors.text),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 120);
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: at + Offset(0, tp.height / 2), width: tp.width + 10, height: tp.height + 5),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, Paint()..color = AppColors.surface.withValues(alpha: 0.94));
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = color.withValues(alpha: 0.35),
    );
    tp.paint(canvas, at + Offset(-tp.width / 2, 0));
  }

  void _label(Canvas canvas, String text, Offset at, Color color,
      {required TextAlign align, required double size, bool bold = false, double offsetY = 0}) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: bold ? 'Poppins' : 'Poppins',
          fontSize: size,
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          letterSpacing: bold ? 0 : 0.8,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: align,
    )..layout();
    final dx = align == TextAlign.center ? -tp.width / 2 : 0.0;
    tp.paint(canvas, at + Offset(dx, offsetY));
  }

  void _dashedLine(Canvas canvas, Offset a, Offset b, Paint paint,
      {required double dash, required double gap}) {
    final total = (b - a).distance;
    if (total == 0) return;
    final dir = (b - a) / total;
    var covered = 0.0;
    while (covered < total) {
      final start = a + dir * covered;
      final end = a + dir * math.min(covered + dash, total);
      canvas.drawLine(start, end, paint);
      covered += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) =>
      oldDelegate.sweep != sweep ||
      oldDelegate.current != current ||
      oldDelegate.trail.length != trail.length ||
      oldDelegate.activeSiteId != activeSiteId;
}

class _Projection {
  _Projection({required List<GeoPoint> points, required this.size, required this.padding}) {
    var minLat = double.infinity;
    var maxLat = -double.infinity;
    var minLng = double.infinity;
    var maxLng = -double.infinity;
    for (final p in points) {
      minLat = math.min(minLat, p.latitude);
      maxLat = math.max(maxLat, p.latitude);
      minLng = math.min(minLng, p.longitude);
      maxLng = math.max(maxLng, p.longitude);
    }
    if (!minLat.isFinite) {
      minLat = 0;
      maxLat = 0;
      minLng = 0;
      maxLng = 0;
    }
    final centerLat = (minLat + maxLat) / 2;
    cosLat = math.cos(centerLat * math.pi / 180).abs().clamp(0.2, 1.0);
    final rawLatSpan = math.max(maxLat - minLat, 0.0025);
    final rawLngSpan = math.max((maxLng - minLng) * cosLat, 0.0025);
    final span = math.max(rawLatSpan, rawLngSpan) * 1.35;
    this.minLat = centerLat - span / 2;
    this.maxLat = centerLat + span / 2;
    final centerLng = (minLng + maxLng) / 2;
    this.minLng = centerLng - span / 2 / cosLat;
    this.maxLng = centerLng + span / 2 / cosLat;
  }

  final Size size;
  final EdgeInsets padding;
  late final double minLat;
  late final double maxLat;
  late final double minLng;
  late final double maxLng;
  late final double cosLat;

  double get metersPerPixel {
    final latSpanMeters = (maxLat - minLat) * 111320;
    final h = (size.height - padding.vertical).clamp(1.0, double.infinity);
    return latSpanMeters / h;
  }

  Offset project(GeoPoint point) {
    final w = size.width - padding.horizontal;
    final h = size.height - padding.vertical;
    final x = ((point.longitude - minLng) / (maxLng - minLng)) * w + padding.left;
    final y = (1 - (point.latitude - minLat) / (maxLat - minLat)) * h + padding.top;
    return Offset(x, y);
  }
}

/// A cinematic route ribbon for the day-story screen.
class RouteStoryMap extends StatefulWidget {
  const RouteStoryMap({
    super.key,
    required this.story,
    this.height = 360,
  });

  final DayStory story;
  final double height;

  @override
  State<RouteStoryMap> createState() => _RouteStoryMapState();
}

class _RouteStoryMapState extends State<RouteStoryMap> with SingleTickerProviderStateMixin {
  // See _RadarMapState: the ticker is only used by the offline painter.
  AnimationController? _draw;

  @override
  void initState() {
    super.initState();
    if (!supportsGoogleMaps) {
      _draw = AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1600),
      )..forward();
    }
  }

  @override
  void dispose() {
    _draw?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (supportsGoogleMaps) {
      final route = widget.story.routePoints;
      String? activeSiteId;
      for (final visit in widget.story.siteVisits) {
        if (visit.isActive) {
          activeSiteId = visit.siteId;
          break;
        }
      }
      final visitedSiteIds = widget.story.siteVisits.map((v) => v.siteId).toSet();
      final relevantSites = widget.story.sites
          .where((s) => visitedSiteIds.contains(s.id))
          .toList();

      return GoogleRouteMap(
        office: widget.story.office,
        sites: relevantSites,
        route: route,
        stationaryEvents: widget.story.stationaryEvents,
        current: route.isEmpty ? null : route.last,
        activeSiteId: activeSiteId,
        height: widget.height,
        showTag: true,
      );
    }

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFFF8FBFE), Color(0xFFEEF5FB), Color(0xFFF2FAF6)],
                ),
              ),
            ),
            AnimatedBuilder(
              animation: _draw!,
              builder: (context, _) => CustomPaint(
                painter: _StoryPainter(story: widget.story, progress: Curves.easeOutCubic.transform(_draw!.value)),
              ),
            ),
            Positioned(
              left: 14,
              top: 14,
              child: _GlassTag(
                icon: Icons.route_rounded,
                label: 'ROUTE REPLAY',
                color: AppColors.mint,
              ),
            ),
            Positioned(
              right: 14,
              top: 14,
              child: _GlassTag(
                icon: Icons.straighten_rounded,
                label: '${(widget.story.stats.distanceMeters / 1000).toStringAsFixed(1)} KM',
                color: AppColors.cyan,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StoryPainter extends CustomPainter {
  _StoryPainter({required this.story, required this.progress});

  final DayStory story;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <GeoPoint>[
      story.office.point,
      ...story.locations.map((l) => l.point),
      ...story.siteVisits.map((v) => v.checkInPoint),
      ...story.stationaryEvents.map((s) => s.point),
    ];
    if (points.length < 2) {
      _paintPlaceholder(canvas, size);
      return;
    }
    final projection = _Projection(
      points: points,
      size: size,
      padding: const EdgeInsets.fromLTRB(30, 44, 30, 30),
    );

    // Baseline grid
    final grid = Paint()
      ..color = AppColors.text.withValues(alpha: 0.06)
      ..strokeWidth = 1;
    for (var i = 1; i < 5; i++) {
      final y = size.height * i / 5;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final path = Path();
    final projected = <Offset>[];
    for (var i = 0; i < story.locations.length; i++) {
      final p = projection.project(story.locations[i].point);
      projected.add(p);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        final prev = projected[i - 1];
        final mid = Offset((prev.dx + p.dx) / 2, (prev.dy + p.dy) / 2);
        path.quadraticBezierTo(prev.dx, prev.dy, mid.dx, mid.dy);
      }
    }
    if (projected.isNotEmpty) {
      path.lineTo(projected.last.dx, projected.last.dy);
    }

    final metric = path.computeMetrics().toList();
    final drawPath = Path();
    for (final m in metric) {
      drawPath.addPath(m.extractPath(0, m.length * progress), Offset.zero);
    }

    final glow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 10
      ..strokeCap = StrokeCap.round
      ..color = AppColors.mint.withValues(alpha: 0.12)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(drawPath, glow);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..shader = const LinearGradient(colors: [AppColors.cyan, AppColors.mint, AppColors.coral])
          .createShader(Offset.zero & size);
    canvas.drawPath(drawPath, line);

    // Site pins
    for (var i = 0; i < story.siteVisits.length; i++) {
      final visit = story.siteVisits[i];
      final px = projection.project(visit.checkInPoint);
      final color = visit.isActive ? AppColors.coral : AppColors.violet;
      canvas.drawCircle(px, 9, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(px, 4, Paint()..color = color);
      _text(canvas, 'S${i + 1}', px + const Offset(0, -18), color, 8);
    }

    // Stationary stop pins
    for (var i = 0; i < story.stationaryEvents.length; i++) {
      final stop = story.stationaryEvents[i];
      if (stop.durationSeconds < 20 && !stop.isActive) continue;
      final px = projection.project(stop.point);
      canvas.drawCircle(px, 10, Paint()..color = AppColors.amber.withValues(alpha: 0.18));
      canvas.drawCircle(px, 4.5, Paint()..color = AppColors.amber);
      canvas.drawCircle(px, 4.5, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.2..color = Colors.white);
      _text(canvas, 'P${i + 1}', px + const Offset(0, -16), AppColors.amber, 8);
    }

    if (projected.isNotEmpty) {
      final start = projected.first;
      final end = projected.last;
      canvas.drawCircle(start, 6, Paint()..color = AppColors.cyan);
      canvas.drawCircle(start, 6, Paint()..style = PaintingStyle.stroke..strokeWidth = 1.5..color = AppColors.text.withValues(alpha: 0.35));
      canvas.drawCircle(end, 7, Paint()..color = AppColors.mint.withValues(alpha: 0.2));
      canvas.drawCircle(end, 4.5, Paint()..color = AppColors.mint);
      _text(canvas, 'START', start + const Offset(0, 12), AppColors.cyan, 7.5);
      _text(canvas, 'NOW', end + const Offset(0, 12), AppColors.mint, 7.5);
    }

    if (story.locations.isEmpty) {
      _paintPlaceholder(canvas, size);
    }
  }

  void _paintPlaceholder(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2 + 10);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = AppColors.textDim.withValues(alpha: 0.4);
    final path = Path()
      ..moveTo(size.width * 0.16, center.dy + 18)
      ..cubicTo(size.width * 0.34, center.dy - 40, size.width * 0.52, center.dy + 52, size.width * 0.7, center.dy - 8)
      ..cubicTo(size.width * 0.8, center.dy - 34, size.width * 0.88, center.dy - 20, size.width * 0.9, center.dy - 24);
    canvas.drawPath(path, paint..strokeWidth = 1.4);
    canvas.drawCircle(Offset(size.width * 0.16, center.dy + 18), 4, Paint()..color = AppColors.cyan);
    canvas.drawCircle(Offset(size.width * 0.9, center.dy - 24), 4, Paint()..color = AppColors.mint);
    _text(canvas, 'NO BREADCRUMBS YET', Offset(size.width / 2, size.height - 26), AppColors.textDim, 8);
  }

  void _text(Canvas canvas, String text, Offset at, Color color, double size) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Poppins',
          fontSize: size,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, at + Offset(-tp.width / 2, 0));
  }

  @override
  bool shouldRepaint(covariant _StoryPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Tiny site thumbnail: the site pin with a directional line to the employee.
class MiniMap extends StatelessWidget {
  const MiniMap({
    super.key,
    required this.site,
    this.current,
    this.size = 84,
    this.active = false,
  });

  final Site site;
  final GeoPoint? current;
  final double size;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: CustomPaint(
          painter: _MiniMapPainter(site: site, current: current, active: active),
        ),
      ),
    );
  }
}

class _MiniMapPainter extends CustomPainter {
  _MiniMapPainter({required this.site, required this.current, required this.active});

  final Site site;
  final GeoPoint? current;
  final bool active;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFF7FBFE), Color(0xFFEDF4FA)],
        ).createShader(rect),
    );
    final center = Offset(size.width / 2, size.height / 2);
    final color = active ? AppColors.coral : AppColors.violet;
    for (var i = 1; i <= 2; i++) {
      canvas.drawCircle(
        center,
        size.width * 0.18 * i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = color.withValues(alpha: 0.12),
      );
    }

    final target = current;
    if (target != null) {
      final angle = bearingBetween(site.point, target) * math.pi / 180;
      final distance = distanceBetween(site.point, target);
      final length = (size.width * 0.28 + math.min(distance / 4000, 1) * size.width * 0.18);
      final end = center + Offset(math.cos(angle), math.sin(angle)) * length;
      _dash(canvas, center, end, AppColors.mint.withValues(alpha: 0.5));
      canvas.drawCircle(end, 3.2, Paint()..color = AppColors.mint);
    }

    canvas.drawCircle(center, 11, Paint()..color = color.withValues(alpha: 0.16));
    canvas.drawCircle(
      center,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.3
        ..color = color.withValues(alpha: 0.7),
    );
    canvas.drawCircle(center, 4.2, Paint()..color = color);
  }

  void _dash(Canvas canvas, Offset a, Offset b, Color color) {
    final total = (b - a).distance;
    final dir = (b - a) / total;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2;
    var covered = 0.0;
    while (covered < total) {
      canvas.drawLine(a + dir * covered, a + dir * math.min(covered + 3, total), paint);
      covered += 6;
    }
  }

  @override
  bool shouldRepaint(covariant _MiniMapPainter oldDelegate) =>
      oldDelegate.current != current || oldDelegate.active != active;
}

/// Battery trace for the tracking screen.
class BatterySparkline extends StatelessWidget {
  const BatterySparkline({
    super.key,
    required this.levels,
    this.height = 54,
    this.color = AppColors.mint,
  });

  final List<int> levels;
  final double height;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _SparkPainter(levels: levels, color: color)),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter({required this.levels, required this.color});

  final List<int> levels;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (levels.length < 2) {
      final paint = Paint()
        ..color = AppColors.text.withValues(alpha: 0.12)
        ..strokeWidth = 1;
      canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
      return;
    }
    final min = levels.reduce(math.min).toDouble();
    final max = levels.reduce(math.max).toDouble();
    final span = math.max(max - min, 6).toDouble();
    final path = Path();
    final fill = Path();
    for (var i = 0; i < levels.length; i++) {
      final x = size.width * i / (levels.length - 1);
      final y = size.height - ((levels[i] - min) / span) * (size.height - 8) - 4;
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
    final last = Offset(size.width, size.height - ((levels.last - min) / span) * (size.height - 8) - 4);
    canvas.drawCircle(last, 3, Paint()..color = color);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter oldDelegate) =>
      oldDelegate.levels != levels || oldDelegate.color != color;
}

/// Expanding rings around a child — the signature "live" element.
class PulseOrb extends StatefulWidget {
  const PulseOrb({
    super.key,
    required this.child,
    this.size = 200,
    this.color = AppColors.mint,
    this.ringCount = 3,
  });

  final Widget child;
  final double size;
  final Color color;
  final int ringCount;

  @override
  State<PulseOrb> createState() => _PulseOrbState();
}

class _PulseOrbState extends State<PulseOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 3),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _PulsePainter(
            progress: _controller.value,
            color: widget.color,
            ringCount: widget.ringCount,
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter({required this.progress, required this.color, required this.ringCount});

  final double progress;
  final Color color;
  final int ringCount;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final base = math.min(size.width, size.height) * 0.28;
    for (var i = 0; i < ringCount; i++) {
      final t = (progress + i / ringCount) % 1.0;
      final r = base + t * (size.width * 0.22);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = color.withValues(alpha: (1 - t) * 0.22),
      );
    }
    canvas.drawCircle(
      center,
      base,
      Paint()
        ..shader = RadialGradient(
          colors: [color.withValues(alpha: 0.16), color.withValues(alpha: 0.02)],
        ).createShader(Rect.fromCircle(center: center, radius: base)),
    );
    canvas.drawCircle(
      center,
      base,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = color.withValues(alpha: 0.25),
    );
  }

  @override
  bool shouldRepaint(covariant _PulsePainter oldDelegate) => oldDelegate.progress != progress;
}
