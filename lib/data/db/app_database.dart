import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../core/config/app_config.dart';

/// Local-only persistence for Phase 1.
///
/// Every table carries a `sync_status` (or is reachable from one that does) so
/// the Phase 2 sync worker can push pending rows without a schema rewrite.
class AppDatabase {
  AppDatabase._()
      : _factory = null,
        _path = null;

  /// Test seam: lets widget/unit tests use an in-memory FFI database without
  /// touching path_provider or the real device database.
  AppDatabase.forTesting({DatabaseFactory? factory, String? path})
      : _factory = factory ?? databaseFactoryFfi,
        _path = path ?? inMemoryDatabasePath;

  static final AppDatabase instance = AppDatabase._();

  final DatabaseFactory? _factory;
  final String? _path;

  Database? _db;

  Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _open();
    return _db!;
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }

  Future<Database> _open() async {
    if (kIsWeb) {
      throw UnsupportedError('PropCare Track persistence requires a mobile or desktop build.');
    }

    if (_factory != null) {
      return _factory.openDatabase(
        _path!,
        options: OpenDatabaseOptions(
          version: 1,
          onConfigure: (db) async {
            await db.execute('PRAGMA foreign_keys = ON');
          },
          onCreate: _onCreate,
        ),
      );
    }

    String path;
    if (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      final dir = await getApplicationSupportDirectory();
      path = p.join(dir.path, 'propcare_track.db');
    } else {
      path = p.join(await getDatabasesPath(), 'propcare_track.db');
    }

    return openDatabase(
      path,
      version: 1,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();

    batch.execute('''
      CREATE TABLE employees (
        id TEXT PRIMARY KEY,
        code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        email TEXT NOT NULL UNIQUE,
        phone TEXT,
        department TEXT,
        designation TEXT,
        joined_at TEXT,
        avatar_seed TEXT,
        password_hash TEXT NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE office_config (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius_meters REAL NOT NULL
      )
    ''');

    batch.execute('''
      CREATE TABLE assigned_sites (
        id TEXT PRIMARY KEY,
        code TEXT,
        name TEXT NOT NULL,
        address TEXT,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        radius_meters REAL NOT NULL,
        is_active INTEGER NOT NULL DEFAULT 1,
        sort_order INTEGER NOT NULL DEFAULT 0
      )
    ''');

    batch.execute('''
      CREATE TABLE attendance_records (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        office_id TEXT NOT NULL,
        check_in_at INTEGER NOT NULL,
        check_out_at INTEGER,
        check_in_lat REAL NOT NULL,
        check_in_lng REAL NOT NULL,
        check_in_accuracy REAL NOT NULL,
        check_in_battery INTEGER NOT NULL,
        check_out_lat REAL,
        check_out_lng REAL,
        check_out_accuracy REAL,
        check_out_battery INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        total_duration_seconds INTEGER,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_attendance_emp ON attendance_records(employee_id, check_in_at)');
    batch.execute('CREATE INDEX idx_attendance_status ON attendance_records(employee_id, status)');

    batch.execute('''
      CREATE TABLE tracking_sessions (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        attendance_id TEXT NOT NULL,
        office_id TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        platform TEXT NOT NULL,
        start_battery INTEGER NOT NULL,
        end_battery INTEGER,
        last_latitude REAL,
        last_longitude REAL,
        last_update_at INTEGER,
        distance_meters REAL NOT NULL DEFAULT 0,
        location_count INTEGER NOT NULL DEFAULT 0,
        sync_status TEXT NOT NULL DEFAULT 'pending',
        created_at INTEGER NOT NULL
      )
    ''');
    batch.execute('CREATE INDEX idx_sessions_emp ON tracking_sessions(employee_id, started_at)');
    batch.execute('CREATE INDEX idx_sessions_status ON tracking_sessions(employee_id, status)');

    batch.execute('''
      CREATE TABLE location_records (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        accuracy REAL NOT NULL,
        speed REAL,
        bearing REAL,
        battery INTEGER NOT NULL,
        platform TEXT NOT NULL,
        movement_status TEXT NOT NULL DEFAULT 'unknown',
        recorded_at INTEGER NOT NULL,
        source TEXT NOT NULL DEFAULT 'native',
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    batch.execute('CREATE INDEX idx_locations_session ON location_records(session_id, recorded_at)');
    batch.execute('CREATE INDEX idx_locations_emp ON location_records(employee_id, recorded_at)');

    batch.execute('''
      CREATE TABLE stationary_events (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        start_at INTEGER NOT NULL,
        end_at INTEGER,
        duration_seconds INTEGER NOT NULL DEFAULT 0,
        accuracy REAL NOT NULL,
        battery INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        radius_meters REAL NOT NULL DEFAULT 30,
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    batch.execute('CREATE INDEX idx_stationary_session ON stationary_events(session_id, start_at)');
    batch.execute('CREATE INDEX idx_stationary_emp ON stationary_events(employee_id, start_at)');

    batch.execute('''
      CREATE TABLE site_attendance (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        session_id TEXT NOT NULL,
        site_id TEXT NOT NULL,
        site_name TEXT NOT NULL,
        check_in_at INTEGER NOT NULL,
        check_out_at INTEGER,
        check_in_lat REAL NOT NULL,
        check_in_lng REAL NOT NULL,
        check_in_accuracy REAL NOT NULL,
        check_in_battery INTEGER NOT NULL,
        check_out_lat REAL,
        check_out_lng REAL,
        check_out_accuracy REAL,
        check_out_battery INTEGER,
        duration_seconds INTEGER,
        status TEXT NOT NULL DEFAULT 'active',
        sync_status TEXT NOT NULL DEFAULT 'pending'
      )
    ''');
    batch.execute('CREATE INDEX idx_site_att_session ON site_attendance(session_id, check_in_at)');
    batch.execute('CREATE INDEX idx_site_att_emp ON site_attendance(employee_id, check_in_at)');

    batch.execute('''
      CREATE TABLE battery_logs (
        id TEXT PRIMARY KEY,
        employee_id TEXT NOT NULL,
        session_id TEXT,
        level INTEGER NOT NULL,
        recorded_at INTEGER NOT NULL,
        context TEXT NOT NULL DEFAULT 'tracking'
      )
    ''');
    batch.execute('CREATE INDEX idx_battery_emp ON battery_logs(employee_id, recorded_at)');

    batch.execute('''
      CREATE TABLE app_meta (
        meta_key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    await batch.commit(noResult: true);
    await _seed(db);
  }

  Future<void> _seed(Database db) async {
    final batch = db.batch();

    for (final employee in AppConfig.demoEmployees) {
      batch.insert(
        'employees',
        {
          'id': employee.id,
          'code': employee.code,
          'name': employee.name,
          'email': employee.email,
          'phone': employee.phone,
          'department': employee.department,
          'designation': employee.designation,
          'joined_at': employee.joinedAt,
          'avatar_seed': employee.id.hashCode.isEven ? 'mint' : 'coral',
          'password_hash': hashPassword(employee.code, AppConfig.demoPassword),
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    batch.insert('office_config', AppConfig.office.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);

    for (var i = 0; i < AppConfig.sites.length; i++) {
      final site = AppConfig.sites[i];
      batch.insert(
        'assigned_sites',
        {
          ...site.toMap(),
          'sort_order': i,
          'is_active': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }

    batch.insert('app_meta', {'meta_key': 'seeded_at', 'value': DateTime.now().toIso8601String()},
        conflictAlgorithm: ConflictAlgorithm.ignore);

    await batch.commit(noResult: true);
  }

  static String hashPassword(String code, String password) {
    return sha256.convert(utf8.encode('propcare::${code.toLowerCase()}::$password')).toString();
  }
}
