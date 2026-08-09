import 'package:flutter/material.dart';

class MacroBreakdown {
  final int proteinGrams;
  final int carbsGrams;
  final int fatGrams;
  final int totalCalories;

  const MacroBreakdown({
    required this.proteinGrams,
    required this.carbsGrams,
    required this.fatGrams,
    required this.totalCalories,
  });
}

class HealthCalculator {
  /// Calculate BMI (Body Mass Index)
  static double calculateBMI({required double weight, required double height}) {
    if (height <= 0) return 0;
    final h = height / 100;
    return weight / (h * h);
  }

  /// Get category for BMI
  static String bmiCategory(double bmi) {
    if (bmi < 18.5) return "Underweight";
    if (bmi < 25.0) return "Normal Weight";
    if (bmi < 30.0) return "Overweight";
    return "Obese";
  }

  /// Get color theme for BMI category
  static Color bmiColor(double bmi) {
    if (bmi < 18.5) return Colors.amber;
    if (bmi < 25.0) return const Color(0xFF22C55E); // Emerald Green
    if (bmi < 30.0) return Colors.orange;
    return Colors.redAccent;
  }

  /// Ideal Weight Range (based on BMI 18.5 - 24.9)
  static Map<String, double> idealWeightRange(double height) {
    if (height <= 0) return {'min': 0, 'max': 0};
    final h = height / 100;
    return {
      'min': 18.5 * h * h,
      'max': 24.9 * h * h,
    };
  }

  /// Calculate BMR using Mifflen-St Jeor Equation
  static double calculateBMR({
    required int age,
    required double height,
    required double weight,
    required String gender,
  }) {
    final g = gender.trim().toLowerCase();
    if (g == "female") {
      return (10 * weight) + (6.25 * height) - (5 * age) - 161;
    } else if (g == "other") {
      return (10 * weight) + (6.25 * height) - (5 * age) - 78;
    } else {
      return (10 * weight) + (6.25 * height) - (5 * age) + 5;
    }
  }

  /// Get Activity level multiplier
  static double activityMultiplier(String activity) {
    switch (activity.toLowerCase()) {
      case "sedentary":
      case "sedentary (little to no exercise)":
        return 1.2;

      case "lightly active":
      case "lightly active (1-3 days/week)":
        return 1.375;

      case "moderately active":
      case "moderately active (3-5 days/week)":
        return 1.55;

      case "very active":
      case "very active (6-7 days/week)":
        return 1.725;

      case "extra active":
      case "extra active (hard exercise & job)":
        return 1.9;

      default:
        return 1.375;
    }
  }

  /// Calculate TDEE (Total Daily Energy Expenditure)
  static double calculateTDEE({
    required double bmr,
    required String activity,
  }) {
    return bmr * activityMultiplier(activity);
  }

  /// Calculate Daily Calorie Goal based on TDEE and Goal
  static int calculateDailyCalories({
    required double bmr,
    required String activity,
    required String goal,
  }) {
    final tdee = calculateTDEE(bmr: bmr, activity: activity);
    final normalizedGoal = goal.toLowerCase();

    if (normalizedGoal.contains("lose")) {
      return (tdee - 500).round();
    } else if (normalizedGoal.contains("gain")) {
      return (tdee + 400).round();
    }
    return tdee.round();
  }

  /// Calculate recommended Macro Breakdown
  static MacroBreakdown calculateMacros(int targetCalories) {
    // Standard healthy ratio: 30% Protein, 40% Carbs, 30% Fat
    final proteinCalories = targetCalories * 0.30;
    final carbsCalories = targetCalories * 0.40;
    final fatCalories = targetCalories * 0.30;

    return MacroBreakdown(
      proteinGrams: (proteinCalories / 4).round(),
      carbsGrams: (carbsCalories / 4).round(),
      fatGrams: (fatCalories / 9).round(),
      totalCalories: targetCalories,
    );
  }

  /// Calculate Walking Distance in Kilometers based on Step Count and User Height
  static double calculateStepDistance(int steps, {double? heightCm}) {
    if (steps <= 0) return 0.0;
    final strideMeters = (heightCm != null && heightCm > 50)
        ? (heightCm * 0.414) / 100.0
        : 0.75;
    final totalMeters = steps * strideMeters;
    return totalMeters / 1000.0;
  }

  /// Calculate Active Calories Burned based on Step Count and User Weight
  static int calculateStepCalories(int steps, {double? weightKg}) {
    if (steps <= 0) return 0;
    final w = (weightKg != null && weightKg > 20) ? weightKg : 70.0;
    // Standard walking energy expenditure (~0.00057 kcal per step per kg body weight)
    final kcalPerStep = w * 0.00057;
    return (steps * kcalPerStep).round();
  }
}
