import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/settings_overlay.dart';
import '../widgets/file_browser_dialog.dart';
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
  final _focusNode = FocusNode();

  bool _showSettings = false;
  bool _showFileBrowser = false;
  bool _inRivePlayer = false; // true while Rive player route is active
  String _currentUrl = 'about:blank';
  bool _keepScreenOn = false;

  // Sensor settings
  bool _proximityDimEnabled = false;
  bool _proximityUprightOnly = true;
  bool _isCurrentlyDimmed = false;

  // Rive sensor settings
  bool _riveAccelerometerEnabled = false;
  bool _riveGyroscopeEnabled = false;
  bool _riveProximityEnabled = false;


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
    final riveAccel = await _settings.getRiveAccelerometerEnabled();
    final riveGyro = await _settings.getRiveGyroscopeEnabled();
    final riveProx = await _settings.getRiveProximityEnabled();

    setState(() {
      _keepScreenOn = keepOn;
      _proximityDimEnabled = proximityDim;
      _proximityUprightOnly = proximityUpright;
      _riveAccelerometerEnabled = riveAccel;
      _riveGyroscopeEnabled = riveGyro;
      _riveProximityEnabled = riveProx;
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
    _focusNode.requestFocus();

    // Re-enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _loadLocalFile(String path) {
    // Check if it's a Rive file
    if (path.toLowerCase().endsWith('.riv')) {
      setState(() => _inRivePlayer = true);
      // Pause WebView to free resources while Rive player is active
      _controller.runJavaScript(
        'document.querySelectorAll("video, audio").forEach(e => e.pause()); '
        'if(typeof window.__mmPaused === "undefined") { window.__mmPaused = true; }',
      );
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RivePlayerScreen(filePath: path),
        ),
      ).then((_) {
        // Resume WebView and re-open the file browser
        _controller.runJavaScript(
          'document.querySelectorAll("video, audio").forEach(e => e.play()); '
          'window.__mmPaused = false;',
        );
        setState(() {
          _inRivePlayer = false;
          _showSettings = false;
          _showFileBrowser = true;
        });
      });
    } else {
      // Load HTML file in WebView
      _controller.loadFile(path);
      _settings.setLastFilePath(path);
    }
    setState(() => _showSettings = false);

    // Re-enable immersive mode
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _focusNode.requestFocus();
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

  void _onRiveAccelerometerChanged(bool value) {
    setState(() => _riveAccelerometerEnabled = value);
    _settings.setRiveAccelerometerEnabled(value);
  }

  void _onRiveGyroscopeChanged(bool value) {
    setState(() => _riveGyroscopeEnabled = value);
    _settings.setRiveGyroscopeEnabled(value);
  }

  void _onRiveProximityChanged(bool value) {
    setState(() => _riveProximityEnabled = value);
    _settings.setRiveProximityEnabled(value);
  }

  void _openFileBrowser() {
    setState(() {
      _showSettings = false;
      _showFileBrowser = true;
    });
  }

  void _closeFileBrowser() {
    setState(() => _showFileBrowser = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  void _onFileBrowserSelect(String path) {
    _closeFileBrowser();
    _loadLocalFile(path);
  }

  void _reload() {
    _controller.reload();
    setState(() => _showSettings = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    // Re-focus the main focus node so long-press detection continues to work
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _stopProximityDimming();
    _focusNode.dispose();
    super.dispose();
  }

  // Track select button for long-press detection
  DateTime? _selectPressStart;
  static const _longPressDuration = Duration(milliseconds: 800);

  /// Handle keyboard and remote control input
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    // Don't handle any keys when file browser is open - it has its own FocusScope
    if (_showFileBrowser) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Track long-press on Select/Enter for opening settings (TV remote center button)
    if (key == LogicalKeyboardKey.select ||
        key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.gameButtonA) {
      if (event is KeyDownEvent) {
        _selectPressStart ??= DateTime.now();
      } else if (event is KeyUpEvent) {
        if (_selectPressStart != null) {
          final pressDuration = DateTime.now().difference(_selectPressStart!);
          _selectPressStart = null;

          // Long press opens/closes settings
          if (pressDuration >= _longPressDuration && !_showSettings) {
            setState(() => _showSettings = true);
            return KeyEventResult.handled;
          }
        }
      }
      // Don't consume short presses - let them work normally
      return KeyEventResult.ignored;
    }

    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Menu button (TV remote) or M key (keyboard) - toggle settings
    if (key == LogicalKeyboardKey.contextMenu ||
        key == LogicalKeyboardKey.keyM ||
        key == LogicalKeyboardKey.f1) {
      setState(() => _showSettings = !_showSettings);
      if (!_showSettings) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      }
      return KeyEventResult.handled;
    }

    // Back button or Escape - close file browser or settings if open
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack) {
      if (_showFileBrowser) {
        _closeFileBrowser();
        return KeyEventResult.handled;
      }
      if (_showSettings) {
        setState(() => _showSettings = false);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        _focusNode.requestFocus();
        return KeyEventResult.handled;
      }
      // Let system handle back if nothing open
      return KeyEventResult.ignored;
    }

    // R key - reload page
    if (key == LogicalKeyboardKey.keyR && !_showSettings) {
      _reload();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_showFileBrowser && !_showSettings && !_inRivePlayer,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // System back was blocked - handle it ourselves
        if (_showFileBrowser) {
          _closeFileBrowser();
        } else if (_showSettings) {
          setState(() => _showSettings = false);
          SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
        }
      },
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: Scaffold(
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
                  riveAccelerometerEnabled: _riveAccelerometerEnabled,
                  riveGyroscopeEnabled: _riveGyroscopeEnabled,
                  riveProximityEnabled: _riveProximityEnabled,
                  onUrlSubmit: _loadUrl,
                  onFileSelect: _loadLocalFile,
                  onReload: _reload,
                  onKeepScreenOnChanged: _onKeepScreenOnChanged,
                  onProximityDimChanged: _onProximityDimChanged,
                  onProximityUprightOnlyChanged: _onProximityUprightOnlyChanged,
                  onRiveAccelerometerChanged: _onRiveAccelerometerChanged,
                  onRiveGyroscopeChanged: _onRiveGyroscopeChanged,
                  onRiveProximityChanged: _onRiveProximityChanged,
                  onBrowseLocalFiles: _openFileBrowser,
                  onClose: () {
                    setState(() => _showSettings = false);
                    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                    _focusNode.requestFocus();
                  },
                ),

              // File browser dialog
              if (_showFileBrowser)
                FileBrowserDialog(
                  onFileSelected: _onFileBrowserSelect,
                  onClose: _closeFileBrowser,
                ),
            ],
          ),
        ),
      ),
    ),
    ),
    );
  }
}
