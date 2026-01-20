import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:proximity_sensor/proximity_sensor.dart';

/// Data class for accelerometer readings
class AccelerometerData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  AccelerometerData({
    required this.x,
    required this.y,
    required this.z,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// Check if the device is approximately upright (held to ear position)
  /// Returns true when the phone is in portrait orientation with significant tilt
  bool get isUpright {
    // Calculate the magnitude of gravity
    final magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude < 0.1) return false; // No valid reading

    // Normalize the values
    final normY = y / magnitude;
    final normZ = z / magnitude;

    // Device is upright when Y-axis has most of the gravity (portrait mode)
    // and Z-axis (screen facing) is relatively small
    // normY > 0.7 means device is tilted more than ~45 degrees from horizontal
    // abs(normZ) < 0.7 means screen isn't facing straight up or down
    return normY > 0.5 && normZ.abs() < 0.8;
  }

  /// Check if the device is lying flat (on a desk)
  bool get isFlat {
    final magnitude = sqrt(x * x + y * y + z * z);
    if (magnitude < 0.1) return false;

    final normZ = z / magnitude;
    // Device is flat when Z-axis has most of the gravity
    return normZ.abs() > 0.85;
  }

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'isUpright': isUpright,
        'isFlat': isFlat,
      };
}

/// Data class for gyroscope readings
class GyroscopeData {
  final double x;
  final double y;
  final double z;
  final DateTime timestamp;

  GyroscopeData({
    required this.x,
    required this.y,
    required this.z,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'x': x,
        'y': y,
        'z': z,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

/// Data class for proximity sensor readings
class ProximityData {
  final bool isNear;
  final int rawValue;
  final DateTime timestamp;

  ProximityData({
    required this.isNear,
    this.rawValue = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'isNear': isNear,
        'rawValue': rawValue,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };
}

/// Service for managing device sensors
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  // Stream subscriptions
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  StreamSubscription<GyroscopeEvent>? _gyroscopeSubscription;
  StreamSubscription<int>? _proximitySubscription;

  // Stream controllers for broadcasting sensor data
  final _accelerometerController = StreamController<AccelerometerData>.broadcast();
  final _gyroscopeController = StreamController<GyroscopeData>.broadcast();
  final _proximityController = StreamController<ProximityData>.broadcast();

  // Latest sensor values
  AccelerometerData? _latestAccelerometer;
  GyroscopeData? _latestGyroscope;
  ProximityData? _latestProximity;

  // Public streams
  Stream<AccelerometerData> get accelerometerStream => _accelerometerController.stream;
  Stream<GyroscopeData> get gyroscopeStream => _gyroscopeController.stream;
  Stream<ProximityData> get proximityStream => _proximityController.stream;

  // Latest values
  AccelerometerData? get latestAccelerometer => _latestAccelerometer;
  GyroscopeData? get latestGyroscope => _latestGyroscope;
  ProximityData? get latestProximity => _latestProximity;

  // Active sensor tracking
  bool _accelerometerActive = false;
  bool _gyroscopeActive = false;
  bool _proximityActive = false;

  bool get isAccelerometerActive => _accelerometerActive;
  bool get isGyroscopeActive => _gyroscopeActive;
  bool get isProximityActive => _proximityActive;

  /// Start the accelerometer sensor
  Future<bool> startAccelerometer({
    Duration samplingPeriod = const Duration(milliseconds: 100),
  }) async {
    if (_accelerometerActive) return true;

    try {
      _accelerometerSubscription = accelerometerEventStream(
        samplingPeriod: samplingPeriod,
      ).listen((event) {
        final data = AccelerometerData(
          x: event.x,
          y: event.y,
          z: event.z,
        );
        _latestAccelerometer = data;
        _accelerometerController.add(data);
      });
      _accelerometerActive = true;
      debugPrint('Accelerometer started');
      return true;
    } catch (e) {
      debugPrint('Error starting accelerometer: $e');
      return false;
    }
  }

  /// Stop the accelerometer sensor
  void stopAccelerometer() {
    _accelerometerSubscription?.cancel();
    _accelerometerSubscription = null;
    _accelerometerActive = false;
    debugPrint('Accelerometer stopped');
  }

  /// Start the gyroscope sensor
  Future<bool> startGyroscope({
    Duration samplingPeriod = const Duration(milliseconds: 100),
  }) async {
    if (_gyroscopeActive) return true;

    try {
      _gyroscopeSubscription = gyroscopeEventStream(
        samplingPeriod: samplingPeriod,
      ).listen((event) {
        final data = GyroscopeData(
          x: event.x,
          y: event.y,
          z: event.z,
        );
        _latestGyroscope = data;
        _gyroscopeController.add(data);
      });
      _gyroscopeActive = true;
      debugPrint('Gyroscope started');
      return true;
    } catch (e) {
      debugPrint('Error starting gyroscope: $e');
      return false;
    }
  }

  /// Stop the gyroscope sensor
  void stopGyroscope() {
    _gyroscopeSubscription?.cancel();
    _gyroscopeSubscription = null;
    _gyroscopeActive = false;
    debugPrint('Gyroscope stopped');
  }

  /// Start the proximity sensor
  Future<bool> startProximity() async {
    if (_proximityActive) {
      debugPrint('SensorService: Proximity already active');
      return true;
    }

    try {
      _proximitySubscription = ProximitySensor.events.listen(
        (int event) {
          // The proximity_sensor package returns:
          // - 1 when something is NEAR
          // - 0 when FAR (nothing close)
          final isNear = event > 0;
          final data = ProximityData(isNear: isNear, rawValue: event);
          _latestProximity = data;
          _proximityController.add(data);
        },
        onError: (error) {
          debugPrint('SensorService: Proximity stream error: $error');
        },
      );
      _proximityActive = true;
      debugPrint('Proximity sensor started');
      return true;
    } catch (e) {
      debugPrint('Error starting proximity sensor: $e');
      return false;
    }
  }

  /// Stop the proximity sensor
  void stopProximity() {
    _proximitySubscription?.cancel();
    _proximitySubscription = null;
    _proximityActive = false;
    debugPrint('Proximity sensor stopped');
  }

  /// Start all sensors
  Future<void> startAll() async {
    await startAccelerometer();
    await startGyroscope();
    await startProximity();
  }

  /// Stop all sensors
  void stopAll() {
    stopAccelerometer();
    stopGyroscope();
    stopProximity();
  }

  /// Dispose of resources
  void dispose() {
    stopAll();
    _accelerometerController.close();
    _gyroscopeController.close();
    _proximityController.close();
  }

  /// Get list of available sensors
  Map<String, bool> getAvailableSensors() {
    // Note: On Flutter, we can't easily check sensor availability without trying to use them
    // This returns which sensors are currently active
    return {
      'accelerometer': _accelerometerActive,
      'gyroscope': _gyroscopeActive,
      'proximity': _proximityActive,
    };
  }
}
