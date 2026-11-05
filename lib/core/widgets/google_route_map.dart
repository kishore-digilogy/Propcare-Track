import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../data/models/place.dart';
import '../../data/models/tracking.dart';
import '../../services/geo_address_service.dart';
import '../theme/app_colors.dart';
import '../utils/formatters.dart';
import '../utils/geo.dart';

/// Google Maps is only available on Android and iOS. Desktop and widget tests
/// fall back to the hand-painted [RadarMap] in `maps.dart`.
bool get supportsGoogleMaps =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// A real Google Map that plots the office, assigned sites, the live fix and
/// the stored breadcrumb trail as a route polyline.
class GoogleRouteMap extends StatefulWidget {
  const GoogleRouteMap({
    super.key,
    required this.office,
    this.sites = const [],
    this.route = const [],
    this.stationaryEvents = const [],
    this.current,
    this.accuracy = 0,
    this.activeSiteId,
    this.height = 360,
    this.showTag = true,
    this.radius = 24,
    this.siteOnly = false,
    this.officeOnly = false,
  });

  final OfficeConfig office;
  final List<Site> sites;
  final List<GeoPoint> route;
  final List<StationaryEvent> stationaryEvents;
  final GeoPoint? current;
  final double accuracy;
  final String? activeSiteId;
  final double height;
  final bool showTag;
  final double radius;
  final bool siteOnly;
  final bool officeOnly;

  @override
  State<GoogleRouteMap> createState() => _GoogleRouteMapState();
}

class _GoogleRouteMapState extends State<GoogleRouteMap> {
  GoogleMapController? _controller;
  bool _expandedHeight = false;
  MapType _mapType = MapType.terrain;
  bool _currentInfoShown = false;

  String _currentLocationLabel() {
    final cur = widget.current;
    if (cur == null) return '';
    final coords =
        '${cur.latitude.toStringAsFixed(5)}, ${cur.longitude.toStringAsFixed(5)}';
    if (widget.accuracy > 0) {
      return '$coords · ±${widget.accuracy.round()} m';
    }
    return coords;
  }

  void _showCurrentMarker() {
    if (!widget.officeOnly || widget.current == null || _currentInfoShown) {
      return;
    }
    _currentInfoShown = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 350), () {
        if (!mounted) return;
        _controller?.showMarkerInfoWindow(const MarkerId('current'));
      });
    });
  }

  void _cycleMapType() {
    setState(() {
      switch (_mapType) {
        case MapType.terrain:
          _mapType = MapType.normal;
          break;
        case MapType.normal:
          _mapType = MapType.hybrid;
          break;
        default:
          _mapType = MapType.terrain;
          break;
      }
    });
  }

  LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

  List<GeoPoint> get _boundsPoints {
    if (widget.officeOnly) {
      return [widget.office.point, if (widget.current != null) widget.current!];
    }
    final points = <GeoPoint>[
      widget.office.point,
      if (widget.current != null) widget.current!,
      ...widget.route,
      ...widget.stationaryEvents.map((e) => e.point),
    ];
    // Before a session starts, include the sites so the map is useful.
    if (widget.route.length < 2) {
      points.addAll(widget.sites.map((site) => site.point));
    }
    return points;
  }

  void _fitBounds() {
    final controller = _controller;
    if (controller == null) return;

    if (widget.officeOnly) {
      final officePoint = widget.office.point;
      final cur = widget.current;
      if (cur != null) {
        final dist = distanceBetween(officePoint, cur);
        // Keep both pins in frame when the employee is close to the office.
        if (dist > 25 && dist <= 1500) {
          final minLat = math.min(officePoint.latitude, cur.latitude);
          final maxLat = math.max(officePoint.latitude, cur.latitude);
          final minLng = math.min(officePoint.longitude, cur.longitude);
          final maxLng = math.max(officePoint.longitude, cur.longitude);
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              64,
            ),
          );
          return;
        }
        // Follow the employee's actual fix, not the office pin.
        controller.animateCamera(CameraUpdate.newLatLngZoom(_latLng(cur), 17));
        return;
      }
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_latLng(officePoint), 16),
      );
      return;
    }

    if (widget.siteOnly && widget.sites.isNotEmpty) {
      final sitePoint = widget.sites.first.point;
      final cur = widget.current;
      if (cur != null) {
        final dist = distanceBetween(sitePoint, cur);
        if (dist <= 1500) {
          final minLat = math.min(sitePoint.latitude, cur.latitude);
          final maxLat = math.max(sitePoint.latitude, cur.latitude);
          final minLng = math.min(sitePoint.longitude, cur.longitude);
          final maxLng = math.max(sitePoint.longitude, cur.longitude);
          controller.animateCamera(
            CameraUpdate.newLatLngBounds(
              LatLngBounds(
                southwest: LatLng(minLat, minLng),
                northeast: LatLng(maxLat, maxLng),
              ),
              64,
            ),
          );
          return;
        }
      }
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_latLng(sitePoint), 16),
      );
      return;
    }

    final points = _boundsPoints;
    if (points.isEmpty) return;

    var minLat = points.first.latitude;
    var maxLat = points.first.latitude;
    var minLng = points.first.longitude;
    var maxLng = points.first.longitude;
    for (final point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    // A single point or a stationary fix cannot form a valid bounds rectangle.
    if ((maxLat - minLat).abs() < 0.00005 &&
        (maxLng - minLng).abs() < 0.00005) {
      controller.animateCamera(
        CameraUpdate.newLatLngZoom(_latLng(points.first), 16),
      );
      return;
    }

    controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        48,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _preResolveAddresses();
  }

  void _preResolveAddresses() {
    for (final stop in widget.stationaryEvents) {
      GeoAddressService.instance.resolve(stop.latitude, stop.longitude).then((
        _,
      ) {
        if (mounted) setState(() {});
      });
    }
    if (widget.route.isNotEmpty) {
      GeoAddressService.instance
          .resolve(widget.route.first.latitude, widget.route.first.longitude)
          .then((_) {
            if (mounted) setState(() {});
          });
      GeoAddressService.instance
          .resolve(widget.route.last.latitude, widget.route.last.longitude)
          .then((_) {
            if (mounted) setState(() {});
          });
    }
  }

  Set<Marker> _markers() {
    if (widget.officeOnly) {
      return {
        Marker(
          markerId: const MarkerId('office'),
          position: _latLng(widget.office.point),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueOrange,
          ),
          infoWindow: InfoWindow(
            title: 'Office',
            snippet: '${widget.office.radiusMeters.round()} m radius',
          ),
        ),
        if (widget.current != null)
          Marker(
            markerId: const MarkerId('current'),
            position: _latLng(widget.current!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: 'You are here',
              snippet: _currentLocationLabel(),
            ),
          ),
      };
    }

    if (widget.siteOnly) {
      final targetSite = widget.sites.isNotEmpty ? widget.sites.first : null;
      return {
        if (targetSite != null)
          Marker(
            markerId: MarkerId('site-${targetSite.id}'),
            position: _latLng(targetSite.point),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              targetSite.id == widget.activeSiteId
                  ? BitmapDescriptor.hueViolet
                  : BitmapDescriptor.hueGreen,
            ),
            infoWindow: InfoWindow(
              title: targetSite.name,
              snippet: '${targetSite.code} · ${targetSite.address}',
            ),
          ),
        if (widget.current != null)
          Marker(
            markerId: const MarkerId('current'),
            position: _latLng(widget.current!),
            icon: BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueAzure,
            ),
            infoWindow: InfoWindow(
              title: 'Your Location',
              snippet: GeoAddressService.instance.getCached(
                widget.current!.latitude,
                widget.current!.longitude,
              ),
            ),
          ),
      };
    }

    return {
      Marker(
        markerId: const MarkerId('office'),
        position: _latLng(widget.office.point),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
        infoWindow: InfoWindow(
          title: widget.office.name,
          snippet: 'Office · ${widget.office.radiusMeters.round()} m radius',
        ),
      ),
      for (final site in widget.sites)
        Marker(
          markerId: MarkerId('site-${site.id}'),
          position: _latLng(site.point),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            site.id == widget.activeSiteId
                ? BitmapDescriptor.hueViolet
                : BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: site.name,
            snippet: '${site.code} · ${site.address}',
          ),
        ),
      for (var i = 0; i < widget.stationaryEvents.length; i++) ...[
        Marker(
          markerId: MarkerId('stationary-${widget.stationaryEvents[i].id}'),
          position: LatLng(
            widget.stationaryEvents[i].latitude,
            widget.stationaryEvents[i].longitude,
          ),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueYellow,
          ),
          infoWindow: InfoWindow(
            title:
                'Hold #${i + 1} (${Fmt.duration(widget.stationaryEvents[i].duration)})',
            snippet:
                GeoAddressService.instance.getCached(
                  widget.stationaryEvents[i].latitude,
                  widget.stationaryEvents[i].longitude,
                ) ??
                'Hold at ${Fmt.time(widget.stationaryEvents[i].startAt)}',
          ),
        ),
      ],
      if (widget.route.length >= 2) ...[
        Marker(
          markerId: const MarkerId('route-start-checkin'),
          position: _latLng(widget.route.first),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueGreen,
          ),
          infoWindow: InfoWindow(
            title: 'Office Check-in',
            snippet:
                GeoAddressService.instance.getCached(
                  widget.route.first.latitude,
                  widget.route.first.longitude,
                ) ??
                'Session started here',
          ),
        ),
        Marker(
          markerId: const MarkerId('route-end-checkout'),
          position: _latLng(widget.route.last),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: InfoWindow(
            title: 'Check-out / Latest',
            snippet:
                GeoAddressService.instance.getCached(
                  widget.route.last.latitude,
                  widget.route.last.longitude,
                ) ??
                'Session ended here',
          ),
        ),
      ],
      if (widget.current != null)
        Marker(
          markerId: const MarkerId('current'),
          position: _latLng(widget.current!),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
          infoWindow: InfoWindow(
            title: 'You are here',
            snippet: GeoAddressService.instance.getCached(
              widget.current!.latitude,
              widget.current!.longitude,
            ),
          ),
        ),
    };
  }

  Set<Polyline> _polylines() {
    if (widget.siteOnly || widget.officeOnly) return {};
    final points = widget.route.map(_latLng).toList(growable: false);
    if (points.length < 2) return {};
    return {
      Polyline(
        polylineId: const PolylineId('route-glow'),
        points: points,
        color: AppColors.cyan.withValues(alpha: 0.18),
        width: 11,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
      Polyline(
        polylineId: const PolylineId('route'),
        points: points,
        color: AppColors.cyan,
        width: 5,
        jointType: JointType.round,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
      ),
    };
  }

  Set<Circle> _circles() {
    if (widget.officeOnly) {
      return {
        Circle(
          circleId: const CircleId('office-radius'),
          center: _latLng(widget.office.point),
          radius: widget.office.radiusMeters,
          fillColor: AppColors.mint.withValues(alpha: 0.12),
          strokeColor: AppColors.mint,
          strokeWidth: 2,
        ),
        if (widget.current != null && widget.accuracy > 0)
          Circle(
            circleId: const CircleId('accuracy'),
            center: _latLng(widget.current!),
            radius: widget.accuracy,
            fillColor: AppColors.cyan.withValues(alpha: 0.10),
            strokeColor: AppColors.cyan.withValues(alpha: 0.30),
            strokeWidth: 1,
          ),
      };
    }

    if (widget.siteOnly) {
      final targetSite = widget.sites.isNotEmpty ? widget.sites.first : null;
      return {
        if (targetSite != null)
          Circle(
            circleId: CircleId('site-radius-${targetSite.id}'),
            center: _latLng(targetSite.point),
            radius: targetSite.radiusMeters,
            fillColor: AppColors.mint.withValues(alpha: 0.12),
            strokeColor: AppColors.mint,
            strokeWidth: 2,
          ),
        if (widget.current != null && widget.accuracy > 0)
          Circle(
            circleId: const CircleId('accuracy'),
            center: _latLng(widget.current!),
            radius: widget.accuracy,
            fillColor: AppColors.cyan.withValues(alpha: 0.10),
            strokeColor: AppColors.cyan.withValues(alpha: 0.30),
            strokeWidth: 1,
          ),
      };
    }

    return {
      Circle(
        circleId: const CircleId('office-radius'),
        center: _latLng(widget.office.point),
        radius: widget.office.radiusMeters,
        fillColor: AppColors.mint.withValues(alpha: 0.07),
        strokeColor: AppColors.mint.withValues(alpha: 0.45),
        strokeWidth: 1,
      ),
      for (final site in widget.sites)
        Circle(
          circleId: CircleId('site-radius-${site.id}'),
          center: _latLng(site.point),
          radius: site.radiusMeters,
          fillColor:
              (site.id == widget.activeSiteId
                      ? AppColors.violet
                      : AppColors.mint)
                  .withValues(alpha: 0.05),
          strokeColor:
              (site.id == widget.activeSiteId
                      ? AppColors.violet
                      : AppColors.mint)
                  .withValues(alpha: 0.25),
          strokeWidth: 1,
        ),
      for (final stop in widget.stationaryEvents)
        Circle(
          circleId: CircleId('stationary-circle-${stop.id}'),
          center: LatLng(stop.latitude, stop.longitude),
          radius: stop.radiusMeters,
          fillColor: AppColors.amber.withValues(alpha: 0.12),
          strokeColor: AppColors.amber.withValues(alpha: 0.55),
          strokeWidth: 1,
        ),
      if (widget.current != null && widget.accuracy > 0)
        Circle(
          circleId: const CircleId('accuracy'),
          center: _latLng(widget.current!),
          radius: widget.accuracy,
          fillColor: AppColors.cyan.withValues(alpha: 0.10),
          strokeColor: AppColors.cyan.withValues(alpha: 0.30),
          strokeWidth: 1,
        ),
    };
  }

  @override
  void didUpdateWidget(covariant GoogleRouteMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.stationaryEvents != widget.stationaryEvents ||
        oldWidget.route != widget.route) {
      _preResolveAddresses();
    }
    if ((oldWidget.route.isEmpty && widget.route.isNotEmpty) ||
        (oldWidget.route != widget.route)) {
      _fitBounds();
    }
    // The office/check-in map follows the live fix as it changes.
    if (widget.officeOnly) {
      if (widget.current == null) _currentInfoShown = false;
      final moved = oldWidget.current == null
          ? widget.current != null
          : widget.current == null ||
                distanceBetween(oldWidget.current!, widget.current!) > 25;
      if (moved) _fitBounds();
      _showCurrentMarker();
    }
  }

  @override
  Widget build(BuildContext context) {
    final target = (widget.siteOnly && widget.sites.isNotEmpty)
        ? widget.sites.first.point
        : (widget.current ?? widget.office.point);
    final fixes = widget.route.length;
    final effectiveHeight = _expandedHeight
        ? (widget.height + 220).clamp(480.0, 720.0)
        : widget.height;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeInOut,
      height: effectiveHeight,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: AppColors.lineStrong),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 20,
            spreadRadius: -6,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(widget.radius - 1),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: _latLng(target),
                zoom: (widget.siteOnly || widget.officeOnly) ? 16 : 15,
              ),
              onMapCreated: (controller) {
                _controller = controller;
                _fitBounds();
                _showCurrentMarker();
              },
              markers: _markers(),
              polylines: _polylines(),
              circles: _circles(),
              mapType: _mapType,
              gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
                Factory<OneSequenceGestureRecognizer>(
                  () => EagerGestureRecognizer(),
                ),
              },
              compassEnabled: true,
              mapToolbarEnabled: true,
              myLocationButtonEnabled: false,
              myLocationEnabled: false,
              zoomControlsEnabled: false,
              rotateGesturesEnabled: true,
              tiltGesturesEnabled: true,
              scrollGesturesEnabled: true,
              zoomGesturesEnabled: true,
            ),
            if (widget.showTag)
              Positioned(
                left: 12,
                top: 12,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.siteOnly && widget.sites.isNotEmpty)
                      _MapTag(
                        icon: Icons.apartment_rounded,
                        label:
                            '${widget.sites.first.code} · ${widget.sites.first.radiusMeters.round()}M',
                        color: AppColors.mint,
                      )
                    else if (widget.officeOnly)
                      _MapTag(
                        icon: Icons.my_location_rounded,
                        label: widget.current == null
                            ? 'LOCATING'
                            : 'YOU ARE HERE',
                        color: widget.current == null
                            ? AppColors.amber
                            : AppColors.mint,
                      )
                    else
                      _MapTag(
                        icon: Icons.route_rounded,
                        label: fixes < 2 ? 'ROUTE READY' : '$fixes FIXES',
                        color: AppColors.cyan,
                      ),
                    const SizedBox(width: 6),
                    _MapTag(
                      icon: _mapType == MapType.terrain
                          ? Icons.park_rounded
                          : _mapType == MapType.hybrid
                          ? Icons.satellite_alt_rounded
                          : Icons.map_rounded,
                      label: _mapType == MapType.terrain
                          ? 'TERRAIN'
                          : _mapType == MapType.hybrid
                          ? 'SATELLITE'
                          : 'NORMAL',
                      color: _mapType == MapType.terrain
                          ? AppColors.mint
                          : AppColors.cyan,
                    ),
                  ],
                ),
              ),
            // Top-right controls: Layer switch & expand toggle
            Positioned(
              right: 12,
              top: 12,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapActionButton(
                    icon: _mapType == MapType.terrain
                        ? Icons.terrain_rounded
                        : _mapType == MapType.hybrid
                        ? Icons.satellite_alt_rounded
                        : Icons.map_rounded,
                    tooltip: 'Map layer: ${_mapType.name.toUpperCase()}',
                    onTap: _cycleMapType,
                  ),
                  const SizedBox(width: 6),
                  _MapActionButton(
                    icon: _expandedHeight
                        ? Icons.fullscreen_exit_rounded
                        : Icons.fullscreen_rounded,
                    tooltip: _expandedHeight ? 'Collapse map' : 'Expand map',
                    onTap: () {
                      setState(() => _expandedHeight = !_expandedHeight);
                      Future.delayed(
                        const Duration(milliseconds: 280),
                        _fitBounds,
                      );
                    },
                  ),
                ],
              ),
            ),
            // Bottom-right on-map controls: Zoom In, Zoom Out, Fit Route
            Positioned(
              right: 12,
              bottom: 12,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _MapActionButton(
                    icon: Icons.add_rounded,
                    tooltip: 'Zoom in',
                    onTap: () =>
                        _controller?.animateCamera(CameraUpdate.zoomIn()),
                  ),
                  const SizedBox(height: 6),
                  _MapActionButton(
                    icon: Icons.remove_rounded,
                    tooltip: 'Zoom out',
                    onTap: () =>
                        _controller?.animateCamera(CameraUpdate.zoomOut()),
                  ),
                  const SizedBox(height: 6),
                  _MapActionButton(
                    icon: Icons.my_location_rounded,
                    tooltip: widget.officeOnly
                        ? 'Center on my location'
                        : 'Fit route',
                    accent: true,
                    onTap: _fitBounds,
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

class _MapActionButton extends StatelessWidget {
  const _MapActionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        elevation: 3,
        shadowColor: const Color(0x330F172A),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: SizedBox(
            width: 38,
            height: 38,
            child: Icon(
              icon,
              size: 20,
              color: accent ? const Color(0xFF0284C7) : const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }
}

class _MapTag extends StatelessWidget {
  const _MapTag({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surface.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.lineStrong),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

const String _lightMapStyle = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f5f7fa"}]},
  {"elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#667085"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#ffffff"}]},
  {"featureType":"administrative.land_parcel","elementType":"labels.text.fill","stylers":[{"color":"#b8c0cc"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#eef2f7"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#8a94a6"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#e6f4ea"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#7a9a85"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"labels.text.fill","stylers":[{"color":"#8a94a6"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#e3e8ef"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#667085"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#a2abba"}]},
  {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#e3e8ef"}]},
  {"featureType":"transit.station","elementType":"geometry","stylers":[{"color":"#eef2f7"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#cfe8f5"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#8a94a6"}]}
]
''';
