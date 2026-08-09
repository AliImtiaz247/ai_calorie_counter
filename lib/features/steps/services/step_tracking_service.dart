import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

enum StepTrackingPermissionStatus {
  granted,
  denied,
  permanentlyDenied,
  restricted,
  unknown,
}

class StepTrackingService {
  StepTrackingService._();

  static final StepTrackingService instance = StepTrackingService._();
  factory StepTrackingService() => instance;

  StreamSubscription<StepCount>? _stepCountSubscription;
  StreamSubscription<PedestrianStatus>? _pedestrianStatusSubscription;

  final StreamController<int> _rawStepStreamController =
      StreamController<int>.broadcast();
  final StreamController<String> _statusStreamController =
      StreamController<String>.broadcast();

  Stream<int> get rawStepStream => _rawStepStreamController.stream;
  Stream<String> get pedestrianStatusStream => _statusStreamController.stream;

  bool _isTracking = false;
  bool get isTracking => _isTracking;

  /// Check if Activity Recognition Permission is Granted
  Future<StepTrackingPermissionStatus> checkPermissionStatus() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return StepTrackingPermissionStatus.denied;
    }

    final status = await Permission.activityRecognition.status;
    if (status.isGranted) {
      return StepTrackingPermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return StepTrackingPermissionStatus.permanentlyDenied;
    } else if (status.isRestricted) {
      return StepTrackingPermissionStatus.restricted;
    } else {
      return StepTrackingPermissionStatus.denied;
    }
  }

  /// Request Activity Recognition Permission
  Future<StepTrackingPermissionStatus> requestPermission() async {
    if (!Platform.isAndroid && !Platform.isIOS) {
      return StepTrackingPermissionStatus.denied;
    }

    final status = await Permission.activityRecognition.request();
    if (status.isGranted) {
      return StepTrackingPermissionStatus.granted;
    } else if (status.isPermanentlyDenied) {
      return StepTrackingPermissionStatus.permanentlyDenied;
    } else {
      return StepTrackingPermissionStatus.denied;
    }
  }

  /// Open System App Settings
  Future<bool> openAppSettingsPage() async {
    return openAppSettings();
  }

  /// Start Listening to Hardware Step Counter Sensor Stream
  Future<bool> startTracking() async {
    if (_isTracking) return true;

    final permission = await checkPermissionStatus();
    if (permission != StepTrackingPermissionStatus.granted) {
      debugPrint("StepTrackingService: Permission not granted ($permission)");
      return false;
    }

    try {
      _stepCountSubscription = Pedometer.stepCountStream.listen(
        _onStepCount,
        onError: _onStepCountError,
        cancelOnError: false,
      );

      _pedestrianStatusSubscription = Pedometer.pedestrianStatusStream.listen(
        _onPedestrianStatus,
        onError: _onPedestrianStatusError,
        cancelOnError: false,
      );

      _isTracking = true;
      debugPrint("StepTrackingService: Hardware step tracking started.");
      return true;
    } catch (e) {
      debugPrint("StepTrackingService: Error starting pedometer streams: $e");
      _isTracking = false;
      return false;
    }
  }

  /// Stop Sensor Listening Streams
  void stopTracking() {
    _stepCountSubscription?.cancel();
    _stepCountSubscription = null;
    _pedestrianStatusSubscription?.cancel();
    _pedestrianStatusSubscription = null;
    _isTracking = false;
    debugPrint("StepTrackingService: Hardware step tracking stopped.");
  }

  void _onStepCount(StepCount event) {
    debugPrint("StepTrackingService: Raw step sensor count = ${event.steps}");
    _rawStepStreamController.add(event.steps);
  }

  void _onStepCountError(dynamic error) {
    debugPrint("StepTrackingService: Step count stream error: $error");
  }

  void _onPedestrianStatus(PedestrianStatus event) {
    debugPrint("StepTrackingService: Pedestrian status = ${event.status}");
    _statusStreamController.add(event.status);
  }

  void _onPedestrianStatusError(dynamic error) {
    debugPrint("StepTrackingService: Pedestrian status stream error: $error");
  }
}
