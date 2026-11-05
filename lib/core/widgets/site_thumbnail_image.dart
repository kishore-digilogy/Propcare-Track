import 'package:flutter/material.dart';

import '../../services/wikipedia_image_service.dart';

/// Renders a real photo for a site fetched asynchronously from Wikipedia / Wikimedia Commons,
/// with a graceful fallback to a modern vector building graphic while loading or offline.
class SiteThumbnailImage extends StatefulWidget {
  const SiteThumbnailImage({
    super.key,
    required this.siteName,
    this.address,
    this.width = 106,
    this.height = 74,
    this.borderRadius = 16,
  });

  final String siteName;
  final String? address;
  final double width;
  final double height;
  final double borderRadius;

  @override
  State<SiteThumbnailImage> createState() => _SiteThumbnailImageState();
}

class _SiteThumbnailImageState extends State<SiteThumbnailImage> {
  late Future<String?> _imageFuture;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant SiteThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.siteName != widget.siteName || oldWidget.address != widget.address) {
      _fetch();
    }
  }

  void _fetch() {
    _imageFuture = WikipediaImageService.instance.fetchImageForSite(
      widget.siteName,
      address: widget.address,
    );
  }

  String? _resolveLocalAsset(String name) {
    final lower = name.toLowerCase();
    if (lower.contains('first') || lower.contains('firstcity') || lower.contains('first city')) {
      return 'assets/sites/casagrand_firstcity.jpg';
    }
    if (lower.contains('sun') || lower.contains('suncity') || lower.contains('sun city')) {
      return 'assets/sites/casagrand_suncity.jpg';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final localAsset = _resolveLocalAsset(widget.siteName);
    if (localAsset != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                localAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _FallbackBuildingGraphic(
                  width: widget.width,
                  height: widget.height,
                ),
              ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Color(0x330F172A),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final cachedUrl = WikipediaImageService.instance.getCached(widget.siteName);

    return SizedBox(
      width: widget.width,
      height: widget.height,
      child: FutureBuilder<String?>(
        initialData: cachedUrl,
        future: _imageFuture,
        builder: (context, snapshot) {
          final imageUrl = snapshot.data;
          if (imageUrl != null && imageUrl.isNotEmpty) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => _FallbackBuildingGraphic(
                      width: widget.width,
                      height: widget.height,
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          _FallbackBuildingGraphic(
                            width: widget.width,
                            height: widget.height,
                          ),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  // Subtle bottom gradient shadow for depth
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Color(0x330F172A),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Small Wiki source indicator badge
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4.5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.public_rounded, size: 8, color: Colors.white),
                          SizedBox(width: 2.5),
                          Text(
                            'WIKI',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 0.4,
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

          return _FallbackBuildingGraphic(
            width: widget.width,
            height: widget.height,
          );
        },
      ),
    );
  }
}

class _FallbackBuildingGraphic extends StatelessWidget {
  const _FallbackBuildingGraphic({
    required this.width,
    required this.height,
  });

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _BuildingVectorPainter()),
    );
  }
}

class _BuildingVectorPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sky backdrop
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

    // Building side
    final sidePath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.16)
      ..lineTo(size.width * 0.82, size.height * 0.28)
      ..lineTo(size.width * 0.82, size.height * 0.86)
      ..lineTo(size.width * 0.54, size.height * 0.90)
      ..close();
    canvas.drawPath(sidePath, buildingSide);

    // Building front
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

    // Windows
    for (var row = 0; row < 4; row++) {
      final yOffset = size.height * (0.34 + row * 0.12);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.34, yOffset, 5, 4.5),
          const Radius.circular(1.2),
        ),
        windowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.44, yOffset, 5, 4.5),
          const Radius.circular(1.2),
        ),
        windowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.60, yOffset - 1, 5, 4.5),
          const Radius.circular(1.2),
        ),
        windowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.70, yOffset - 2, 5, 4.5),
          const Radius.circular(1.2),
        ),
        windowPaint,
      );
    }

    // Green lawn base
    final groundPaint = Paint()
      ..color = const Color(0xFF4ADE80)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(size.width * 0.12, size.height * 0.84, size.width * 0.76, 7),
        const Radius.circular(4),
      ),
      groundPaint,
    );

    // Trees
    final treePaint = Paint()
      ..color = const Color(0xFF16A34A)
      ..style = PaintingStyle.fill;
    final trunkPaint = Paint()
      ..color = const Color(0xFF78350F)
      ..style = PaintingStyle.fill;

    // Left tree
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.20, size.height * 0.75, 2.5, 9),
      trunkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.21, size.height * 0.72),
      7,
      treePaint,
    );

    // Right tree
    canvas.drawRect(
      Rect.fromLTWH(size.width * 0.78, size.height * 0.75, 2.5, 9),
      trunkPaint,
    );
    canvas.drawCircle(
      Offset(size.width * 0.79, size.height * 0.72),
      7,
      treePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

