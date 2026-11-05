import 'package:shared_preferences/shared_preferences.dart';

class SessionStore {
  static const String _authKey = 'propcare.auth.employeeId';
  static const String _onboardingKey = 'propcare.onboarding.seen';
  static const String _demoKey = 'propcare.demo.mode';

  Future<SharedPreferences> get _prefs => SharedPreferences.getInstance();

  Future<String?> employeeId() async => (await _prefs).getString(_authKey);

  Future<void> saveEmployeeId(String id) async => (await _prefs).setString(_authKey, id);

  Future<void> clearEmployeeId() async => (await _prefs).remove(_authKey);

  Future<bool> onboardingSeen() async => (await _prefs).getBool(_onboardingKey) ?? false;

  Future<void> markOnboardingSeen() async => (await _prefs).setBool(_onboardingKey, true);

  Future<bool> demoMode() async => (await _prefs).getBool(_demoKey) ?? true;

  Future<void> setDemoMode(bool value) async => (await _prefs).setBool(_demoKey, value);
}
