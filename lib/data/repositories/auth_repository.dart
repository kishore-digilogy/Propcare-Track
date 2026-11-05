import 'package:sqflite/sqflite.dart';

import '../../core/config/app_config.dart';
import '../db/app_database.dart';
import '../models/employee.dart';

class AuthRepository {
  AuthRepository(this._db);

  final AppDatabase _db;

  Future<Employee?> login(String identifier, String password) async {
    final db = await _db.database;
    final rows = await db.query(
      'employees',
      where: 'lower(email) = ? OR lower(code) = ?',
      whereArgs: [identifier.trim().toLowerCase(), identifier.trim().toLowerCase()],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    final expected = AppDatabase.hashPassword(row['code'] as String, password);
    if (row['password_hash'] != expected) return null;
    return Employee.fromMap(row);
  }

  Future<Employee?> byId(String id) async {
    final db = await _db.database;
    final rows = await db.query('employees', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return Employee.fromMap(rows.first);
  }

  Future<List<Employee>> all() async {
    final db = await _db.database;
    final rows = await db.query('employees', orderBy: 'name ASC');
    return rows.map(Employee.fromMap).toList();
  }

  Future<bool> hasEmployees() async {
    final db = await _db.database;
    final count = Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM employees'));
    return (count ?? 0) > 0;
  }

  /// Convenience for the demo login chips.
  String demoPassword() => AppConfig.demoPassword;
}
