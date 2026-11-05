import '../../core/config/app_config.dart';
import '../../core/utils/geo.dart';

/// Holds the "device" position for desktop demos. On a phone this is never
/// used — the real GPS fix wins.
class DemoLocationProvider {
  DemoLocationProvider._();

  static final DemoLocationProvider instance = DemoLocationProvider._();

  GeoPoint _position = AppConfig.office.point;
  double _accuracy = 8;

  GeoPoint get position => _position;
  double get accuracy => _accuracy;

  void moveTo(GeoPoint point, {double accuracy = 8}) {
    _position = point;
    _accuracy = accuracy;
  }

  void resetToOffice() => moveTo(AppConfig.office.point);
}
