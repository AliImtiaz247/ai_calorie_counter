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
  String _selectedFilter = 'all'; // 'all', 'unread', 'goals', 'system'

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

  Future<void> _deleteNotification(AppNotification notification) async {
    await _notificationService.deleteNotification(notification.id);
    await _loadNotifications();

    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.tr("Notification deleted")),
        action: SnackBarAction(
          label: LanguageService.tr("Undo"),
          onPressed: () async {
            await _localStorage.saveNotification(notification);
            await _loadNotifications();
          },
        ),
      ),
    );
  }

  Future<void> _sendTestNotification() async {
    await _notificationService.sendTestNotification();
    await _loadNotifications();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LanguageService.tr("Test notification sent!")),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _handleNotificationTap(AppNotification notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
      await _loadNotifications();
    }

    if (!mounted) return;

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

  List<AppNotification> get _filteredNotifications {
    if (_selectedFilter == 'unread') {
      return _notifications.where((n) => !n.isRead).toList();
    }
    if (_selectedFilter == 'goals') {
      return _notifications.where((n) => n.type == 'goal' || n.goalType != null).toList();
    }
    if (_selectedFilter == 'system') {
      return _notifications.where((n) => n.type == 'system' || n.category == 'system').toList();
    }
    return _notifications;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const primaryColor = Color(0xFF22C55E);
    final displayedList = _filteredNotifications;

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
          IconButton(
            icon: const Icon(Icons.add_alert_outlined),
            tooltip: LanguageService.tr("Send Test Notification"),
            onPressed: _sendTestNotification,
          ),
          if (_notifications.isNotEmpty)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              onSelected: (value) {
                if (value == 'read_all') _markAllAsRead();
                if (value == 'clear_all') _clearAll();
                if (value == 'test_notif') _sendTestNotification();
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
                  value: 'test_notif',
                  child: Row(
                    children: [
                      const Icon(Icons.notifications_active_outlined, size: 18),
                      const SizedBox(width: 8),
                      Text(LanguageService.tr("Send test notification")),
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
          child: Column(
            children: [
              // YouTube-style Category Filter Chips Bar
              _buildFilterBar(isDark, primaryColor),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : displayedList.isEmpty
                        ? _buildEmptyState(isDark)
                        : RefreshIndicator(
                            onRefresh: _loadNotifications,
                            child: ListView(
                              padding: EdgeInsets.symmetric(
                                horizontal: Responsive.horizontalPadding(context),
                                vertical: 12,
                              ),
                              children: _buildGroupedNotificationList(displayedList, isDark, primaryColor),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(bool isDark, Color primaryColor) {
    final unreadCount = _notifications.where((n) => !n.isRead).length;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white12 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', LanguageService.tr("All"), _notifications.length, isDark, primaryColor),
            const SizedBox(width: 8),
            _buildFilterChip('unread', LanguageService.tr("Unread"), unreadCount, isDark, primaryColor),
            const SizedBox(width: 8),
            _buildFilterChip('goals', LanguageService.tr("Goals"), null, isDark, primaryColor),
            const SizedBox(width: 8),
            _buildFilterChip('system', LanguageService.tr("System"), null, isDark, primaryColor),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label, int? count, bool isDark, Color primaryColor) {
    final isSelected = _selectedFilter == filterKey;

    return FilterChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label),
          if (count != null && count > 0) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                    : (isDark ? Colors.white24 : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected
                      ? (isDark ? Colors.white : primaryColor)
                      : (isDark ? Colors.white70 : Colors.black87),
                ),
              ),
            ),
          ],
        ],
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      selectedColor: primaryColor,
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        color: isSelected
            ? Colors.white
            : (isDark ? Colors.white70 : Colors.grey.shade800),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 13,
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? primaryColor
              : (isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.05)),
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
              _selectedFilter == 'unread'
                  ? LanguageService.tr("No unread notifications.")
                  : LanguageService.tr("No notifications match your current filter."),
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white60 : Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _sendTestNotification,
              icon: const Icon(Icons.send_rounded, size: 18),
              label: Text(LanguageService.tr("Send Test Notification")),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF22C55E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupedNotificationList(
      List<AppNotification> items, bool isDark, Color primaryColor) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final todayItems = <AppNotification>[];
    final yesterdayItems = <AppNotification>[];
    final earlierItems = <AppNotification>[];

    for (final item in items) {
      final localTs = item.timestamp.toLocal();
      final itemDate = DateTime(localTs.year, localTs.month, localTs.day);

      if (itemDate.year == today.year &&
          itemDate.month == today.month &&
          itemDate.day == today.day) {
        todayItems.add(item);
      } else if (itemDate.year == yesterday.year &&
          itemDate.month == yesterday.month &&
          itemDate.day == yesterday.day) {
        yesterdayItems.add(item);
      } else {
        earlierItems.add(item);
      }
    }

    final widgets = <Widget>[];

    if (todayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(LanguageService.tr("Today"), isDark));
      widgets.addAll(todayItems.map((n) => _buildDismissibleNotificationCard(n, isDark, primaryColor)));
    }

    if (yesterdayItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(LanguageService.tr("Yesterday"), isDark));
      widgets.addAll(yesterdayItems.map((n) => _buildDismissibleNotificationCard(n, isDark, primaryColor)));
    }

    if (earlierItems.isNotEmpty) {
      widgets.add(_buildSectionHeader(LanguageService.tr("Earlier"), isDark));
      widgets.addAll(earlierItems.map((n) => _buildDismissibleNotificationCard(n, isDark, primaryColor)));
    }

    return widgets;
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w900,
          color: isDark ? Colors.white70 : Colors.grey.shade700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildDismissibleNotificationCard(
      AppNotification notification, bool isDark, Color primaryColor) {
    return Dismissible(
      key: Key(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _deleteNotification(notification),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: Colors.red.shade600,
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
      ),
      child: _buildNotificationCard(notification, isDark, primaryColor),
    );
  }

  Widget _buildNotificationCard(
      AppNotification notification, bool isDark, Color primaryColor) {
    final timeStr = DateFormat('h:mm a').format(notification.timestamp);
    final timeAgoStr = notification.timeAgo;

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
                      Row(
                        children: [
                          Text(
                            timeAgoStr,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white60 : Colors.grey.shade700,
                            ),
                          ),
                          Text(
                            " • $timeStr",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: isDark ? Colors.white38 : Colors.grey.shade500,
                            ),
                          ),
                        ],
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
