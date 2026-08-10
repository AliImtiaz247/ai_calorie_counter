import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'package:intl/intl.dart';
import '../../features/notifications/models/app_notification.dart';
import '../../features/notifications/presentation/notification_center_screen.dart';
import '../../features/notifications/services/notification_local_storage.dart';
import 'connectivity_service.dart';

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  debugPrint('[NotificationService] Background notification tap received: ${notificationResponse.payload}');
}

class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();
  factory NotificationService() => instance;

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final NotificationLocalStorage _localStorage = NotificationLocalStorage.instance;
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  GlobalKey<NavigatorState>? navigatorKey;

  final ValueNotifier<int> unreadCountNotifier = ValueNotifier<int>(0);

  final StreamController<List<AppNotification>> _notificationsStreamController =
      StreamController<List<AppNotification>>.broadcast();

  Stream<List<AppNotification>> get notificationsStream =>
      _notificationsStreamController.stream;

  StreamSubscription<QuerySnapshot>? _firestoreSubscription;
  StreamSubscription<User?>? _authSubscription;

  bool _initialized = false;
  static const int _persistentTrackingNotificationId = 8888;
  static const String _defaultChannelId = 'calorix_notifications';

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  /// Initialize Local Notification Plugin & Android Channels & Firestore Stream
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('ic_notification');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
    );

    try {
      await _localNotifications.initialize(
        initSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) {
          debugPrint("[NotificationService] System notification tapped! Payload: ${response.payload}");
          final payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            _handleNotificationTapPayload(payload);
          }
        },
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Create Android Notification Channels
      final androidPlugin = _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            _defaultChannelId,
            'Calorix Notifications',
            description: 'Goal-completion and health updates from Calorix',
            importance: Importance.high,
            enableVibration: true,
            playSound: true,
          ),
        );

        await androidPlugin.createNotificationChannel(
          const AndroidNotificationChannel(
            'activity_tracking',
            'Activity Tracking Service',
            description: 'Persistent notification for active background step tracking',
            importance: Importance.low,
          ),
        );

        // Request Android 13+ Notification Permission
        await androidPlugin.requestNotificationsPermission();
      }

      _initialized = true;

      // Handle notification app launch payload (if app was terminated and launched by notification tap)
      final launchDetails = await _localNotifications.getNotificationAppLaunchDetails();
      if (launchDetails != null && launchDetails.didNotificationLaunchApp) {
        final payload = launchDetails.notificationResponse?.payload;
        if (payload != null && payload.isNotEmpty) {
          Future.delayed(const Duration(milliseconds: 800), () {
            _handleNotificationTapPayload(payload);
          });
        }
      }

      // Listen to Auth State changes to bind/unbind Firestore real-time listener
      _authSubscription?.cancel();
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null) {
          _setupFirestoreListener(user.uid);
        } else {
          _cancelFirestoreListener();
        }
      });

      if (uid != null) {
        _setupFirestoreListener(uid!);
      }

      final initialList = await _localStorage.getNotifications();
      _notificationsStreamController.add(initialList);
      await refreshUnreadCount();
      debugPrint("[NotificationService] Notification Service Initialized (${initialList.length} items).");

      await ensureWelcomeNotification();
    } catch (e) {
      debugPrint("[NotificationService] Initialization error: $e");
    }
  }

  void _handleNotificationTapPayload(String payload) async {
    try {
      debugPrint("[NotificationService] Processing tap for notification payload: $payload");
      String notifId = payload;

      if (payload.trim().startsWith('{') && payload.trim().endsWith('}')) {
        try {
          final notif = AppNotification.fromJson(payload);
          await _localStorage.saveNotification(notif);
          notifId = notif.id;
        } catch (_) {}
      }

      await markAsRead(notifId);

      final navState = navigatorKey?.currentState;
      if (navState != null) {
        navState.push(
          MaterialPageRoute(
            builder: (_) => const NotificationCenterScreen(),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error handling notification tap payload: $e");
    }
  }

  void _setupFirestoreListener(String userId) {
    _firestoreSubscription?.cancel();
    try {
      _firestoreSubscription = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen((snapshot) async {
        for (final doc in snapshot.docs) {
          try {
            final cloudNotification = AppNotification.fromMap(doc.data(), doc.id).copyWith(synced: true);
            await _localStorage.saveNotification(cloudNotification);
          } catch (err) {
            debugPrint("Error parsing cloud notification doc: $err");
          }
        }
        final updatedList = await _localStorage.getNotifications();
        _notificationsStreamController.add(updatedList);
        await refreshUnreadCount();
      }, onError: (err) async {
        debugPrint("[NotificationService] Firestore notifications stream error: $err");
        final localList = await _localStorage.getNotifications();
        _notificationsStreamController.add(localList);
        await refreshUnreadCount();
      });
    } catch (e) {
      debugPrint("[NotificationService] Error setting up Firestore listener: $e");
    }
  }

  void _cancelFirestoreListener() {
    _firestoreSubscription?.cancel();
    _firestoreSubscription = null;
  }

  /// Refresh Unread Badge Count
  Future<int> refreshUnreadCount() async {
    final count = await _localStorage.getUnreadCount();
    unreadCountNotifier.value = count;
    return count;
  }

  /// Show Persistent Background Tracking Notification in Android Shade
  Future<void> showPersistentTrackingNotification({
    required int steps,
    required int goal,
  }) async {
    try {
      if (!_initialized) await init();

      const androidDetails = AndroidNotificationDetails(
        'activity_tracking',
        'Activity Tracking Service',
        channelDescription: 'Persistent notification for active background step tracking',
        importance: Importance.low,
        priority: Priority.low,
        ongoing: true,
        autoCancel: false,
        showWhen: false,
        icon: 'ic_notification',
        color: Color(0xFF22C55E),
      );

      const notificationDetails = NotificationDetails(android: androidDetails);

      final formattedSteps = NumberFormat('#,##0').format(steps);
      final bodyText = steps > 0
          ? 'Tracking your steps and progress • $formattedSteps steps today'
          : 'Tracking your steps and progress';

      await _localNotifications.show(
        _persistentTrackingNotificationId,
        'Calorix is running',
        bodyText,
        notificationDetails,
      );
    } catch (e) {
      debugPrint("[NotificationService] Error showing persistent tracking notification: $e");
    }
  }

  /// Cancel Persistent Tracking Notification when tracking is paused/disabled
  Future<void> cancelPersistentTrackingNotification() async {
    try {
      await _localNotifications.cancel(_persistentTrackingNotificationId);
    } catch (e) {
      debugPrint("[NotificationService] Error canceling persistent tracking notification: $e");
    }
  }

  /// Ensure Welcome Notification exists for new feeds
  Future<void> ensureWelcomeNotification() async {
    try {
      final existing = await _localStorage.getNotifications();
      if (existing.isEmpty) {
        await notifyGoalReached(
          id: 'welcome_calorix',
          type: 'system',
          title: '🎉 Welcome to Calorix!',
          message: 'Track your daily calories, steps, and water intake effortlessly.',
          category: 'system',
        );
      }
    } catch (e) {
      debugPrint("Error creating welcome notification: $e");
    }
  }

  /// Local Goal & Achievement Notification Event Handler (Idempotent)
  Future<void> notifyGoalReached({
    required String id,
    required String type, // 'goal', 'achievement', 'activity', 'sync', 'system'
    required String title,
    required String message,
    required String category,
    String? relatedEntityId,
    String? goalType,
    num? goalTarget,
    num? goalProgress,
  }) async {
    try {
      if (!_initialized) await init();

      // 1. Idempotency Check: Prevent duplicate notifications for same ID
      final existingList = await _localStorage.getNotifications();
      if (existingList.any((n) => n.id == id)) {
        debugPrint("[NotificationService] Notification $id already exists. Skipping duplicate.");
        return;
      }

      final now = DateTime.now();

      final newNotification = AppNotification(
        id: id,
        userId: uid ?? 'local',
        type: type,
        title: title,
        message: message,
        timestamp: now,
        isRead: false,
        category: category,
        relatedEntityId: relatedEntityId,
        createdAt: now,
        synced: false,
        goalType: goalType,
        goalTarget: goalTarget,
        goalProgress: goalProgress,
      );

      // 2. Save locally first (Offline-First)
      await _localStorage.saveNotification(newNotification);
      final updatedList = await _localStorage.getNotifications();
      _notificationsStreamController.add(updatedList);
      await refreshUnreadCount();

      // 3. Trigger Mobile System Notification (Android Shade & iOS)
      const androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        'Calorix Notifications',
        channelDescription: 'Goal-completion and health updates from Calorix',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
        color: Color(0xFF22C55E),
        enableVibration: true,
        playSound: true,
      );

      const darwinDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: darwinDetails,
      );

      await _localNotifications.show(
        id.hashCode,
        title,
        message,
        details,
        payload: id,
      );

      // 4. Background Sync to Cloud Firestore if online
      syncPendingNotifications();
    } catch (e) {
      debugPrint("[NotificationService] Error triggering goal notification: $e");
    }
  }

  /// Mark Notification Read locally & update badge
  Future<void> markAsRead(String id) async {
    final now = DateTime.now();
    await _localStorage.markAsRead(id, readAt: now);

    if (uid != null) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(id)
            .set({
          'isRead': true,
          'readAt': now.toIso8601String(),
        }, SetOptions(merge: true));
      } catch (e) {
        debugPrint("Error updating cloud notification read status: $e");
      }
    }

    final updatedList = await _localStorage.getNotifications();
    _notificationsStreamController.add(updatedList);
    await refreshUnreadCount();
    syncPendingNotifications();
  }

  /// Mark All Notifications Read
  Future<void> markAllAsRead() async {
    final now = DateTime.now();
    await _localStorage.markAllAsRead(readAt: now);

    if (uid != null) {
      try {
        final pendingUnread = await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .where('isRead', isEqualTo: false)
            .get();

        final batch = _firestore.batch();
        for (final doc in pendingUnread.docs) {
          batch.update(doc.reference, {
            'isRead': true,
            'readAt': now.toIso8601String(),
          });
        }
        await batch.commit();
      } catch (e) {
        debugPrint("Error updating cloud mark all read: $e");
      }
    }

    final updatedList = await _localStorage.getNotifications();
    _notificationsStreamController.add(updatedList);
    await refreshUnreadCount();
    syncPendingNotifications();
  }

  /// Clear All Notifications
  Future<void> clearAll() async {
    await _localStorage.clearAll();
    _notificationsStreamController.add([]);
    await refreshUnreadCount();
  }

  /// Delete a single notification locally and in cloud
  Future<void> deleteNotification(String id) async {
    await _localStorage.deleteNotification(id);
    if (uid != null) {
      try {
        await _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(id)
            .delete();
      } catch (e) {
        debugPrint("Error deleting cloud notification: $e");
      }
    }
    final updatedList = await _localStorage.getNotifications();
    _notificationsStreamController.add(updatedList);
    await refreshUnreadCount();
  }

  /// Send a Test Notification to verify system & in-app inbox behavior
  Future<void> sendTestNotification() async {
    final now = DateTime.now();
    final testId = 'test_notif_${now.millisecondsSinceEpoch}';

    await notifyGoalReached(
      id: testId,
      type: 'system',
      title: '🔔 Calorix Notification Test',
      message: 'This is a test notification! It will appear in your notification screen like YouTube.',
      category: 'system',
    );
  }

  static const int _waterReminderNotifId = 9001;
  static const int _mealReminderNotifId = 9002;

  /// Schedule Daily Hydration & Meal Reminders
  Future<void> scheduleDailyReminders() async {
    try {
      if (!_initialized) await init();

      const androidDetails = AndroidNotificationDetails(
        _defaultChannelId,
        'Calorix Notifications',
        channelDescription: 'Goal-completion and health updates from Calorix',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_notification',
        color: Color(0xFF22C55E),
      );

      const details = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(),
      );

      await _localNotifications.periodicallyShow(
        _waterReminderNotifId,
        '💧 Stay Hydrated!',
        'Don\'t forget to log your water intake today to reach your hydration goal.',
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      await _localNotifications.periodicallyShow(
        _mealReminderNotifId,
        '🥗 Log Your Meal',
        'Keep track of your calories and macros by logging your latest meal in Calorix.',
        RepeatInterval.daily,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );

      debugPrint("[NotificationService] Daily reminders scheduled successfully.");
    } catch (e) {
      debugPrint("[NotificationService] Error scheduling daily reminders: $e");
    }
  }

  /// Cancel Daily Reminders when disabled in Settings
  Future<void> cancelDailyReminders() async {
    try {
      await _localNotifications.cancel(_waterReminderNotifId);
      await _localNotifications.cancel(_mealReminderNotifId);
      debugPrint("[NotificationService] Daily reminders canceled.");
    } catch (e) {
      debugPrint("[NotificationService] Error canceling daily reminders: $e");
    }
  }

  /// Background Cloud Firestore Sync for Notifications
  Future<void> syncPendingNotifications() async {
    if (uid == null) return;

    final isOnline = await ConnectivityService.hasInternetConnection();
    if (!isOnline) return;

    try {
      final pending = await _localStorage.getPendingSyncNotifications();
      if (pending.isEmpty) return;

      for (final notification in pending) {
        final docRef = _firestore
            .collection('users')
            .doc(uid)
            .collection('notifications')
            .doc(notification.id);

        await docRef.set(notification.toMap(), SetOptions(merge: true));

        final syncedItem = notification.copyWith(synced: true);
        await _localStorage.saveNotification(syncedItem);
      }
    } catch (e) {
      debugPrint("[NotificationService] Cloud notification sync error: $e");
    }
  }
}
