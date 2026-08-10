import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/models/user_profile.dart';
import '../../meals/data/meal_repository.dart';
import '../../meals/models/meal.dart';
import '../../water/data/water_repository.dart';
import '../models/weekly_report.dart';

/// Single data entry point for Phase 4 growth features.
///
/// It deliberately aggregates the last seven days with one meals query and
/// one water query. The resulting WeeklyReport can then be reused by insights,
/// streaks, achievements, recommendations and the progress dashboard.
class GrowthRepository {
  GrowthRepository._();

  static final GrowthRepository instance = GrowthRepository._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MealRepository _mealRepository = MealRepository.instance;
  final WaterRepository _waterRepository = WaterRepository();

  WeeklyReport? _weeklyCache;
  DateTime? _weeklyCacheEndDate;
  Future<WeeklyReport>? _inFlightWeeklyReport;

  WeeklyReport? get cachedWeeklyReport => _weeklyCache;

  String? get uid => FirebaseAuth.instance.currentUser?.uid;

  void clearCache() {
    _weeklyCache = null;
    _weeklyCacheEndDate = null;
    _inFlightWeeklyReport = null;
  }

  Future<WeeklyReport> getWeeklyReport({
    required UserProfile profile,
    bool forceRefresh = false,
  }) async {
    final end = _dayOnly(DateTime.now());

    if (!forceRefresh &&
        _weeklyCache != null &&
        _weeklyCacheEndDate == end) {
      return _weeklyCache!;
    }

    if (!forceRefresh && _inFlightWeeklyReport != null) {
      return _inFlightWeeklyReport!;
    }

    final future = _loadWeeklyReport(profile, end);
    _inFlightWeeklyReport = future;

    try {
      return await future;
    } finally {
      if (identical(_inFlightWeeklyReport, future)) {
        _inFlightWeeklyReport = null;
      }
    }
  }

  Future<WeeklyReport> _loadWeeklyReport(
    UserProfile profile,
    DateTime end,
  ) async {
    if (uid == null) return WeeklyReport.empty(endDate: end);

    // MealRepository already has its own daily cache. The seven-day query is
    // used here because a weekly report should require only one Firestore read
    // rather than seven separate daily reads.
    final mealFuture = _loadMealsForWeek(end);
    final waterFuture = _waterRepository.getWaterForLastDays(7);

    final results = await Future.wait<Object>([mealFuture, waterFuture]);
    final meals = results[0] as List<Meal>;
    final waterByDay = Map<String, int>.from(results[1] as Map<String, int>);

    final dailyCalories = _calculateDailyCalorieGoal(profile);

    final report = WeeklyReportCalculator.calculate(
      endDate: end,
      meals: meals,
      waterByDay: waterByDay,
      dailyCalorieGoal: dailyCalories,
      dailyWaterGoal: 3000,
    );

    _weeklyCache = report;
    _weeklyCacheEndDate = end;
    return report;
  }

  Future<List<Meal>> _loadMealsForWeek(DateTime end) async {
    final start = end.subtract(const Duration(days: 6));
    final query = await _firestore
        .collection('users')
        .doc(uid)
        .collection('meals')
        .where(
          'createdAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(start),
        )
        .where(
          'createdAt',
          isLessThan: Timestamp.fromDate(end.add(const Duration(days: 1))),
        )
        .orderBy('createdAt')
        .get();

    return query.docs.map((doc) => Meal.fromMap(doc.data())).toList();
  }

  double _calculateDailyCalorieGoal(UserProfile profile) {
    if (profile.age <= 0 || profile.height <= 0 || profile.currentWeight <= 0) {
      return 0;
    }

    final weight = profile.currentWeight;
    final height = profile.height;
    final age = profile.age;

    // Mifflin-St Jeor. The repository keeps this calculation local so reports
    // do not require an API request.
    final base = profile.gender.toLowerCase() == 'female'
        ? (10 * weight) + (6.25 * height) - (5 * age) - 161
        : (10 * weight) + (6.25 * height) - (5 * age) + 5;

    final activity = profile.activityLevel.toLowerCase();
    final multiplier = activity.contains('very')
        ? 1.725
        : activity.contains('high')
            ? 1.725
            : activity.contains('moderate')
                ? 1.55
                : activity.contains('light')
                    ? 1.375
                    : 1.2;

    final maintenance = base * multiplier;
    final goal = profile.goal.toLowerCase();

    if (goal.contains('lose') || goal.contains('loss')) {
      return maintenance - 400;
    }
    if (goal.contains('gain') || goal.contains('gain weight')) {
      return maintenance + 300;
    }
    return maintenance;
  }

  DateTime _dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}
