import 'package:shared_preferences/shared_preferences.dart';

/// Service for persisting app settings
class SettingsService {
  static const _keyHomeUrl = 'home_url';
  static const _keyKeepScreenOn = 'keep_screen_on';
  static const _keyLastFilePath = 'last_file_path';
  static const _keyRecentUrls = 'recent_urls';

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
}
