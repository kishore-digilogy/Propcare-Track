import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/glass.dart';
import '../../core/widgets/maps.dart';
import '../../core/widgets/site_thumbnail_image.dart';
import '../../data/models/place.dart';
import '../../services/app_controller.dart';
import '../screens/site_detail_screen.dart';
import '../widgets/app_page.dart';

class SitesScreen extends StatefulWidget {
  const SitesScreen({super.key});

  @override
  State<SitesScreen> createState() => _SitesScreenState();
}

class _SitesScreenState extends State<SitesScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _showSiteMapSheet(BuildContext context, Site site, AppController controller) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        final distance = controller.distanceToSite(site);
        final active = controller.activeSiteVisit?.siteId == site.id;
        final inside = distance != null && controller.isInsideSite(site, distance);
        final office = controller.office;

        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Color(0x1A0F172A),
                blurRadius: 28,
                offset: Offset(0, -6),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            site.code.toUpperCase(),
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          site.name,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(sheetContext).pop(),
                    icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Address row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on, size: 16, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      site.address,
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF475569),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              // Map preview
              if (office != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: RadarMap(
                    office: office,
                    sites: [site],
                    current: controller.position,
                    accuracy: controller.accuracy,
                    trail: const [],
                    stationary: const [],
                    activeSiteId: active ? site.id : null,
                    height: 240,
                    showLegend: false,
                    siteOnly: true,
                  ),
                ),
              const SizedBox(height: 16),
              // Distance + radius info
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.near_me_rounded,
                            size: 14,
                            color: inside ? const Color(0xFF0E9F6E) : const Color(0xFF0284C7),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            distance == null ? 'Locating...' : Fmt.distance(distance),
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: inside ? const Color(0xFF0E9F6E) : const Color(0xFF0284C7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.radar_rounded,
                            size: 14,
                            color: Color(0xFF7E3AF2),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${site.radiusMeters.round()} m geofence',
                            style: const TextStyle(
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
              ),
              const SizedBox(height: 16),
              // Action button to full details
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SiteDetailScreen(site: site)),
                    );
                  },
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  label: const Text('Open Full Site Details'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    textStyle: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final sites = controller.sites.where((site) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return site.name.toLowerCase().contains(q) ||
          site.code.toLowerCase().contains(q) ||
          site.address.toLowerCase().contains(q);
    }).toList();

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
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.domain_rounded, size: 13, color: Color(0xFF0284C7)),
                SizedBox(width: 4),
                Text(
                  'PROPERTY ROSTER',
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
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Expanded(
                child: Text(
                  'Your sites,\nat a glance.',
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
                  color: controller.activeSiteVisit == null
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: controller.activeSiteVisit == null
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFFF87171),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.apartment_rounded,
                      size: 14,
                      color: controller.activeSiteVisit == null
                          ? const Color(0xFF64748B)
                          : const Color(0xFFDC2626),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      controller.activeSiteVisit == null ? 'NO OPEN VISIT' : 'ON SITE',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: controller.activeSiteVisit == null
                            ? const Color(0xFF64748B)
                            : const Color(0xFFDC2626),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${controller.sites.length} assigned properties · tap for details',
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 12,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Search Bar ───────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x060F172A),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            child: TextField(
              controller: _search,
              onChanged: (value) => setState(() => _query = value.trim()),
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF0F172A),
              ),
              decoration: InputDecoration(
                hintText: 'Search sites, codes or addresses',
                hintStyle: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  size: 20,
                  color: Color(0xFF0284C7),
                ),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFF64748B)),
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Active Site Visit Banner ─────────────────────────────────────
          if (controller.activeSiteVisit != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFCA5A5), width: 1.2),
              ),
              child: Row(
                children: [
                  const LiveDot(color: Color(0xFFDC2626), size: 8),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ACTIVE SITE VISIT',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          controller.activeSiteVisit!.siteName,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                  StatusPill(
                    label: Fmt.clock(controller.activeSiteVisit!.visitDuration),
                    color: const Color(0xFFDC2626),
                    dense: true,
                    icon: Icons.timer_outlined,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ─── Sites List ───────────────────────────────────────────────────
          if (sites.isEmpty)
            const EmptyState(
              icon: Icons.travel_explore_rounded,
              title: 'No sites match',
              message: 'Try a different site name, code or address.',
              accent: AppColors.violet,
            )
          else
            for (final site in sites) ...[
              _SiteCard(
                site: site,
                controller: controller,
                onViewInMap: () => _showSiteMapSheet(context, site, controller),
              ),
              const SizedBox(height: 14),
            ],
          const SizedBox(height: 8),

          // ─── Bottom Info Banner ───────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFDCFCE7), width: 1.2),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 19, color: Color(0xFF16A34A)),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Site check-in requires an active office attendance session. Checking in or out of a site never stops background tracking.',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 11,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF166534),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Redesigned Site Card with Address & View in Map
// ─────────────────────────────────────────────────────────────────────────────
class _SiteCard extends StatelessWidget {
  const _SiteCard({
    required this.site,
    required this.controller,
    required this.onViewInMap,
  });

  final Site site;
  final AppController controller;
  final VoidCallback onViewInMap;

  @override
  Widget build(BuildContext context) {
    final distance = controller.distanceToSite(site);
    final active = controller.activeSiteVisit?.siteId == site.id;
    final inside = distance != null && controller.isInsideSite(site, distance);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => SiteDetailScreen(site: site)),
      ),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: active
                ? const Color(0xFFDC2626).withValues(alpha: 0.4)
                : const Color(0xFFE8EEF5),
            width: 1.2,
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x080F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Code Pill + Status Pill
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0F2FE),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    site.code.toUpperCase(),
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0284C7),
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Spacer(),
                if (active)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFFDC2626)),
                        SizedBox(width: 4),
                        Text(
                          'ON SITE',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (inside)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFF16A34A)),
                        SizedBox(width: 4),
                        Text(
                          'INSIDE GEOFENCE',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  )
                else if (distance == null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF3C7),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(radius: 3, backgroundColor: Color(0xFFD97706)),
                        SizedBox(width: 4),
                        Text(
                          'LOCATING',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${Fmt.distance(distance)} away',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Site Title & Vector Building Graphic
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        site.name,
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Address Row with location pin
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.location_on,
                              size: 15,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              site.address,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                height: 1.35,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF475569),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                SiteThumbnailImage(
                  siteName: site.name,
                  address: site.address,
                  width: 96,
                  height: 68,
                  borderRadius: 14,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Metrics / Info row
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.near_me_outlined,
                        size: 13,
                        color: inside ? const Color(0xFF0E9F6E) : const Color(0xFF0284C7),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        active
                            ? 'You are on site'
                            : distance == null
                            ? 'Locating...'
                            : Fmt.distance(distance),
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: inside || active
                              ? const Color(0xFF0E9F6E)
                              : const Color(0xFF0284C7),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.radar_rounded,
                        size: 13,
                        color: Color(0xFF7E3AF2),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${site.radiusMeters.round()} m radius',
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF7E3AF2),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

            // Actions: "View in map" and "Site details"
            Row(
              children: [
                // View in map button
                Expanded(
                  child: InkWell(
                    onTap: onViewInMap,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0F2FE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.map_rounded, size: 14, color: Color(0xFF0284C7)),
                          SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              'View map',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Site details button
                Expanded(
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => SiteDetailScreen(site: site)),
                    ),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              'Site details',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(Icons.arrow_forward_rounded, size: 13, color: Color(0xFF334155)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Building Vector Graphic for Site Cards
// ─────────────────────────────────────────────────────────────────────────────
class _SiteCardBuildingGraphic extends StatelessWidget {
  const _SiteCardBuildingGraphic();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 64,
      child: CustomPaint(
        painter: _BuildingThumbnailPainter(),
      ),
    );
  }
}

class _BuildingThumbnailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Sky backdrop
    final skyPaint = Paint()
      ..color = const Color(0xFFE0F2FE).withValues(alpha: 0.9)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(4, 3, size.width - 8, size.height - 6),
        const Radius.circular(18),
      ),
      skyPaint,
    );

    // 2. Building geometry
    final buildingBase = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    final buildingSide = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..style = PaintingStyle.fill;
    final windowPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    final sideWindowPaint = Paint()
      ..color = const Color(0xFF0284C7)
      ..style = PaintingStyle.fill;

    // Side face
    final sidePath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.18)
      ..lineTo(size.width * 0.78, size.height * 0.28)
      ..lineTo(size.width * 0.78, size.height * 0.84)
      ..lineTo(size.width * 0.54, size.height * 0.88)
      ..close();
    canvas.drawPath(sidePath, buildingSide);

    // Front face
    final frontPath = Path()
      ..moveTo(size.width * 0.54, size.height * 0.18)
      ..lineTo(size.width * 0.30, size.height * 0.28)
      ..lineTo(size.width * 0.30, size.height * 0.84)
      ..lineTo(size.width * 0.54, size.height * 0.88)
      ..close();
    canvas.drawPath(frontPath, buildingBase);

    // Windows front
    for (var row = 0; row < 3; row++) {
      final y = size.height * (0.34 + row * 0.15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.35, y, 6, 5),
          const Radius.circular(1),
        ),
        windowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.45, y + 2, 6, 5),
          const Radius.circular(1),
        ),
        windowPaint,
      );
    }

    // Windows side
    for (var row = 0; row < 3; row++) {
      final y = size.height * (0.36 + row * 0.15);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.58, y + 2, 5, 4),
          const Radius.circular(1),
        ),
        sideWindowPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(size.width * 0.67, y, 5, 4),
          const Radius.circular(1),
        ),
        sideWindowPaint,
      );
    }

    // 3. Green lawn
    final grassPaint = Paint()
      ..color = const Color(0xFF86EFAC)
      ..style = PaintingStyle.fill;
    final grassPath = Path()
      ..moveTo(4, size.height * 0.86)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.80,
        size.width - 4,
        size.height * 0.86,
      )
      ..lineTo(size.width - 4, size.height - 3)
      ..lineTo(4, size.height - 3)
      ..close();
    canvas.drawPath(grassPath, grassPaint);

    // 4. Little trees
    final treeCrown = Paint()
      ..color = const Color(0xFF22C55E)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(size.width * 0.20, size.height * 0.76), 7, treeCrown);
    canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.76), 7, treeCrown);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
