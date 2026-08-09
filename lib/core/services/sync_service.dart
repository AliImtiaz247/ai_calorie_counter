import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../features/meals/data/meal_repository.dart';
import '../../features/profile/data/profile_repository.dart';
import '../../features/steps/data/step_repository.dart';
import '../../features/water/data/water_repository.dart';
import 'connectivity_service.dart';
import 'notification_service.dart';

enum SyncStatus { synced, pending, syncing, failed }

class SyncItem {
  final String id;
  final String title;
  final String type; // 'meal', 'water', 'step', 'weight', 'profile'
  final DateTime timestamp;

  const SyncItem({
    required this.id,
    required this.title,
    required this.type,
    required this.timestamp,
  });
}

class SyncService with WidgetsBindingObserver {
  SyncService._();

  static final SyncService instance = SyncService._();
  factory SyncService() => instance;

  final ValueNotifier<SyncStatus> statusNotifier =
      ValueNotifier<SyncStatus>(SyncStatus.synced);

  final ValueNotifier<List<SyncItem>> pendingItemsNotifier =
      ValueNotifier<List<SyncItem>>([]);

  final ValueNotifier<bool> isOnlineNotifier = ValueNotifier<bool>(true);

  DateTime? lastSyncTime = DateTime.now();
  Timer? _connectivityTimer;
  bool _wasOffline = false;
  bool _isSyncing = false;
  bool _initialized = false;

  void init() {
    if (_initialized) return;
    _initialized = true;

    WidgetsBinding.instance.addObserver(this);
    _checkConnectivity();

    _connectivityTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectivity();
    });

    // Initial background sync on launch
    Future.delayed(const Duration(seconds: 2), () {
      syncNow();
    });
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivityTimer?.cancel();
    _initialized = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      debugPrint("[SyncService] App resumed -> triggering automatic lightweight sync.");
      syncNow();
    }
  }

  Future<void> _checkConnectivity() async {
    final hasNet = await ConnectivityService.hasInternetConnection();
    final previousNet = isOnlineNotifier.value;

    isOnlineNotifier.value = hasNet;

    if (!previousNet && hasNet && _wasOffline) {
      debugPrint("[SyncService] Internet connection restored -> triggering auto-sync.");
      _wasOffline = false;
      await syncNow();
    } else if (!hasNet) {
      _wasOffline = true;
    }
  }

  void addPendingItem({
    required String id,
    required String title,
    required String type,
  }) {
    final current = List<SyncItem>.from(pendingItemsNotifier.value);
    current.removeWhere((item) => item.id == id);
    current.insert(
      0,
      SyncItem(
        id: id,
        title: title,
        type: type,
        timestamp: DateTime.now(),
      ),
    );

    pendingItemsNotifier.value = current;
    statusNotifier.value = SyncStatus.pending;
  }

  void removePendingItem(String id) {
    final current = List<SyncItem>.from(pendingItemsNotifier.value);
    current.removeWhere((item) => item.id == id);
    pendingItemsNotifier.value = current;

    if (current.isEmpty) {
      statusNotifier.value = SyncStatus.synced;
      lastSyncTime = DateTime.now();
    }
  }

  /// Centralized Automatic Sync Core (Idempotent & Concurrency Locked)
  Future<void> syncNow({bool forceRefresh = false}) async {
    if (_isSyncing) {
      debugPrint("[SyncService] Sync already in progress. Skipping duplicate request.");
      return;
    }

    final hasNet = await ConnectivityService.hasInternetConnection();
    isOnlineNotifier.value = hasNet;

    if (!hasNet) {
      statusNotifier.value = SyncStatus.failed;
      return;
    }

    _isSyncing = true;
    statusNotifier.value = SyncStatus.syncing;

    try {
      // 1. Sync Pending Step Logs
      await StepRepository.instance.syncPendingLogs();

      // 2. Sync Pending Cloud Notifications
      await NotificationService.instance.syncPendingNotifications();

      // 3. Refresh Active User Data
      final now = DateTime.now();
      await WaterRepository().getWaterForDate(now, forceRefresh: forceRefresh);
      await MealRepository().getMealsByDate(now, forceRefresh: forceRefresh);
      await ProfileRepository().getProfile(forceRefresh: forceRefresh);

      pendingItemsNotifier.value = [];
      statusNotifier.value = SyncStatus.synced;
      lastSyncTime = DateTime.now();
      debugPrint("[SyncService] Automatic sync completed successfully.");
    } catch (e) {
      debugPrint("[SyncService] Sync error: $e");
      statusNotifier.value = SyncStatus.failed;
    } finally {
      _isSyncing = false;
    }
  }

  /// Cleanup handler for user logout
  void onLogout() {
    _connectivityTimer?.cancel();
    _connectivityTimer = null;
    pendingItemsNotifier.value = [];
    statusNotifier.value = SyncStatus.synced;
    _isSyncing = false;
  }
}
