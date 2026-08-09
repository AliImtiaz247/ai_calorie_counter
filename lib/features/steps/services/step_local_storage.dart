import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import '../models/step_log.dart';

class StepLocalStorage {
  StepLocalStorage._();

  static final StepLocalStorage instance = StepLocalStorage._();
  factory StepLocalStorage() => instance;

  static const String _keyPrefixLog = 'step_log_';
  static const String _keyPrefixBaseline = 'step_baseline_';
  static const String _keyLastRawSensor = 'step_last_raw_sensor';
  static const String _keyActiveDate = 'step_active_date';
  static const String _keyDeviceId = 'step_device_id';
  static const String _keyDailyGoal = 'step_daily_goal';
  static const String _keyTrackingEnabled = 'step_tracking_enabled';
  static const String _keyPendingSyncDates = 'step_pending_sync_dates';

  /// Save daily StepLog locally
  Future<void> saveStepLog(StepLog log) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyPrefixLog${log.date}', log.toJson());

      if (log.syncStatus == 'pending') {
        await addPendingSyncDate(log.date);
      } else if (log.syncStatus == 'synced') {
        await removePendingSyncDate(log.date);
      }
    } catch (e) {
      debugPrint("StepLocalStorage: Error saving StepLog for ${log.date}: $e");
    }
  }

  /// Get daily StepLog locally
  Future<StepLog?> getStepLog(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('$_keyPrefixLog$dateKey');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return StepLog.fromJson(jsonStr, dateKey);
      }
    } catch (e) {
      debugPrint("StepLocalStorage: Error loading StepLog for $dateKey: $e");
    }
    return null;
  }

  /// Save daily Sensor Baseline
  Future<void> saveBaseline(String dateKey, int baseline) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('$_keyPrefixBaseline$dateKey', baseline);
    } catch (e) {
      debugPrint("StepLocalStorage: Error saving baseline for $dateKey: $e");
    }
  }

  /// Get daily Sensor Baseline
  Future<int?> getBaseline(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt('$_keyPrefixBaseline$dateKey');
    } catch (e) {
      debugPrint("StepLocalStorage: Error getting baseline for $dateKey: $e");
      return null;
    }
  }

  /// Save Last Recorded Raw Cumulative Sensor Reading
  Future<void> saveLastRawSensorValue(int val) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyLastRawSensor, val);
    } catch (e) {
      debugPrint("StepLocalStorage: Error saving last raw sensor value: $e");
    }
  }

  /// Get Last Recorded Raw Cumulative Sensor Reading
  Future<int> getLastRawSensorValue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyLastRawSensor) ?? 0;
    } catch (e) {
      return 0;
    }
  }

  /// Get or Create Unique Device ID
  Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_keyDeviceId);
      if (deviceId == null || deviceId.isEmpty) {
        deviceId = const Uuid().v4();
        await prefs.setString(_keyDeviceId, deviceId);
      }
      return deviceId;
    } catch (e) {
      return 'device_local';
    }
  }

  /// Save Default Step Goal
  Future<void> saveDefaultGoal(int goal) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_keyDailyGoal, goal);
    } catch (e) {
      debugPrint("StepLocalStorage: Error saving default goal: $e");
    }
  }

  /// Get Default Step Goal
  Future<int> getDefaultGoal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_keyDailyGoal) ?? 10000;
    } catch (e) {
      return 10000;
    }
  }

  /// Set Step Tracking Enabled State
  Future<void> setTrackingEnabled(bool enabled) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_keyTrackingEnabled, enabled);
    } catch (e) {
      debugPrint("StepLocalStorage: Error setting tracking enabled: $e");
    }
  }

  /// Get Step Tracking Enabled State
  Future<bool> isTrackingEnabled() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_keyTrackingEnabled) ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Save Active Tracking Date
  Future<void> saveActiveDate(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyActiveDate, dateKey);
    } catch (e) {
      debugPrint("StepLocalStorage: Error saving active date: $e");
    }
  }

  /// Get Active Tracking Date
  Future<String?> getActiveDate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_keyActiveDate);
    } catch (e) {
      return null;
    }
  }

  /// Queue a date key for Firestore synchronization
  Future<void> addPendingSyncDate(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_keyPendingSyncDates) ?? [];
      if (!pending.contains(dateKey)) {
        pending.add(dateKey);
        await prefs.setStringList(_keyPendingSyncDates, pending);
      }
    } catch (e) {
      debugPrint("StepLocalStorage: Error adding pending sync date: $e");
    }
  }

  /// Remove a date key from pending sync queue
  Future<void> removePendingSyncDate(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final pending = prefs.getStringList(_keyPendingSyncDates) ?? [];
      if (pending.contains(dateKey)) {
        pending.remove(dateKey);
        await prefs.setStringList(_keyPendingSyncDates, pending);
      }
    } catch (e) {
      debugPrint("StepLocalStorage: Error removing pending sync date: $e");
    }
  }

  /// Get all pending sync date keys
  Future<List<String>> getPendingSyncDates() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_keyPendingSyncDates) ?? [];
    } catch (e) {
      return [];
    }
  }

  /// Goal Notification Flags per Date
  static const String _keyPrefixGoalNotified = 'step_goal_notified_';

  Future<bool> hasNotifiedGoalForDate(String dateKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_keyPrefixGoalNotified$dateKey') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setNotifiedGoalForDate(String dateKey, bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_keyPrefixGoalNotified$dateKey', value);
    } catch (e) {
      debugPrint("StepLocalStorage: Error setting goal notified: $e");
    }
  }
}
