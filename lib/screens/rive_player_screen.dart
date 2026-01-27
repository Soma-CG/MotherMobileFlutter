import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:rive/rive.dart';
import '../services/settings_service.dart';
import '../services/sensor_service.dart';
import '../services/screen_controller.dart';

/// Holds discovered Rive ViewModel properties for sensor binding (using Data Binding API)
class _RiveSensorBindings {
  // Accelerometer properties (numbers)
  ViewModelInstanceNumber? accelX;
  ViewModelInstanceNumber? accelY;
  ViewModelInstanceNumber? accelZ;
  // Accelerometer derived properties (booleans)
  ViewModelInstanceBoolean? isFlat;
  ViewModelInstanceBoolean? isUpright;
  // Gyroscope properties (numbers)
  ViewModelInstanceNumber? gyroX;
  ViewModelInstanceNumber? gyroY;
  ViewModelInstanceNumber? gyroZ;
  // Proximity property (boolean)
  ViewModelInstanceBoolean? isNear;

  bool get hasAccelerometerBindings =>
      accelX != null || accelY != null || accelZ != null ||
      isFlat != null || isUpright != null;

  bool get hasGyroscopeBindings =>
      gyroX != null || gyroY != null || gyroZ != null;

  bool get hasProximityBindings => isNear != null;

  List<String> get boundPropertyNames {
    final names = <String>[];
    if (accelX != null) names.add('accelX');
    if (accelY != null) names.add('accelY');
    if (accelZ != null) names.add('accelZ');
    if (isFlat != null) names.add('isFlat');
    if (isUpright != null) names.add('isUpright');
    if (gyroX != null) names.add('gyroX');
    if (gyroY != null) names.add('gyroY');
    if (gyroZ != null) names.add('gyroZ');
    if (isNear != null) names.add('isNear');
    return names;
  }
}

/// Screen for playing Rive animations using the native Rive package
/// Supports data binding and view models for full feature compatibility
class RivePlayerScreen extends StatefulWidget {
  final String filePath;

  const RivePlayerScreen({super.key, required this.filePath});

  @override
  State<RivePlayerScreen> createState() => _RivePlayerScreenState();
}

class _RivePlayerScreenState extends State<RivePlayerScreen> {
  File? _riveFile;
  RiveWidgetController? _controller;
  ViewModelInstance? _viewModelInstance;
  bool _isLoading = true;
  String? _error;
  final _focusNode = FocusNode();

  // For two-finger gesture detection
  int _pointerCount = 0;
  double _startY = 0;

  // Proximity dimming
  final _settings = SettingsService();
  final _sensorService = SensorService();
  final _blackOverlayController = BlackOverlayController();
  bool _proximityDimEnabled = false;
  bool _proximityUprightOnly = true;
  bool _isCurrentlyDimmed = false;
  StreamSubscription<ProximityData>? _proximitySubscription;

  // Rive sensor input settings
  bool _riveAccelerometerEnabled = false;
  bool _riveGyroscopeEnabled = false;
  bool _riveProximityEnabled = false;

  // Sensor subscriptions for Rive
  StreamSubscription<AccelerometerData>? _riveAccelSubscription;
  StreamSubscription<GyroscopeData>? _riveGyroSubscription;
  StreamSubscription<ProximityData>? _riveProximitySubscription;

  @override
  void initState() {
    super.initState();
    _loadRiveFile();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final proximityDim = await _settings.getProximityDimEnabled();
    final proximityUpright = await _settings.getProximityUprightOnly();
    final riveAccel = await _settings.getRiveAccelerometerEnabled();
    final riveGyro = await _settings.getRiveGyroscopeEnabled();
    final riveProx = await _settings.getRiveProximityEnabled();

    setState(() {
      _proximityDimEnabled = proximityDim;
      _proximityUprightOnly = proximityUpright;
      _riveAccelerometerEnabled = riveAccel;
      _riveGyroscopeEnabled = riveGyro;
      _riveProximityEnabled = riveProx;
    });

    if (_proximityDimEnabled) {
      _setupProximityDimming();
    }
  }

  Future<void> _setupProximityDimming() async {
    await _sensorService.startProximity();
    if (_proximityUprightOnly) {
      await _sensorService.startAccelerometer();
    }

    _proximitySubscription?.cancel();
    _proximitySubscription = _sensorService.proximityStream.listen((data) {
      _handleProximityChange(data.isNear);
    });
  }

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

  void _stopProximityDimming() {
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    _sensorService.stopProximity();
    _sensorService.stopAccelerometer();
    if (_isCurrentlyDimmed) {
      _blackOverlayController.hide();
      _isCurrentlyDimmed = false;
    }
  }

  Future<void> _loadRiveFile() async {
    try {
      // Load file using the new rive_native API
      final file = await File.path(
        widget.filePath,
        riveFactory: Factory.rive,
      );

      if (file == null) {
        throw Exception('Failed to decode Rive file');
      }

      debugPrint('Rive file loaded from: ${widget.filePath}');

      // Create the widget controller with default artboard and state machine
      final controller = RiveWidgetController(
        file,
        artboardSelector: const ArtboardDefault(),
        stateMachineSelector: const StateMachineDefault(),
      );

      debugPrint('Created controller with artboard: ${controller.artboard.name}');

      // Try to enable data binding
      ViewModelInstance? vmi;
      try {
        vmi = controller.dataBind(DataBind.auto());
        debugPrint('Data binding enabled (auto mode)');
      } catch (e) {
        debugPrint('Data binding not available: $e');
      }

      setState(() {
        _riveFile = file;
        _controller = controller;
        _viewModelInstance = vmi;
        _isLoading = false;
      });

      // Discover and bind sensor properties from ViewModel (Data Binding API)
      if (vmi != null) {
        _discoverAndBindSensorProperties(vmi);
      }
    } catch (e, stack) {
      debugPrint('Error loading Rive: $e');
      debugPrint('Stack: $stack');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  /// Try to find a number property by checking multiple name variants
  ViewModelInstanceNumber? _findNumberProperty(ViewModelInstance vmi, List<String> names) {
    for (final name in names) {
      try {
        final prop = vmi.number(name);
        if (prop != null) return prop;
      } catch (_) {
        // Property not found, try next name
      }
    }
    return null;
  }

  /// Try to find a boolean property by checking multiple name variants
  ViewModelInstanceBoolean? _findBooleanProperty(ViewModelInstance vmi, List<String> names) {
    for (final name in names) {
      try {
        final prop = vmi.boolean(name);
        if (prop != null) return prop;
      } catch (_) {
        // Property not found, try next name
      }
    }
    return null;
  }

  /// Discover ViewModel properties that match sensor naming conventions (Data Binding API)
  void _discoverAndBindSensorProperties(ViewModelInstance vmi) {
    final bindings = _RiveSensorBindings();

    // Try to find accelerometer properties (numbers)
    bindings.accelX = _findNumberProperty(vmi, ['accelX', 'accelerometerX']);
    bindings.accelY = _findNumberProperty(vmi, ['accelY', 'accelerometerY']);
    bindings.accelZ = _findNumberProperty(vmi, ['accelZ', 'accelerometerZ']);

    // Try to find derived accelerometer properties (booleans)
    bindings.isFlat = _findBooleanProperty(vmi, ['isFlat']);
    bindings.isUpright = _findBooleanProperty(vmi, ['isUpright']);

    // Try to find gyroscope properties (numbers)
    bindings.gyroX = _findNumberProperty(vmi, ['gyroX', 'gyroscopeX']);
    bindings.gyroY = _findNumberProperty(vmi, ['gyroY', 'gyroscopeY']);
    bindings.gyroZ = _findNumberProperty(vmi, ['gyroZ', 'gyroscopeZ']);

    // Try to find proximity properties (boolean)
    bindings.isNear = _findBooleanProperty(vmi, ['isNear', 'proximity', 'proximityNear']);

    final boundNames = bindings.boundPropertyNames;
    if (boundNames.isNotEmpty) {
      debugPrint('Discovered Rive sensor bindings (Data Binding): ${boundNames.join(', ')}');
    } else {
      debugPrint('No sensor properties found in Rive ViewModel');
    }

    // Start sensor streams for discovered bindings
    _setupRiveSensorStreams(bindings);
  }

  /// Set up sensor streams to feed data to Rive ViewModel properties
  void _setupRiveSensorStreams(_RiveSensorBindings bindings) {
    // Accelerometer stream
    if (_riveAccelerometerEnabled && bindings.hasAccelerometerBindings) {
      _sensorService.startAccelerometer(samplingPeriod: const Duration(milliseconds: 16));
      _riveAccelSubscription = _sensorService.accelerometerStream.listen((data) {
        bindings.accelX?.value = data.x;
        bindings.accelY?.value = data.y;
        bindings.accelZ?.value = data.z;
        bindings.isFlat?.value = data.isFlat;
        bindings.isUpright?.value = data.isUpright;
      });
      debugPrint('Rive accelerometer stream started (Data Binding)');
    }

    // Gyroscope stream
    if (_riveGyroscopeEnabled && bindings.hasGyroscopeBindings) {
      _sensorService.startGyroscope(samplingPeriod: const Duration(milliseconds: 16));
      _riveGyroSubscription = _sensorService.gyroscopeStream.listen((data) {
        bindings.gyroX?.value = data.x;
        bindings.gyroY?.value = data.y;
        bindings.gyroZ?.value = data.z;
      });
      debugPrint('Rive gyroscope stream started (Data Binding)');
    }

    // Proximity stream (separate from dimming proximity)
    if (_riveProximityEnabled && bindings.hasProximityBindings) {
      _sensorService.startProximity();
      _riveProximitySubscription = _sensorService.proximityStream.listen((data) {
        bindings.isNear?.value = data.isNear;
      });
      debugPrint('Rive proximity stream started (Data Binding)');
    }
  }

  /// Stop Rive sensor streams
  void _stopRiveSensorStreams() {
    _riveAccelSubscription?.cancel();
    _riveAccelSubscription = null;

    _riveGyroSubscription?.cancel();
    _riveGyroSubscription = null;

    _riveProximitySubscription?.cancel();
    _riveProximitySubscription = null;
  }

  void _goBack() {
    Navigator.pop(context);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  /// Handle keyboard and remote control input
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final key = event.logicalKey;

    // Back button, Escape, or Q key - go back to browser
    if (key == LogicalKeyboardKey.goBack ||
        key == LogicalKeyboardKey.escape ||
        key == LogicalKeyboardKey.browserBack ||
        key == LogicalKeyboardKey.keyQ) {
      _goBack();
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  @override
  void dispose() {
    _stopProximityDimming();
    _stopRiveSensorStreams();
    _focusNode.dispose();
    _viewModelInstance?.dispose();
    _controller?.dispose();
    _riveFile?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      focusNode: _focusNode,
      autofocus: true,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: BlackOverlayWidget(
          controller: _blackOverlayController,
          child: Listener(
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
              if (_pointerCount == 2) {
                final deltaY = event.position.dy - _startY;
                if (deltaY > 100) {
                  _goBack();
                }
              }
            },
            child: _buildContent(),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFFE94560)),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Color(0xFFE94560), size: 64),
              const SizedBox(height: 16),
              Text(
                'Error loading Rive file',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(onPressed: _goBack, child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    if (_controller != null) {
      return RiveWidget(
        controller: _controller!,
        fit: Fit.contain,
        alignment: Alignment.center,
      );
    }

    return const SizedBox.shrink();
  }
}
