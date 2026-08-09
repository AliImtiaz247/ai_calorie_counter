class DailyMealSummary {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;

  final double breakfast;
  final double lunch;
  final double dinner;
  final double snacks;

  const DailyMealSummary({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.breakfast,
    required this.lunch,
    required this.dinner,
    required this.snacks,
  });

  factory DailyMealSummary.empty() {
    return const DailyMealSummary(
      calories: 0,
      protein: 0,
      carbs: 0,
      fat: 0,
      breakfast: 0,
      lunch: 0,
      dinner: 0,
      snacks: 0,
    );
  }
}