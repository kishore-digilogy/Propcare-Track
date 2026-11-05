import '../db/app_database.dart';
import '../models/place.dart';

class ConfigRepository {
  ConfigRepository(this._db);

  final AppDatabase _db;

  Future<OfficeConfig> office() async {
    final db = await _db.database;
    final rows = await db.query('office_config', limit: 1);
    if (rows.isEmpty) {
      throw StateError('Office configuration missing');
    }
    return OfficeConfig.fromMap(rows.first);
  }

  Future<List<Site>> sites() async {
    final db = await _db.database;
    final rows = await db.query('assigned_sites', where: 'is_active = 1', orderBy: 'sort_order ASC');
    return rows.map(Site.fromMap).toList();
  }

  Future<void> updateSiteRadius(String siteId, double radiusMeters) async {
    final db = await _db.database;
    await db.update('assigned_sites', {'radius_meters': radiusMeters}, where: 'id = ?', whereArgs: [siteId]);
  }

  Future<void> updateOfficeRadius(double radiusMeters) async {
    final db = await _db.database;
    await db.update('office_config', {'radius_meters': radiusMeters});
  }
}
