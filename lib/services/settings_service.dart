import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting app settings
class SettingsService {
  static const _keyHomeUrl = 'home_url';
  static const _keyKeepScreenOn = 'keep_screen_on';
  static const _keyLastFilePath = 'last_file_path';
  static const _keyRecentUrls = 'recent_urls';

  // Sensor settings
  static const _keyProximityDimEnabled = 'proximity_dim_enabled';
  static const _keyProximityUprightOnly = 'proximity_upright_only';
  static const _keyAccelerometerEnabled = 'accelerometer_enabled';
  static const _keyGyroscopeEnabled = 'gyroscope_enabled';

  /// Get the home URL
  Future<String> getHomeUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyHomeUrl) ?? 'about:blank';
  }

  /// Set the home URL
  Future<void> setHomeUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyHomeUrl, url);
  }

  /// Get keep screen on setting
  Future<bool> getKeepScreenOn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyKeepScreenOn) ?? false;
  }

  /// Set keep screen on setting
  Future<void> setKeepScreenOn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyKeepScreenOn, value);
  }

  /// Get last opened file path
  Future<String?> getLastFilePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyLastFilePath);
  }

  /// Set last opened file path
  Future<void> setLastFilePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLastFilePath, path);
  }

  /// Get recent URLs
  Future<List<String>> getRecentUrls() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_keyRecentUrls) ?? [];
  }

  /// Add a URL to recent list (max 10)
  Future<void> addRecentUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    final recent = prefs.getStringList(_keyRecentUrls) ?? [];

    // Remove if already exists
    recent.remove(url);

    // Add to front
    recent.insert(0, url);

    // Keep max 10
    if (recent.length > 10) {
      recent.removeLast();
    }

    await prefs.setStringList(_keyRecentUrls, recent);
  }

  // ============ Sensor Settings ============

  /// Get proximity dim enabled setting
  Future<bool> getProximityDimEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyProximityDimEnabled) ?? false;
  }

  /// Set proximity dim enabled setting
  Future<void> setProximityDimEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProximityDimEnabled, value);
  }

  /// Get proximity upright-only setting
  /// When true, proximity dim only works when phone is held upright (to ear)
  Future<bool> getProximityUprightOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyProximityUprightOnly) ?? true; // Default to true for phones
  }

  /// Set proximity upright-only setting
  Future<void> setProximityUprightOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyProximityUprightOnly, value);
  }

  /// Get accelerometer enabled setting
  Future<bool> getAccelerometerEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyAccelerometerEnabled) ?? false;
  }

  /// Set accelerometer enabled setting
  Future<void> setAccelerometerEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyAccelerometerEnabled, value);
  }

  /// Get gyroscope enabled setting
  Future<bool> getGyroscopeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyGyroscopeEnabled) ?? false;
  }

  /// Set gyroscope enabled setting
  Future<void> setGyroscopeEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyGyroscopeEnabled, value);
  }
}
