import 'package:flutter_test/flutter_test.dart';
import 'package:ai_calorie_counter/features/notifications/models/app_notification.dart';

void main() {
  group('AppNotification Tests', () {
    test('AppNotification serialization and deserialization', () {
      final now = DateTime.now();
      final notification = AppNotification(
        id: 'test_123',
        userId: 'user_1',
        type: 'goal',
        title: 'Goal Complete!',
        message: 'You reached 10,000 steps!',
        timestamp: now,
        isRead: false,
        category: 'steps',
        createdAt: now,
        goalType: 'step',
        goalTarget: 10000,
        goalProgress: 10000,
      );

      final map = notification.toMap();
      expect(map['id'], equals('test_123'));
      expect(map['title'], equals('Goal Complete!'));
      expect(map['category'], equals('steps'));

      final jsonStr = notification.toJson();
      final decoded = AppNotification.fromJson(jsonStr);

      expect(decoded.id, equals(notification.id));
      expect(decoded.title, equals(notification.title));
      expect(decoded.message, equals(notification.message));
      expect(decoded.category, equals(notification.category));
    });

    test('AppNotification relative timeAgo formatting', () {
      final now = DateTime.now();
      final recent = AppNotification(
        id: 'test_recent',
        userId: 'user_1',
        type: 'system',
        title: 'Recent',
        message: 'Hello',
        timestamp: now,
        category: 'system',
        createdAt: now,
      );

      expect(recent.timeAgo, equals('Just now'));

      final fiveMinsAgo = AppNotification(
        id: 'test_5m',
        userId: 'user_1',
        type: 'system',
        title: 'Five mins ago',
        message: 'Hello',
        timestamp: now.subtract(const Duration(minutes: 5)),
        category: 'system',
        createdAt: now,
      );

      expect(fiveMinsAgo.timeAgo, equals('5m ago'));
    });
  });
}
