import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_notification.dart';

class NotificationLocalStorage {
  NotificationLocalStorage._();

  static final NotificationLocalStorage instance = NotificationLocalStorage._();
  factory NotificationLocalStorage() => instance;

  static const String _keyNotificationsList = 'calorix_notifications_v1';

  /// Get all stored notifications (newest first)
  Future<List<AppNotification>> getNotifications() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final rawList = prefs.getStringList(_keyNotificationsList) ?? [];
      final result = <AppNotification>[];

      for (final itemStr in rawList) {
        try {
          result.add(AppNotification.fromJson(itemStr));
        } catch (_) {}
      }

      result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return result;
    } catch (e) {
      debugPrint("NotificationLocalStorage: Error reading notifications: $e");
      return [];
    }
  }

  /// Save or update a notification locally
  Future<void> saveNotification(AppNotification notification) async {
    try {
      final list = await getNotifications();
      final index = list.indexWhere((n) => n.id == notification.id);

      if (index >= 0) {
        list[index] = notification;
      } else {
        list.insert(0, notification);
      }

      final prefs = await SharedPreferences.getInstance();
      final encoded = list.map((n) => n.toJson()).toList();
      await prefs.setStringList(_keyNotificationsList, encoded);
    } catch (e) {
      debugPrint("NotificationLocalStorage: Error saving notification: $e");
    }
  }

  /// Mark single notification as read
  Future<void> markAsRead(String notificationId, {DateTime? readAt}) async {
    try {
      final list = await getNotifications();
      final index = list.indexWhere((n) => n.id == notificationId);
      if (index >= 0) {
        final now = readAt ?? DateTime.now();
        list[index] = list[index].copyWith(isRead: true, readAt: now, synced: false);
        final prefs = await SharedPreferences.getInstance();
        final encoded = list.map((n) => n.toJson()).toList();
        await prefs.setStringList(_keyNotificationsList, encoded);
      }
    } catch (e) {
      debugPrint("NotificationLocalStorage: Error marking notification read: $e");
    }
  }

  /// Mark all notifications as read
  Future<void> markAllAsRead({DateTime? readAt}) async {
    try {
      final list = await getNotifications();
      final now = readAt ?? DateTime.now();
      final updated = list.map((n) => n.copyWith(isRead: true, readAt: now, synced: false)).toList();
      final prefs = await SharedPreferences.getInstance();
      final encoded = updated.map((n) => n.toJson()).toList();
      await prefs.setStringList(_keyNotificationsList, encoded);
    } catch (e) {
      debugPrint("NotificationLocalStorage: Error marking all read: $e");
    }
  }

  /// Get current unread notification count
  Future<int> getUnreadCount() async {
    final list = await getNotifications();
    return list.where((n) => !n.isRead).length;
  }

  /// Clear all notifications
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyNotificationsList);
    } catch (e) {
      debugPrint("NotificationLocalStorage: Error clearing notifications: $e");
    }
  }

  /// Get notifications that are pending cloud sync
  Future<List<AppNotification>> getPendingSyncNotifications() async {
    final list = await getNotifications();
    return list.where((n) => !n.synced).toList();
  }
}
