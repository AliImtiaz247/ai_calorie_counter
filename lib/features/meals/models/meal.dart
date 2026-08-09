import 'package:cloud_firestore/cloud_firestore.dart';

class Meal {
  final String id;
  final String userId;

  final String mealType;
  final String foodName;

  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  final double quantity;

  final DateTime createdAt;

  Meal({
    required this.id,
    required this.userId,
    required this.mealType,
    required this.foodName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.quantity,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      "id": id,
      "userId": userId,
      "mealType": mealType,
      "foodName": foodName,
      "calories": calories,
      "protein": protein,
      "carbs": carbs,
      "fat": fat,
      "quantity": quantity,
      "createdAt": Timestamp.fromDate(createdAt),
    };
  }

  factory Meal.fromMap(Map<String, dynamic> map) {
    return Meal(
      id: map["id"],
      userId: map["userId"],
      mealType: map["mealType"],
      foodName: map["foodName"],
      calories: (map["calories"] as num).toDouble(),
      protein: (map["protein"] as num).toDouble(),
      carbs: (map["carbs"] as num).toDouble(),
      fat: (map["fat"] as num).toDouble(),
      quantity: (map["quantity"] as num).toDouble(),
      createdAt: map["createdAt"].toDate(),
    );
  }
}
