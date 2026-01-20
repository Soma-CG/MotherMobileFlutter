import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../widgets/settings_overlay.dart';
import '../services/settings_service.dart';
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
  bool _showSettings = false;
  String _currentUrl = 'about:blank';
  bool _keepScreenOn = false;

  // For two-finger gesture detection
  int _pointerCount = 0;
  double _startY = 0;

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

    setState(() {
      _keepScreenOn = keepOn;
    });

    if (url.isNotEmpty && url != 'about:blank') {
      _controller.loadRequest(Uri.parse(url));
      setState(() => _currentUrl = url);
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

  void _reload() {
    _controller.reload();
    setState(() => _showSettings = false);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Listener(
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
                onUrlSubmit: _loadUrl,
                onFileSelect: _loadLocalFile,
                onReload: _reload,
                onKeepScreenOnChanged: _onKeepScreenOnChanged,
                onClose: () {
                  setState(() => _showSettings = false);
                  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
                },
              ),
          ],
        ),
      ),
    );
  }
}
