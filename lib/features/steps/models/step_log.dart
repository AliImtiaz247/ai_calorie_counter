import 'dart:convert';
import '../../../core/utils/health_calculator.dart';

class StepLog {
  final String id;
  final String userId;
  final String date; // YYYY-MM-DD
  final int steps;
  final int goal;
  final Map<int, int> hourlySteps; // hour (0-23) -> step count
  final int baselineSteps; // Raw cumulative sensor value at start of day
  final int lastSensorValue; // Latest raw cumulative sensor reading
  final String deviceId;
  final DateTime updatedAt;
  final String syncStatus; // 'synced', 'pending', 'syncing', 'failed'
  final double? customDistanceKm;
  final int? customCaloriesBurned;

  StepLog({
    required this.id,
    required this.userId,
    required this.date,
    required this.steps,
    this.goal = 10000,
    this.hourlySteps = const {},
    this.baselineSteps = 0,
    this.lastSensorValue = 0,
    this.deviceId = '',
    DateTime? updatedAt,
    this.syncStatus = 'synced',
    double? customDistanceKm,
    int? customCaloriesBurned,
  })  : updatedAt = updatedAt ?? DateTime.now(),
        customDistanceKm =
            (customDistanceKm != null && customDistanceKm > 0) ? customDistanceKm : null,
        customCaloriesBurned =
            (customCaloriesBurned != null && customCaloriesBurned > 0) ? customCaloriesBurned : null;

  /// Computed Distance in Kilometers (uses HealthCalculator or custom/stride default)
  double distanceKmWithProfile({double? heightCm}) {
    if (steps <= 0) return 0.0;
    if (customDistanceKm != null && customDistanceKm! > 0) {
      return customDistanceKm!;
    }
    return HealthCalculator.calculateStepDistance(steps, heightCm: heightCm);
  }

  double get distanceKm {
    if (steps <= 0) return 0.0;
    if (customDistanceKm != null && customDistanceKm! > 0) {
      return customDistanceKm!;
    }
    return (steps * 0.75) / 1000.0;
  }

  /// Computed Calories Burned (uses HealthCalculator or custom/weight default)
  int caloriesBurnedWithProfile({double? weightKg}) {
    if (steps <= 0) return 0;
    if (customCaloriesBurned != null && customCaloriesBurned! > 0) {
      return customCaloriesBurned!;
    }
    return HealthCalculator.calculateStepCalories(steps, weightKg: weightKg);
  }

  int get caloriesBurned {
    if (steps <= 0) return 0;
    if (customCaloriesBurned != null && customCaloriesBurned! > 0) {
      return customCaloriesBurned!;
    }
    return (steps * 0.045).round();
  }

  /// Goal completion percentage (0.0 to 1.0)
  double get completionPercentage =>
      goal > 0 ? (steps / goal).clamp(0.0, 1.0) : 0.0;

  Map<String, dynamic> toMap() {
    final hourlyMap = <String, int>{};
    hourlySteps.forEach((hour, count) {
      hourlyMap[hour.toString()] = count;
    });

    return {
      'id': id,
      'userId': userId,
      'date': date,
      'steps': steps,
      'goal': goal,
      'hourlySteps': hourlyMap,
      'baselineSteps': baselineSteps,
      'lastSensorValue': lastSensorValue,
      'deviceId': deviceId,
      'updatedAt': updatedAt.toIso8601String(),
      'syncStatus': syncStatus,
      'distanceKm': distanceKm,
      'caloriesBurned': caloriesBurned,
    };
  }

  factory StepLog.fromMap(Map<String, dynamic> map, String docId) {
    final rawHourly = map['hourlySteps'] as Map<String, dynamic>? ?? {};
    final hourlyMap = <int, int>{};

    rawHourly.forEach((key, value) {
      final hour = int.tryParse(key);
      if (hour != null) {
        hourlyMap[hour] = (value as num).toInt();
      }
    });

    DateTime parsedDate;
    try {
      parsedDate = map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'].toString())
          : DateTime.now();
    } catch (_) {
      parsedDate = DateTime.now();
    }

    final stepsCount = (map['steps'] as num?)?.toInt() ?? 0;

    return StepLog(
      id: docId,
      userId: map['userId']?.toString() ?? '',
      date: map['date']?.toString() ?? docId,
      steps: stepsCount,
      goal: (map['goal'] as num?)?.toInt() ?? 10000,
      hourlySteps: hourlyMap,
      baselineSteps: (map['baselineSteps'] as num?)?.toInt() ?? 0,
      lastSensorValue: (map['lastSensorValue'] as num?)?.toInt() ?? 0,
      deviceId: map['deviceId']?.toString() ?? '',
      updatedAt: parsedDate,
      syncStatus: map['syncStatus']?.toString() ?? 'synced',
      customDistanceKm: (map['distanceKm'] as num?)?.toDouble(),
      customCaloriesBurned: (map['caloriesBurned'] as num?)?.toInt(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory StepLog.fromJson(String jsonStr, String docId) =>
      StepLog.fromMap(jsonDecode(jsonStr) as Map<String, dynamic>, docId);

  StepLog copyWith({
    String? id,
    String? userId,
    String? date,
    int? steps,
    int? goal,
    Map<int, int>? hourlySteps,
    int? baselineSteps,
    int? lastSensorValue,
    String? deviceId,
    DateTime? updatedAt,
    String? syncStatus,
    double? customDistanceKm,
    int? customCaloriesBurned,
  }) {
    final nextSteps = steps ?? this.steps;
    return StepLog(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      date: date ?? this.date,
      steps: nextSteps,
      goal: goal ?? this.goal,
      hourlySteps: hourlySteps ?? this.hourlySteps,
      baselineSteps: baselineSteps ?? this.baselineSteps,
      lastSensorValue: lastSensorValue ?? this.lastSensorValue,
      deviceId: deviceId ?? this.deviceId,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      customDistanceKm: customDistanceKm ?? this.customDistanceKm,
      customCaloriesBurned: customCaloriesBurned ?? this.customCaloriesBurned,
    );
  }
}
