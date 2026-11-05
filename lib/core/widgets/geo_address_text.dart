import 'package:flutter/material.dart';

import '../../services/geo_address_service.dart';

/// Renders a human-readable street/area address for GPS coordinates.
/// Automatically resolves via reverse geocoding with caching, and falls back to
/// coordinates if offline or unresolved.
class GeoAddressText extends StatefulWidget {
  const GeoAddressText({
    super.key,
    required this.latitude,
    required this.longitude,
    this.style,
    this.fallbackText,
    this.prefixIcon,
    this.showCoordinatesFallback = true,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  final double latitude;
  final double longitude;
  final TextStyle? style;
  final String? fallbackText;
  final Widget? prefixIcon;
  final bool showCoordinatesFallback;
  final int maxLines;
  final TextOverflow overflow;

  @override
  State<GeoAddressText> createState() => _GeoAddressTextState();
}

class _GeoAddressTextState extends State<GeoAddressText> {
  String? _address;

  @override
  void initState() {
    super.initState();
    _resolveAddress();
  }

  @override
  void didUpdateWidget(covariant GeoAddressText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.latitude - widget.latitude).abs() > 0.0005 ||
        (oldWidget.longitude - widget.longitude).abs() > 0.0005) {
      _resolveAddress();
    }
  }

  void _resolveAddress() {
    final cached = GeoAddressService.instance.getCached(widget.latitude, widget.longitude);
    if (cached != null) {
      _address = cached;
      return;
    }

    GeoAddressService.instance.resolve(widget.latitude, widget.longitude).then((resolved) {
      if (mounted && resolved != null && resolved.isNotEmpty) {
        setState(() {
          _address = resolved;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultFallback = widget.showCoordinatesFallback
        ? '${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}'
        : 'Locating address…';

    final displayText = _address ?? widget.fallbackText ?? defaultFallback;

    final textWidget = Text(
      displayText,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
      style: widget.style,
    );

    if (widget.prefixIcon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          widget.prefixIcon!,
          const SizedBox(width: 4),
          Flexible(child: textWidget),
        ],
      );
    }

    return textWidget;
  }
}

