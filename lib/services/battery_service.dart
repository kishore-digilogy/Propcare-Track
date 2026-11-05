import 'package:battery_plus/battery_plus.dart';

class BatteryService {
  BatteryService();

  final Battery _battery = Battery();
  int _cached = 87;

  int get cached => _cached;

  Future<int> refresh() async {
    try {
      final level = await _battery.batteryLevel;
      if (level >= 0 && level <= 100) _cached = level;
    } catch (_) {
      // Desktop without a battery, simulator, or a transient platform error.
    }
    return _cached;
  }

  Future<int> currentLevel() => refresh();
}
