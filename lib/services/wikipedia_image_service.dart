import 'dart:convert';
import 'dart:io';

/// Service that searches the Wikipedia & Wikimedia Commons API for images
/// matching a site's name or locality, caching results in memory.
class WikipediaImageService {
  WikipediaImageService._();

  static final WikipediaImageService instance = WikipediaImageService._();

  final Map<String, String?> _cache = {};

  String? getCached(String siteName) => _cache[siteName];

  /// Searches Wikipedia for the best thumbnail image for the given [siteName].
  Future<String?> fetchImageForSite(
    String siteName, {
    String? address,
  }) async {
    if (_cache.containsKey(siteName)) {
      return _cache[siteName];
    }

    // Generate prioritized search queries:
    // 1. Direct site name (e.g. "Casagrand Suncity")
    // 2. Site name + Chennai (e.g. "Casagrand Suncity Chennai")
    // 3. Locality extracted from address (e.g. "Kelambakkam", "Sholinganallur")
    final queries = <String>[
      siteName,
      '$siteName Chennai',
    ];

    if (address != null && address.isNotEmpty) {
      final locality = _extractLocality(address);
      if (locality != null && !queries.contains(locality)) {
        queries.add(locality);
      }
    }

    for (final q in queries) {
      try {
        final url = await _searchWikipediaImage(q);
        if (url != null && url.isNotEmpty) {
          _cache[siteName] = url;
          return url;
        }
      } catch (_) {
        // Continue to fallback query
      }
    }

    _cache[siteName] = null;
    return null;
  }

  Future<String?> _searchWikipediaImage(String query) async {
    try {
      final uri = Uri.parse(
        'https://en.wikipedia.org/w/api.php?action=query&generator=search'
        '&gsrsearch=${Uri.encodeComponent(query)}&gsrlimit=3'
        '&prop=pageimages&pithumbsize=400&format=json',
      );

      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 4);
      final request = await client.getUrl(uri);
      request.headers.set('User-Agent', 'PropCareTrack/1.0 (field-app@propcare.app)');
      final response = await request.close().timeout(const Duration(seconds: 4));

      if (response.statusCode != HttpStatus.ok) {
        client.close();
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      client.close();

      final json = jsonDecode(body) as Map<String, dynamic>;
      final queryObj = json['query'] as Map<String, dynamic>?;
      final pages = queryObj?['pages'] as Map<String, dynamic>?;
      if (pages == null || pages.isEmpty) return null;

      // Iterate through the returned pages to find one with a valid thumbnail
      for (final page in pages.values) {
        if (page is Map) {
          final title = (page['title']?.toString() ?? '').toLowerCase();
          // Reject people, musicians, filmography, discographies, albums
          if (title.contains('discography') ||
              title.contains('filmography') ||
              title.contains('awards') ||
              title.contains('songs') ||
              title.contains('album') ||
              title.contains('actor') ||
              title.contains('singer') ||
              title.contains('anirudh') ||
              title.contains('musician')) {
            continue;
          }
          final thumb = page['thumbnail'] as Map?;
          final source = thumb?['source']?.toString();
          if (source != null && source.startsWith('http')) {
            return source;
          }
        }
      }
    } catch (_) {
      // In offline / test environments, fail silently.
    }
    return null;
  }

  String? _extractLocality(String address) {
    final parts = address.split(RegExp(r'[,/–-]')).map((s) => s.trim()).toList();
    for (final part in parts) {
      if (part.isEmpty) continue;
      if (part.toLowerCase().contains('chennai')) continue;
      if (part.toLowerCase().contains('road')) continue;
      return part;
    }
    return null;
  }
}

