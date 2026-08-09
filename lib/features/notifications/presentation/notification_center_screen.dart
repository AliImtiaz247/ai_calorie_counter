import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/services/language_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/utils/responsive.dart';
import '../../calories/presentation/calories_detail_screen.dart';
import '../../steps/presentation/steps_screen.dart';
import '../../water/presentation/water_screen.dart';
import '../models/app_notification.dart';
import '../services/notification_local_storage.dart';

class NotificationCenterScreen extends StatefulWidget {
  const NotificationCenterScreen({super.key});

  @override
  State<NotificationCenterScreen> createState() =>
      _NotificationCenterScreenState();
}

class _NotificationCenterScreenState extends State<NotificationCenterScreen> {
  final NotificationLocalStorage _localStorage = NotificationLocalStorage.instance;
  final NotificationService _notificationService = NotificationService.instance;

  List<AppNotification> _notifications = [];
  bool _isLoading = true;

  StreamSubscription<List<AppNotification>>? _streamSub;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
    _streamSub = _notificationService.notificationsStream.listen((items) {
      if (mounted) {
        setState(() {
          _notifications = items;
          _isLoading = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _streamSub?.cancel();
    super.dispose();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    final items = await _localStorage.getNotifications();
    if (!mounted) return;
    setState(() {
      _notifications = items;
      _isLoading = false;
    });
  }

  Future<void> _markAllAsRead() async {
    await _notificationService.markAllAsRead();
    await _loadNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(LanguageService.tr("All notifications marked as read"))),
    );
  }

  Future<void> _clearAll() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(LanguageService.tr("Clear All Notifications")),
        content: Text(
          LanguageService.tr("Are you sure you want to clear all notifications?"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(LanguageService.tr("Cancel")),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(LanguageService.tr("Clear All")),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _notificationService.clearAll();
      await _loadNotifications();
    }
  }

  void _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
      await _loadNotifications();
    }

    if (!mounted) return;

    // Deep link routing based on category or goalType
    final category = (notification.category).toLowerCase();
    final goalType = (notification.goalType ?? '').toLowerCase();

    if (category == 'steps' || goalType == 'step' || notification.type == 'step_goal') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const StepsScreen()),
      );
    } else if (category == 'calories' || category == 'meals' || goalType == 'calorie') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const CaloriesDetailScreen()),
      );
    } else if (category == 'water' || goalType == 'water') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const WaterScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF22C55E);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          LanguageService.tr("Notifications"),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        actions: [
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'read_all') _markAllAsRead();
                if (value == 'clear_all') _clearAll();
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'read_all',
                  child: Row(
                    children: [
                      const Icon(Icons.done_all_rounded, size: 18),
                      const SizedBox(width: 8),
                      Text(LanguageService.tr("Mark all as read")),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(
                        LanguageService.tr("Clear all"),
                        style: const TextStyle(color: Colors.red),
                      ),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContentConstrained(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _notifications.isEmpty
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView(
                        padding: EdgeInsets.symmetric(
                          horizontal: Responsive.horizontalPadding(context),
                          vertical: 16,
                        ),
                        children: _buildGroupedNotificationList(isDark, primaryColor),
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_off_outlined,
                size: 54,
                color: Color(0xFF22C55E),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              LanguageService.tr("You're all caught up 🎉"),
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              LanguageService.tr("No new notifications yet."),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedNotificationList(bool isDark, Color primaryColor) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <AppNotification>[];
    final yesterdayItems = <AppNotification>[];
    final earlierItems = <AppNotification>[];

    for (final item in _notifications) {
      final itemDate = DateTime(
        item.timestamp.year,
        item.timestamp.month,
        item.timestamp.day,
      );

      if (itemDate.isAtSameMomentAs(today)) {
        todayItems.add(item);
      } else if (itemDate.isAtSameMomentAs(yesterday)) {
        yesterdayItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    final widgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(LanguageService.tr("Today"), isDark));
      widgets.addAll(todayItems.map((n) => _buildNotificationCard(n, isDark, primaryColor)));
    }

    if (yesterdayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(LanguageService.tr("Yesterday"), isDark));
      widgets.addAll(yesterdayItems.map((n) => _buildNotificationCard(n, isDark, primaryColor)));
    }

    if (earlierItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(LanguageService.tr("Earlier"), isDark));
      widgets.addAll(earlierItems.map((n) => _buildNotificationCard(n, isDark, primaryColor)));
    }

    return widgets;
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, bool isDark, Color primaryColor) {
    final timeStr = DateFormat('h:mm a').format(notification.timestamp);

    IconData iconData = Icons.notifications_active_rounded;
    Color iconColor = primaryColor;

    final cat = (notification.category).toLowerCase();
    final goalType = (notification.goalType ?? '').toLowerCase();

    if (goalType == 'calorie' || cat == 'calories') {
      iconData = Icons.local_fire_department_rounded;
      iconColor = const Color(0xFFEF4444);
    } else if (goalType == 'water' || cat == 'water') {
      iconData = Icons.water_drop_rounded;
      iconColor = const Color(0xFF3B82F6);
    } else if (goalType == 'step' || cat == 'steps') {
      iconData = Icons.directions_walk_rounded;
      iconColor = const Color(0xFF22C55E);
    } else if (goalType == 'weight' || cat == 'weight') {
      iconData = Icons.monitor_weight_rounded;
      iconColor = const Color(0xFF8B5CF6);
    } else if (notification.type == 'goal') {
      iconData = Icons.emoji_events_rounded;
      iconColor = const Color(0xFFF59E0B);
    } else if (notification.type == 'achievement') {
      iconData = Icons.star_rounded;
      iconColor = const Color(0xFF8B5CF6);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _handleNotificationTap(notification),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: notification.isRead
                  ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                  : (isDark
                      ? const Color(0xFF1E293B).withValues(alpha: 0.95)
                      : primaryColor.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: !notification.isRead
                    ? primaryColor.withValues(alpha: 0.4)
                    : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.04)),
                width: !notification.isRead ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(iconData, color: iconColor, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: notification.isRead
                                    ? FontWeight.w600
                                    : FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                          ),
                          if (!notification.isRead)
                            Container(
                              width: 8,
                              height: 8,
                              margin: const EdgeInsets.only(left: 6),
                              decoration: const BoxDecoration(
                                color: Color(0xFF22C55E),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white70 : Colors.grey.shade700,
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        timeStr,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: isDark ? Colors.white38 : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
