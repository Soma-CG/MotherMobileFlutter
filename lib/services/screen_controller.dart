import 'package:flutter/material.dart';
import 'package:screen_brightness/screen_brightness.dart';

/// Controller for screen brightness and black overlay
class ScreenController {
  static final ScreenController _instance = ScreenController._internal();
  factory ScreenController() => _instance;
  ScreenController._internal();

  final ScreenBrightness _screenBrightness = ScreenBrightness();

  double _savedBrightness = 0.5;
  bool _isDimmed = false;

  bool get isDimmed => _isDimmed;

  /// Get current screen brightness (0.0 to 1.0)
  Future<double> getBrightness() async {
    try {
      return await _screenBrightness.current;
    } catch (e) {
      debugPrint('Error getting brightness: $e');
      return 0.5;
    }
  }

  /// Set screen brightness (0.0 to 1.0)
  Future<bool> setBrightness(double brightness) async {
    try {
      await _screenBrightness.setScreenBrightness(brightness.clamp(0.0, 1.0));
      return true;
    } catch (e) {
      debugPrint('Error setting brightness: $e');
      return false;
    }
  }

  /// Reset brightness to system default
  Future<bool> resetBrightness() async {
    try {
      await _screenBrightness.resetScreenBrightness();
      return true;
    } catch (e) {
      debugPrint('Error resetting brightness: $e');
      return false;
    }
  }

  /// Save current brightness for later restoration
  Future<void> saveBrightness() async {
    _savedBrightness = await getBrightness();
  }

  /// Restore previously saved brightness
  Future<void> restoreBrightness() async {
    await setBrightness(_savedBrightness);
  }

  /// Dim the screen to minimum brightness
  Future<void> dimScreen() async {
    if (!_isDimmed) {
      await saveBrightness();
      await setBrightness(0.0);
      _isDimmed = true;
    }
  }

  /// Restore screen from dimmed state
  Future<void> undimScreen() async {
    if (_isDimmed) {
      await restoreBrightness();
      _isDimmed = false;
    }
  }
}

/// A widget that provides a black overlay for fading the screen to black
/// This is more effective than brightness control for achieving true black
class BlackOverlayWidget extends StatefulWidget {
  final Widget child;
  final BlackOverlayController controller;

  const BlackOverlayWidget({
    super.key,
    required this.child,
    required this.controller,
  });

  @override
  State<BlackOverlayWidget> createState() => _BlackOverlayWidgetState();
}

class _BlackOverlayWidgetState extends State<BlackOverlayWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    // Connect controller to this widget
    widget.controller._attachState(this);
  }

  @override
  void dispose() {
    widget.controller._detachState();
    _animationController.dispose();
    super.dispose();
  }

  void _showOverlay({Duration? duration}) {
    if (duration != null) {
      _animationController.duration = duration;
    }
    _animationController.forward();
  }

  void _hideOverlay({Duration? duration}) {
    if (duration != null) {
      _animationController.duration = duration;
    }
    _animationController.reverse();
  }

  void _setOverlayImmediate(bool show) {
    if (show) {
      _animationController.value = 1.0;
    } else {
      _animationController.value = 0.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        AnimatedBuilder(
          animation: _opacityAnimation,
          builder: (context, child) {
            if (_opacityAnimation.value == 0) {
              return const SizedBox.shrink();
            }
            return IgnorePointer(
              ignoring: _opacityAnimation.value < 0.5,
              child: Container(
                color: Colors.black.withValues(alpha: _opacityAnimation.value),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// Controller for the black overlay widget
class BlackOverlayController {
  _BlackOverlayWidgetState? _state;
  bool _isVisible = false;

  bool get isVisible => _isVisible;

  void _attachState(_BlackOverlayWidgetState state) {
    _state = state;
    debugPrint('BlackOverlayController: State attached');
  }

  void _detachState() {
    _state = null;
    debugPrint('BlackOverlayController: State detached');
  }

  /// Show the black overlay with animation
  void show({Duration duration = const Duration(milliseconds: 200)}) {
    debugPrint('BlackOverlayController: show() called, state=${_state != null}');
    _state?._showOverlay(duration: duration);
    _isVisible = true;
  }

  /// Hide the black overlay with animation
  void hide({Duration duration = const Duration(milliseconds: 200)}) {
    debugPrint('BlackOverlayController: hide() called, state=${_state != null}');
    _state?._hideOverlay(duration: duration);
    _isVisible = false;
  }

  /// Set overlay state immediately without animation
  void setImmediate(bool show) {
    _state?._setOverlayImmediate(show);
    _isVisible = show;
  }

  /// Toggle the overlay state
  void toggle({Duration duration = const Duration(milliseconds: 200)}) {
    if (_isVisible) {
      hide(duration: duration);
    } else {
      show(duration: duration);
    }
  }
}
