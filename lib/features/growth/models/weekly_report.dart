import '../../../features/meals/models/meal.dart';

/// Aggregated seven-day nutrition data used by growth features.
///
/// This model intentionally contains only derived values so screens can render
/// reports without repeatedly querying Firestore.
class WeeklyReport {
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final double totalCalories;
  final double averageDailyCalories;
  final double totalProtein;
  final double averageDailyProtein;
  final double totalCarbs;
  final double averageDailyCarbs;
  final double totalFat;
  final double averageDailyFat;
  final int totalMeals;
  final int daysWithMeals;
  final int daysMeetingCalorieGoal;
  final int totalWater;
  final int averageDailyWater;
  final int daysMeetingWaterGoal;
  final Map<String, double> caloriesByDay;
  final Map<String, int> waterByDay;

  const WeeklyReport({
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.totalCalories,
    required this.averageDailyCalories,
    required this.totalProtein,
    required this.averageDailyProtein,
    required this.totalCarbs,
    required this.averageDailyCarbs,
    required this.totalFat,
    required this.averageDailyFat,
    required this.totalMeals,
    required this.daysWithMeals,
    required this.daysMeetingCalorieGoal,
    required this.totalWater,
    required this.averageDailyWater,
    required this.daysMeetingWaterGoal,
    required this.caloriesByDay,
    required this.waterByDay,
  });

  double get mealConsistency => days == 0 ? 0 : daysWithMeals / days;

  double get calorieGoalConsistency =>
      days == 0 ? 0 : daysMeetingCalorieGoal / days;

  double get waterGoalConsistency =>
      days == 0 ? 0 : daysMeetingWaterGoal / days;

  bool get hasData => totalMeals > 0 || totalWater > 0;

  factory WeeklyReport.empty({DateTime? endDate}) {
    final end = _dayOnly(endDate ?? DateTime.now());
    final start = end.subtract(const Duration(days: 6));
    final calories = <String, double>{};
    final water = <String, int>{};

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final key = _dateKey(day);
      calories[key] = 0;
      water[key] = 0;
    }

    return WeeklyReport(
      startDate: start,
      endDate: end,
      days: 7,
      totalCalories: 0,
      averageDailyCalories: 0,
      totalProtein: 0,
      averageDailyProtein: 0,
      totalCarbs: 0,
      averageDailyCarbs: 0,
      totalFat: 0,
      averageDailyFat: 0,
      totalMeals: 0,
      daysWithMeals: 0,
      daysMeetingCalorieGoal: 0,
      totalWater: 0,
      averageDailyWater: 0,
      daysMeetingWaterGoal: 0,
      caloriesByDay: calories,
      waterByDay: water,
    );
  }

  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static DateTime _dayOnly(DateTime date) =>
      DateTime(date.year, date.month, date.day);
}

/// Internal helper for constructing a report from already fetched data.
class WeeklyReportCalculator {
  const WeeklyReportCalculator._();

  static WeeklyReport calculate({
    required DateTime endDate,
    required List<Meal> meals,
    required Map<String, int> waterByDay,
    required double dailyCalorieGoal,
    required int dailyWaterGoal,
  }) {
    final end = DateTime(endDate.year, endDate.month, endDate.day);
    final start = end.subtract(const Duration(days: 6));

    final caloriesByDay = <String, double>{};
    final proteinByDay = <String, double>{};
    final carbsByDay = <String, double>{};
    final fatByDay = <String, double>{};

    for (var i = 0; i < 7; i++) {
      final day = start.add(Duration(days: i));
      final key = _key(day);
      caloriesByDay[key] = 0;
      proteinByDay[key] = 0;
      carbsByDay[key] = 0;
      fatByDay[key] = 0;
      waterByDay.putIfAbsent(key, () => 0);
    }

    for (final meal in meals) {
      final key = _key(meal.createdAt);
      if (!caloriesByDay.containsKey(key)) continue;
      caloriesByDay[key] = caloriesByDay[key]! + meal.calories;
      proteinByDay[key] = proteinByDay[key]! + meal.protein;
      carbsByDay[key] = carbsByDay[key]! + meal.carbs;
      fatByDay[key] = fatByDay[key]! + meal.fat;
    }

    final totalCalories = _sum(caloriesByDay.values);
    final totalProtein = _sum(proteinByDay.values);
    final totalCarbs = _sum(carbsByDay.values);
    final totalFat = _sum(fatByDay.values);
    final daysWithMeals = caloriesByDay.values.where((v) => v > 0).length;
    final calorieDays = dailyCalorieGoal > 0
        ? caloriesByDay.values
            .where((v) => v > 0 && v <= dailyCalorieGoal * 1.10)
            .length
        : 0;
    final waterTotal = waterByDay.values.fold<int>(0, (sum, value) => sum + value);
    final waterDays = dailyWaterGoal > 0
        ? waterByDay.values.where((v) => v >= dailyWaterGoal).length
        : 0;

    return WeeklyReport(
      startDate: start,
      endDate: end,
      days: 7,
      totalCalories: totalCalories,
      averageDailyCalories: totalCalories / 7,
      totalProtein: totalProtein,
      averageDailyProtein: totalProtein / 7,
      totalCarbs: totalCarbs,
      averageDailyCarbs: totalCarbs / 7,
      totalFat: totalFat,
      averageDailyFat: totalFat / 7,
      totalMeals: meals.length,
      daysWithMeals: daysWithMeals,
      daysMeetingCalorieGoal: calorieDays,
      totalWater: waterTotal,
      averageDailyWater: (waterTotal / 7).round(),
      daysMeetingWaterGoal: waterDays,
      caloriesByDay: caloriesByDay,
      waterByDay: waterByDay,
    );
  }

  static String _key(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static double _sum(Iterable<double> values) =>
      values.fold<double>(0, (sum, value) => sum + value);
}
