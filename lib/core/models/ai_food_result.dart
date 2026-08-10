import 'scan_usage.dart';

class AIFoodResult {
  final String foodName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double quantity;
  final double confidence;
  final String servingSize;
  final int healthyScore;
  final ScanUsage? scanUsage;

  const AIFoodResult({
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    required this.quantity,
    required this.confidence,
    required this.servingSize,
    required this.healthyScore,
    this.scanUsage,
  });

  factory AIFoodResult.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> food;

    if (json['foods'] is List && (json['foods'] as List).isNotEmpty) {
      final firstFood = (json['foods'] as List).first;
      food = firstFood is Map
          ? Map<String, dynamic>.from(firstFood)
          : <String, dynamic>{};
    } else {
      food = json;
    }

    final totals = json['totals'] is Map
        ? Map<String, dynamic>.from(json['totals'] as Map)
        : <String, dynamic>{};

    double numToDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is num) return value.toDouble();
      return double.tryParse(value.toString()) ?? 0.0;
    }

    ScanUsage? usage;

    if (json['scanUsage'] is Map) {
      usage = ScanUsage.fromJson(
        Map<String, dynamic>.from(json['scanUsage'] as Map),
      );
    } else if (json.containsKey('remainingScans') ||
        json.containsKey('dailyLimit') ||
        json.containsKey('quota') ||
        json.containsKey('usage')) {
      usage = ScanUsage.fromJson(json);
    }

    final healthyScoreValue = json['healthyScore'];
    final healthyScore = healthyScoreValue is num
        ? healthyScoreValue.toInt()
        : int.tryParse(healthyScoreValue?.toString() ?? '') ?? 80;

    return AIFoodResult(
      foodName: food['foodName']?.toString() ??
          food['name']?.toString() ??
          'Unknown Food',
      calories: numToDouble(totals['calories'] ?? food['calories']),
      protein: numToDouble(totals['protein'] ?? food['protein']),
      carbs: numToDouble(totals['carbs'] ?? food['carbs']),
      fat: numToDouble(totals['fat'] ?? food['fat']),
      fiber: numToDouble(totals['fiber'] ?? food['fiber']),
      quantity: numToDouble(
        food['estimatedWeight'] ?? food['quantity'] ?? 100,
      ),
      confidence: numToDouble(
        food['confidenceScore'] ?? food['confidence'] ?? 0.9,
      ),
      servingSize: food['servingSize']?.toString() ??
          '${food['estimatedWeight'] ?? 100} g',
      healthyScore: healthyScore,
      scanUsage: usage,
    );
  }
}
