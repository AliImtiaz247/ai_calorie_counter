import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/services/goal_completion_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/sync_service.dart';
import '../models/step_log.dart';
import '../services/step_local_storage.dart';
import '../services/step_tracking_service.dart';

enum StepTrackingState {
  notSetup,
  active,
  permissionDenied,
  permissionPermanentlyDenied,
  sensorUnavailable,
}

class StepRepository extends ChangeNotifier with WidgetsBindingObserver {
  StepRepository._();

  static final StepRepository instance = StepRepository._();
  factory StepRepository() => instance;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final StepTrackingService _trackingService = StepTrackingService.instance;
  final StepLocalStorage _localStorage = StepLocalStorage.instance;

  StepLog? _cachedTodayLog;
  StepTrackingState _trackingState = StepTrackingState.notSetup;
  StreamSubscription<int>? _sensorSubscription;
  Timer? _autoSyncTimer;
  Timer? _syncDebounceTimer;
  bool _isSyncing = false;

  StepTrackingState get trackingState => _trackingState;
  StepLog? get cachedTodayLog => _cachedTodayLog;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  String formatDateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  String get today => formatDateKey(DateTime.now());

  DocumentReference<Map<String, dynamic>> _stepDocForDate(DateTime dt) {
    return _firestore
        .collection("users")
        .doc(uid)
        .collection("steps")
        .doc(formatDateKey(dt));
  }

  /// Initialize Step Repository & Sensor Listeners
  Future<void> init() async {
    WidgetsBinding.instance.addObserver(this);

    final isEnabled = await _localStorage.isTrackingEnabled();
    final permStatus = await _trackingService.checkPermissionStatus();

    if (permStatus == StepTrackingPermissionStatus.granted) {
      if (isEnabled) {
        _trackingState = StepTrackingState.active;
        await _startSensorTracking();
      } else {
        _trackingState = StepTrackingState.notSetup;
      }
    } else if (permStatus == StepTrackingPermissionStatus.permanentlyDenied) {
      _trackingState = StepTrackingState.permissionPermanentlyDenied;
    } else if (permStatus == StepTrackingPermissionStatus.denied) {
      _trackingState = isEnabled
          ? StepTrackingState.permissionDenied
          : StepTrackingState.notSetup;
    }

    // Load initial local data
    await getTodaySteps();

    // Trigger immediate background sync check on launch
    scheduleDebouncedSync(delay: const Duration(seconds: 3));

    // Start periodic auto-sync timer (every 5 minutes)
    _autoSyncTimer?.cancel();
    _autoSyncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      syncPendingLogs();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("[Steps] App resumed -> refreshing local step data and triggering auto-sync");
      getTodaySteps(forceRefresh: true).then((_) {
        scheduleDebouncedSync(delay: const Duration(seconds: 2));
      });
    }
  }

  /// Schedule debounced cloud sync (prevents Firestore spam on rapid step changes)
  void scheduleDebouncedSync({Duration delay = const Duration(seconds: 15)}) {
    _syncDebounceTimer?.cancel();
    _syncDebounceTimer = Timer(delay, () {
      debugPrint("[Steps] Sync debounce timer triggered -> running syncPendingLogs()");
      syncPendingLogs();
    });
  }

  /// User Action: Setup & Enable Step Tracking
  Future<StepTrackingState> enableStepTracking() async {
    final permStatus = await _trackingService.requestPermission();

    if (permStatus == StepTrackingPermissionStatus.granted) {
      await _localStorage.setTrackingEnabled(true);
      _trackingState = StepTrackingState.active;

      final success = await _startSensorTracking();
      if (!success) {
        _trackingState = StepTrackingState.sensorUnavailable;
      } else {
        final currentLog = await getTodaySteps();
        NotificationService.instance.showPersistentTrackingNotification(
          steps: currentLog.steps,
          goal: currentLog.goal,
        );
      }

      await getTodaySteps(forceRefresh: true);
      notifyListeners();
      return _trackingState;
    } else if (permStatus == StepTrackingPermissionStatus.permanentlyDenied) {
      _trackingState = StepTrackingState.permissionPermanentlyDenied;
      notifyListeners();
      return _trackingState;
    } else {
      _trackingState = StepTrackingState.permissionDenied;
      notifyListeners();
      return _trackingState;
    }
  }

  /// User Action: Disable Background Step Tracking
  Future<void> disableStepTracking() async {
    await _localStorage.setTrackingEnabled(false);
    _trackingService.stopTracking();
    _sensorSubscription?.cancel();
    _sensorSubscription = null;
    _trackingState = StepTrackingState.notSetup;
    await NotificationService.instance.cancelPersistentTrackingNotification();
    notifyListeners();
  }

  /// Open System App Settings for permissions
  Future<bool> openAppSettings() async {
    return _trackingService.openAppSettingsPage();
  }

  /// Start Listening to Raw Pedometer Sensor Stream
  Future<bool> _startSensorTracking() async {
    final success = await _trackingService.startTracking();
    if (success) {
      _sensorSubscription?.cancel();
      _sensorSubscription = _trackingService.rawStepStream.listen(
        _onRawSensorReading,
        onError: (err) {
          debugPrint("StepRepository: Sensor stream error: $err");
        },
      );
    }
    return success;
  }

  /// Handle Incoming Hardware Step Counter Sensor Stream Update
  Future<void> _onRawSensorReading(int rawSensorValue) async {
    final currentDateKey = today;
    final activeDateKey = await _localStorage.getActiveDate() ?? currentDateKey;
    final deviceId = await _localStorage.getDeviceId();
    final defaultGoal = await _localStorage.getDefaultGoal();
    final lastRawValue = await _localStorage.getLastRawSensorValue();

    // 1. Date Rollover Check
    if (currentDateKey != activeDateKey) {
      debugPrint("StepRepository: Date rollover detected! ($activeDateKey -> $currentDateKey)");
      await _localStorage.saveActiveDate(currentDateKey);
      await _localStorage.saveBaseline(currentDateKey, rawSensorValue);
      await _localStorage.saveLastRawSensorValue(rawSensorValue);

      final newLog = StepLog(
        id: currentDateKey,
        userId: uid ?? 'local',
        date: currentDateKey,
        steps: 0,
        goal: defaultGoal,
        baselineSteps: rawSensorValue,
        lastSensorValue: rawSensorValue,
        deviceId: deviceId,
        syncStatus: 'pending',
      );

      _cachedTodayLog = newLog;
      await _localStorage.saveStepLog(newLog);
      notifyListeners();
      return;
    }

    // Load or create current day's record
    var currentLog = _cachedTodayLog ?? await _localStorage.getStepLog(currentDateKey);
    int? baseline = await _localStorage.getBaseline(currentDateKey);

    if (baseline == null || baseline <= 0) {
      baseline = rawSensorValue;
      await _localStorage.saveBaseline(currentDateKey, baseline);
    }

    // 2. Device Reboot / Sensor Reset Check
    if (lastRawValue > 0 && rawSensorValue < lastRawValue) {
      debugPrint("StepRepository: Sensor reset / device reboot detected! (Previous raw: $lastRawValue, New raw: $rawSensorValue)");
      final existingSteps = currentLog?.steps ?? 0;
      baseline = (rawSensorValue - existingSteps).clamp(0, rawSensorValue);
      await _localStorage.saveBaseline(currentDateKey, baseline);
    }

    await _localStorage.saveLastRawSensorValue(rawSensorValue);

    // 3. Compute Today's Steps
    final computedSteps = (rawSensorValue - baseline).clamp(0, 500000);
    final previousSteps = currentLog?.steps ?? 0;
    final stepDelta = (computedSteps - previousSteps).clamp(0, 10000);

    final currentHour = DateTime.now().hour;
    final updatedHourly = Map<int, int>.from(currentLog?.hourlySteps ?? {});
    if (stepDelta > 0 || !updatedHourly.containsKey(currentHour)) {
      updatedHourly[currentHour] = (updatedHourly[currentHour] ?? 0) + stepDelta;
    }

    final updatedLog = (currentLog ?? StepLog(
      id: currentDateKey,
      userId: uid ?? 'local',
      date: currentDateKey,
      steps: 0,
      goal: defaultGoal,
      deviceId: deviceId,
    )).copyWith(
      steps: computedSteps,
      baselineSteps: baseline,
      lastSensorValue: rawSensorValue,
      hourlySteps: updatedHourly,
      deviceId: deviceId,
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    _cachedTodayLog = updatedLog;
    await _localStorage.saveStepLog(updatedLog);

    // Notify SyncService of pending update
    SyncService.instance.addPendingItem(
      id: 'step_$currentDateKey',
      title: 'Daily Steps: ${updatedLog.steps}',
      type: 'step',
    );

    notifyListeners();

    // Update Persistent Background Tracking Notification
    final isTrackingEnabled = await _localStorage.isTrackingEnabled();
    if (isTrackingEnabled) {
      NotificationService.instance.showPersistentTrackingNotification(
        steps: updatedLog.steps,
        goal: updatedLog.goal,
      );
    }

    // Goal Reach Detection
    if (updatedLog.steps >= updatedLog.goal && updatedLog.goal > 0) {
      _handleGoalReached(updatedLog);
    }

    // Schedule debounced cloud sync (15s after latest step change)
    scheduleDebouncedSync(delay: const Duration(seconds: 15));
  }

  Future<void> _handleGoalReached(StepLog log) async {
    await GoalCompletionService.instance.checkStepGoal(
      steps: log.steps,
      goal: log.goal,
    );
  }

  /// Clear Cache
  void clearCache() {
    _cachedTodayLog = null;
  }

  /// Get today's step log (Offline-first)
  Future<StepLog> getTodaySteps({bool forceRefresh = false}) async {
    return getStepsForDate(DateTime.now(), forceRefresh: forceRefresh);
  }

  /// Get steps for specific date (Offline-first local read, then background sync)
  Future<StepLog> getStepsForDate(DateTime dt, {bool forceRefresh = false}) async {
    final dateKey = formatDateKey(dt);

    if (!forceRefresh && dateKey == today && _cachedTodayLog != null) {
      return _cachedTodayLog!;
    }

    // 1. Try Local Storage first
    final localLog = await _localStorage.getStepLog(dateKey);
    if (localLog != null && !forceRefresh) {
      if (dateKey == today) _cachedTodayLog = localLog;
      return localLog;
    }

    final defaultGoal = await _localStorage.getDefaultGoal();
    final deviceId = await _localStorage.getDeviceId();

    final fallbackLog = localLog ?? StepLog(
      id: dateKey,
      userId: uid ?? 'local',
      date: dateKey,
      steps: 0,
      goal: defaultGoal,
      deviceId: deviceId,
      syncStatus: 'pending',
    );

    if (dateKey == today) {
      _cachedTodayLog = fallbackLog;
    }

    // 2. Fetch from Firestore if online and logged in
    if (uid != null) {
      _fetchFromFirestoreInBackground(dt);
    }

    return fallbackLog;
  }

  Future<void> _fetchFromFirestoreInBackground(DateTime dt) async {
    final dateKey = formatDateKey(dt);
    try {
      final doc = await _stepDocForDate(dt).get();
      if (doc.exists && doc.data() != null) {
        final cloudLog = StepLog.fromMap(doc.data()!, doc.id);
        final localLog = await _localStorage.getStepLog(dateKey);
        final defaultGoal = await _localStorage.getDefaultGoal();

        // Preserve user's configured goal (local goal > default goal > cloud goal)
        final effectiveGoal = (localLog?.goal != null && localLog!.goal > 0)
            ? localLog.goal
            : (defaultGoal > 0 ? defaultGoal : cloudLog.goal);

        final mergedLog = cloudLog.copyWith(
          goal: effectiveGoal,
          steps: (localLog != null && localLog.steps > cloudLog.steps)
              ? localLog.steps
              : cloudLog.steps,
        );

        if (localLog == null || cloudLog.steps > localLog.steps || localLog.goal != effectiveGoal) {
          await _localStorage.saveStepLog(mergedLog);
          if (dateKey == today) {
            _cachedTodayLog = mergedLog;
            notifyListeners();
          }
        }
      }
    } catch (e) {
      debugPrint("StepRepository: Background Firestore fetch error for $dateKey: $e");
    }
  }

  /// Optimistic Add Manual / Bonus Steps
  Future<void> addSteps(int addedCount, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);
    final currentLog = await getStepsForDate(targetDate);

    final newTotal = currentLog.steps + addedCount;
    final currentHour = DateTime.now().hour;
    final updatedHourly = Map<int, int>.from(currentLog.hourlySteps);
    updatedHourly[currentHour] = (updatedHourly[currentHour] ?? 0) + addedCount;

    final updatedLog = currentLog.copyWith(
      steps: newTotal,
      hourlySteps: updatedHourly,
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    if (dateKey == today) {
      _cachedTodayLog = updatedLog;
    }

    await _localStorage.saveStepLog(updatedLog);
    notifyListeners();

    if (updatedLog.steps >= updatedLog.goal && updatedLog.goal > 0) {
      GoalCompletionService.instance.checkStepGoal(
        steps: updatedLog.steps,
        goal: updatedLog.goal,
        date: targetDate,
      );
    }

    // Queue sync
    syncPendingLogs();
  }

  /// Optimistic Set Daily Goal
  Future<void> setDailyGoal(int newGoal, {DateTime? date}) async {
    final targetDate = date ?? DateTime.now();
    final dateKey = formatDateKey(targetDate);
    final currentLog = await getStepsForDate(targetDate);

    await _localStorage.saveDefaultGoal(newGoal);

    final updatedLog = currentLog.copyWith(
      goal: newGoal,
      updatedAt: DateTime.now(),
      syncStatus: 'pending',
    );

    if (dateKey == today) {
      _cachedTodayLog = updatedLog;
    }

    await _localStorage.saveStepLog(updatedLog);
    notifyListeners();

    // Check goal completion immediately after goal update
    if (updatedLog.steps >= newGoal && newGoal > 0) {
      GoalCompletionService.instance.checkStepGoal(
        steps: updatedLog.steps,
        goal: newGoal,
        date: targetDate,
      );
    }

    // Queue cloud sync
    if (uid != null) {
      try {
        await _firestore.collection('users').doc(uid).set(
          {'dailyStepGoal': newGoal},
          SetOptions(merge: true),
        );
      } catch (e) {
        debugPrint("StepRepository: Cloud goal update error: $e");
      }
    }

    syncPendingLogs();
  }

  /// Get Historical Step Logs for Last X Days
  Future<List<StepLog>> getStepHistoryForLastDays(int days) async {
    final list = <StepLog>[];
    final now = DateTime.now();

    for (int i = 0; i < days; i++) {
      final dt = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: days - 1 - i));
      final log = await getStepsForDate(dt);
      list.add(log);
    }

    return list;
  }

  /// Synchronize Pending Local Logs to Firestore (Offline-First Auto-Sync with Conflict Resolution)
  Future<void> syncPendingLogs() async {
    if (uid == null || _isSyncing) return;

    final isOnline = await ConnectivityService.hasInternetConnection();
    if (!isOnline) return;

    _isSyncing = true;
    try {
      final pendingDates = await _localStorage.getPendingSyncDates();
      final datesToSync = Set<String>.from(pendingDates);
      if (_cachedTodayLog != null && _cachedTodayLog!.syncStatus == 'pending') {
        datesToSync.add(_cachedTodayLog!.date);
      }

      if (datesToSync.isEmpty) {
        _isSyncing = false;
        return;
      }

      for (final dateKey in datesToSync) {
        final localLog = await _localStorage.getStepLog(dateKey) ??
            (dateKey == today ? _cachedTodayLog : null);
        if (localLog == null) continue;

        try {
          final dt = DateTime.parse(dateKey);
          final docRef = _stepDocForDate(dt);

          // 1. Conflict Resolution: Read existing cloud document if available
          final docSnap = await docRef.get();
          StepLog logToUpload = localLog;

          if (docSnap.exists && docSnap.data() != null) {
            final cloudLog = StepLog.fromMap(docSnap.data()!, docSnap.id);
            // If cloud has more steps than local, preserve cloud step count locally
            if (cloudLog.steps > localLog.steps) {
              debugPrint("[Sync] Cloud steps higher for $dateKey (${cloudLog.steps} > ${localLog.steps}). Merging cloud step count.");
              logToUpload = localLog.copyWith(
                steps: cloudLog.steps,
                hourlySteps: cloudLog.hourlySteps.isNotEmpty ? cloudLog.hourlySteps : localLog.hourlySteps,
              );
            }
          }

          // 2. Upload to Firestore
          await docRef.set(
            logToUpload.toMap(),
            SetOptions(merge: true),
          );

          // 3. Confirm write success and mark locally as synced
          final syncedLog = logToUpload.copyWith(syncStatus: 'synced');
          await _localStorage.saveStepLog(syncedLog);
          if (dateKey == today) {
            _cachedTodayLog = syncedLog;
          }

          SyncService.instance.removePendingItem('step_$dateKey');
          debugPrint("[Sync] Firestore write success for $dateKey (${syncedLog.steps} steps)");
        } catch (e) {
          debugPrint("[Sync] Error syncing log for $dateKey: $e");
        }
      }
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncDebounceTimer?.cancel();
    _sensorSubscription?.cancel();
    _autoSyncTimer?.cancel();
    super.dispose();
  }
}
