import 'dart:convert';

class AppNotification {
  final String id;
  final String userId;
  final String type; // 'goal', 'achievement', 'activity', 'sync', 'system'
  final String title;
  final String message;
  final DateTime timestamp;
  final bool isRead;
  final String category;
  final String? relatedEntityId;
  final DateTime createdAt;
  final bool synced;

  final String? goalType; // 'step', 'calorie', 'water', 'weight'
  final num? goalTarget;
  final num? goalProgress;
  final DateTime? readAt;

  const AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.category,
    this.relatedEntityId,
    required this.createdAt,
    this.synced = false,
    this.goalType,
    this.goalTarget,
    this.goalProgress,
    this.readAt,
  });

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? message,
    DateTime? timestamp,
    bool? isRead,
    String? category,
    String? relatedEntityId,
    DateTime? createdAt,
    bool? synced,
    String? goalType,
    num? goalTarget,
    num? goalProgress,
    DateTime? readAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      message: message ?? this.message,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
      category: category ?? this.category,
      relatedEntityId: relatedEntityId ?? this.relatedEntityId,
      createdAt: createdAt ?? this.createdAt,
      synced: synced ?? this.synced,
      goalType: goalType ?? this.goalType,
      goalTarget: goalTarget ?? this.goalTarget,
      goalProgress: goalProgress ?? this.goalProgress,
      readAt: readAt ?? this.readAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'notificationId': id,
      'userId': userId,
      'type': type,
      'title': title,
      'message': message,
      'timestamp': timestamp.toIso8601String(),
      'isRead': isRead,
      'category': category,
      'relatedEntityId': relatedEntityId,
      'createdAt': createdAt.toIso8601String(),
      'synced': synced,
      if (goalType != null) 'goalType': goalType,
      if (goalTarget != null) 'goalTarget': goalTarget,
      if (goalProgress != null) 'goalProgress': goalProgress,
      if (readAt != null) 'readAt': readAt!.toIso8601String(),
    };
  }

  factory AppNotification.fromMap(Map<String, dynamic> map, [String? docId]) {
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) {
        return DateTime.tryParse(value) ?? DateTime.now();
      }
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate();
      }
      return DateTime.now();
    }

    DateTime? parseNullableDateTime(dynamic value) {
      if (value == null) return null;
      if (value is String) {
        return DateTime.tryParse(value);
      }
      if (value.runtimeType.toString().contains('Timestamp')) {
        return (value as dynamic).toDate();
      }
      return null;
    }

    final id = docId ?? map['notificationId'] ?? map['id'] ?? '';

    return AppNotification(
      id: id,
      userId: map['userId'] ?? 'local',
      type: map['type'] ?? 'system',
      title: map['title'] ?? '',
      message: map['message'] ?? '',
      timestamp: parseDateTime(map['timestamp']),
      isRead: map['isRead'] ?? false,
      category: map['category'] ?? 'general',
      relatedEntityId: map['relatedEntityId'],
      createdAt: parseDateTime(map['createdAt']),
      synced: map['synced'] ?? false,
      goalType: map['goalType'],
      goalTarget: map['goalTarget'] is num ? map['goalTarget'] : num.tryParse(map['goalTarget']?.toString() ?? ''),
      goalProgress: map['goalProgress'] is num ? map['goalProgress'] : num.tryParse(map['goalProgress']?.toString() ?? ''),
      readAt: parseNullableDateTime(map['readAt']),
    );
  }

  String toJson() => json.encode(toMap());

  factory AppNotification.fromJson(String source) =>
      AppNotification.fromMap(json.decode(source));
}
