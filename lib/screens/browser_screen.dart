import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/settings_overlay.dart';
import '../services/settings_service.dart';
import '../services/sensor_service.dart';
import '../services/screen_controller.dart';
import 'rive_player_screen.dart';

/// Main browser screen with fullscreen WebView
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  late WebViewController _controller;
  final _settings = SettingsService();
  final _sensorService = SensorService();
  final _blackOverlayController = BlackOverlayController();

  bool _showSettings = false;
  String _currentUrl = 'about:blank';
  bool _keepScreenOn = false;

  // Sensor settings
  bool _proximityDimEnabled = false;
  bool _proximityUprightOnly = true;
  bool _isCurrentlyDimmed = false;


  // For two-finger gesture detection
  int _pointerCount = 0;
  double _startY = 0;

  // Sensor subscriptions
  StreamSubscription<ProximityData>? _proximitySubscription;
  StreamSubscription<AccelerometerData>? _accelerometerSubscription;

  @override
  void initState() {
    super.initState();
    _initWebView();
    _loadSettings();
  }

  void _initWebView() {
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          setState(() => _currentUrl = url);
        },
        onPageFinished: (url) {
          setState(() => _currentUrl = url);
        },
        onNavigationRequest: (request) {
          // Allow all navigation
          return NavigationDecision.navigate;
        },
      ));
  }

  Future<void> _loadSettings() async {
    final url = await _settings.getHomeUrl();
    final keepOn = await _settings.getKeepScreenOn();
    final proximityDim = await _settings.getProximityDimEnabled();
    final proximityUpright = await _settings.getProximityUprightOnly();

    setState(() {
      _keepScreenOn = keepOn;
      _proximityDimEnabled = proximityDim;
      _proximityUprightOnly = proximityUpright;
    });

    // Set up proximity dimming if enabled
    if (_proximityDimEnabled) {
      _setupProximityDimming();
    }

    if (url.isNotEmpty && url != 'about:blank') {
      _controller.loadRequest(Uri.parse(url));
      setState(() => _currentUrl = url);
    }
  }

  /// Set up proximity sensor for screen dimming
  Future<void> _setupProximityDimming() async {
    debugPrint('BrowserScreen: Setting up proximity dimming...');

    // Start sensors
    final proximityStarted = await _sensorService.startProximity();
    debugPrint('BrowserScreen: Proximity sensor started: $proximityStarted');

    // If upright-only mode is enabled, also start accelerometer
    if (_proximityUprightOnly) {
      final accelStarted = await _sensorService.startAccelerometer();
      debugPrint('BrowserScreen: Accelerometer started: $accelStarted');
    }

    // Subscribe to proximity changes
    _proximitySubscription?.cancel();
    _proximitySubscription = _sensorService.proximityStream.listen((data) {
      _handleProximityChange(data.isNear);
    });
  }

  /// Stop proximity dimming
  void _stopProximityDimming() {
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _sensorService.stopProximity();
    _sensorService.stopAccelerometer();

    // Make sure overlay is hidden
    if (_isCurrentlyDimmed) {
      _blackOverlayController.hide();
      _isCurrentlyDimmed = false;
    }
  }

  /// Handle proximity sensor change
  void _handleProximityChange(bool isNear) {
    if (!_proximityDimEnabled) return;

    // Always allow hiding the overlay (when not near), regardless of orientation
    if (!isNear && _isCurrentlyDimmed) {
      _blackOverlayController.hide(duration: const Duration(milliseconds: 200));
      _isCurrentlyDimmed = false;
      return;
    }

    // Check orientation if upright-only mode is enabled (only for showing overlay)
    if (_proximityUprightOnly && isNear) {
      final accelData = _sensorService.latestAccelerometer;
      if (accelData != null && (accelData.isFlat || !accelData.isUpright)) {
        // Device is flat or not upright, don't show overlay
        return;
      }
    }

    // Show overlay when near and not already dimmed
    if (isNear && !_isCurrentlyDimmed) {
      _blackOverlayController.show(duration: const Duration(milliseconds: 200));
      _isCurrentlyDimmed = true;
    }
  }

  void _loadUrl(String url) {
    // Ensure URL has a scheme - default to http for local servers
    String finalUrl = url;
    if (!url.startsWith('http://') && !url.startsWith('https://') && !url.startsWith('file://')) {
      finalUrl = 'http://$url';
    }

    _settings.setHomeUrl(finalUrl);
    _settings.addRecentUrl(finalUrl);
    _controller.loadRequest(Uri.parse(finalUrl));
    setState(() {
      _showSettings = false;
      _currentUrl = finalUrl;
    });

    // Re-enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _loadLocalFile(String path) {
    // Check if it's a Rive file
    if (path.toLowerCase().endsWith('.riv')) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RivePlayerScreen(filePath: path),
        ),
      );
    } else {
      // Load HTML file in WebView
      _controller.loadFile(path);
      _settings.setLastFilePath(path);
    }
    setState(() => _showSettings = false);

    // Re-enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onKeepScreenOnChanged(bool value) {
    setState(() => _keepScreenOn = value);
    _settings.setKeepScreenOn(value);
    if (value) {
      WakelockPlus.enable();
    } else {
      WakelockPlus.disable();
    }
  }

  void _onProximityDimChanged(bool value) {
    debugPrint('BrowserScreen: Proximity dim changed to: $value');
    setState(() => _proximityDimEnabled = value);
    _settings.setProximityDimEnabled(value);

    if (value) {
      _setupProximityDimming();
    } else {
      _stopProximityDimming();
    }
  }

  void _onProximityUprightOnlyChanged(bool value) {
    setState(() => _proximityUprightOnly = value);
    _settings.setProximityUprightOnly(value);

    // Update accelerometer state based on new setting
    if (_proximityDimEnabled) {
      if (value) {
        _sensorService.startAccelerometer();
      } else {
        _sensorService.stopAccelerometer();
      }
    }
  }

  void _reload() {
    _controller.reload();
    setState(() => _showSettings = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _stopProximityDimming();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlackOverlayWidget(
        controller: _blackOverlayController,
        child: Listener(
          // Track pointer count for two-finger detection
          onPointerDown: (event) {
            _pointerCount++;
            if (_pointerCount == 2) {
              _startY = event.position.dy;
            }
          },
          onPointerUp: (event) {
            _pointerCount--;
            if (_pointerCount < 0) _pointerCount = 0;
          },
          onPointerCancel: (event) {
            _pointerCount--;
            if (_pointerCount < 0) _pointerCount = 0;
          },
          onPointerMove: (event) {
            // Two-finger swipe down detection
            if (_pointerCount == 2 && !_showSettings) {
              final deltaY = event.position.dy - _startY;
              if (deltaY > 100) {
                setState(() => _showSettings = true);
                _startY = event.position.dy; // Reset to prevent repeated triggers
              }
            }
          },
          child: Stack(
            children: [
              // WebView
              WebViewWidget(controller: _controller),

              // Settings overlay
              if (_showSettings)
                SettingsOverlay(
                  currentUrl: _currentUrl,
                  keepScreenOn: _keepScreenOn,
                  proximityDimEnabled: _proximityDimEnabled,
                  proximityUprightOnly: _proximityUprightOnly,
                  onUrlSubmit: _loadUrl,
                  onFileSelect: _loadLocalFile,
                  onReload: _reload,
                  onKeepScreenOnChanged: _onKeepScreenOnChanged,
                  onProximityDimChanged: _onProximityDimChanged,
                  onProximityUprightOnlyChanged: _onProximityUprightOnlyChanged,
                  onClose: () {
                    setState(() => _showSettings = false);
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}
